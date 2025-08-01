# PDF Extraction Pipeline Implementation

## Overview
The PDF extraction pipeline processes survival PDFs into structured JSON format optimized for mobile offline use in PrepperApp. The pipeline extracts text, tables, images, and generates validation checkpoints for critical survival information.

## Architecture

### Core Components

1. **pdf_processor.py** - Main extraction engine
   - Text and structure extraction using pdfplumber
   - Table detection and formatting
   - Chapter/section detection
   - TF-IDF keyword extraction
   - Emergency priority assignment
   - Validation and summary generation

2. **image_extractor.py** - Image processing module
   - Embedded image extraction using PyMuPDF
   - Multi-resolution output (thumb: 150px, mobile: 800px, full: 1600px)
   - WebP compression with fallback PNG
   - Page screenshot capability
   - Size optimization for mobile

3. **content_structurer.py** - Content structuring and validation
   - Enhanced JSON structure building
   - Automatic emergency priority detection
   - Human validation checkpoint identification
   - Procedure extraction
   - Content segmentation

4. **test_pdf_pipeline.py** - Comprehensive testing suite
   - End-to-end pipeline testing
   - Performance metrics
   - File size analysis
   - Report generation

## Usage

### Basic PDF Processing
```bash
python3 pdf_processor.py "/path/to/pdf.pdf" ./output_dir
```

### With Image Extraction
```bash
python3 pdf_processor.py "/path/to/pdf.pdf" ./output_dir --with-images
```

### Full Pipeline
```bash
# 1. Extract text and basic structure
python3 pdf_processor.py "PoisonousPlants.pdf" ./extracted

# 2. Extract images
python3 image_extractor.py "PoisonousPlants.pdf" ./extracted

# 3. Structure content with validation
python3 content_structurer.py ./extracted/PoisonousPlants_extracted.json
```

## Output Structure

### JSON Schema
```json
{
  "source_pdf": "filename.pdf",
  "extracted_date": "ISO-8601 timestamp",
  "total_pages": 120,
  "validation_required": [...],
  "content_stats": {...},
  "chapters": [
    {
      "title": "Chapter Title",
      "page_start": 1,
      "page_end": 20,
      "emergency_priority": "critical|high|medium|low",
      "quick_reference": "Summary text",
      "keywords": ["keyword1", "keyword2"],
      "images": [...],
      "procedures": [...],
      "validation_flags": [...],
      "content_sections": [...],
      "raw_content": "Original text"
    }
  ]
}
```

### Image Output
- `images/{pdf_name}/page{N}_img{M}.webp` - Full resolution
- `images/{pdf_name}/page{N}_img{M}_mobile.webp` - Mobile optimized
- `images/{pdf_name}/page{N}_img{M}_thumb.webp` - Thumbnail
- `images/{pdf_name}/page{N}_img{M}.png` - Compatibility fallback

### Validation Report
- `{pdf_name}_validation.txt` - Human review checklist
- Groups items by type: medical_dosages, time_critical, measurements, ratios, percentages, temperatures
- Provides context for each validation point

## Performance Metrics

Based on PoisonousPlants.pdf (4.1MB, 120 pages):
- **Text extraction**: ~30-60 pages/second
- **Image extraction**: ~10-15 pages/second  
- **Total processing**: ~8-10 pages/second
- **Output size**: JSON (~10% of PDF) + Images (varies)
- **Memory usage**: Moderate (streaming for large files)

## Critical Features

### Emergency Priority Detection
Automatically assigns priority based on keyword analysis:
- **Critical**: immediate, urgent, emergency, life-threatening
- **High**: poison, toxic, deadly, fatal, severe
- **Medium**: injury, wound, fracture, burn
- **Low**: minor, mild, simple, basic

### Human Validation Requirements
Automatically flags content requiring expert review:
- Medical dosages (mg, ml, cc, tablets)
- Time-critical procedures (minutes/hours before/after)
- Measurements (gallons, liters, ounces)
- Ratios and percentages
- Temperature specifications

### Content Safety
- All medical procedures flagged for review
- Plant identification requires expert verification
- Chemical ratios double-checked
- Emergency procedures validated

## Dependencies

Core requirements:
- pdfplumber>=0.11.4 - Text extraction
- PyMuPDF>=1.26.0 - Image extraction (no poppler needed)
- Pillow>=10.0.0 - Image processing
- scikit-learn>=1.5.2 - Keyword extraction
- pandas, numpy - Data processing

## Known Limitations

1. **Chapter Detection**: Basic pattern matching, may miss complex structures
2. **Large PDFs**: Files >100MB may need chunked processing
3. **Scanned PDFs**: OCR not implemented (pytesseract ready)
4. **Complex Tables**: Some tables may need manual verification

## Next Steps

1. Process remaining PDFs:
   - water-purification.pdf (20MB)
   - where-there-is-no-doctor-2019.pdf (40MB)
   - post-disaster-survival.pdf (615MB)

2. Implement FlatBuffers conversion for mobile efficiency

3. Create Tantivy search indexes

4. Build human validation workflow UI

5. Package content into ZIM format

## Testing

Run comprehensive tests:
```bash
python3 test_pdf_pipeline.py
```

This generates:
- Performance metrics
- File size analysis
- Test report (test_extraction/test_report.md)
- Validation of all components

## Safety Considerations

⚠️ **CRITICAL**: All extracted content MUST undergo human validation before deployment. Lives depend on accuracy of:
- Medical dosages and procedures
- Plant identification for toxicity
- Water purification ratios
- Emergency timelines

The pipeline provides validation checkpoints but cannot replace expert review.

Last Updated: 2025-07-31