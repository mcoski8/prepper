#!/usr/bin/env python3
"""
Extract all medical articles from Wikipedia Medical ZIM file
Builds both JSONL for indexing and SQLite content store
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
from typing import List, Dict, Tuple, Optional
from tqdm import tqdm
import time

try:
    import libzim
except ImportError:
    print("Error: libzim not installed. Please run: pip3 install libzim")
    sys.exit(1)

try:
    import zstandard
except ImportError:
    print("Error: zstandard not installed. Please run: pip3 install zstandard")
    sys.exit(1)

class UnifiedZIMExtractor:
    def __init__(self, keywords_file: str, data_dir: Path):
        self.keywords_file = Path(keywords_file)
        self.data_dir = data_dir
        self.keywords_by_priority = self.load_keywords()
        self.extracted_count = 0
        
        # Output paths
        self.output_dir = self.data_dir / "processed"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.jsonl_path = self.output_dir / "articles.jsonl"
        self.sqlite_path = self.output_dir / "content.sqlite"
        self.manifest_path = self.output_dir / "extraction_manifest.json"
        
        # Zstandard compressor for content
        self.compressor = zstd.ZstdCompressor(level=3)  # Fast compression
        
        self.stats = {
            "total_scanned": 0,
            "extracted_by_priority": {0: 0, 1: 0, 2: 0},
            "rejected": 0,
            "redirects_skipped": 0,
            "total_content_size": 0,
            "compressed_content_size": 0
        }
    
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
        for priority, keywords in keywords_by_priority.items():
            print(f"  Priority {priority}: {len(keywords)} keywords")
        
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
    
    def assess_priority(self, title: str, content_preview: str) -> Tuple[int, List[str]]:
        """Assess article priority based on keywords in title and content"""
        title_lower = title.lower()
        content_lower = content_preview.lower()
        
        matched_keywords = []
        
        # Check each priority level (0 is highest)
        for priority in [0, 1, 2]:
            for keyword in self.keywords_by_priority[priority]:
                if keyword in title_lower or keyword in content_lower:
                    matched_keywords.append(keyword)
                    if priority == 0:  # Critical keywords get immediate priority
                        return priority, matched_keywords
        
        # Return lowest matched priority
        if matched_keywords:
            for priority in [0, 1, 2]:
                for keyword in self.keywords_by_priority[priority]:
                    if keyword in matched_keywords:
                        return priority, matched_keywords
        
        return -1, []  # No match
    
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
    
    def extract_article(self, item, priority: int, matched_keywords: List[str], 
                       jsonl_file, content_conn) -> bool:
        """Extract article and write to both JSONL and SQLite"""
        try:
            # Get article content
            content = bytes(item.content).decode('utf-8', errors='ignore')
            
            # Clean content
            cleaned_content = self.clean_content(content)
            
            # Generate summary (first 300 chars of cleaned content)
            summary = re.sub(r'<[^>]+>', '', cleaned_content)[:300]
            if len(cleaned_content) > 300:
                summary += "..."
            
            # Generate article ID
            article_id = hashlib.md5(f"{priority}:{item.title}".encode()).hexdigest()[:12]
            
            # Write to JSONL (for indexing)
            article_data = {
                "id": article_id,
                "title": item.title,
                "summary": summary,
                "content": cleaned_content,  # Full content for indexing
                "priority": priority,
                "keywords": matched_keywords[:5]  # Limit keywords
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
            
            return True
            
        except Exception as e:
            print(f"\nError extracting {item.title}: {e}")
            return False
    
    def process_zim_file(self, zim_path: str, limit: Optional[int] = None):
        """Process ZIM file and extract all matching articles"""
        print(f"\nOpening ZIM file: {zim_path}")
        start_time = time.time()
        
        # Initialize outputs
        jsonl_file = open(self.jsonl_path, 'w', encoding='utf-8')
        content_conn = self.init_content_store()
        
        try:
            zim = libzim.Archive(zim_path)
            print(f"ZIM file opened. Total entries: {zim.all_entry_count:,}")
            print(f"  Articles: {zim.article_count:,}")
            
            # Use tqdm for progress bar
            # Note: libzim doesn't support direct iteration, need to use entry access
            for i in tqdm(range(zim.all_entry_count), desc="Scanning ZIM entries"):
                try:
                    entry = zim.get_entry_by_id(i)
                except:
                    # Some entries might not be accessible by ID
                    continue
                    self.stats["total_scanned"] += 1
                    
                    # Skip redirects
                    if entry.is_redirect:
                        self.stats["redirects_skipped"] += 1
                        continue
                    
                    # Skip non-article entries
                    if not entry.path.startswith('A/'):
                        continue
                    
                    # Get item from entry
                    try:
                        item = entry.get_item()
                    except:
                        continue
                    
                    # Get content preview for assessment
                    try:
                        content_preview = bytes(item.content).decode('utf-8', errors='ignore')
                        content_preview = content_preview[:2000]  # First 2KB
                    except:
                        continue
                    
                    # Assess priority
                    priority, matched_keywords = self.assess_priority(
                        item.title, 
                        content_preview
                    )
                    
                    if priority >= 0:
                        # Extract article
                        if self.extract_article(item, priority, matched_keywords, 
                                              jsonl_file, content_conn):
                            self.stats["extracted_by_priority"][priority] += 1
                            self.extracted_count += 1
                            
                            # Commit to SQLite periodically
                            if self.extracted_count % 100 == 0:
                                content_conn.commit()
                                
                                # Update progress
                                if self.extracted_count % 1000 == 0:
                                    tqdm.write(f"Extracted: {self.extracted_count} | "
                                             f"P0: {self.stats['extracted_by_priority'][0]} | "
                                             f"P1: {self.stats['extracted_by_priority'][1]} | "
                                             f"P2: {self.stats['extracted_by_priority'][2]}")
                    else:
                        self.stats["rejected"] += 1
                    
                    # Check limit
                    if limit and self.extracted_count >= limit:
                        print(f"\nReached extraction limit of {limit} articles")
                        break
        
        finally:
            # Close outputs
            jsonl_file.close()
            content_conn.commit()
            content_conn.close()
            
            # Record timing
            self.stats["extraction_time_seconds"] = time.time() - start_time
    
    def save_manifest(self):
        """Save extraction manifest with statistics"""
        # Get file sizes
        jsonl_size = self.jsonl_path.stat().st_size if self.jsonl_path.exists() else 0
        sqlite_size = self.sqlite_path.stat().st_size if self.sqlite_path.exists() else 0
        
        manifest = {
            "extraction_info": {
                "date": datetime.now().isoformat(),
                "keywords_file": str(self.keywords_file),
                "article_count": self.extracted_count,
                "extraction_time_seconds": self.stats.get("extraction_time_seconds", 0),
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
        print(f"Total entries scanned: {self.stats['total_scanned']:,}")
        print(f"Redirects skipped: {self.stats['redirects_skipped']:,}")
        print(f"Articles extracted: {self.extracted_count:,}")
        
        print("\nBy priority:")
        for priority in [0, 1, 2]:
            count = self.stats['extracted_by_priority'][priority]
            pct = (count / max(self.extracted_count, 1)) * 100
            print(f"  Priority {priority}: {count:,} articles ({pct:.1f}%)")
        
        print(f"\nRejected (no keyword match): {self.stats['rejected']:,}")
        
        print(f"\nCompression stats:")
        original_mb = self.stats["total_content_size"] / (1024 * 1024)
        compressed_mb = self.stats["compressed_content_size"] / (1024 * 1024)
        ratio = self.stats["compressed_content_size"] / max(self.stats["total_content_size"], 1)
        print(f"  Original content size: {original_mb:.1f} MB")
        print(f"  Compressed size: {compressed_mb:.1f} MB")
        print(f"  Compression ratio: {ratio:.2%}")
        
        if "extraction_time_seconds" in self.stats:
            minutes = self.stats["extraction_time_seconds"] / 60
            rate = self.extracted_count / max(self.stats["extraction_time_seconds"], 1)
            print(f"\nExtraction time: {minutes:.1f} minutes ({rate:.0f} articles/sec)")

def main():
    parser = argparse.ArgumentParser(description='Extract medical articles from ZIM file')
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
    extractor = UnifiedZIMExtractor(args.keywords, args.data_dir)
    
    try:
        # Process ZIM file
        extractor.process_zim_file(args.zim_file, args.limit)
        
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