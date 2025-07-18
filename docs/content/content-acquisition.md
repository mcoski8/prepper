# Content Acquisition Guide

## Overview
This document tracks all external content that needs to be downloaded or acquired for PrepperApp. It includes both automated downloads (that Claude can handle) and manual acquisitions (requiring human intervention).

## Quick Status
- ✅ = Downloaded and processed
- 📥 = Ready for automated download
- 🔐 = Requires manual download (licensing/access restrictions)
- 🚧 = In progress
- ❌ = Blocked/unavailable

---

## Core Content Sources

### 1. Wikipedia Medical Subset
**Status**: 📥 Ready for automated download
**Size**: ~4.2GB compressed
**Source**: https://download.kiwix.org/zim/wikipedia/
**Filename**: `wikipedia_en_medicine_2023-07.zim`

**Claude Instructions**:
```bash
# Download Wikipedia medical subset
wget https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_2023-07.zim
# Verify checksum
sha256sum wikipedia_en_medicine_2023-07.zim
```

**Human Instructions**:
If automated download fails, manually download from:
1. Visit https://wiki.kiwix.org/wiki/Content_in_all_languages
2. Find "Wikipedia Medical" under English
3. Download the ZIM file (~4.2GB)
4. Place in `/content/raw/wikipedia/`

---

### 2. OpenStreetMap Offline Data
**Status**: 📥 Ready for automated download
**Size**: Varies by region (100MB-5GB per region)
**Source**: https://download.geofabrik.de/

**Regions Needed**:
- North America: https://download.geofabrik.de/north-america-latest.osm.pbf
- Europe: https://download.geofabrik.de/europe-latest.osm.pbf
- Asia: https://download.geofabrik.de/asia-latest.osm.pbf
- South America: https://download.geofabrik.de/south-america-latest.osm.pbf
- Africa: https://download.geofabrik.de/africa-latest.osm.pbf
- Australia/Oceania: https://download.geofabrik.de/australia-oceania-latest.osm.pbf

**Claude Instructions**:
```bash
# Create directory
mkdir -p content/raw/maps

# Download map data
for region in north-america europe asia south-america africa australia-oceania; do
  wget https://download.geofabrik.de/${region}-latest.osm.pbf -O content/raw/maps/${region}.osm.pbf
done
```

---

### 3. US Military Survival Manuals
**Status**: 📥 Ready for automated download (Public Domain)
**Size**: ~500MB total
**Sources**: Various .mil and archive sites

**Required Manuals**:
- FM 21-76 Army Survival Manual
- TC 4-02.1 First Aid  
- FM 4-25.11 First Aid
- FM 3-05.70 Survival, Evasion, and Recovery
- ATP 3-50.21 Survival

**Claude Instructions**:
```bash
# These are available from public archives
mkdir -p content/raw/military

# Download from Archive.org
wget https://archive.org/download/FM21-76SurvivalManual/FM21-76.pdf
wget https://archive.org/download/FirstAidTC4-02.1/TC_4-02.1.pdf
# ... continue for each manual
```

**Human Instructions**:
If blocked, search for these on:
1. https://archive.org
2. https://www.globalsecurity.org/military/library/policy/army/fm/
3. Official .mil sites (may require US IP)

---

### 4. Plant Identification Databases
**Status**: 🔐 Requires manual setup
**Size**: ~10GB for images
**Sources**: Multiple botanical databases

**Required Databases**:
- USDA PLANTS Database: https://plants.usda.gov/home
- Flora of North America: http://floranorthamerica.org/
- Global Biodiversity Information Facility: https://www.gbif.org/

**Human Instructions**:
1. Request API access from each service
2. Use provided scripts to bulk download:
   - Plant descriptions
   - Distribution maps
   - Identification photos
   - Toxicity data

**API Keys Needed**:
```env
USDA_PLANTS_API_KEY=
GBIF_API_KEY=
FNA_ACCESS_TOKEN=
```

---

### 5. Medical Images & Diagrams
**Status**: 🔐 Requires manual curation
**Size**: ~2GB
**Sources**: Creative Commons medical illustrations

**Required Content**:
- Anatomy diagrams (wounds, pressure points)
- First aid procedures (step-by-step)
- Medical device usage (tourniquets, etc.)
- Injury identification photos

**Human Sources**:
1. OpenStax Anatomy (CC BY): https://openstax.org/details/books/anatomy-and-physiology
2. Wikimedia Commons Medical: https://commons.wikimedia.org/wiki/Category:Medical_illustrations
3. Public Health Image Library: https://phil.cdc.gov/

---

### 6. Where There Is No Doctor/Dentist
**Status**: 📥 Ready for automated download
**Size**: ~50MB each
**Source**: Hesperian Foundation

**Claude Instructions**:
```bash
# Download free versions
wget https://store.hesperian.org/prod/downloads/B010R_wtnd_2021.pdf -O content/raw/medical/where_there_is_no_doctor.pdf
wget https://store.hesperian.org/prod/downloads/B012R_wtndentist_2021.pdf -O content/raw/medical/where_there_is_no_dentist.pdf
```

