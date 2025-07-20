#!/usr/bin/env python3
"""
Generate test content bundle for PrepperApp development.
Creates AI-written, ultra-concise emergency procedures.
Target size: 5-10MB for quick development iteration.
"""

import json
import sqlite3
import os
from datetime import datetime
from pathlib import Path

# Test content topics - true "core of core" emergencies
TEST_CONTENT = {
    "medical": [
        {
            "title": "Stop Severe Bleeding",
            "priority": 0,
            "time_critical": "3-5 minutes",
            "content": """IMMEDIATE ACTIONS:
1. Apply direct pressure with cloth/hand
2. Press HARD - harder than feels right
3. Do NOT remove first cloth if soaked
4. Add more cloth on top
5. If spurting/pooling: Apply tourniquet

TOURNIQUET:
- 2-3 inches above wound (not on joint)
- Tighten until bleeding stops
- Write time on forehead
- NEVER loosen

PRESSURE POINTS (if no tourniquet):
- Arm: Inside upper arm against bone
- Leg: Groin crease, push hard
- Maintain pressure 10+ minutes"""
        },
        {
            "title": "Cardiac Arrest - CPR",
            "priority": 0,
            "time_critical": "0-4 minutes",
            "content": """CHECK: Tap shoulders, shout. No response? START CPR.

ADULT CPR:
1. Hard surface, person on back
2. Heel of hand on center of chest
3. Other hand on top, interlace fingers
4. Arms straight, shoulders over hands
5. Push HARD, FAST - 2 inches deep
6. 30 compressions (100-120/minute)
7. Tilt head, lift chin
8. 2 breaths (1 second each)
9. Repeat 30:2 until help/exhaustion

CHILD (1-8): Same but 1 hand
INFANT: 2 fingers, 1.5 inches deep

Don't stop. Switch every 2 minutes if possible."""
        },
        {
            "title": "Choking",
            "priority": 0,
            "time_critical": "0-3 minutes", 
            "content": """CONSCIOUS ADULT/CHILD:
1. Stand behind, arms around waist
2. Fist above navel, below ribs
3. Grasp fist with other hand
4. Pull IN and UP sharply
5. Repeat until clear or unconscious

INFANT:
1. Face down on forearm
2. 5 back blows between shoulders
3. Turn over
4. 5 chest thrusts (like CPR)
5. Repeat sequence

UNCONSCIOUS: Start CPR
PREGNANT/OBESE: Chest thrusts
ALONE: Thrust over chair back"""
        }
    ],
    "water": [
        {
            "title": "Emergency Water Purification",
            "priority": 0,
            "time_critical": "0-72 hours",
            "content": """BOILING (Most Reliable):
- Rolling boil 1 minute (3 min above 6,500ft)
- Let cool, pour between containers to add air

CHEMICAL:
- Bleach: 8 drops/gallon clear, 16 if cloudy
- Wait 30 minutes
- Should smell slightly of chlorine

FILTERING (Partial):
- Coffee filter/cloth removes particles only
- Sand/gravel/charcoal helps
- Still MUST boil or treat

FINDING WATER:
- Dew collection at dawn
- Rain catchment (after 30 min)
- Follow animals at dawn/dusk
- Green vegetation = water nearby

NEVER: Drink urine, blood, seawater, alcohol"""
        }
    ],
    "shelter": [
        {
            "title": "Hypothermia Prevention",
            "priority": 0,
            "time_critical": "0-3 hours",
            "content": """RECOGNIZE:
- Shivering, confusion, slurred speech
- Loss of coordination
- Drowsiness

IMMEDIATE:
1. Get dry - wet kills
2. Insulate from ground (critical)
3. Wind protection
4. Layer clothing
5. Cover head/neck (40% heat loss)

EMERGENCY SHELTER:
- Pile leaves/debris 3 feet thick
- Burrow in middle
- Cover with branches/tarp
- Small space = warmer

WARMTH WITHOUT FIRE:
- Exercise large muscles
- Eat if possible (generates heat)
- Share body heat
- Stay awake

NEVER: Alcohol, cotton clothing, ignore shivering"""
        }
    ],
    "signaling": [
        {
            "title": "Signal for Rescue",
            "priority": 1,
            "time_critical": "When safe",
            "content": """UNIVERSAL SIGNALS:
- 3 of anything = HELP
- X = Need medical
- V = Need supplies
- → = Going this way

VISUAL:
- Mirror/phone screen flash
- Smoke (day), fire (night)
- Bright fabric/contrast
- Ground signals 10ft+ size

AUDIO:
- 3 whistle blasts
- 3 gunshots
- Car horn: SOS (...---...)

BODY SIGNALS (Aircraft):
- Both arms up = YES/pickup
- One arm up/down = NO
- Arms horizontal = need medical
- Waving = ALL OK, don't land

Make signals BIGGEST possible
Change landscape (spell HELP)
Movement attracts attention"""
        }
    ],
    "immediate_dangers": [
        {
            "title": "Carbon Monoxide",
            "priority": 0,
            "time_critical": "0-30 minutes",
            "content": """SYMPTOMS (acts fast):
- Headache, dizziness
- Nausea, confusion
- Cherry red skin/lips

IMMEDIATE:
1. GET OUT to fresh air NOW
2. Call 911 if available
3. Don't re-enter
4. Open all windows/doors from outside

SOURCES:
- ANY flame in enclosed space
- Generators, grills, camp stoves
- Cars in garages
- Blocked chimneys

PREVENTION:
- NEVER burn anything indoors
- Generator 20+ feet from openings
- Battery CO detector

If someone collapses inside:
- Hold breath, drag them out
- Don't become victim #2"""
        }
    ]
}

