# PrepperApp Data Flow & Content Pipeline

## Overview
This document describes how content flows through the PrepperApp system, from raw source materials to compressed, searchable content on user devices. The pipeline prioritizes compression efficiency, search performance, and minimal battery usage.

## Content Pipeline Architecture

### High-Level Pipeline
```
Raw Content → Validation → Processing → Compression → Indexing → Packaging → Distribution
     ↓            ↓           ↓            ↓           ↓           ↓            ↓
   (HTML)     (Medical)   (Optimize)   (Zstd)    (Tantivy)    (ZIM)      (CDN/USB)
```

## Stage 1: Content Acquisition

### Source Materials
```yaml
sources:
  medical:
    - name: "Where There Is No Doctor"
      type: "PDF"
      size: "28MB"
      license: "Creative Commons"
    
  reference:
    - name: "Wikipedia Medical Subset"
      type: "XML Dump"
      size: "4.2GB"
      license: "CC BY-SA"
    
  original:
    - name: "Custom Survival Guides"
      type: "Markdown"
      size: "Variable"
      license: "Proprietary"
```

### Acquisition Process
1. **Legal Verification**: Confirm licensing allows offline distribution
2. **Source Download**: Automated retrieval from approved sources
3. **Version Control**: Git LFS for large binary sources
4. **Integrity Check**: SHA-256 verification of source files

## Stage 2: Content Validation

### Medical Content Validation
```python
# Pseudo-code for validation pipeline
class MedicalValidator:
    def validate(content):
        # Check against medical guidelines
        verify_dosages(content)
        verify_procedures(content)
        check_contraindications(content)
        
        # Flag for expert review
        if contains_critical_procedures(content):
            queue_for_expert_review(content)
```

### Accuracy Checks
- **Automated Checks**
  - Drug dosage ranges
  - Metric/Imperial conversions
  - Cross-reference verification
  - Image-text alignment

- **Manual Reviews**
  - Medical professional sign-off
  - Field expert validation
  - Legal compliance review
  - Cultural sensitivity check

## Stage 3: Content Processing

### Text Processing Pipeline
```
Raw Text → Simplification → Structuring → Linking → Optimization
```

#### Text Simplification
```javascript
// Readability optimization
function simplifyText(input) {
    // Target 8th grade reading level
    text = replaceMedicalJargon(input);
    text = shortenSentences(text, maxWords: 20);
    text = convertPassiveToActive(text);
    text = addGlossaryLinks(text);
    return text;
}
```

#### Content Structuring
```xml
<!-- Standardized content structure -->
<article>
    <metadata>
        <title>Treating Severe Bleeding</title>
        <category>medical.trauma.hemorrhage</category>
        <priority>critical</priority>
        <reading_time>3</reading_time>
    </metadata>
    
    <summary>
        Quick steps to stop severe bleeding
    </summary>
    
    <content>
        <section id="immediate-action">
            <steps>...</steps>
        </section>
    </content>
    
    <related>
        <link>tourniquet-application</link>
        <link>shock-treatment</link>
    </related>
</article>
```

### Image Processing Pipeline

#### Optimization Workflow
```bash
# Image processing script
for image in source_images/*; do
    # Resize to max width
    magick "$image" -resize 1200x\> temp.png
    
    # Convert to WebP with quality setting
    cwebp -q 75 temp.png -o "processed/${image%.*}.webp"
    
    # Generate thumbnail
    magick "$image" -resize 200x200^ -gravity center -extent 200x200 "thumbs/${image%.*}.webp"
done
```

#### Diagram Standardization
- Convert all diagrams to SVG where possible
- Standardize color palette (high contrast)
- Remove unnecessary details
- Add accessibility descriptions

## Stage 4: Compression Strategy

### Text Compression

#### Custom Dictionary Creation
```python
# Build domain-specific compression dictionary
def build_compression_dict(corpus):
    # Extract common medical terms
    medical_terms = extract_medical_vocabulary(corpus)
    
    # Extract common phrases
    phrases = extract_frequent_phrases(corpus, min_length=3)
    
    # Build Zstd dictionary
    dict_data = zstd.train_dictionary(
        samples=corpus_samples,
        dict_size=100_000,  # 100KB dictionary
        compressionLevel=19
    )
    
    return dict_data
```

#### Compression Results
```
Original HTML: 100MB
With zstd (generic): 18MB (82% reduction)
With custom dictionary: 12MB (88% reduction)
Additional savings: 33%
```

### Binary Data Optimization

#### FlatBuffers Schema
```flatbuffers
// Schema for structured survival data
namespace PrepperApp;

table Plant {
    id: string;
    name: string;
    latin_name: string;
    edible: bool;
    poisonous: bool;
    medicinal: bool;
    regions: [uint8];  // Bitfield for regions
    seasons: uint8;    // Bitfield for seasons
    warnings: [string];
    preparation: string;
    image_id: string;
}

table PlantDatabase {
    plants: [Plant];
}
```

## Stage 5: Search Index Generation

### Tantivy Indexing Pipeline

