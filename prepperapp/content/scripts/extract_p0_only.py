#!/usr/bin/env python3
"""
Extract only Priority 0 (critical) medical articles from Wikipedia Medical ZIM file
This is for creating a minimal mobile deployment (<400MB target)
"""

import argparse
import json
import sys
from pathlib import Path
from extract_all_final import SearchBasedZIMExtractor

class P0OnlyExtractor(SearchBasedZIMExtractor):
    """Modified extractor that only processes P0 keywords"""
    
    def load_keywords(self):
        """Load only P0 keywords"""
        # First load all keywords normally
        all_keywords = super().load_keywords()
        
        # Then filter to only P0
        p0_only = {0: all_keywords[0], 1: [], 2: []}
        
        print(f"P0-only extraction mode:")
        print(f"  Processing {len(p0_only[0])} critical keywords only")
        print(f"  Skipping P1 ({len(all_keywords[1])}) and P2 ({len(all_keywords[2])}) keywords")
        
        # Update stats
        self.stats["total_keywords"] = len(p0_only[0])
        
        return p0_only

def main():
    parser = argparse.ArgumentParser(description='Extract P0 medical articles only')
    parser.add_argument('zim_file', help='Path to Wikipedia medical ZIM file')
    parser.add_argument('--keywords', default='../medical_priorities.txt',
                       help='Path to keywords file (default: ../medical_priorities.txt)')
    parser.add_argument('--data-dir', type=Path, 
                       default=Path(__file__).resolve().parent.parent.parent / 'data',
                       help='Path to data directory')
    parser.add_argument('--output-suffix', default='p0',
                       help='Suffix for output files (default: p0)')
    
    args = parser.parse_args()
    
    # Verify ZIM file exists
    if not Path(args.zim_file).exists():
        print(f"Error: ZIM file not found: {args.zim_file}")
        sys.exit(1)
    
    # Create extractor with custom output paths
    extractor = P0OnlyExtractor(args.keywords, args.data_dir)
    
    # Override output paths to use P0 suffix
    extractor.output_dir = args.data_dir / f"processed-{args.output_suffix}"
    extractor.output_dir.mkdir(parents=True, exist_ok=True)
    
    extractor.jsonl_path = extractor.output_dir / f"articles-{args.output_suffix}.jsonl"
    extractor.sqlite_path = extractor.output_dir / f"content-{args.output_suffix}.sqlite"
    extractor.manifest_path = extractor.output_dir / f"extraction_manifest-{args.output_suffix}.json"
    
    try:
        # Process ZIM file using search (no limit - get all P0)
        import time
        start_time = time.time()
        extractor.search_articles_by_keywords(args.zim_file)
        extractor.stats["processing_time_seconds"] = time.time() - start_time
        
        # Save manifest
        extractor.save_manifest()
        
        # Print summary
        extractor.print_summary()
        
        print(f"\nP0-only output files:")
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