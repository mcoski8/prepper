# Content Acquisition Guide

## Overview
This document tracks all external content that needs to be downloaded or acquired for PrepperApp. It includes both automated downloads (that Claude can handle) and manual acquisitions (requiring human intervention).

## 🚨 CRITICAL UPDATE (2025-07-30)
Based on comprehensive gap analysis, PrepperApp needs a fundamental shift from 70% archival content to 70% practical content. See `content_gap_analysis.md` for detailed analysis.

## 🔴 HIGHEST PRIORITY: Practical Rebuilding Content

### Phase 2 Stabilization Content (CRITICAL GAPS)

#### 1. Foxfire Book Series
**Status**: 🔐 Manual acquisition required  
**Priority**: CRITICAL  
**Size**: ~2GB for complete series (14 books)  
**Source**: Archive.org has volumes 1-14  
**Content**: Traditional Appalachian skills including:
- Building log cabins, stone masonry
- Blacksmithing and tool making
- Food preservation and moonshining
- Animal husbandry and butchering
- Soap making and traditional crafts

**Acquisition**:
```bash
# Search Archive.org for "Foxfire Book" and download PDFs
# Volumes 1-6 are most critical for basic skills
```

#### 2. USDA/Extension Service Agriculture Guides
**Status**: 📥 Partially available for download  
**Priority**: CRITICAL  
**Size**: ~5GB estimated  
**Sources**: 
- https://www.nal.usda.gov/
- State extension services
- https://www.farmers.gov/

**Critical Guides Needed**:
- Small-scale farming basics
- Crop rotation and companion planting
- Soil management without chemicals
- Seed saving techniques
- Integrated pest management
- Season extension methods

#### 3. Peace Corps Technical Manuals
**Status**: 📥 Available for download  
**Priority**: HIGH  
**Size**: ~3GB for complete collection  
**Source**: https://www.peacecorps.gov/educators/resources/

**Essential Manuals**:
- Appropriate Technology Sourcebook
- Small Farm Development
- Water Systems
- Construction Techniques
- Health and Sanitation

#### 4. Traditional Skills & Crafts
**Status**: 🔐 Manual curation required  
**Priority**: HIGH  
**Sources**: Various archives and museums

**Must Include**:
- **Blacksmithing**: "The Backyard Blacksmith" by Lorelei Sims
- **Textiles**: "Hands On Spinning" by Lee Raven
- **Construction**: "Building with Earth" by Paulina Wojciechowska
- **Pottery**: Traditional pottery techniques
- **Leather**: Brain-tanning and hide working

#### 5. Food Preservation & Storage
**Status**: 📥 Some available online  
**Priority**: CRITICAL  
**Size**: ~1GB

**Essential Content**:
- Ball Complete Book of Home Preserving
- Root Cellaring by Mike & Nancy Bubel
- Wild Fermentation by Sandor Katz
- Preserving Food without Freezing or Canning
- Traditional smoking and curing guides

#### 6. Animal Husbandry
**Status**: 🔐 Manual acquisition  
**Priority**: HIGH  
**Size**: ~2GB

**Key Resources**:
- "Storey's Guide to Raising..." series (chickens, rabbits, goats)
- "Where There Is No Vet" by Bill Forse
- Basic veterinary care manuals
- Breeding and genetics basics
- Pasture management

#### 7. Education & Child Development
**Status**: 📥 Some freely available  
**Priority**: HIGH  
**Size**: ~10GB for complete K-8

**Resources**:
- Khan Academy offline content
- OpenStax textbooks
- Classic McGuffey Readers
- Montessori teaching guides
- One-room schoolhouse methods

#### 8. Community Governance
**Status**: 🤖 May need AI generation  
**Priority**: CRITICAL  
**Size**: ~500MB

**Content Needed**:
- Small community governance models
- Consensus building guides
- Conflict resolution frameworks
- Basic legal templates
- Resource sharing agreements
- Trade and barter systems

