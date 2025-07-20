#!/usr/bin/env python3
"""
Extract medical articles from Wikipedia Medical ZIM file using Search API
Final version: Uses libzim 3.7.0 Search API since the ZIM has full-text index
"""

import argparse
import json
import re
import sys
import sqlite3
import zstandard as zstd
from pathlib import Path
from datetime import datetime
import hashlib
from typing import List, Dict, Tuple, Optional, Set
from tqdm import tqdm
import time

try:
    import libzim.reader
    from libzim.search import Query, Searcher
except ImportError:
    print("Error: libzim not installed. Please run: pip3 install libzim")
    sys.exit(1)

try:
    import zstandard
except ImportError:
    print("Error: zstandard not installed. Please run: pip3 install zstandard")
    sys.exit(1)

class SearchBasedZIMExtractor:
    def __init__(self, keywords_file: str, data_dir: Path):
        self.keywords_file = Path(keywords_file)
        self.data_dir = data_dir
        self.extracted_count = 0
        
        # Output paths
        self.output_dir = self.data_dir / "processed"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.jsonl_path = self.output_dir / "articles.jsonl"
        self.sqlite_path = self.output_dir / "content.sqlite"
        self.manifest_path = self.output_dir / "extraction_manifest.json"
        
        # Zstandard compressor for content
        self.compressor = zstd.ZstdCompressor(level=3)  # Fast compression
        
        # Initialize stats before loading keywords
        self.stats = {
            "total_keywords": 0,
            "keywords_searched": 0,
            "total_search_results": 0,
            "unique_articles": 0,
            "extracted_by_priority": {0: 0, 1: 0, 2: 0},
            "total_content_size": 0,
            "compressed_content_size": 0,
            "errors": 0,
            "search_time_seconds": 0,
            "processing_time_seconds": 0
        }
        
        # Load keywords after stats is initialized
        self.keywords_by_priority = self.load_keywords()
    
    def load_keywords(self) -> Dict[int, List[str]]:
        """Load keywords from file, organized by priority"""
        keywords_by_priority = {0: [], 1: [], 2: []}
        
        with open(self.keywords_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                parts = line.split('|')
                if len(parts) == 2:
                    keyword = parts[0].strip().lower()
                    priority = int(parts[1])
                    keywords_by_priority[priority].append(keyword)
        
        print(f"Loaded keywords:")
        total = 0
        for priority, keywords in keywords_by_priority.items():
            print(f"  Priority {priority}: {len(keywords)} keywords")
            total += len(keywords)
        self.stats["total_keywords"] = total
        
        return keywords_by_priority
    
    def init_content_store(self):
        """Initialize SQLite database for content storage"""
        conn = sqlite3.connect(self.sqlite_path)
        cursor = conn.cursor()
        
        # Create table if not exists
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS articles (
                id TEXT PRIMARY KEY NOT NULL,
                content BLOB NOT NULL
            )
        ''')
        
        # Create index on id for fast lookups
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_articles_id ON articles(id)')
        
        conn.commit()
        return conn
    
    def determine_priority(self, path: str, keywords_found: Set[str]) -> Tuple[int, List[str]]:
        """Determine article priority based on which keywords were found"""
        # Check which priority keywords were matched
        for priority in [0, 1, 2]:
            priority_keywords = [kw for kw in keywords_found 
                               if kw in self.keywords_by_priority[priority]]
            if priority_keywords:
                return priority, priority_keywords[:5]  # Return first 5 matching keywords
        
        # This shouldn't happen if we found the article via search
        return 2, list(keywords_found)[:5]
    
    def clean_content(self, content: str) -> str:
        """Clean Wikipedia formatting from content"""
        # Remove Wikipedia templates
        content = re.sub(r'\{\{[^}]+\}\}', '', content)
        # Remove [[links|display]]
        content = re.sub(r'\[\[([^|\]]+)\|([^\]]+)\]\]', r'\2', content)
        # Remove [[links]]
        content = re.sub(r'\[\[([^\]]+)\]\]', r'\1', content)
        # Remove references <ref>...</ref>
        content = re.sub(r'<ref[^>]*>.*?</ref>', '', content, flags=re.DOTALL)
        # Remove other HTML tags
        content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL)
        content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL)
        # Clean up multiple spaces
        content = re.sub(r'\s+', ' ', content)
        
        return content.strip()
    
    def extract_article(self, entry, keywords_found: Set[str], 
                       jsonl_file, content_conn) -> bool:
        """Extract article and write to both JSONL and SQLite"""
        try:
            # Get the item from the entry
            item = entry.get_item()
            
            # Get article title and path
            title = entry.title
            path = entry.path
            
            # Skip if not an HTML article
            if not item.mimetype.startswith('text/html'):
                return False
            
            # Get article content - use content property which returns memoryview
            content_memview = item.content
            content_bytes = bytes(content_memview)
            content = content_bytes.decode('utf-8', errors='ignore')
            
            # Clean content
            cleaned_content = self.clean_content(content)
            
            # Determine priority based on matched keywords
            priority, matched_keywords = self.determine_priority(path, keywords_found)
            
            # Generate summary (first 300 chars of cleaned content)
            summary = re.sub(r'<[^>]+>', '', cleaned_content)[:300]
            if len(cleaned_content) > 300:
                summary += "..."
            
            # Generate article ID
            article_id = hashlib.md5(f"{priority}:{title}".encode()).hexdigest()[:12]
            
            # Write to JSONL (for indexing)
            article_data = {
                "id": article_id,
                "title": title,
                "summary": summary,
                "content": cleaned_content,  # Full content for indexing
                "priority": priority,
                "keywords": matched_keywords
            }
            jsonl_file.write(json.dumps(article_data) + '\n')
            
            # Compress content for storage
            content_bytes = cleaned_content.encode('utf-8')
            compressed_content = self.compressor.compress(content_bytes)
            
            # Write to SQLite (for content retrieval)
            cursor = content_conn.cursor()
            cursor.execute('INSERT OR REPLACE INTO articles (id, content) VALUES (?, ?)',
                         (article_id, compressed_content))
            
            # Update stats
            self.stats["total_content_size"] += len(content_bytes)
            self.stats["compressed_content_size"] += len(compressed_content)
            self.stats["extracted_by_priority"][priority] += 1
            
            return True
            
        except Exception as e:
            print(f"\nError extracting {entry.title}: {e}")
            self.stats["errors"] += 1
            return False
    
    def search_articles_by_keywords(self, zim_path: str, limit: Optional[int] = None):
        """Search for articles matching medical keywords using full-text search"""
        print(f"\nOpening ZIM file: {zim_path}")
        
        # Open ZIM archive
        archive = libzim.reader.Archive(zim_path)
        
        # Verify it has full-text index
        if not archive.has_fulltext_index:
            print("ERROR: This ZIM file does not have a full-text index!")
            print("Cannot use search-based extraction. Consider using zimdump instead.")
            sys.exit(1)
        
        print(f"✓ ZIM file has full-text index")
        print(f"Total entries: {archive.all_entry_count:,}")
        print(f"Article entries: {archive.article_count:,}")
        
        # Initialize outputs
        jsonl_file = open(self.jsonl_path, 'w', encoding='utf-8')
        content_conn = self.init_content_store()
        
        # Track unique articles to avoid duplicates
        processed_paths = set()
        
        # Create searcher
        searcher = Searcher(archive)
        
        try:
            search_start = time.time()
            
            # Iterate through all keywords
            all_keywords = []
            for priority in [0, 1, 2]:  # Process in priority order
                all_keywords.extend([(kw, priority) for kw in self.keywords_by_priority[priority]])
            
            # Use tqdm for keyword progress
            for keyword, priority in tqdm(all_keywords, desc="Searching keywords"):
                self.stats["keywords_searched"] += 1
                
                # Create query for this keyword
                query = Query().set_query(keyword)
                
                try:
                    # Perform search
                    search = searcher.search(query)
                    estimated_matches = search.getEstimatedMatches()
                    
                    if estimated_matches > 0:
                        # Get all results for this keyword
                        # Note: For very common terms, you might want to limit this
                        results = search.getResults(0, min(estimated_matches, 1000))
                        
                        # Count results (since len() doesn't work on SearchResultSet)
                        result_count = 0
                        paths_to_process = []
                        
                        # Collect paths from results
                        for result in results:
                            result_count += 1
                            # Result is a string path when iterating SearchResultSet
                            path = result
                            paths_to_process.append(path)
                        
                        self.stats["total_search_results"] += result_count
                        
                        # Process each path
                        for path in paths_to_process:
                            # Skip if already processed
                            if path in processed_paths:
                                continue
                            
                            # Mark as processed
                            processed_paths.add(path)
                            self.stats["unique_articles"] += 1
                            
                            # Get the entry
                            try:
                                entry = archive.get_entry_by_path(path)
                                
                                # Extract the article
                                if self.extract_article(entry, {keyword}, jsonl_file, content_conn):
                                    self.extracted_count += 1
                                    
                                    # Commit periodically
                                    if self.extracted_count % 100 == 0:
                                        content_conn.commit()
                                        
                                        # Update progress
                                        if self.extracted_count % 1000 == 0:
                                            tqdm.write(f"Extracted: {self.extracted_count} | "
                                                     f"P0: {self.stats['extracted_by_priority'][0]} | "
                                                     f"P1: {self.stats['extracted_by_priority'][1]} | "
                                                     f"P2: {self.stats['extracted_by_priority'][2]}")
                                    
                                    # Check limit
                                    if limit and self.extracted_count >= limit:
                                        print(f"\nReached extraction limit of {limit} articles")
                                        return
                                        
                            except Exception as e:
                                print(f"\nError getting entry for path {path}: {e}")
                                self.stats["errors"] += 1
                
                except Exception as e:
                    print(f"\nError searching for keyword '{keyword}': {e}")
                    self.stats["errors"] += 1
            
            self.stats["search_time_seconds"] = time.time() - search_start
            
        finally:
            # Close outputs
            jsonl_file.close()
            content_conn.commit()
            content_conn.close()
    
    def save_manifest(self):
        """Save extraction manifest with statistics"""
        # Get file sizes
        jsonl_size = self.jsonl_path.stat().st_size if self.jsonl_path.exists() else 0
        sqlite_size = self.sqlite_path.stat().st_size if self.sqlite_path.exists() else 0
        
        manifest = {
            "extraction_info": {
                "date": datetime.now().isoformat(),
                "keywords_file": str(self.keywords_file),
                "extraction_method": "search-based",
                "article_count": self.extracted_count,
                "search_time_seconds": self.stats.get("search_time_seconds", 0),
                "statistics": self.stats
            },
            "output_files": {
                "jsonl_path": str(self.jsonl_path),
                "jsonl_size_mb": jsonl_size / (1024 * 1024),
                "sqlite_path": str(self.sqlite_path),
                "sqlite_size_mb": sqlite_size / (1024 * 1024),
                "compression_ratio": (self.stats["compressed_content_size"] / 
                                    max(self.stats["total_content_size"], 1))
            }
        }
        
        with open(self.manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print(f"\n✓ Saved manifest: {self.manifest_path}")
    
    def print_summary(self):
        """Print extraction summary"""
        print("\n=== Extraction Summary ===")
        print(f"Total keywords: {self.stats['total_keywords']}")
        print(f"Keywords searched: {self.stats['keywords_searched']}")
        print(f"Total search results: {self.stats['total_search_results']:,}")
        print(f"Unique articles found: {self.stats['unique_articles']:,}")
        print(f"Articles extracted: {self.extracted_count:,}")
        if self.stats["errors"] > 0:
            print(f"Errors encountered: {self.stats['errors']:,}")
        
        print("\nBy priority:")
        for priority in [0, 1, 2]:
            count = self.stats['extracted_by_priority'][priority]
            pct = (count / max(self.extracted_count, 1)) * 100
            print(f"  Priority {priority}: {count:,} articles ({pct:.1f}%)")
        
        print(f"\nCompression stats:")
        original_mb = self.stats["total_content_size"] / (1024 * 1024)
        compressed_mb = self.stats["compressed_content_size"] / (1024 * 1024)
        ratio = self.stats["compressed_content_size"] / max(self.stats["total_content_size"], 1)
        print(f"  Original content size: {original_mb:.1f} MB")
        print(f"  Compressed size: {compressed_mb:.1f} MB")
        print(f"  Compression ratio: {ratio:.2%}")
        
        if self.stats["search_time_seconds"] > 0:
            minutes = self.stats["search_time_seconds"] / 60
            print(f"\nSearch time: {minutes:.1f} minutes")

def main():
    parser = argparse.ArgumentParser(description='Extract medical articles from ZIM file using search')
    parser.add_argument('zim_file', help='Path to Wikipedia medical ZIM file')
    parser.add_argument('--keywords', default='../medical_priorities.txt',
                       help='Path to keywords file (default: ../medical_priorities.txt)')
    parser.add_argument('--data-dir', type=Path, 
                       default=Path(__file__).resolve().parent.parent.parent / 'data',
                       help='Path to data directory')
    parser.add_argument('--limit', type=int, help='Limit number of articles to extract')
    
    args = parser.parse_args()
    
    # Verify ZIM file exists
    if not Path(args.zim_file).exists():
        print(f"Error: ZIM file not found: {args.zim_file}")
        sys.exit(1)
    
    # Create extractor
    extractor = SearchBasedZIMExtractor(args.keywords, args.data_dir)
    
    try:
        # Process ZIM file using search
        start_time = time.time()
        extractor.search_articles_by_keywords(args.zim_file, args.limit)
        extractor.stats["processing_time_seconds"] = time.time() - start_time
        
        # Save manifest
        extractor.save_manifest()
        
        # Print summary
        extractor.print_summary()
        
        print(f"\nOutput files:")
        print(f"  JSONL for indexing: {extractor.jsonl_path}")
        print(f"  SQLite content store: {extractor.sqlite_path}")
        print(f"  Extraction manifest: {extractor.manifest_path}")
        
    except KeyboardInterrupt:
        print("\n\nInterrupted!")
        extractor.print_summary()
    except Exception as e:
        print(f"\nError during extraction: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()