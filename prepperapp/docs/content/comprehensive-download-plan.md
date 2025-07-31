# PrepperApp Comprehensive Content Download Plan

## Executive Summary

This plan addresses all failed downloads and missing content, with verified sources and a prioritized acquisition strategy. Total new content identified: ~15GB of critical survival resources.

## 🚨 Priority Downloads (Fix Immediately)

### 1. Fix Wrong Version - Wikipedia Medical
**Current:** 123MB (mini version)  
**Correct:** 2.0GB (maxi version)  
```bash
# Delete wrong version
rm "/Volumes/Vid SSD/prepperapp-content/medical/wikipedia_en_medicine_maxi_2025-07.zim"

# Download correct version
aria2c -c -x10 \
  "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/medical/"
```

### 2. Critical New Discovery - Post-Disaster Content
**HIGHLY RECOMMENDED:** Specifically designed for emergency scenarios
```bash
aria2c -c -x10 \
  "https://download.kiwix.org/zim/other/zimgit-post-disaster_en_2024-05.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/survival/"
```

### 3. Water Purification Guide
**Essential for survival** - Only 20MB
```bash
aria2c -c -x10 \
  "https://download.kiwix.org/zim/other/zimgit-water_en_2024-08.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/survival/"
```

## 📥 Fix Failed Downloads

### Medical Content
```bash
# Medicine collection (67MB)
aria2c -c -x10 \
  "https://download.kiwix.org/zim/other/zimgit-medicine_en_2024-08.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/medical/"

# Note: MedlinePlus and WikiMed as separate ZIMs don't exist
# The Wikipedia Medical maxi (2GB) contains comprehensive medical content
```

### Repair Guides
```bash
# iFixit (3.2GB) - June 2025 version
aria2c -c -x10 \
  "https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-06.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/repair/"
```

### Reference Materials
```bash
# Wikibooks (4.3GB with images)
aria2c -c -x10 \
  "https://download.kiwix.org/zim/wikibooks/wikibooks_en_all_maxi_2021-03.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/reference/"

# Wikiversity (2.2GB with images)
aria2c -c -x10 \
  "https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_maxi_2025-06.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/reference/"
```

### Survival/How-To
```bash
# WikiHow doesn't exist as ZIM - use alternative sources
# Appropedia - sustainable living (1.1GB)
aria2c -c -x10 \
  "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2024-03.zim" \
  -d "/Volumes/Vid SSD/prepperapp-content/homestead/"
```

## 🆕 Fill Empty Categories

### 1. Communications
**Manual downloads required** - No ZIM available
```bash
# FCC Frequency Allocation Chart
wget "https://www.fcc.gov/sites/default/files/media/radio_spectrum_chart.pdf" \
  -O "/Volumes/Vid SSD/prepperapp-content/comms/fcc_frequency_chart.pdf"

# ARRL Band Plan
wget "http://www.arrl.org/files/file/Regulatory/Band%20Chart/Band%20Chart%208_5%20X%2011%20Color.pdf" \
  -O "/Volumes/Vid SSD/prepperapp-content/comms/arrl_band_plan.pdf"

# NOAA Weather Radio Frequencies
wget "https://www.weather.gov/nwr/Maps" \
  -O "/Volumes/Vid SSD/prepperapp-content/comms/noaa_weather_frequencies.html"
```

### 2. Family Care
```bash
# Red Cross First Aid Guide
wget "https://www.redcross.org/content/dam/redcross/atg/PDF_s/Health___Safety_Services/Training/Adult_ready_reference.pdf" \
  -O "/Volumes/Vid SSD/prepperapp-content/family/redcross_first_aid.pdf"

# CDC Emergency Preparedness
wget "https://www.cdc.gov/childrenindisasters/checklists/kids-and-families.pdf" \
  -O "/Volumes/Vid SSD/prepperapp-content/family/cdc_family_emergency.pdf"
```

### 3. Homesteading
```bash
# USDA Complete Guide to Home Canning
wget "https://nchfp.uga.edu/publications/publications_usda.html" \
  -O "/Volumes/Vid SSD/prepperapp-content/homestead/usda_canning_guide.pdf"

# Also use the Appropedia ZIM downloaded above
```

