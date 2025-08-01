#!/usr/bin/env python3
"""
PDF Processor for PrepperApp Content Extraction
Extracts text, structure, and metadata from survival PDFs
"""

import json
import logging
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pdfplumber
from PIL import Image
from tqdm import tqdm

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class PDFProcessor:
    """Extract and structure content from survival PDFs"""
    
    def __init__(self, pdf_path: str, output_dir: str = "./extracted"):
        self.pdf_path = Path(pdf_path)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Create subdirectories
        self.images_dir = self.output_dir / "images" / self.pdf_path.stem
        self.images_dir.mkdir(parents=True, exist_ok=True)
        
        self.metadata = {
            "source_pdf": self.pdf_path.name,
            "extracted_date": datetime.now().isoformat(),
            "total_pages": 0,
            "chapters": [],
            "search_index": {
                "terms": [],
                "pages": []
            }
        }
    
    def extract_text_and_structure(self) -> Dict:
        """Extract text content and identify document structure"""
        logger.info(f"Processing PDF: {self.pdf_path}")
        
        try:
            with pdfplumber.open(self.pdf_path) as pdf:
                self.metadata["total_pages"] = len(pdf.pages)
                
                current_chapter = None
                chapters = []
                
                # Process each page
                for page_num, page in enumerate(tqdm(pdf.pages, desc="Extracting pages")):
                    page_number = page_num + 1
                    
                    # Extract text
                    text = page.extract_text() or ""
                    
                    # Simple chapter detection (looking for headers)
                    chapter_title = self._detect_chapter(text, page_number)
                    
                    if chapter_title:
                        # Save previous chapter if exists
                        if current_chapter:
                            chapters.append(current_chapter)
                        
                        # Start new chapter
                        current_chapter = {
                            "title": chapter_title,
                            "page_start": page_number,
                            "page_end": page_number,
                            "content": text,
                            "keywords": [],
                            "images": [],
                            "quick_reference": "",
                            "emergency_priority": "medium"  # Default, needs human review
                        }
                    elif current_chapter:
                        # Continue current chapter
                        current_chapter["content"] += "\n\n" + text
                        current_chapter["page_end"] = page_number
                    else:
                        # No chapter detected yet, create a default one
                        current_chapter = {
                            "title": f"Section {page_number}",
                            "page_start": page_number,
                            "page_end": page_number,
                            "content": text,
                            "keywords": [],
                            "images": [],
                            "quick_reference": "",
                            "emergency_priority": "medium"
                        }
                    
                    # Extract tables if present
                    tables = page.extract_tables()
                    if tables:
                        logger.info(f"Found {len(tables)} table(s) on page {page_number}")
                        for i, table in enumerate(tables):
                            if current_chapter:
                                current_chapter["content"] += f"\n\n[TABLE {i+1}]\n"
                                current_chapter["content"] += self._format_table(table)
                
                # Don't forget the last chapter
                if current_chapter:
                    chapters.append(current_chapter)
                
                self.metadata["chapters"] = chapters
                
        except Exception as e:
            logger.error(f"Error processing PDF: {e}")
            raise
        
        return self.metadata
    
    def _detect_chapter(self, text: str, page_num: int) -> Optional[str]:
        """Detect chapter headers - basic implementation"""
        lines = text.split('\n')
        
        # Look for common chapter patterns
        for line in lines[:10]:  # Check first 10 lines
            line = line.strip()
            
            # Pattern 1: "Chapter X" or "CHAPTER X"
            if line.lower().startswith('chapter'):
                return line
            
            # Pattern 2: Numbered sections (1., 2., etc)
            if len(line) < 100 and line and line[0].isdigit() and '.' in line[:3]:
                return line
            
            # Pattern 3: All caps headers
            if len(line) > 5 and line.isupper() and len(line.split()) < 10:
                return line
        
        return None
    
    def _format_table(self, table: List[List]) -> str:
        """Format table data as text"""
        formatted = []
        for row in table:
            formatted.append(" | ".join(str(cell) if cell else "" for cell in row))
        return "\n".join(formatted)
    
    def extract_keywords(self):
        """Extract keywords using TF-IDF - basic implementation"""
        from sklearn.feature_extraction.text import TfidfVectorizer
        
        # Combine all chapter texts
        documents = [chapter["content"] for chapter in self.metadata["chapters"]]
        
        if not documents:
            return
        
        # Configure TF-IDF
        vectorizer = TfidfVectorizer(
            max_features=20,
            stop_words='english',
            ngram_range=(1, 2)
        )
        
        try:
            # Fit and transform
            tfidf_matrix = vectorizer.fit_transform(documents)
            feature_names = vectorizer.get_feature_names_out()
            
            # Extract keywords for each chapter
            for idx, chapter in enumerate(self.metadata["chapters"]):
                scores = tfidf_matrix[idx].toarray().flatten()
                keywords_idx = scores.argsort()[-10:][::-1]  # Top 10
                chapter["keywords"] = [feature_names[i] for i in keywords_idx if scores[i] > 0]
                
                logger.info(f"Chapter '{chapter['title']}' keywords: {chapter['keywords'][:5]}")
                
        except Exception as e:
            logger.warning(f"Keyword extraction failed: {e}")
    
    def extract_images(self):
        """Extract instructional images from PDF"""
        logger.info("Starting image extraction...")
        
        try:
            import pdf2image
            
            # Convert PDF pages to images
            pages = pdf2image.convert_from_path(
                self.pdf_path,
                dpi=150,  # Balance quality vs size
                fmt='PNG'
            )
            
            # For now, just save first few pages as examples
            # In production, we'd use computer vision to detect diagrams
            for i, page_img in enumerate(pages[:5]):
                img_path = self.images_dir / f"page_{i+1}.png"
                page_img.save(img_path, "PNG")
                
                # Convert to WebP for better compression
                webp_path = self.images_dir / f"page_{i+1}.webp"
                page_img.save(webp_path, "WEBP", quality=85)
                
                logger.info(f"Saved page {i+1} as image")
                
                # Add to metadata (simplified for now)
                if i < len(self.metadata["chapters"]):
                    self.metadata["chapters"][i]["images"].append({
                        "filename": webp_path.name,
                        "caption": f"Page {i+1} content",
                        "page": i+1
                    })
                    
        except ImportError:
            logger.warning("pdf2image not available, skipping image extraction")
        except Exception as e:
            logger.error(f"Image extraction failed: {e}")
    
    def add_quick_references(self):
        """Generate quick reference summaries - needs human validation"""
        logger.info("Generating quick references...")
        
        # Placeholder implementation - in production this needs expert review
        emergency_keywords = ['immediate', 'urgent', 'critical', 'danger', 'warning', 
                            'poison', 'toxic', 'deadly', 'fatal', 'severe']
        
        for chapter in self.metadata["chapters"]:
            content_lower = chapter["content"].lower()
            
            # Check for emergency keywords
            emergency_count = sum(1 for keyword in emergency_keywords if keyword in content_lower)
            
            if emergency_count > 5:
                chapter["emergency_priority"] = "high"
            elif emergency_count > 2:
                chapter["emergency_priority"] = "medium"
            else:
                chapter["emergency_priority"] = "low"
            
            # Extract first substantive sentence as quick reference
            sentences = [s.strip() for s in chapter["content"].split('.') if len(s.strip()) > 20]
            if sentences:
                chapter["quick_reference"] = sentences[0] + "."
    
    def save_output(self):
        """Save extracted data as JSON"""
        output_path = self.output_dir / f"{self.pdf_path.stem}_extracted.json"
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(self.metadata, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Saved extracted data to: {output_path}")
        
        # Also save a human-readable summary
        summary_path = self.output_dir / f"{self.pdf_path.stem}_summary.txt"
        with open(summary_path, 'w', encoding='utf-8') as f:
            f.write(f"PDF Extraction Summary\n")
            f.write(f"=====================\n\n")
            f.write(f"Source: {self.metadata['source_pdf']}\n")
            f.write(f"Pages: {self.metadata['total_pages']}\n")
            f.write(f"Chapters: {len(self.metadata['chapters'])}\n\n")
            
            f.write("Chapters Found:\n")
            for i, chapter in enumerate(self.metadata['chapters']):
                f.write(f"{i+1}. {chapter['title']} (pages {chapter['page_start']}-{chapter['page_end']})\n")
                f.write(f"   Priority: {chapter['emergency_priority']}\n")
                f.write(f"   Keywords: {', '.join(chapter['keywords'][:5])}\n\n")
        
        logger.info(f"Saved summary to: {summary_path}")
        
        return output_path
    
    def validate_extraction(self):
        """Basic validation of extracted content"""
        logger.info("Validating extraction...")
        
        issues = []
        
        # Check for empty chapters
        for chapter in self.metadata["chapters"]:
            if not chapter["content"].strip():
                issues.append(f"Empty chapter: {chapter['title']}")
        
        # Check page continuity
        expected_pages = set(range(1, self.metadata["total_pages"] + 1))
        covered_pages = set()
        
        for chapter in self.metadata["chapters"]:
            for page in range(chapter["page_start"], chapter["page_end"] + 1):
                covered_pages.add(page)
        
        missing_pages = expected_pages - covered_pages
        if missing_pages:
            issues.append(f"Missing pages: {sorted(missing_pages)}")
        
        if issues:
            logger.warning("Validation issues found:")
            for issue in issues:
                logger.warning(f"  - {issue}")
        else:
            logger.info("Validation passed!")
        
        return issues


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python pdf_processor.py <pdf_file> [output_dir]")
        sys.exit(1)
    
    pdf_file = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "./extracted"
    
    if not os.path.exists(pdf_file):
        logger.error(f"PDF file not found: {pdf_file}")
        sys.exit(1)
    
    # Process PDF
    processor = PDFProcessor(pdf_file, output_dir)
    
    try:
        # Extract text and structure
        processor.extract_text_and_structure()
        
        # Extract keywords
        processor.extract_keywords()
        
        # Extract images (optional)
        if '--with-images' in sys.argv:
            processor.extract_images()
        
        # Add quick references
        processor.add_quick_references()
        
        # Validate
        processor.validate_extraction()
        
        # Save output
        output_path = processor.save_output()
        
        logger.info("Extraction complete!")
        logger.info(f"Output saved to: {output_path}")
        
        # Print validation reminder
        print("\n" + "="*60)
        print("CRITICAL REMINDER: Human Validation Required!")
        print("="*60)
        print("This extracted content MUST be reviewed by experts for:")
        print("- Medical procedures and dosages")
        print("- Plant identification accuracy")
        print("- Chemical ratios and timings")
        print("- Emergency procedure correctness")
        print("="*60)
        
    except Exception as e:
        logger.error(f"Processing failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()