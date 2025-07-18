# Content Curation Guide

## Overview
This guide outlines the process for selecting, validating, and preparing survival content for PrepperApp. Every piece of content must meet strict accuracy, practicality, and clarity standards to ensure user safety in emergency situations.

## Curation Principles

### 1. Life Safety First
- **Critical Accuracy**: Medical and safety procedures must be 100% accurate
- **Evidence-Based**: All content backed by authoritative sources
- **Field-Tested**: Procedures validated by survival experts
- **Conservative Approach**: When in doubt, choose the safer option

### 2. Practical Over Theoretical
- **Real-World Application**: Content must work with minimal resources
- **Clear Instructions**: Step-by-step procedures anyone can follow
- **Visual Priority**: Diagrams over lengthy text descriptions
- **Time-Sensitive**: Prioritize immediate survival needs

### 3. Universal Accessibility
- **8th Grade Reading Level**: Simple, clear language
- **Cultural Neutrality**: Avoid region-specific assumptions
- **No Special Equipment**: Focus on improvised solutions
- **Stress-Tested**: Readable under panic conditions

## Content Sources

### Approved Sources

#### Public Domain
- **US Military Manuals**
  - FM 21-76 Army Survival Manual
  - TC 4-02.1 First Aid
  - FM 4-25.11 First Aid
  
- **Government Publications**
  - CDC Emergency Preparedness
  - FEMA Disaster Guides
  - USDA Plant Databases
  
- **International Organizations**
  - WHO Emergency Care
  - Red Cross/Red Crescent Guides
  - UN Disaster Response

#### Creative Commons
- **Medical Resources**
  - Where There Is No Doctor (Hesperian)
  - OpenStax Anatomy & Physiology
  - WikiEM Emergency Medicine
  
- **Educational Materials**
  - OpenStax Biology (plant identification)
  - MIT OpenCourseWare (engineering basics)
  - Khan Academy (basic sciences)

#### Licensed Content
- **Expert Contributions**
  - Wilderness medicine textbooks
  - Survival school curricula
  - Regional foraging guides
  
- **Original Content**
  - Commissioned expert articles
  - Custom illustrations
  - Video demonstrations

### Prohibited Sources
- Unverified blog posts
- Forum discussions
- AI-generated content without expert review
- Copyrighted material without license
- Outdated medical procedures
- Experimental techniques

## Validation Process

### Medical Content Validation

#### Required Reviews
1. **Primary Medical Review**
   - Board-certified emergency physician
   - Current practice experience
   - Wilderness medicine preferred

2. **Secondary Review**
   - Different medical professional
   - Paramedic or nurse acceptable
   - Focus on field practicality

3. **Legal Review**
   - Medical liability assessment
   - Disclaimer requirements
   - Scope of practice issues

#### Validation Checklist
```markdown
## Medical Procedure Validation

- [ ] Procedure name matches medical standards
- [ ] Indications clearly stated
- [ ] Contraindications listed
- [ ] Step-by-step instructions clear
- [ ] Anatomical landmarks accurate
- [ ] Dosages double-checked
- [ ] Complications addressed
- [ ] When to seek help specified
- [ ] Alternative methods provided
- [ ] References cited

Reviewer: _________________ Date: _________
License #: ________________ State: _________
```

### Plant/Wildlife Validation

#### Expert Requirements
- **Botanist**: PhD or equivalent experience
- **Regional Expert**: Local knowledge required
- **Toxicologist**: For poisonous species

#### Validation Process
1. **Scientific Accuracy**
   - Correct Latin names
   - Accurate identification features
   - Habitat information correct
   - Seasonal variations noted

2. **Safety Verification**
   - Look-alike warnings
   - Preparation requirements
   - Toxicity levels accurate
   - Regional variations noted

3. **Photo Validation**
   - Multiple angles shown
   - Seasonal appearances
   - Size references included
   - High resolution (min 1200px)

## Content Preparation

### Text Processing

#### Simplification Rules
1. **Sentence Structure**
   - Maximum 20 words per sentence
   - Active voice preferred
   - One concept per sentence
   - Avoid subordinate clauses

2. **Vocabulary**
   - Common words only
   - Define technical terms
   - Avoid jargon
   - Use consistent terminology

3. **Formatting**
   - Short paragraphs (3-4 sentences)
   - Bullet points for lists
   - Bold for warnings
   - Clear headings

#### Example Transformation
```markdown
# Before
"Hemorrhage control can be achieved through the application of direct manual pressure to the wound site, which should be maintained continuously for a minimum of 10-15 minutes to allow for clot formation."

# After
"To stop bleeding:
1. Press directly on the wound with a clean cloth
2. Press hard and don't let go
3. Keep pressing for 15 minutes
4. Don't peek - this breaks the clot"
```

### Image Guidelines

#### Required Images
- **Medical Procedures**: Step-by-step photos/diagrams
- **Plant ID**: Minimum 4 angles + size reference
- **Knots**: Progressive tying sequence
- **Shelters**: Construction stages