### 4. Plants
```bash
# USDA PLANTS Database
wget "https://plants.usda.gov/assets/docs/CompletePLANTSList/CompleteCharacteristics.csv" \
  -O "/Volumes/Vid SSD/prepperapp-content/plants/usda_plants_database.csv"

# Regional guides - example for California
wget "https://ucanr.edu/sites/poisonous_safe_plants/files/154528.pdf" \
  -O "/Volumes/Vid SSD/prepperapp-content/plants/california_poisonous_plants.pdf"
```

## 🤖 AI-Generated Content Strategy

### When to Use AI
1. **Synthesizing checklists** from multiple verified sources
2. **Reformatting content** for mobile viewing
3. **Creating quick reference cards** from detailed guides

### When NOT to Use AI
- ❌ Medical dosages or procedures
- ❌ Plant/mushroom identification
- ❌ Chemical formulations
- ❌ Any safety-critical information

### AI Content Workflow
```bash
# Example: Generate emergency kit checklist
# 1. Gather source materials (FEMA, Red Cross PDFs)
# 2. Extract relevant sections
# 3. Use AI to synthesize with this prompt:

cat <<EOF > checklist_prompt.txt
Based ONLY on the provided FEMA and Red Cross emergency preparedness guides,
create a prioritized 72-hour emergency kit checklist in Markdown format.
Group items by category: Water, Food, Medical, Tools, Documents, Clothing.
Include quantities per person. Do not add any items not mentioned in the sources.
EOF

# 4. Manually verify every item against source documents
# 5. Save as: /family/ai_verified_emergency_checklist.md
```

## 🔍 Verification Strategy

### Pre-Download Verification
```bash
# Check if URL is valid and file size before downloading
check_zim_url() {
    URL=$1
    echo "Checking: $URL"
    curl -sI "$URL" | grep -E "(Content-Length|HTTP/)"
}
```

### Post-Download Verification
```bash
# Verify all ZIM files after download
cd "/Volumes/Vid SSD/prepperapp-content"
find . -name "*.zim" -type f -exec ls -lah {} \; | sort -k5 -h

# Remove any files under 1MB (likely errors)
find . -name "*.zim" -type f -size -1M -exec rm {} \;
```

## 📊 Download Priority Matrix

| Priority | Content | Size | Critical for Survival |
|----------|---------|------|----------------------|
| 🔴 HIGH | Wikipedia Medical (correct) | 2.0GB | Yes - Medical emergencies |
| 🔴 HIGH | Post-Disaster Guide | 615MB | Yes - Designed for emergencies |
| 🔴 HIGH | Water Purification | 20MB | Yes - Clean water essential |
| 🟡 MED | iFixit Repairs | 3.2GB | Yes - Equipment maintenance |
| 🟡 MED | Medicine Collection | 67MB | Yes - Drug information |
| 🟢 LOW | Wikibooks | 4.3GB | No - General reference |
| 🟢 LOW | Wikiversity | 2.2GB | No - Educational content |

## 🚀 Implementation Steps

1. **Clean up failed downloads**
   ```bash
   find "/Volumes/Vid SSD/prepperapp-content" -size 196c -delete
   ```

2. **Run priority downloads first** (Medical, Post-Disaster, Water)

3. **Download remaining ZIMs** using aria2c scripts

4. **Manual PDF downloads** for comms/family/plants

5. **Verify all downloads** meet minimum size requirements

6. **Generate AI content** only where needed with verification

## 📈 Expected Results

- **Total New Content:** ~15GB
- **Critical Survival Content:** ~3GB (can fit in Tier 1 core app)
- **Extended Knowledge:** ~12GB (for Tier 2 modules)
- **Coverage:** 100% of originally planned categories

## 🔧 Maintenance

Create a monthly cron job to check for updated ZIM files:
```bash
#!/bin/bash
# check_zim_updates.sh
curl -s https://download.kiwix.org/zim/ | grep -E "(wikipedia_en_medicine|zimgit-post-disaster|zimgit-water)" > latest_versions.txt
diff latest_versions.txt previous_versions.txt
```

---

Last Updated: 2025-07-21
Next Review: 2025-07-28