#!/usr/bin/env python3
"""
Process downloaded content into PrepperApp format
Extracts, categorizes, and prioritizes survival information
"""

import json
import hashlib
from pathlib import Path
from datetime import datetime
import re

# Content categories with priority weights
CATEGORIES = {
    "medical": {
        "priority_base": 5,
        "keywords": ["bleeding", "wound", "injury", "first aid", "CPR", "shock", "trauma", "emergency", "tourniquet"]
    },
    "water": {
        "priority_base": 5,
        "keywords": ["water", "purification", "dehydration", "filter", "boil", "drinking", "hydration"]
    },
    "shelter": {
        "priority_base": 4,
        "keywords": ["shelter", "hypothermia", "cold", "heat", "protection", "insulation", "windbreak"]
    },
    "fire": {
        "priority_base": 4,
        "keywords": ["fire", "warmth", "cooking", "signal", "friction", "spark", "tinder", "fuel"]
    },
    "food": {
        "priority_base": 3,
        "keywords": ["food", "edible", "poisonous", "hunting", "fishing", "foraging", "nutrition"]
    },
    "navigation": {
        "priority_base": 3,
        "keywords": ["navigation", "compass", "map", "direction", "north", "landmark", "GPS"]
    },
    "communication": {
        "priority_base": 2,
        "keywords": ["radio", "signal", "emergency", "rescue", "communication", "frequency"]
    }
}

class ContentProcessor:
    def __init__(self):
        self.processed_dir = Path("../processed")
        self.core_dir = self.processed_dir / "core"
        self.modules_dir = self.processed_dir / "modules"
        self.index_dir = Path("../indexes")
        
        # Create directories
        for dir in [self.core_dir, self.modules_dir, self.index_dir]:
            dir.mkdir(parents=True, exist_ok=True)
        
        self.articles = []
        self.stats = {
            "total_articles": 0,
            "categories": {},
            "priority_distribution": {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
        }
    
    def generate_id(self, title, category):
        """Generate unique article ID"""
        # Clean title for ID
        clean_title = re.sub(r'[^a-zA-Z0-9]', '_', title.lower())
        clean_title = re.sub(r'_+', '_', clean_title).strip('_')
        
        # Create ID: category-first_3_words-hash
        words = clean_title.split('_')[:3]
        title_part = '_'.join(words)
        
        # Add short hash for uniqueness
        hash_input = f"{category}:{title}".encode()
        short_hash = hashlib.md5(hash_input).hexdigest()[:6]
        
        return f"{category}-{title_part}-{short_hash}"
    
    def categorize_content(self, title, content):
        """Determine category based on content analysis"""
        title_lower = title.lower()
        content_lower = content.lower()[:1000]  # Check first 1000 chars
        
        scores = {}
        for category, config in CATEGORIES.items():
            score = 0
            for keyword in config["keywords"]:
                # Title matches are worth more
                score += title_lower.count(keyword) * 3
                score += content_lower.count(keyword)
            scores[category] = score
        
        # Get category with highest score
        if scores:
            best_category = max(scores, key=scores.get)
            if scores[best_category] > 0:
                return best_category
        
        return "general"
    
    def calculate_priority(self, title, content, category):
        """Calculate article priority (1-5)"""
        base_priority = CATEGORIES.get(category, {}).get("priority_base", 2)
        
        # Boost priority for critical keywords
        critical_keywords = ["emergency", "immediate", "life-threatening", "severe", "critical"]
        boost = 0
        
        content_sample = (title + " " + content[:500]).lower()
        for keyword in critical_keywords:
            if keyword in content_sample:
                boost = 1
                break
        
        return min(5, base_priority + boost)
    
    def extract_summary(self, content, max_length=200):
        """Extract or generate article summary"""
        # Try to find first paragraph
        paragraphs = content.split('\n\n')
        for para in paragraphs:
            para = para.strip()
            if len(para) > 50:  # Skip very short paragraphs
                # Clean and truncate
                summary = re.sub(r'\s+', ' ', para)
                if len(summary) > max_length:
                    summary = summary[:max_length-3] + "..."
                return summary
        
        # Fallback: use beginning of content
        summary = re.sub(r'\s+', ' ', content[:max_length])
        return summary + "..."
    
    def process_wikipedia_article(self, title, content):
        """Process a Wikipedia medical article"""
        # Remove Wikipedia formatting
        content = re.sub(r'\[\[([^\]]+)\]\]', r'\1', content)  # [[links]]
        content = re.sub(r'\{\{[^}]+\}\}', '', content)  # {{templates}}
        content = re.sub(r'<[^>]+>', '', content)  # HTML tags
        
        category = self.categorize_content(title, content)
        priority = self.calculate_priority(title, content, category)
        summary = self.extract_summary(content)
        
        article = {
            "id": self.generate_id(title, category),
            "title": title,
            "category": category,
            "priority": priority,
            "summary": summary,
            "content": content,
            "source": "wikipedia_medical",
            "processed_date": datetime.now().isoformat()
        }
        
        return article
    
    def process_military_manual_section(self, manual_id, chapter, title, content):
        """Process a section from military manual"""
        category = self.categorize_content(title, content)
        priority = self.calculate_priority(title, content, category)
        summary = self.extract_summary(content)
        
        article = {
            "id": self.generate_id(f"{manual_id}_{title}", category),
            "title": f"{title} ({manual_id})",
            "category": category,
            "priority": priority,
            "summary": summary,
            "content": content,
            "source": f"military_{manual_id}",
            "chapter": chapter,
            "processed_date": datetime.now().isoformat()
        }
        
        return article
    
    def save_article_batch(self, articles, batch_name):
        """Save a batch of articles to JSON"""
        output_file = self.core_dir / f"{batch_name}.json"
        
        with open(output_file, 'w') as f:
            json.dump({
                "batch_info": {
                    "name": batch_name,
                    "article_count": len(articles),
                    "generated": datetime.now().isoformat()
                },
                "articles": articles
            }, f, indent=2)
        
        print(f"✓ Saved {len(articles)} articles to {output_file}")
        
        # Update stats
        for article in articles:
            category = article['category']
            priority = article['priority']
            
            self.stats['total_articles'] += 1
            self.stats['categories'][category] = self.stats['categories'].get(category, 0) + 1
            self.stats['priority_distribution'][priority] += 1
    
    def create_tantivy_import_file(self):
        """Create file ready for Tantivy indexing"""
        # Combine all articles
        all_articles = []
        
        for json_file in self.core_dir.glob("*.json"):
            with open(json_file, 'r') as f:
                data = json.load(f)
                all_articles.extend(data['articles'])
        
        # Create JSONL file for efficient streaming
        import_file = self.index_dir / "articles_for_indexing.jsonl"
        
        with open(import_file, 'w') as f:
            for article in all_articles:
                # Write one article per line
                f.write(json.dumps(article) + '\n')
        
        print(f"✓ Created Tantivy import file: {import_file}")
        print(f"  Total articles: {len(all_articles)}")
        
        return import_file
    
    def generate_report(self):
        """Generate processing report"""
        report_path = self.processed_dir / "processing_report.json"
        
        report = {
            "generated": datetime.now().isoformat(),
            "statistics": self.stats,
            "recommendations": []
        }
        
        # Add recommendations based on stats
        if self.stats['total_articles'] < 50:
            report['recommendations'].append("Need more content for effective search")
        
        medical_count = self.stats['categories'].get('medical', 0)
        if medical_count < 10:
            report['recommendations'].append("Insufficient medical content - this is critical")
        
        high_priority = self.stats['priority_distribution'][4] + self.stats['priority_distribution'][5]
        if high_priority < self.stats['total_articles'] * 0.3:
            report['recommendations'].append("Need more high-priority survival content")
        
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"\n✓ Processing report saved: {report_path}")
        print("\nContent Statistics:")
        print(f"  Total articles: {self.stats['total_articles']}")
        print("\n  Categories:")
        for cat, count in sorted(self.stats['categories'].items()):
            print(f"    {cat}: {count}")
        print("\n  Priority distribution:")
        for priority in range(5, 0, -1):
            count = self.stats['priority_distribution'][priority]
            print(f"    Priority {priority}: {count} articles")

