# PDF Extraction Pipeline Plan

## Overview
Build a Python-based pipeline to extract and process existing PDF content into searchable, structured JSON format optimized for mobile offline use.

## Target PDFs (Priority Order)
1. **PoisonousPlants.pdf** (4.5MB) - Smallest, good for testing
2. **water-purification.pdf** (20MB) - Critical survival info
3. **where-there-is-no-doctor-2019.pdf** (40MB) - Essential medical
4. **post-disaster-survival.pdf** (615MB) - Comprehensive guide

## Technical Architecture

### 1. PDF Extraction Module
```python
# Core dependencies
- PyPDF2 or pdfplumber for text extraction
- pdf2image + PIL for image extraction
- pytesseract for OCR (if needed)
- WebP converter for image compression
```

### 2. Content Structure
```json
{
  "source_pdf": "filename.pdf",
  "extracted_date": "2025-07-31",
  "total_pages": 100,
  "chapters": [
    {
      "title": "Water Purification Methods",
      "page_start": 10,
      "page_end": 25,
      "content": "extracted text...",
      "keywords": ["boiling", "filtration", "chemical"],
      "images": [
        {
          "filename": "water_boiling_diagram.webp",
          "caption": "Boiling times by altitude",
          "page": 12
        }
      ],
      "quick_reference": "Boil 1 min at sea level, +1 min per 1000ft",
      "emergency_priority": "high"
    }
  ],
  "search_index": {
    "terms": ["water", "purification", "boiling"],
    "pages": [10, 12, 15]
  }
}
```

### 3. Image Processing Pipeline
- Extract diagrams, charts, identification photos
- Convert to WebP format (better compression than JPEG/PNG)
- Multiple resolutions: thumbnail (150px), mobile (800px), full (1600px)
- Skip decorative images, focus on instructional content

### 4. Search Optimization
- Create inverted index for full-text search
- Extract key medical terms, plant names, procedures
- Build emergency decision trees from content
- Tag content by urgency: immediate, hours, days

## Implementation Steps

### Phase 1: Basic Extraction (Week 1)
1. Set up Python environment with dependencies
2. Create PDF text extraction script
3. Handle multi-column layouts and tables
4. Extract chapter/section structure
5. Save as structured JSON

### Phase 2: Image Processing (Week 1-2)
1. Identify and extract instructional images
2. OCR text within images if needed
3. Compress to WebP format
4. Link images to relevant text sections

### Phase 3: Search Enhancement (Week 2)
1. Build keyword extraction
2. Create emergency procedure index
3. Generate quick-reference summaries
4. Prepare for Tantivy integration

## Script Structure
```
prepperapp/content/scripts/
├── pdf_processor.py          # Main extraction script
├── image_extractor.py        # Image processing
├── content_structurer.py     # JSON structure builder
├── search_indexer.py         # Search optimization
└── requirements.txt          # Python dependencies
```

## Quality Checks & Human Validation

### Automated Checks
- [ ] Text extraction completeness (no missing pages)
- [ ] Image extraction success rate
- [ ] File sizes within mobile constraints
- [ ] Basic keyword extraction functioning

### CRITICAL: Human-in-the-Loop Validation
For survival content, automated extraction CANNOT be the sole source:
- [ ] **Medical Procedures**: Manual review of ALL dosages, timings, procedures
- [ ] **Plant Identification**: Expert verification of image-text matching
- [ ] **Emergency Procedures**: Step-by-step validation by medical professionals
- [ ] **Water Purification**: Chemical ratios and boiling times double-checked

## Integration with PrepperApp Tech Stack

### FlatBuffers Conversion
```python
# After JSON extraction, convert to FlatBuffers
content_structurer.py → JSON → flatbuffers_converter.py → .fbs files
```

### ZIM Packaging Strategy
- Use ZIM as container for FlatBuffers + WebP images
- Tantivy indexes stored separately for performance
- No HTML generation - direct FlatBuffers consumption

## Enhanced Tooling
- **pdfplumber** instead of PyPDF2 (better for tables)
- **camelot** for complex table extraction
- **Simple keyword extraction** (TF-IDF) initially
- **Manual urgency tagging** by domain experts

## Next Steps After Pipeline
1. Human validation workflow setup
2. FlatBuffers schema design
3. ZIM packaging implementation
4. Tantivy search integration
5. Quick-reference card generator

Last Updated: 2025-07-31