#### Index Configuration
```rust
// Tantivy index schema
let mut schema_builder = Schema::builder();

// Define fields
schema_builder.add_text_field("title", TEXT | STORED);
schema_builder.add_text_field("content", TEXT);
schema_builder.add_text_field("category", STRING | STORED);
schema_builder.add_u64_field("priority", INDEXED | STORED);
schema_builder.add_text_field("keywords", TEXT);

// Build index with custom analyzer
let index = Index::create_in_dir(&index_path, schema)?;
```

#### Indexing Process
```python
# Parallel indexing workflow
def build_search_index(content_dir, output_dir):
    # Initialize Tantivy
    index = tantivy.Index(schema)
    writer = index.writer(150_000_000)  # 150MB buffer
    
    # Process documents in parallel
    with ThreadPoolExecutor(max_workers=8) as executor:
        futures = []
        for doc in get_documents(content_dir):
            future = executor.submit(index_document, doc, writer)
            futures.append(future)
        
        # Wait for completion
        for future in as_completed(futures):
            processed += 1
            if processed % 1000 == 0:
                writer.commit()  # Periodic commits
    
    # Final optimization
    writer.commit()
    writer.wait_merging_threads()
```

### Index Optimization
- **Stemming**: Medical terms preserved, common words stemmed
- **Stop Words**: Minimal removal (keep medical prepositions)
- **Fuzzy Search**: Levenshtein distance ≤ 2
- **Synonyms**: Medical term alternatives included

## Stage 6: Content Packaging

### ZIM File Creation

#### Package Structure
```
content.zim
├── metadata/
│   ├── version.json
│   ├── checksums.sha256
│   └── license.txt
├── content/
│   ├── articles/
│   ├── images/
│   └── styles/
└── index/
    └── tantivy/
```

#### ZIM Creation Process
```python
# ZIM packaging pipeline
def create_zim_package(content_dir, index_dir, output_file):
    creator = zimwriterfs.Creator()
    
    # Set metadata
    creator.config_metadata(
        title="PrepperApp Core Content",
        description="Essential survival information",
        creator="PrepperApp Team",
        publisher="PrepperApp",
        date=datetime.now()
    )
    
    # Add content with compression
    creator.config_compression("zstd")
    creator.config_cluster_size(2048)  # 2MB clusters
    
    # Add search index
    creator.add_custom_data("index", index_dir)
    
    # Build ZIM
    creator.create(output_file)
```

## Stage 7: Distribution

### Module Distribution

#### CDN Structure
```
cdn.prepperapp.com/
├── core/
│   ├── v1.0.0/
│   │   ├── content.zim
│   │   ├── content.zim.sha256
│   │   └── manifest.json
│   └── latest → v1.0.0
├── modules/
│   ├── medical_advanced/
│   ├── regional_northeast/
│   └── communications/
└── metadata/
    └── catalog.json
```

#### Update Mechanism
```kotlin
// Module update check
class ModuleUpdater {
    suspend fun checkForUpdates() {
        val localManifest = getLocalManifest()
        val remoteManifest = fetchRemoteManifest()
        
        val updates = remoteManifest.modules
            .filter { remote ->
                val local = localManifest.modules[remote.id]
                local == null || remote.version > local.version
            }
        
        if (updates.isNotEmpty()) {
            notifyUpdatesAvailable(updates)
        }
    }
}
```

### Offline Distribution

#### USB Content Structure
```
PrepperApp_Content/
├── README.txt
├── install_guide.pdf
├── content/
│   ├── core.zim
│   ├── modules/
│   │   ├── medical_advanced.zim
│   │   └── wikipedia_subset.zim
│   └── checksums.sha256
└── apps/
    ├── PrepperApp.apk
    └── PrepperApp.ipa
```

## Performance Metrics

### Compression Ratios
| Content Type | Original | Compressed | Ratio |
|-------------|----------|------------|-------|
| Text (HTML) | 100MB | 12MB | 88% |
| Images | 500MB | 125MB | 75% |
| Index | 50MB | 15MB | 70% |
| **Total** | **650MB** | **152MB** | **77%** |

### Processing Speed
- Text processing: 10MB/second
- Image optimization: 50 images/minute
- Index generation: 1000 documents/second
- ZIM packaging: 100MB/minute

### Search Performance
- Index load time: <500ms
- Query execution: <50ms
- Result retrieval: <100ms
- Memory usage: 50MB (core index)

## Quality Assurance

### Automated Testing
```python
# Content validation tests
def test_content_integrity():
    # Verify all links resolve
    assert all_internal_links_valid()
    
    # Check image references
    assert all_images_exist()
    
    # Validate search index
    assert search_index_complete()
    
    # Test compression integrity
    assert decompress_without_errors()
```

### Performance Testing
- Load test with 100GB external content
- Battery usage monitoring
- Memory pressure testing
- Search response time validation

## Monitoring & Analytics

### Pipeline Metrics
```yaml
metrics:
  processing:
    - documents_processed_per_hour
    - compression_ratio_average
    - validation_failure_rate
    
  quality:
    - readability_score_average
    - expert_review_completion
    - user_reported_errors
    
  performance:
    - index_size_per_document
    - search_speed_percentiles
    - compression_time_average
```

### Error Handling
- Validation failures → Queue for manual review
- Compression errors → Fallback to lower ratio
- Index corruption → Rebuild from source
- Distribution failures → Retry with backoff