---

### 7. Emergency Radio Frequencies
**Status**: 📥 Ready for automated download
**Size**: ~50MB
**Source**: RadioReference.com API

**Required Data**:
- Emergency service frequencies by region
- HAM radio repeater locations
- Maritime emergency channels
- Aviation emergency frequencies

**Claude Instructions**:
```bash
# Requires API key
export RADIOREFERENCE_API_KEY="your_key_here"
python scripts/download_radio_freqs.py
```

---

### 8. Weather Pattern Data
**Status**: 🔐 Requires manual download
**Size**: ~5GB historical data
**Source**: NOAA

**Required Data**:
- Historical severe weather patterns
- Seasonal weather guides
- Storm tracking basics
- Climate zone maps

**Human Instructions**:
1. Visit https://www.ncdc.noaa.gov/data-access
2. Download historical summaries
3. Focus on extreme weather events

---

## Content Processing Pipeline

### After Download
1. **Verify Integrity**
   ```bash
   find content/raw -type f -exec sha256sum {} \; > content/checksums.txt
   ```

2. **Extract Text Content**
   ```bash
   python scripts/extract_content.py
   ```

3. **Optimize Images**
   ```bash
   python scripts/optimize_images.py --format webp --quality 75
   ```

4. **Build Search Indexes**
   ```bash
   cargo run --bin index_builder
   ```

---

## Storage Structure
```
content/
├── raw/                    # Original downloaded files
│   ├── wikipedia/
│   ├── maps/
│   ├── military/
│   ├── medical/
│   └── plants/
├── processed/              # Optimized content
│   ├── core/              # <1GB for app bundle
│   ├── modules/           # 1-5GB modules
│   └── external/          # Large archives
├── indexes/               # Tantivy search indexes
└── checksums.txt         # Integrity verification
```

---

## Download Priorities

### Phase 1 - Critical (Core App)
1. ✅ Basic first aid procedures
2. 📥 Water purification methods
3. 📥 Dangerous plants (top 20)
4. 📥 Emergency shelter basics

### Phase 2 - Important (First Modules)  
1. 📥 Where There Is No Doctor
2. 📥 Regional maps (user's location)
3. 🔐 Extended plant database
4. 📥 Military survival manuals

### Phase 3 - Comprehensive (External Storage)
1. 📥 Full Wikipedia medical
2. 📥 All OpenStreetMap data
3. 🔐 Complete plant databases
4. 🔐 Historical weather data

---

## Automation Scripts

### Setup Download Environment
```bash
# Install required tools
pip install -r scripts/requirements.txt
npm install -g zim-tools

# Set up API keys
cp .env.example .env
# Edit .env with your API keys
```

### Run Automated Downloads
```bash
# Download all available content
./scripts/download_all.sh

# Download specific category
./scripts/download_all.sh --category medical
```

### Manual Download Checklist
When automation fails or manual download is required:

1. **Create tracking issue**
   ```
   Title: Manual Download Required - [Content Name]
   Body: 
   - Source URL:
   - Size:
   - License:
   - Blocking automated download:
   - Instructions:
   ```

2. **Document in this file**
   - Update status to 🚧
   - Add specific error/blocker
   - Include workaround

3. **Verify download**
   - Check file integrity
   - Confirm license compliance
   - Test content extraction

---

## Legal Compliance Checklist

Before downloading any content:
- [ ] Verify content is public domain or appropriately licensed
- [ ] Check for attribution requirements
- [ ] Confirm offline distribution is permitted
- [ ] Document license in `/licenses/` directory
- [ ] No commercial use restrictions
- [ ] No modification restrictions that conflict with our needs

---

## Troubleshooting

### Common Issues

**Rate Limiting**
```bash
# Add delays between downloads
export DOWNLOAD_DELAY=5  # seconds
```

**Large File Interruptions**
```bash
# Use wget with resume
wget -c [URL]

# Or use aria2 for parallel chunks
aria2c -x 16 -s 16 [URL]
```

**Access Denied**
- Try different user agent
- Use VPN for geo-restricted content
- Check if login/API key required

---

## Progress Tracking

### Current Status Summary
- Total content sources: 24
- Automated downloads ready: 15
- Manual downloads required: 9
- Total estimated size: ~150GB raw, ~40GB processed

### Weekly Update Format
```markdown
## Week of [Date]

### Completed
- ✅ [Content] - [Size] - [Notes]

### In Progress  
- 🚧 [Content] - [% complete] - [Blockers]

### Blocked
- ❌ [Content] - [Reason] - [Workaround needed]

### Next Week
- [ ] [Priority items]
```

---

## Contact for Manual Downloads

If you need to handle manual downloads, prioritize in this order:

1. **Medical content** - Critical for user safety
2. **Plant identification** - Prevent poisoning
3. **Maps** - Navigation and location
4. **Weather data** - Preparation and planning
5. **Radio frequencies** - Communication

For questions or access issues:
- Create GitHub issue with `content-acquisition` label
- Include specific error messages
- Tag `@content-team` for urgent items

---

Last Updated: 2025-07-18
Next Review: 2025-07-25