#### 9. Mental Health Resources
**Status**: 📥 Some available  
**Priority**: HIGH  
**Size**: ~1GB

**Essential Guides**:
- "Where There Is No Psychiatrist"
- PTSD treatment manuals
- Community mental health models
- Grief counseling guides
- Child trauma resources

#### 10. Permaculture & Sustainable Agriculture
**Status**: 📥 Available  
**Priority**: CRITICAL  
**Size**: ~2GB

**Core Resources**:
- "Permaculture: A Designer's Manual" by Bill Mollison
- "Gaia's Garden" by Toby Hemenway
- "The One-Straw Revolution" by Masanobu Fukuoka
- Regional planting guides
- Water harvesting techniques

### Acquisition Strategy

1. **Immediate Actions** (This week):
   - Download all Peace Corps manuals
   - Acquire Foxfire books from Archive.org
   - Get USDA public domain guides
   
2. **Partner Outreach** (Next 2 weeks):
   - Contact agricultural universities
   - Reach out to historical societies
   - Connect with maker spaces
   
3. **Content Creation** (Next month):
   - Commission illustrated guides for gaps
   - Create climate-specific versions
   - Develop quick reference cards

### Download Commands for Available Content

```bash
# Create new directory structure for practical content
mkdir -p content/practical/{agriculture,crafts,education,governance,health}

# Peace Corps Collection (example)
wget -r -l 1 -np -nd -A pdf https://files.peacecorps.gov/library/

# USDA Historical Books (public domain)
# Visit https://naldc.nal.usda.gov/usda-historical-books
```

---

## ⚠️ IMPORTANT: Git Exclusions
All content files are excluded from Git version control due to their large size. The `.gitignore` file is configured to exclude:
- All `.zim` files (Wikipedia, medical references)
- All map data (`.osm`, `.pbf`, `.mbtiles`)
- The entire `data/` directory structure
- Download directories

**Never attempt to commit content files to Git!** They should be downloaded locally for development but kept out of version control.

## Quick Status
- ✅ = Downloaded and processed
- 📥 = Ready for automated download
- 🔐 = Requires manual download (licensing/access restrictions)
- 🚧 = In progress
- ❌ = Failed download (needs retry)
- 🤖 = AI-generated content needed

---

## Core Content Sources

### 1. Wikipedia Medical Subset
**Status**: ❌ Wrong version downloaded (need maxi 2.0GB, have mini 123MB)
**Size**: 2.0GB compressed (corrected size)
**Source**: https://download.kiwix.org/zim/wikipedia/
**Filename**: `wikipedia_en_medicine_maxi_2025-07.zim`

**Claude Instructions**:
```bash
# Delete wrong version first
rm -f "/Volumes/Vid SSD/prepperapp-content/medical/wikipedia_en_medicine_maxi_2025-07.zim"

# Download Wikipedia medical subset (FULL maxi version - 2.0GB)
aria2c -c -x10 \
  "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/medical/"

# Verify size is 2.0GB, not 123MB
ls -lh "/Volumes/Vid SSD/prepperapp-content/medical/wikipedia_en_medicine_maxi_2025-07.zim"
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
**Status**: 📥 Ready for automated download
**Size**: ~10GB for images + data
**Sources**: Multiple botanical databases

**Required Databases**:
- USDA PLANTS Database: https://plants.usda.gov/home (public data)
- USDA Plant Characteristics: https://plants.usda.gov/home/downloads
- BONAP North American Plant Atlas: http://bonap.org/
- eFloras.org: http://www.efloras.org/

**Claude Instructions**:
```bash
# Download USDA PLANTS database (CSV format)
mkdir -p content/raw/plants/usda
wget https://plants.usda.gov/assets/docs/CompletePLANTSList/plantlst.txt
wget https://plants.usda.gov/assets/docs/CompletePLANTSList/CompleteCharacteristics.csv

