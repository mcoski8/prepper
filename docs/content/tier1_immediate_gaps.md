# Tier 1 Immediate Content Gaps & Acquisition Plan

Generated: 2025-07-30  
Status: URGENT - Required for MVP launch  
Timeline: 2 months to acquire and process

## Executive Summary

This document details the five critical content gaps that must be filled for Tier 1 launch. These represent the minimum viable content beyond what we already have. Total estimated size: 15-20GB additional content.

## Gap 1: WikiHow Curated Subset

### Current Status
**Have**: None  
**Need**: 10,000 most relevant articles for emergencies  
**Size**: ~5GB with images  
**Priority**: CRITICAL - This is our most versatile content

### Content Categories Needed
1. **Medical & First Aid** (2,000 articles)
   - CPR and rescue breathing
   - Wound care and bleeding control  
   - Fracture and sprain treatment
   - Poisoning and overdose response
   - Burn treatment
   - Shock management

2. **Home Emergencies** (2,000 articles)
   - Electrical problems
   - Plumbing failures
   - Gas leaks
   - Structural damage
   - Fire prevention/response
   - Flood damage control

3. **Food & Water** (1,500 articles)
   - Water purification methods
   - Food safety without refrigeration
   - Emergency cooking methods
   - Identifying spoiled food
   - Foraging basics (with warnings)
   - Making water filters

4. **Shelter & Warmth** (1,500 articles)
   - Emergency shelters
   - Insulation techniques
   - Heating without power
   - Cooling strategies
   - Weatherproofing
   - Temporary repairs

5. **Communication & Navigation** (1,000 articles)
   - Emergency signals
   - Radio operation
   - Navigation without GPS
   - Signaling for help
   - Family communication plans
   - Emergency codes

6. **Power & Light** (1,000 articles)
   - Generator safety
   - Battery maintenance
   - Solar basics
   - Emergency lighting
   - Power conservation
   - Manual alternatives

7. **Security & Safety** (1,000 articles)
   - Home security basics
   - Personal safety
   - Child safety
   - Pet emergencies
   - Evacuation procedures
   - Document protection

### Acquisition Strategy
```bash
# Option 1: Direct negotiation with WikiHow
# Contact: content-partnerships@wikihow.com
# Pitch: Offline emergency subset license

# Option 2: Manual curation + fair use
# Create article list → Request specific articles → Process for offline use

# Option 3: Web scraping (check legal first)
python scripts/wikihow_emergency_scraper.py --categories emergency,medical,survival --limit 10000
```

### Processing Requirements
- Remove ads and unnecessary elements
- Optimize images for offline viewing
- Create category indexes
- Build symptom-to-article mappings
- Generate quick reference cards

---

## Gap 2: Plant Identification & Foraging Guide

### Current Status
**Have**: Text descriptions in Wikipedia  
**Need**: Visual identification guide with clear warnings  
**Size**: ~3GB with high-quality images  
**Priority**: HIGH - Safety critical

### Content Requirements
1. **Poisonous Plants** (PRIORITY)
   - Clear photos from multiple angles
   - Look-alike warnings
   - Poisoning symptoms
   - Regional variations
   - Child-safety focus

2. **Edible Plants** (CAREFUL CURATION)
   - Only 100% safe identifications
   - Multiple verification points
   - Seasonal changes shown
   - Preparation requirements
   - Nutritional value

3. **Medicinal Plants** (BASIC ONLY)
   - First aid applications
   - Clear preparation methods
   - Dosage warnings
   - Drug interactions
   - When NOT to use

### Image Requirements
- Minimum 2048x2048 resolution
- Multiple angles (leaf, flower, fruit, bark)
- Seasonal variations
- Size comparisons
- Habitat context

### Acquisition Sources
```bash
# USDA PLANTS Database
wget https://plants.usda.gov/assets/docs/CompletePLANTSList/plantlst.txt
python scripts/download_plant_images.py --source usda --resolution high

# iNaturalist Research Grade
# API: https://www.inaturalist.org/pages/api+reference
python scripts/inaturalist_scraper.py --quality research_grade --license cc

# Regional Extension Offices
# Manual collection from .edu sources
```

### Critical Safety Features
- ⚠️ "NEVER EAT IF UNSURE" warnings
- ❌ Poisonous plant priority placement
- 🔍 Multiple ID verification steps
- 📍 Regional accuracy filters
- 👶 Child poison control emphasis

---

## Gap 3: Emergency Communications Guide

### Current Status
**Have**: Basic Wikipedia articles  
**Need**: Practical implementation guide  
**Size**: ~1GB including frequency databases  
**Priority**: HIGH - Connectivity backup

### Content Structure
1. **Quick Start Guides**
   - Cell phone emergency features
   - Text when calls fail
   - WiFi without internet
   - Mesh networking basics
   - Battery conservation

2. **Radio Operations**
   - HAM radio basics (no license required for emergency)
   - FRS/GMRS radio use
   - Emergency frequencies
   - Scanner programming
   - International distress signals

3. **Regional Frequency Lists**
   - Emergency services by area
   - HAM repeaters
   - Maritime channels
   - Aviation emergency
   - NOAA weather

4. **Alternative Methods**
   - Signal mirrors
   - Ground signals
   - Whistle codes
   - Flag signals
   - Light signals

### Acquisition Plan
```bash
# RadioReference.com data
# Requires API subscription ($15/month)
export RADIOREFERENCE_API_KEY="your_key"
python scripts/download_radio_frequencies.py --regions all

# FCC database
wget https://data.fcc.gov/download/public/uls/complete/l_amat.zip

# ARRL repeater directory
# Manual download required
```

