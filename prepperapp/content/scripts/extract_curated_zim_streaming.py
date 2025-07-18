#!/usr/bin/env python3
"""
Extract curated articles from Wikipedia Medical ZIM file with streaming and checkpointing
Uses priority keywords to select most critical survival medical content
"""

import argparse
import json
import re
import sys
import subprocess
from pathlib import Path
from datetime import datetime
import hashlib
from typing import List, Dict, Tuple, Optional
from tqdm import tqdm

try:
    import libzim
except ImportError:
    print("Error: libzim not installed. Please run: pip3 install libzim")
    sys.exit(1)

class StreamingZIMExtractor:
    def __init__(self, keywords_file: str, batch_size: int = 1000):
        self.keywords_file = Path(keywords_file)
        self.batch_size = batch_size
        self.keywords_by_priority = self.load_keywords()
        self.extracted_count = 0
        self.batch_count = 0
        self.output_dir = Path("../processed/curated")
        self.temp_dir = Path("../temp/batches")
        self.index_dir = Path("../indexes/tantivy")
        
        # Create directories
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.temp_dir.mkdir(parents=True, exist_ok=True)
        self.index_dir.mkdir(parents=True, exist_ok=True)
        
        self.stats = {
            "total_scanned": 0,
            "extracted_by_priority": {0: 0, 1: 0, 2: 0},
            "rejected": 0,
            "redirects_skipped": 0,
            "batch_errors": 0
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
    
    def get_last_processed_uuid(self) -> Optional[str]:
        """Load checkpoint to resume processing"""
        state_file = self.output_dir / "processing_state.json"
        if state_file.exists():
            with open(state_file, 'r') as f:
                state = json.load(f)
                return state.get("last_processed_uuid")
        return None
    
    def save_progress(self, last_processed_uuid: str):
        """Save checkpoint after successful batch processing"""
        state_file = self.output_dir / "processing_state.json"
        state = {
            "last_processed_uuid": last_processed_uuid,
            "timestamp": datetime.now().isoformat(),
            "extracted_count": self.extracted_count,
            "batch_count": self.batch_count,
            "stats": self.stats
        }
        with open(state_file, 'w') as f:
            json.dump(state, f, indent=2)
    
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
        # Remove other HTML tags (but preserve structure for later use)
        # We'll keep some structure for medical diagrams extraction
        content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL)
        content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL)
        # Clean up multiple spaces
        content = re.sub(r'\s+', ' ', content)
        
        return content.strip()
    
    def extract_article_data(self, item, priority: int, matched_keywords: List[str]) -> Optional[Dict]:
        """Extract article data for JSON output (not files)"""
        try:
            # Get article content
            content = bytes(item.content).decode('utf-8', errors='ignore')
            
            # Clean content
            cleaned_content = self.clean_content(content)
            
            # Generate summary (first 300 chars of cleaned content)
            summary = re.sub(r'<[^>]+>', '', cleaned_content)[:300]
            if len(cleaned_content) > 300:
                summary += "..."
            
            # Create article metadata
            article_id = hashlib.md5(f"{priority}:{item.title}".encode()).hexdigest()[:12]
            
            article_data = {
                "id": article_id,
                "title": item.title,
                "summary": summary,
                "content": cleaned_content,  # Full content for indexing
                "priority": priority,
                "keywords": matched_keywords[:5]  # Limit keywords to top 5
            }
            
            return article_data
            
        except Exception as e:
            print(f"\nError extracting {item.title}: {e}")
            return None
    
    def process_batch(self, articles: List[Dict], batch_num: int):
        """Write batch to JSONL and call Rust indexer"""
        batch_file = self.temp_dir / f"batch_{batch_num:04d}.jsonl"
        print(f"\nProcessing batch {batch_num} with {len(articles)} articles...")
        
        # Write batch to JSONL
        with open(batch_file, 'w', encoding='utf-8') as f:
            for article in articles:
                f.write(json.dumps(article) + '\n')
        
        # Call the Rust indexer (assuming it's built and in PATH)
        cmd = [
            'tantivy-indexer',
            '--index', str(self.index_dir),
            '--input', str(batch_file),
            '--threads', '2',  # Use 2 threads for mobile optimization
            '--heap-size', '300'  # 300MB heap
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✓ Successfully indexed batch {batch_num}")
                # Delete batch file after successful indexing
                batch_file.unlink()
            else:
                print(f"✗ Error indexing batch {batch_num}: {result.stderr}")
                self.stats["batch_errors"] += 1
                # Keep batch file for debugging/retry
        except FileNotFoundError:
            print(f"✗ tantivy-indexer not found. Please build it first.")
            print(f"  Batch saved to: {batch_file}")
            self.stats["batch_errors"] += 1
        except Exception as e:
            print(f"✗ Error running indexer: {e}")
            self.stats["batch_errors"] += 1
    
    def process_zim_file(self, zim_path: str, limit: Optional[int] = None):
        """Process ZIM file with streaming and checkpointing"""
        print(f"\nOpening ZIM file: {zim_path}")
        
        # Load checkpoint
        last_uuid = self.get_last_processed_uuid()
        found_start_point = not last_uuid
        
        if last_uuid:
            print(f"Resuming from checkpoint: {last_uuid}")
            # Load previous stats
            state_file = self.output_dir / "processing_state.json"
            if state_file.exists():
                with open(state_file, 'r') as f:
                    state = json.load(f)
                    self.stats = state.get("stats", self.stats)
                    self.extracted_count = state.get("extracted_count", 0)
                    self.batch_count = state.get("batch_count", 0)
        
        batch_articles = []
        last_processed_uuid = None
        
        with libzim.Archive(zim_path) as zim:
            print(f"ZIM file opened. Total entries: {len(zim)}")
            
            # Use tqdm for progress bar
            for entry in tqdm(zim, total=len(zim), desc="Scanning ZIM entries"):
                # Skip to checkpoint if resuming
                if not found_start_point:
                    if hasattr(entry, 'uuid') and entry.uuid == last_uuid:
                        found_start_point = True
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
                    # Extract article data
                    article_data = self.extract_article_data(
                        item, priority, matched_keywords
                    )
                    
                    if article_data:
                        batch_articles.append(article_data)
                        self.stats["extracted_by_priority"][priority] += 1
                        self.extracted_count += 1
                        
                        # Store UUID for checkpoint
                        if hasattr(entry, 'uuid'):
                            last_processed_uuid = entry.uuid
                else:
                    self.stats["rejected"] += 1
                
                # Process batch when full
                if len(batch_articles) >= self.batch_size:
                    self.batch_count += 1
                    self.process_batch(batch_articles, self.batch_count)
                    
                    # Save checkpoint
                    if last_processed_uuid:
                        self.save_progress(str(last_processed_uuid))
                    
                    # Reset for next batch
                    batch_articles = []
                    
                    # Update progress bar description
                    tqdm.write(f"Extracted: {self.extracted_count} | "
                             f"P0: {self.stats['extracted_by_priority'][0]} | "
                             f"P1: {self.stats['extracted_by_priority'][1]} | "
                             f"P2: {self.stats['extracted_by_priority'][2]}")
                
                # Check limit
                if limit and self.extracted_count >= limit:
                    print(f"\nReached extraction limit of {limit} articles")
                    break
        
        # Process remaining articles in final batch
        if batch_articles:
            self.batch_count += 1
            self.process_batch(batch_articles, self.batch_count)
            if last_processed_uuid:
                self.save_progress(str(last_processed_uuid))
    
    def save_final_manifest(self):
        """Save final extraction manifest"""
        manifest = {
            "extraction_info": {
                "date": datetime.now().isoformat(),
                "keywords_file": str(self.keywords_file),
                "article_count": self.extracted_count,
                "batch_count": self.batch_count,
                "statistics": self.stats
            },
            "index_info": {
                "index_path": str(self.index_dir),
                "batch_size": self.batch_size,
                "total_batches": self.batch_count
            }
        }
        
        manifest_file = self.output_dir / "final_manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print(f"\n✓ Saved final manifest: {manifest_file}")
    
    def print_summary(self):
        """Print extraction summary"""
        print("\n=== Extraction Summary ===")
        print(f"Total entries scanned: {self.stats['total_scanned']}")
        print(f"Redirects skipped: {self.stats['redirects_skipped']}")
        print(f"Articles extracted: {self.extracted_count}")
        print(f"Batches processed: {self.batch_count}")
        if self.stats["batch_errors"] > 0:
            print(f"Batch errors: {self.stats['batch_errors']}")
        print("\nBy priority:")
        for priority in [0, 1, 2]:
            count = self.stats['extracted_by_priority'][priority]
            print(f"  Priority {priority}: {count} articles")
        print(f"\nRejected (no keyword match): {self.stats['rejected']}")

def main():
    parser = argparse.ArgumentParser(description='Extract and index curated medical articles from ZIM file')
    parser.add_argument('zim_file', help='Path to Wikipedia medical ZIM file')
    parser.add_argument('--keywords', default='../medical_priorities.txt',
                       help='Path to keywords file (default: ../medical_priorities.txt)')
    parser.add_argument('--batch-size', type=int, default=1000,
                       help='Number of articles per batch (default: 1000)')
    parser.add_argument('--limit', type=int, help='Limit number of articles to extract')
    parser.add_argument('--reset', action='store_true',
                       help='Reset checkpoint and start from beginning')
    
    args = parser.parse_args()
    
    # Verify ZIM file exists
    if not Path(args.zim_file).exists():
        print(f"Error: ZIM file not found: {args.zim_file}")
        sys.exit(1)
    
    # Create extractor
    extractor = StreamingZIMExtractor(args.keywords, args.batch_size)
    
    # Reset checkpoint if requested
    if args.reset:
        state_file = extractor.output_dir / "processing_state.json"
        if state_file.exists():
            state_file.unlink()
            print("✓ Checkpoint reset")
    
    try:
        # Process ZIM file
        extractor.process_zim_file(args.zim_file, args.limit)
        
        # Save final manifest
        extractor.save_final_manifest()
        
        # Print summary
        extractor.print_summary()
        
    except KeyboardInterrupt:
        print("\n\nInterrupted! Progress has been saved.")
        print("Run again to resume from checkpoint.")
        extractor.print_summary()
    except Exception as e:
        print(f"\nError during extraction: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()