# Download plant images script
python scripts/download_plant_images.py --source usda --limit 1000

# For poisonous plants specifically
wget https://www.ars.usda.gov/ARSUserFiles/oc/np/PoisonousPlants/PoisonousPlants.pdf
```

**Additional Sources**:
- Poisonous Plants of North America: McGraw-Hill textbook (manual acquisition)
- North American Mycological Association (mushroom toxicity)
- Regional extension office guides (state-specific)

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

## Additional Content Sources from Kiwix

### 9. iFixit Repair Guides
**Status**: 📥 Ready for automated download
**Size**: ~3.2GB
**Source**: https://download.kiwix.org/zim/ifixit/
**Filename**: `ifixit_en_all_2025-06.zim` (latest version)

**Claude Instructions**:
```bash
# Download iFixit repair guides (useful for equipment maintenance)
wget -c https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-06.zim
# Alternative: March 2025 version
wget -c https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-03.zim
```

---

### 10. Wikibooks
**Status**: 📥 Ready for automated download (older content)
**Size**: ~4.3GB (maxi) or ~3.4GB (nopic)
**Source**: https://download.kiwix.org/zim/wikibooks/
**Filename**: `wikibooks_en_all_maxi_2021-03.zim`

**Claude Instructions**:
```bash
# Download Wikibooks (contains various how-to guides)
# Full version with images
wget -c https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_maxi_2021-03.zim
# Or without images (smaller)
wget -c https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_nopic_2021-03.zim
```

**Note**: These are from 2021 - newer versions may be available for other languages but not English.

---

### 11. Wikiversity
**Status**: 📥 Ready for automated download
**Size**: ~2.2GB (maxi) or ~1.5GB (nopic)
**Source**: https://download.kiwix.org/zim/wikiversity/
**Filename**: `wikiversity_en_all_maxi_2025-06.zim` (latest)

**Claude Instructions**:
```bash
# Download Wikiversity educational content
# Full version with images (recommended)
wget -c https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_maxi_2025-06.zim
# Or without images
wget -c https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_nopic_2025-06.zim
```

---

### 12. Emergency & Medical Content from "Other" Category
**Status**: 📥 Ready for automated download
**Size**: Varies
**Source**: https://download.kiwix.org/zim/other/

**Available Content**:

**a) Medicine Collection**
```bash
# General medicine content (67MB)
wget -c https://download.kiwix.org/zim/other/zimgit-medicine_en_2024-08.zim
```

**b) Post-Disaster Information**
```bash
# Post-disaster survival content (615MB) - HIGHLY RELEVANT
wget -c https://download.kiwix.org/zim/other/zimgit-post-disaster_en_2024-05.zim
```

**c) Water Safety & Purification**
```bash
# Water-related content (20MB)
wget -c https://download.kiwix.org/zim/other/zimgit-water_en_2024-08.zim
```

**d) Practical Solutions (Appropedia)**
```bash
# Appropriate technology and sustainability
wget -c https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim
```

**e) Energy Solutions**
```bash
# Off-grid energy information
wget -c https://download.kiwix.org/zim/other/energypedia_en_all_maxi_2025-06.zim
```

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

## ⚠️ CRITICAL: Claude Code Large File Bug

### The Issue
Claude Code has a known bug (Issue #1452) where it attempts to read entire files into memory when they appear in command outputs. This causes the CLI to crash when working with large files (>1GB), particularly problematic with PrepperApp's massive content files like the 102GB Wikipedia archive.

### What Happens
1. You run a command like `ls` or `find` that shows a large file path
2. Claude Code sees the file path in the output
3. It attempts to read the entire file into memory for processing/hashing
4. With files >1GB, this exhausts available RAM and swap space
5. The process gets killed by the OS with "zsh: killed"

### Workarounds

#### Option 1: Use Environment Variables (Recommended)
```bash
# Set external content path as environment variable
export PREPPER_EXTERNAL_CONTENT="/Volumes/Vid SSD/PrepperApp-Content"