### Integration Requirements
- Location-aware frequency lists
- Offline repeater maps
- Visual antenna guides
- Power/range calculators
- Protocol quick cards

---

## Gap 4: Crisis Navigation Interface

### Current Status
**Have**: Nothing - Standard search only  
**Need**: Emergency-optimized decision trees  
**Size**: ~500MB (mostly logic, not content)  
**Priority**: CRITICAL - Our key differentiator

### Interface Components
1. **"What's Your Emergency?" Entry**
   - Medical emergency
   - No power
   - No water  
   - Severe weather
   - Security threat
   - Evacuation needed

2. **Symptom-Based Medical Trees**
   - Breathing problems → Airway, allergic, anxiety
   - Chest pain → Heart, muscle, anxiety
   - Bleeding → Severity, location, control
   - Unconscious → Breathing check, recovery position
   - Poisoning → Substance, time, symptoms

3. **Guided Walkthroughs**
   - Step-by-step with images
   - Checkpoint confirmations
   - Alternative paths
   - "Get help" prompts
   - Success indicators

4. **Stress UI Features**
   - Extra large buttons
   - High contrast mode
   - Voice commands
   - Haptic feedback
   - Panic shortcuts

### Development Requirements
```javascript
// Example decision tree structure
const medicalEmergency = {
  question: "Is the person conscious?",
  yes: {
    question: "Are they breathing normally?",
    yes: { action: "Check for injuries" },
    no: { action: "Position airway, prepare rescue breathing" }
  },
  no: {
    action: "Check breathing, start CPR if needed",
    guide: "cpr_unconscious_adult"
  }
};
```

### Content Mapping
- Link symptoms to WikiHow articles
- Connect to medical references
- Integrate plant ID for poisoning
- Include communication guides
- Add local emergency numbers

---

## Gap 5: Quick Reference Card System

### Current Status
**Have**: Long-form articles only  
**Need**: Printable/glanceable cards  
**Size**: ~500MB  
**Priority**: HIGH - Critical for stress use

### Card Categories
1. **Medical Emergency Cards**
   - CPR steps (adult/child/infant)
   - Choking response
   - Severe bleeding
   - Shock treatment
   - Allergic reactions
   - Stroke signs

2. **Basic Survival Cards**
   - Water purification methods
   - Shelter priorities
   - Fire starting
   - Signaling techniques
   - Navigation basics
   - Weather signs

3. **Home Emergency Cards**
   - Power outage checklist
   - Gas leak response
   - Flood immediate actions
   - Fire evacuation
   - Earthquake safety
   - Hurricane prep

### Design Requirements
- Single screen/page view
- Mostly visual
- Numbered steps
- Warning highlights
- Print-optimized
- Lamination marks

### Creation Process
```bash
# Extract key points from existing content
python scripts/generate_quick_cards.py --source wikihow,medical --format pdf

# Manual design needed for:
# - Visual hierarchy
# - Icon selection  
# - Color coding
# - Print optimization
```

---

## Implementation Timeline

### Week 1-2: Planning & Partnerships
- Contact WikiHow for licensing
- Set up API access (RadioReference, iNaturalist)
- Design crisis navigation architecture
- Create quick card templates

### Week 3-4: Content Acquisition
- Begin WikiHow download/curation
- Start plant image collection
- Download frequency databases
- Design decision trees

### Week 5-6: Processing & Integration
- Process WikiHow for offline use
- Verify plant identifications
- Build frequency lookups
- Implement crisis navigation

### Week 7-8: Testing & Refinement
- Stress test under poor conditions
- Medical professional review
- Amateur radio operator validation
- User testing with personas

---

## Budget Estimates

### One-Time Costs
- WikiHow license: $5,000-25,000 (negotiable)
- Plant photo licensing: $2,000
- RadioReference API: $180/year
- Design work: $5,000
- **Total: ~$32,000**

### Ongoing Costs
- Content updates: $500/month
- API maintenance: $50/month
- Review/validation: $1,000/month
- **Total: ~$1,550/month**

---

## Success Criteria

### Content Completeness
- ✓ 10,000 WikiHow articles indexed
- ✓ 500+ plants with visual ID
- ✓ 10,000+ emergency frequencies
- ✓ 50+ decision trees
- ✓ 200+ quick reference cards

### Performance Metrics
- Search to result: <2 seconds
- Crisis navigation: <3 taps to guidance
- Image loading: <1 second
- Offline reliability: 100%

### User Validation
- 90% find critical info in <30 seconds
- 95% successful task completion
- 85% would recommend
- 0% dangerous misinformation

---

## Risk Mitigation

### Legal Risks
- **Fair use documentation**
- **License agreements**
- **Attribution compliance**
- **Medical disclaimers**
- **Liability insurance**

### Content Risks
- **Expert review required**
- **Poisonous plant double-check**
- **Medical accuracy validation**
- **Regional relevance verification**
- **Update procedures**

### Technical Risks
- **Offline search performance**
- **Image storage optimization**
- **Decision tree complexity**
- **Voice command accuracy**
- **Battery usage**

---

## Conclusion

These five gaps represent the minimum additional content needed to launch Tier 1. With our existing content (Wikipedia medical, water purification, post-disaster guide, etc.) plus these additions, we'll have a compelling entry-level product that truly serves the "Practical Pat" persona during real emergencies.

Total additional storage: ~15-20GB  
Total Tier 1 size: 45-64GB  
Development time: 2 months  
Budget needed: ~$35,000 + $1,500/month