#!/usr/bin/env python3
"""
Extract curated articles from Wikipedia Medical ZIM file
Uses priority keywords to select most critical survival medical content
"""

import argparse
import json
import re
import sys
from pathlib import Path
from datetime import datetime
import hashlib
import subprocess
import shutil
from typing import List, Dict, Tuple, Set

try:
    import pyzim
except ImportError:
    print("Error: pyzim not installed. Please run: pip3 install pyzim")
    sys.exit(1)

class CuratedZIMExtractor:
    def __init__(self, keywords_file: str, limit: int = None):
        self.keywords_file = Path(keywords_file)
        self.limit = limit
        self.keywords_by_priority = self.load_keywords()
        self.extracted_count = 0
        self.temp_dir = Path("temp_extracted")
        self.output_dir = Path("../processed/curated")
        
        # Create directories
        self.temp_dir.mkdir(exist_ok=True)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.stats = {
            "total_scanned": 0,
            "extracted_by_priority": {0: 0, 1: 0, 2: 0},
            "rejected": 0,
            "redirects_skipped": 0
        }
    
    def load_keywords(self) -> Dict[int, List[Tuple[str, int]]]:
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
        content = re.sub(r'<[^>]+>', '', content)
        # Clean up multiple spaces
        content = re.sub(r'\s+', ' ', content)
        
        return content.strip()
    
    def extract_article(self, zim_file, entry, priority: int, matched_keywords: List[str]) -> Dict:
        """Extract and process a single article"""
        try:
            # Get article content
            content = entry.read()
            if isinstance(content, bytes):
                content = content.decode('utf-8', errors='ignore')
            
            # Clean content
            cleaned_content = self.clean_content(content)
            
            # Generate summary (first 200 chars of cleaned content)
            summary = cleaned_content[:200]
            if len(cleaned_content) > 200:
                summary += "..."
            
            # Create article metadata
            article_id = hashlib.md5(f"{priority}:{entry.title}".encode()).hexdigest()[:12]
            
            article_data = {
                "id": article_id,
                "title": entry.title,
                "url": entry.url,
                "priority": priority,
                "matched_keywords": matched_keywords,
                "summary": summary,
                "content_length": len(cleaned_content),
                "extracted_date": datetime.now().isoformat()
            }
            
            # Save content to temp directory
            article_path = self.temp_dir / f"{article_id}.html"
            with open(article_path, 'w', encoding='utf-8') as f:
                f.write(f"<html><head><title>{entry.title}</title></head><body>")
                f.write(f"<h1>{entry.title}</h1>")
                f.write(cleaned_content)
                f.write("</body></html>")
            
            return article_data
            
        except Exception as e:
            print(f"Error extracting {entry.title}: {e}")
            return None
    
    def process_zim_file(self, zim_path: str) -> List[Dict]:
        """Process ZIM file and extract curated articles"""
        print(f"\nOpening ZIM file: {zim_path}")
        
        extracted_articles = []
        
        with pyzim.Zim.open(zim_path) as zim:
            print(f"ZIM file opened. Starting extraction...")
            
            # Iterate through entries
            for entry in zim.entries():
                self.stats["total_scanned"] += 1
                
                # Progress indicator
                if self.stats["total_scanned"] % 1000 == 0:
                    print(f"  Scanned {self.stats['total_scanned']} entries...")
                
                # Skip redirects
                if entry.is_redirect:
                    self.stats["redirects_skipped"] += 1
                    continue
                
                # Skip non-article entries
                if not entry.url.startswith('A/'):
                    continue
                
                # Get resolved entry
                try:
                    resolved_entry = entry.resolve()
                except:
                    resolved_entry = entry
                
                # Get content preview for assessment
                try:
                    content_preview = resolved_entry.read()
                    if isinstance(content_preview, bytes):
                        content_preview = content_preview.decode('utf-8', errors='ignore')
                    content_preview = content_preview[:2000]  # First 2KB
                except:
                    continue
                
                # Assess priority
                priority, matched_keywords = self.assess_priority(
                    resolved_entry.title, 
                    content_preview
                )
                
                if priority >= 0:
                    # Extract article
                    article_data = self.extract_article(
                        zim, resolved_entry, priority, matched_keywords
                    )
                    
                    if article_data:
                        extracted_articles.append(article_data)
                        self.stats["extracted_by_priority"][priority] += 1
                        self.extracted_count += 1
                        
                        print(f"✓ Extracted [{priority}]: {resolved_entry.title}")
                        print(f"  Keywords: {', '.join(matched_keywords[:3])}")
                        
                        # Check limit
                        if self.limit and self.extracted_count >= self.limit:
                            print(f"\nReached extraction limit of {self.limit} articles")
                            break
                else:
                    self.stats["rejected"] += 1
        
        return extracted_articles
    
    def create_curated_zim(self, articles: List[Dict], output_name: str):
        """Create new ZIM file with curated content using zimwriterfs"""
        print(f"\nCreating curated ZIM file...")
        
        # Check if zimwriterfs is available
        if not shutil.which('zimwriterfs'):
            print("Warning: zimwriterfs not found. Please install it to create ZIM files.")
            print("Articles have been extracted to:", self.temp_dir)
            return None
        
        # Create metadata file
        metadata = {
            "Title": f"PrepperApp Medical Survival Guide",
            "Description": "Curated emergency medical content for offline survival situations",
            "Creator": "PrepperApp Content Pipeline",
            "Publisher": "PrepperApp",
            "Date": datetime.now().strftime("%Y-%m-%d"),
            "Language": "eng",
            "Tags": "medical;survival;emergency;first-aid;offline",
            "Source": "Wikipedia Medical",
            "Article_Count": str(len(articles))
        }
        
        metadata_file = self.temp_dir / "metadata.txt"
        with open(metadata_file, 'w') as f:
            for key, value in metadata.items():
                f.write(f"{key}={value}\n")
        
        # Create welcome page
        welcome_file = self.temp_dir / "index.html"
        with open(welcome_file, 'w') as f:
            f.write("""<html>
<head><title>PrepperApp Medical Guide</title></head>
<body>
<h1>PrepperApp Emergency Medical Guide</h1>
<p>This curated collection contains critical medical information for emergency situations.</p>
<h2>Priority 0 - Life-Threatening Emergencies</h2>
<ul>
""")
            for article in sorted(articles, key=lambda x: (x['priority'], x['title'])):
                if article['priority'] == 0:
                    f.write(f'<li><a href="{article["id"]}.html">{article["title"]}</a></li>\n')
            f.write("</ul>\n<h2>Priority 1 - Important Procedures</h2>\n<ul>")
            for article in articles:
                if article['priority'] == 1:
                    f.write(f'<li><a href="{article["id"]}.html">{article["title"]}</a></li>\n')
            f.write("</ul>\n</body>\n</html>")
        
        # Run zimwriterfs
        output_file = self.output_dir / f"{output_name}.zim"
        cmd = [
            'zimwriterfs',
            '--welcome', 'index.html',
            '--metadata', 'metadata.txt',
            '--name', 'prepperapp_medical',
            '--output', str(output_file),
            str(self.temp_dir)
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"✓ Created curated ZIM: {output_file}")
                return output_file
            else:
                print(f"Error creating ZIM: {result.stderr}")
                return None
        except Exception as e:
            print(f"Error running zimwriterfs: {e}")
            return None
    
    def save_manifest(self, articles: List[Dict], zim_file: Path):
        """Save extraction manifest with metadata"""
        manifest = {
            "extraction_info": {
                "date": datetime.now().isoformat(),
                "keywords_file": str(self.keywords_file),
                "article_count": len(articles),
                "statistics": self.stats
            },
            "content_info": {
                "zim_file": str(zim_file) if zim_file else None,
                "temp_html_dir": str(self.temp_dir),
                "articles_by_priority": {
                    "0": sum(1 for a in articles if a['priority'] == 0),
                    "1": sum(1 for a in articles if a['priority'] == 1),
                    "2": sum(1 for a in articles if a['priority'] == 2)
                }
            },
            "articles": articles
        }
        
        manifest_file = self.output_dir / "extraction_manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print(f"✓ Saved manifest: {manifest_file}")
    
    def cleanup(self):
        """Clean up temporary files"""
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
            print("✓ Cleaned up temporary files")
    
    def print_summary(self):
        """Print extraction summary"""
        print("\n=== Extraction Summary ===")
        print(f"Total entries scanned: {self.stats['total_scanned']}")
        print(f"Redirects skipped: {self.stats['redirects_skipped']}")
        print(f"Articles extracted: {self.extracted_count}")
        print("\nBy priority:")
        for priority in [0, 1, 2]:
            count = self.stats['extracted_by_priority'][priority]
            print(f"  Priority {priority}: {count} articles")
        print(f"\nRejected (no keyword match): {self.stats['rejected']}")