def main():
    """Main processing pipeline"""
    print("=== PrepperApp Content Processor ===\n")
    
    processor = ContentProcessor()
    
    # Example: Process some sample content
    # In reality, this would read from downloaded files
    
    sample_articles = [
        {
            "title": "Controlling Severe Bleeding",
            "content": """Severe bleeding is a life-threatening emergency that requires immediate action. 
            Apply direct pressure to the wound using a clean cloth or gauze. If bleeding continues, 
            use a tourniquet 2-3 inches above the wound. Never apply a tourniquet directly on a joint.
            Write the time of application on the tourniquet. Seek immediate medical help."""
        },
        {
            "title": "Emergency Water Purification",
            "content": """In survival situations, clean water is critical. Boiling is the most reliable method - 
            bring water to a rolling boil for at least 1 minute (3 minutes above 6,500 feet). 
            Water purification tablets are effective but require 30 minutes. UV purifiers work quickly 
            but need clear water. Always filter debris first before purifying."""
        },
        {
            "title": "Building Emergency Shelters",
            "content": """Hypothermia can kill in hours. Your first priority is getting out of wind and rain. 
            Find natural windbreaks like rock formations or dense trees. Insulate yourself from the ground 
            using branches, leaves, or any available material. Build the smallest shelter possible to 
            conserve body heat. Never sleep directly on cold ground or snow."""
        }
    ]
    
    # Process sample articles
    processed = []
    for article_data in sample_articles:
        article = processor.process_wikipedia_article(
            article_data['title'],
            article_data['content']
        )
        processed.append(article)
    
    # Save batch
    processor.save_article_batch(processed, "sample_survival_basics")
    
    # Create import file
    import_file = processor.create_tantivy_import_file()
    
    # Generate report
    processor.generate_report()
    
    print("\n✅ Content processing complete!")
    print("\nNext steps:")
    print(f"1. Index with Tantivy: cargo run --bin index_builder {import_file}")
    print("2. Copy indexes to app: cp -r ../indexes ../../ios/Resources/")

if __name__ == "__main__":
    main()