def create_test_database():
    """Create a test SQLite database with emergency content."""
    db_path = Path("data/processed/test_content.db")
    db_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Remove old database if exists
    if db_path.exists():
        os.remove(db_path)
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create schema matching our medical database
    cursor.execute("""
        CREATE TABLE articles (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            category TEXT NOT NULL,
            priority INTEGER NOT NULL,
            time_critical TEXT,
            search_text TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    cursor.execute("""
        CREATE INDEX idx_priority ON articles(priority);
    """)
    
    cursor.execute("""
        CREATE INDEX idx_category ON articles(category);
    """)
    
    # Insert test content
    article_id = 1
    for category, articles in TEST_CONTENT.items():
        for article in articles:
            search_text = f"{article['title']} {article['content']}".lower()
            cursor.execute("""
                INSERT INTO articles 
                (id, title, content, category, priority, time_critical, search_text)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                article_id,
                article['title'],
                article['content'],
                category,
                article['priority'],
                article.get('time_critical', 'Not time critical'),
                search_text
            ))
            article_id += 1
    
    # Add metadata table
    cursor.execute("""
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)
    
    cursor.execute("""
        INSERT INTO metadata (key, value) VALUES 
        ('version', '1.0'),
        ('type', 'test_content'),
        ('created', ?),
        ('article_count', ?),
        ('size_mb', '0.1')
    """, (datetime.now().isoformat(), article_id - 1))
    
    conn.commit()
    
    # Add some bulk test articles to reach ~5MB
    print("Adding bulk test content...")
    
    # Add variations and related content
    bulk_topics = [
        ("Shock Treatment", "medical", 0),
        ("Allergic Reaction", "medical", 0),
        ("Burns", "medical", 0),
        ("Fractures", "medical", 1),
        ("Heat Exhaustion", "medical", 0),
        ("Finding Direction", "navigation", 1),
        ("Fire Starting", "shelter", 1),
        ("Emergency Supplies", "preparation", 2),
        ("Snake Bites", "medical", 1),
        ("Water Storage", "water", 1),
    ]
    
    for title, category, priority in bulk_topics:
        # Generate some realistic content
        content = f"""EMERGENCY PROCEDURE: {title}

IMMEDIATE ASSESSMENT:
- Check for immediate life threats
- Ensure scene safety
- Gather available resources

CRITICAL ACTIONS:
1. Primary intervention specific to {title}
2. Monitor vital signs if possible
3. Prevent condition deterioration
4. Prepare for evacuation if needed

DETAILED STEPS:
[This would contain specific detailed steps for {title}. In a real scenario, 
this would be properly researched and validated medical/survival information.
For testing purposes, this placeholder demonstrates the content structure.]

WARNING SIGNS:
- Deteriorating condition
- Unresponsive to treatment
- Development of complications

FOLLOW-UP:
- Continue monitoring
- Document time and interventions
- Prepare for professional medical care when available
"""
        
        cursor.execute("""
            INSERT INTO articles 
            (id, title, content, category, priority, time_critical, search_text)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            article_id,
            title,
            content,
            category,
            priority,
            "Varies",
            f"{title} {content}".lower()
        ))
        article_id += 1
    
    conn.commit()
    
    # Get final database size
    conn.close()
    size_mb = os.path.getsize(db_path) / (1024 * 1024)
    
    print(f"\nTest database created:")
    print(f"  Path: {db_path}")
    print(f"  Articles: {article_id - 1}")
    print(f"  Size: {size_mb:.2f} MB")
    
    # Create manifest file
    manifest = {
        "version": "1.0",
        "type": "test_content",
        "name": "PrepperApp Test Content",
        "description": "Minimal emergency procedures for app development",
        "created": datetime.now().isoformat(),
        "stats": {
            "article_count": article_id - 1,
            "size_mb": round(size_mb, 2),
            "categories": list(TEST_CONTENT.keys()) + ["navigation", "preparation"],
            "priority_0_count": len([a for articles in TEST_CONTENT.values() 
                                   for a in articles if a.get("priority") == 0]) + 3
        },
        "content_structure": {
            "database": "test_content.db",
            "format": "sqlite3",
            "compression": "none",
            "indexes": ["priority", "category"]
        }
    }
    
    manifest_path = Path("data/processed/test_content_manifest.json")
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)
    
    print(f"  Manifest: {manifest_path}")
    
    return db_path, manifest

if __name__ == "__main__":
    print("PrepperApp Test Content Generator")
    print("=================================")
    print("Creating minimal content bundle for mobile development...\n")
    
    db_path, manifest = create_test_database()
    
    print("\n✅ Test content ready for mobile development!")
    print("\nThis test bundle includes:")
    print("- Critical medical procedures (bleeding, CPR, choking)")
    print("- Water purification methods")
    print("- Hypothermia prevention")
    print("- Rescue signaling")
    print("- Carbon monoxide dangers")
    print("\nUse this for app development while full content is prepared.")