def main():
    parser = argparse.ArgumentParser(description='Extract curated medical articles from ZIM file')
    parser.add_argument('zim_file', help='Path to Wikipedia medical ZIM file')
    parser.add_argument('--keywords', default='../medical_priorities.txt',
                       help='Path to keywords file (default: ../medical_priorities.txt)')
    parser.add_argument('--limit', type=int, help='Limit number of articles to extract')
    parser.add_argument('--output-name', default='curated_medical',
                       help='Name for output ZIM file (default: curated_medical)')
    parser.add_argument('--keep-temp', action='store_true',
                       help='Keep temporary extracted files')
    
    args = parser.parse_args()
    
    # Verify ZIM file exists
    if not Path(args.zim_file).exists():
        print(f"Error: ZIM file not found: {args.zim_file}")
        sys.exit(1)
    
    # Create extractor
    extractor = CuratedZIMExtractor(args.keywords, args.limit)
    
    try:
        # Extract articles
        articles = extractor.process_zim_file(args.zim_file)
        
        if articles:
            # Create curated ZIM
            zim_file = extractor.create_curated_zim(articles, args.output_name)
            
            # Save manifest
            extractor.save_manifest(articles, zim_file)
            
            # Print summary
            extractor.print_summary()
            
            # Cleanup
            if not args.keep_temp:
                extractor.cleanup()
        else:
            print("\nNo articles extracted!")
            
    except Exception as e:
        print(f"\nError during extraction: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()