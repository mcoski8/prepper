#!/usr/bin/env python3
"""
Content structurer for PrepperApp
Builds structured JSON with emergency priorities and validation checkpoints
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import re

logger = logging.getLogger(__name__)


class ContentStructurer:
    """Structure PDF content for PrepperApp consumption"""
    
    # Emergency keywords for automatic priority detection
    EMERGENCY_KEYWORDS = {
        'critical': ['immediate', 'urgent', 'emergency', 'life-threatening', 
                    'severe bleeding', 'cardiac arrest', 'anaphylaxis', 'airway'],
        'high': ['poison', 'toxic', 'deadly', 'fatal', 'severe', 'dangerous',
                'contaminated', 'infected', 'hemorrhage', 'shock'],
        'medium': ['injury', 'wound', 'fracture', 'burn', 'dehydration',
                  'infection', 'fever', 'pain', 'swelling'],
        'low': ['minor', 'mild', 'simple', 'basic', 'preventive']
    }
    
    # Content requiring human validation
    VALIDATION_REQUIRED = {
        'medical_dosages': r'\d+\s*(mg|ml|cc|mcg|units?|tablets?|pills?)',
        'time_critical': r'\d+\s*(minutes?|hours?|seconds?)\s*(before|after|within)',
        'measurements': r'\d+\.?\d*\s*(gallons?|liters?|ounces?|pounds?|grams?)',
        'ratios': r'\d+:\d+|\d+\s*to\s*\d+',
        'percentages': r'\d+\.?\d*\s*%',
        'temperatures': r'\d+\s*°?\s*[FCK]'
    }
    
    def __init__(self, metadata: Dict):
        self.metadata = metadata
        self.validation_flags = []
        
    def structure_content(self) -> Dict:
        """Build structured content with validation flags"""
        structured = {
            "source_pdf": self.metadata["source_pdf"],
            "extracted_date": self.metadata["extracted_date"],
            "total_pages": self.metadata["total_pages"],
            "validation_required": [],
            "content_stats": self._generate_stats(),
            "chapters": []
        }
        
        # Process each chapter
        for chapter in self.metadata["chapters"]:
            structured_chapter = self._structure_chapter(chapter)
            structured["chapters"].append(structured_chapter)
        
        # Add validation summary
        structured["validation_required"] = self.validation_flags
        
        return structured
    
    def _structure_chapter(self, chapter: Dict) -> Dict:
        """Structure individual chapter with enhancements"""
        content = chapter["content"]
        
        # Detect emergency priority
        priority = self._detect_priority(content)
        
        # Extract quick reference
        quick_ref = self._extract_quick_reference(content)
        
        # Find validation requirements
        validations = self._find_validation_points(content, chapter["title"])
        
        # Extract procedural steps
        procedures = self._extract_procedures(content)
        
        # Build structured chapter
        structured = {
            "title": chapter["title"],
            "page_start": chapter["page_start"],
            "page_end": chapter["page_end"],
            "emergency_priority": priority,
            "quick_reference": quick_ref,
            "keywords": chapter.get("keywords", []),
            "images": chapter.get("images", []),
            "procedures": procedures,
            "validation_flags": validations,
            "content_sections": self._segment_content(content),
            "raw_content": content  # Keep original for reference
        }
        
        return structured
    
    def _detect_priority(self, content: str) -> str:
        """Detect emergency priority based on content"""
        content_lower = content.lower()
        
        # Count keyword matches
        scores = {}
        for priority, keywords in self.EMERGENCY_KEYWORDS.items():
            scores[priority] = sum(1 for kw in keywords if kw in content_lower)
        
        # Determine priority
        if scores['critical'] > 2:
            return 'critical'
        elif scores['high'] > 3:
            return 'high'
        elif scores['medium'] > 2:
            return 'medium'
        else:
            return 'low'
    
    def _extract_quick_reference(self, content: str) -> str:
        """Extract or generate quick reference summary"""
        # Look for summary sections
        summary_patterns = [
            r'summary:?\s*(.{20,200})',
            r'quick\s+reference:?\s*(.{20,200})',
            r'key\s+points?:?\s*(.{20,200})',
            r'remember:?\s*(.{20,200})'
        ]
        
        for pattern in summary_patterns:
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                return match.group(1).strip()
        
        # Fallback: first substantive sentence
        sentences = [s.strip() for s in content.split('.') if len(s.strip()) > 30]
        if sentences:
            return sentences[0] + "."
        
        return "See full content for details."
    
    def _find_validation_points(self, content: str, chapter_title: str) -> List[Dict]:
        """Find content requiring human validation"""
        validations = []
        
        for val_type, pattern in self.VALIDATION_REQUIRED.items():
            matches = re.finditer(pattern, content, re.IGNORECASE)
            for match in matches:
                # Get surrounding context
                start = max(0, match.start() - 50)
                end = min(len(content), match.end() + 50)
                context = content[start:end].strip()
                
                validation = {
                    "type": val_type,
                    "value": match.group(),
                    "context": context,
                    "chapter": chapter_title,
                    "requires_expert_review": True
                }
                
                validations.append(validation)
                self.validation_flags.append(validation)
        
        return validations
    
    def _extract_procedures(self, content: str) -> List[Dict]:
        """Extract step-by-step procedures"""
        procedures = []
        
        # Look for numbered lists
        numbered_pattern = r'(\d+\.)\s+([^\n]+)'
        matches = re.finditer(numbered_pattern, content)
        
        current_procedure = None
        for match in matches:
            step_num = match.group(1)
            step_text = match.group(2).strip()
            
            # Check if this is a new procedure or continuation
            if step_num == "1.":
                if current_procedure:
                    procedures.append(current_procedure)
                current_procedure = {
                    "title": "Procedure",
                    "steps": [step_text]
                }
            elif current_procedure:
                current_procedure["steps"].append(step_text)
        
        if current_procedure:
            procedures.append(current_procedure)
        
        return procedures
    
    def _segment_content(self, content: str) -> List[Dict]:
        """Segment content into logical sections"""
        sections = []
        
        # Split by common section markers
        section_patterns = [
            r'(?:^|\n)([A-Z][A-Z\s]+)(?:\n|$)',  # All caps headers
            r'(?:^|\n)(\w+:)\s*\n',  # Headers with colons
            r'(?:^|\n)((?:Introduction|Overview|Summary|Conclusion))\s*\n'
        ]
        
        # For now, simple paragraph-based segmentation
        paragraphs = content.split('\n\n')
        
        for i, para in enumerate(paragraphs):
            if len(para.strip()) > 20:
                sections.append({
                    "type": "paragraph",
                    "content": para.strip(),
                    "index": i
                })
        
        return sections
    
    def _generate_stats(self) -> Dict:
        """Generate content statistics"""
        total_content_length = sum(len(ch["content"]) for ch in self.metadata["chapters"])
        
        return {
            "total_chapters": len(self.metadata["chapters"]),
            "total_characters": total_content_length,
            "avg_chapter_length": total_content_length // len(self.metadata["chapters"]) if self.metadata["chapters"] else 0,
            "has_images": any(ch.get("images") for ch in self.metadata["chapters"]),
            "has_tables": any("[TABLE" in ch["content"] for ch in self.metadata["chapters"])
        }
    
    def save_structured_content(self, output_path: Path) -> Path:
        """Save structured content to JSON"""
        structured = self.structure_content()
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(structured, f, indent=2, ensure_ascii=False)
        
        logger.info(f"Saved structured content to: {output_path}")
        
        # Generate validation report
        if self.validation_flags:
            validation_path = output_path.parent / f"{output_path.stem}_validation.txt"
            self._generate_validation_report(validation_path)
        
        return output_path
    
    def _generate_validation_report(self, output_path: Path):
        """Generate human validation checklist"""
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("HUMAN VALIDATION CHECKLIST\n")
            f.write("="*50 + "\n\n")
            f.write(f"Generated: {datetime.now().isoformat()}\n")
            f.write(f"Source: {self.metadata['source_pdf']}\n\n")
            
            f.write("CRITICAL ITEMS REQUIRING EXPERT REVIEW:\n")
            f.write("-"*40 + "\n\n")
            
            # Group by type
            by_type = {}
            for val in self.validation_flags:
                val_type = val["type"]
                if val_type not in by_type:
                    by_type[val_type] = []
                by_type[val_type].append(val)
            
            for val_type, items in by_type.items():
                f.write(f"\n{val_type.upper().replace('_', ' ')}:\n")
                for item in items[:10]:  # Limit to first 10
                    f.write(f"  - Value: {item['value']}\n")
                    f.write(f"    Chapter: {item['chapter']}\n")
                    f.write(f"    Context: ...{item['context']}...\n\n")
                
                if len(items) > 10:
                    f.write(f"  ... and {len(items) - 10} more items\n\n")
        
        logger.info(f"Generated validation report: {output_path}")


def main():
    """Test content structuring"""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python content_structurer.py <extracted_json>")
        sys.exit(1)
    
    json_path = Path(sys.argv[1])
    
    if not json_path.exists():
        logger.error(f"JSON file not found: {json_path}")
        sys.exit(1)
    
    # Load extracted metadata
    with open(json_path, 'r', encoding='utf-8') as f:
        metadata = json.load(f)
    
    # Structure content
    structurer = ContentStructurer(metadata)
    
    # Save structured version
    output_path = json_path.parent / f"{json_path.stem}_structured.json"
    structurer.save_structured_content(output_path)
    
    print(f"\nStructured content saved to: {output_path}")
    print(f"Validation flags: {len(structurer.validation_flags)}")


if __name__ == "__main__":
    main()