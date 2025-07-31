# Tier 1 Content Action Plan

## Immediate Actions (This Week)

### 1. WikiHow Partnership Outreach
**Contact**: content-partnerships@wikihow.com
**Request**: 10,000 article subset focused on:
- Medical emergencies (CPR, choking, wounds)
- Water purification and storage
- Emergency shelter construction
- Fire starting methods
- Basic food preservation
- Emergency communications

**Pitch Points**:
- Offline emergency preparedness app
- Credit WikiHow prominently
- Non-commercial open source project
- Life-saving information access

### 2. Process Existing Content
We already have valuable content that needs processing:

#### PDFs to Extract:
- `/Volumes/Vid SSD/prepperapp-content/plants/PoisonousPlants.pdf` (4.5MB)
- `/Volumes/Vid SSD/prepperapp-content/medical/where-there-is-no-doctor-2019.pdf` (40MB)
- `/Volumes/Vid SSD/prepperapp-content/water/water-purification.pdf` (20MB)
- `/Volumes/Vid SSD/prepperapp-content/emergency/post-disaster-survival.pdf` (615MB)

#### Processing Steps:
1. Extract text content using PyPDF2 or similar
2. Create structured JSON with:
   - Title/chapter organization
   - Search keywords
   - Quick reference summaries
   - Emergency decision trees
3. Extract critical images (diagrams, identification photos)
4. Compress images for mobile (WebP format)

### 3. Quick Reference Cards
Create visual cards for instant access during emergencies:

#### Priority Cards:
1. **Bleeding Control** - Tourniquet placement, pressure points
2. **Water Purification** - Boiling times, chemical ratios, filter methods
3. **Poisonous Plants** - Top 20 most dangerous with photos
4. **Emergency Signals** - International distress signals
5. **Shock Treatment** - Recognition and immediate steps
6. **Hypothermia/Heat Stroke** - Temperature thresholds and treatment

#### Card Format:
- 1080x1920 mobile-optimized images
- High contrast for outdoor viewing
- Minimal text, maximum visuals
- Color-coded by severity/urgency

## Technical Implementation

### Search Infrastructure
```python
# Tantivy index structure
{
    "content_type": "medical|water|shelter|food|comms",
    "urgency": "immediate|hours|days",
    "title": "...",
    "keywords": ["..."],
    "content": "...",
    "images": ["..."],
    "source": "..."
}
```

### Crisis Navigation UI
```
EMERGENCY → 
├── BLEEDING → Direct Pressure → Tourniquet → Shock
├── NOT BREATHING → CPR → Recovery Position
├── POISONING → Identify → Call Poison Control → Induce Vomiting?
└── ENVIRONMENTAL → Too Hot → Too Cold → Can't Find Water
```

## Content We're NOT Pursuing
Based on our analysis:
- ❌ USDA plant database (requires auth, no images)
- ❌ FCC amateur radio (failed download, Tier 2/3 content)
- ❌ Complex military manuals (too specialized)
- ❌ Gear reviews and product guides
- ❌ Theoretical prep scenarios

## Success Metrics
- [ ] 500MB-1GB total Tier 1 size
- [ ] <100ms search response time
- [ ] All content works offline
- [ ] Crisis UI navigable in <3 taps
- [ ] 90% of emergency scenarios covered

## Next Sprint Focus
1. WikiHow API integration or scraping solution
2. PDF processing pipeline
3. Quick reference card generator
4. Tantivy search prototype
5. Crisis UI wireframes

## Timeline
- Week 1: WikiHow outreach, PDF extraction scripts
- Week 2: Quick reference cards, search indexing
- Week 3: UI prototypes, content packaging
- Week 4: Testing and optimization

Last Updated: 2025-07-31