# Use the safe verification scripts
python prepperapp/content/scripts/verify_downloads.py
# or
python prepperapp/content/scripts/safe_content_check.py
```

#### Option 2: Use Safe Mode Scripts
The updated scripts include safe mode by default:
```bash
# Run with safe mode (default - hides large file paths)
python verify_downloads.py

# Run without safe mode (may crash Claude Code!)
python verify_downloads.py --unsafe
```

#### Option 3: Work Around File Paths
- Never directly reference paths to files >1GB in commands
- Use wildcards or partial paths that don't resolve to the actual file
- Check file sizes before displaying paths

### What Doesn't Work
- Adding files to `.claudeignore` - Claude still tries to read them
- Removing read permissions - Claude still attempts to access
- Using `head` or `tail` - The issue occurs when Claude sees the path

### Safe Commands for Large Files
```bash
# Instead of: ls -la /path/to/large/file.zim
# Use: echo "Large file exists at external location"

# Instead of: find /external/drive -name "*.zim"
# Use: find /external/drive -name "*.zim" -size -1G

# Check sizes without exposing paths
du -sh "$PREPPER_EXTERNAL_CONTENT"/* | grep -E "(G|T)" | awk '{print $1, "large_file"}'
```

### Development Tips
1. Always use the safe verification scripts when checking content
2. Set `PREPPER_EXTERNAL_CONTENT` in your shell profile
3. Be cautious with commands that might expose large file paths
4. If Claude Code crashes, restart and use environment variables

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
- Total content sources: 32 (updated with new Kiwix findings)
- Automated downloads ready: 23 (including new Kiwix content)
- Manual downloads required: 9
- Total estimated size: ~165GB raw, ~45GB processed
- **NEW**: Found highly relevant post-disaster and water purification content

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

## 🆕 Critical New Discoveries (2025-07-21)

### Must-Have Survival Content

#### 1. Post-Disaster Guide
- **Size**: 615MB  
- **Perfect for PrepperApp** - Specifically designed for emergency scenarios
- **Download**: 
  ```bash
  aria2c -c -x10 \
    "https://download.kiwix.org/zim/other/zimgit-post-disaster_en_2024-05.zim" \
    -d "/Volumes/Vid SSD/prepperapp-content/survival/"
  ```

#### 2. Water Purification
- **Size**: 20MB
- **Essential** - Clean water is #1 survival priority
- **Download**:
  ```bash
  aria2c -c -x10 \
    "https://download.kiwix.org/zim/other/zimgit-water_en_2024-08.zim" \
    -d "/Volumes/Vid SSD/prepperapp-content/survival/"
  ```

### Updated Download URLs (All Verified)

**Medical**:
- Wikipedia Medical: `wikipedia_en_medicine_maxi_2025-07.zim` (2.0GB, not 4.2GB)
- Medicine Collection: `zimgit-medicine_en_2024-08.zim` (67MB)

**Repair**: 
- iFixit: `ifixit_en_all_2025-06.zim` (3.2GB)

**Reference**:
- Wikibooks: `wikibooks_en_all_maxi_2021-03.zim` (4.3GB)  
- Wikiversity: `wikiversity_en_all_maxi_2025-06.zim` (2.2GB)

**Homesteading**:
- Appropedia: `appropedia_en_all_maxi_2024-03.zim` (1.1GB)

**Note**: MedlinePlus, WikiMed, and WikiHow don't exist as separate ZIMs

---

## Comprehensive Resources

- **[Comprehensive Download Plan](./comprehensive-download-plan.md)** - Complete implementation guide with all commands
- **[Download Status Report](./download-status-report.md)** - Current progress and recommendations

---

Last Updated: 2025-07-21
Next Review: 2025-07-28