#### Image Standards
- **Resolution**: 1200px wide maximum
- **Format**: WebP or AVIF only
- **Compression**: 75% quality
- **File Size**: <200KB per image
- **Style**: High contrast, clear details

#### Diagram Requirements
```yaml
style:
  background: white or transparent
  lines: minimum 3px width
  colors: high contrast only
  labels: 14pt minimum
  arrows: clear directional
  
content:
  - Remove decorative elements
  - Simplify complex illustrations
  - Number sequential steps
  - Include scale references
  - Mark critical points
```

### Metadata Standards

#### Required Fields
```json
{
  "id": "uuid-v4",
  "title": "Clear, descriptive title",
  "category": "medical|water|shelter|fire|food|navigation|signals",
  "subcategory": "specific-topic",
  "priority": "critical|high|medium|low",
  "reading_time": 3,
  "difficulty": "beginner|intermediate|advanced",
  "climate": ["temperate", "tropical", "arctic", "desert", "all"],
  "required_items": ["clean-cloth", "water"],
  "related_articles": ["article-id-1", "article-id-2"],
  "warnings": ["Seek medical help immediately if..."],
  "last_reviewed": "2025-07-18",
  "reviewer_id": "expert-id",
  "version": "1.0.0"
}
```

## Quality Checklist

### Pre-Publication Review

#### Content Review
- [ ] Accuracy verified by expert
- [ ] Procedures tested in field
- [ ] Safety warnings prominent
- [ ] Alternative methods included
- [ ] Regional variations noted
- [ ] Sources cited

#### Readability Review
- [ ] 8th grade reading level confirmed
- [ ] Sentences under 20 words
- [ ] Technical terms defined
- [ ] Clear action steps
- [ ] Logical flow

#### Technical Review
- [ ] Images optimized
- [ ] Metadata complete
- [ ] Links functional
- [ ] Search keywords added
- [ ] Category correct

### Red Flags - Automatic Rejection
- Medical procedures without expert review
- Plant ID without multiple confirmation sources
- Survival techniques requiring special equipment
- Content promoting dangerous practices
- Unverified "traditional" remedies
- Political or religious content
- Commercial product endorsements

## Maintenance Schedule

### Review Cycles
- **Critical Medical**: Every 6 months
- **General Medical**: Annual
- **Plant/Wildlife**: Seasonal
- **Techniques**: Biannual
- **All Content**: After any incident report

### Update Triggers
- New medical guidelines published
- Safety incident reported
- Expert recommendation
- User feedback pattern
- Legal requirement change

## Expert Network

### Required Experts
1. **Medical Team**
   - Emergency physicians (2)
   - Wilderness medicine specialist
   - Paramedic/EMT
   - Nurse practitioner

2. **Natural Sciences**
   - Botanist
   - Mycologist (mushrooms)
   - Herpetologist (reptiles)
   - Entomologist (insects)

3. **Survival Specialists**
   - Military SERE instructor
   - Wilderness guide (certified)
   - Traditional skills expert
   - Regional specialists (per area)

4. **Support Team**
   - Technical writer
   - Medical illustrator
   - Legal advisor
   - Cultural consultant

### Expert Compensation
- Initial review: $200-500 per article
- Annual updates: $100 per article
- Consultation: $150/hour
- Emergency review: 2x standard rate

## Legal Compliance

### Required Disclaimers
```markdown
⚠️ MEDICAL DISCLAIMER
This information is for emergency use when professional medical 
help is not available. Always seek professional medical care 
when possible. PrepperApp and its contributors are not liable 
for outcomes from using this information.
```

### Documentation Requirements
- Expert reviewer credentials on file
- Review dates logged
- Change history maintained
- Source materials archived
- Legal review documentation

## Metrics & Monitoring

### Quality Metrics
- Expert approval rate: >95%
- Readability score: 8th grade
- Image optimization: <200KB
- Review cycle compliance: 100%
- User incident reports: <0.01%

### Tracking Requirements
```sql
CREATE TABLE content_reviews (
    content_id TEXT PRIMARY KEY,
    reviewer_id TEXT NOT NULL,
    review_date DATE NOT NULL,
    review_type TEXT NOT NULL,
    issues_found INTEGER DEFAULT 0,
    status TEXT NOT NULL,
    next_review_date DATE NOT NULL
);
```

## Emergency Update Protocol

### Immediate Action Required
1. **Safety Issue Reported**
   - Remove content immediately
   - Notify all users
   - Expert review within 24 hours
   - Legal consultation
   - Corrected content or permanent removal

2. **Update Process**
   - Document issue thoroughly
   - Multiple expert review
   - Test corrections
   - Legal sign-off
   - Phased rollout
   - Monitor feedback

### Communication Template
```
Subject: Critical Content Update - [Article Name]

We've identified an issue with [specific content].

Immediate Action:
- Stop using this procedure
- See corrected information: [link]
- Previous version archived: [date]

Details: [what was wrong, what's corrected]

This update reviewed by:
- Dr. [Name], MD, Emergency Medicine
- [Name], Wilderness EMT

Questions? safety@prepperapp.com
```