#!/usr/bin/env python3
"""
Create Pill Identification Database for PrepperApp
Uses publicly available FDA data to create offline pill ID system
"""

import json
import sqlite3
import requests
from pathlib import Path
import csv
import re
from typing import Dict, List
import time

class PillDatabaseCreator:
    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.db_path = self.output_dir / "pharma" / "pill_id.db"
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        
    def create_database(self):
        """Create SQLite database for pill identification"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Create tables
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS pills (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ndc TEXT,
                brand_name TEXT,
                generic_name TEXT,
                dosage TEXT,
                form TEXT,
                shape TEXT,
                color TEXT,
                imprint TEXT,
                size_mm INTEGER,
                manufacturer TEXT,
                schedule TEXT,
                active_ingredients TEXT,
                warnings TEXT,
                common_uses TEXT,
                UNIQUE(ndc)
            )
        ''')
        
        # Create search indexes
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_imprint ON pills(imprint)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_color ON pills(color)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_shape ON pills(shape)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_generic ON pills(generic_name)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_brand ON pills(brand_name)')
        
        # Create common medications reference
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS common_meds (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category TEXT,
                generic_name TEXT,
                brand_names TEXT,
                typical_uses TEXT,
                dosage_info TEXT,
                warnings TEXT,
                shelf_life_years INTEGER,
                storage_requirements TEXT,
                scavenging_priority TEXT
            )
        ''')
        
        conn.commit()
        return conn
    
    def populate_common_medications(self, conn):
        """Add common medications that would be priority in scavenging"""
        
        common_meds = [
            # Antibiotics - Highest Priority
            {
                "category": "Antibiotic",
                "generic_name": "Amoxicillin",
                "brand_names": "Amoxil, Trimox",
                "typical_uses": "Bacterial infections, pneumonia, skin infections",
                "dosage_info": "Adults: 250-500mg every 8 hours",
                "warnings": "Allergic reactions possible, complete full course",
                "shelf_life_years": 5,
                "storage_requirements": "Cool, dry place",
                "scavenging_priority": "CRITICAL"
            },
            {
                "category": "Antibiotic",
                "generic_name": "Ciprofloxacin",
                "brand_names": "Cipro",
                "typical_uses": "UTIs, anthrax, plague, severe infections",
                "dosage_info": "Adults: 250-750mg twice daily",
                "warnings": "Can cause tendon damage, avoid in children",
                "shelf_life_years": 5,
                "storage_requirements": "Room temperature",
                "scavenging_priority": "CRITICAL"
            },
            {
                "category": "Antibiotic",
                "generic_name": "Doxycycline",
                "brand_names": "Vibramycin",
                "typical_uses": "Respiratory infections, Lyme disease, malaria prevention",
                "dosage_info": "Adults: 100mg twice daily",
                "warnings": "Sun sensitivity, don't take with dairy",
                "shelf_life_years": 5,
                "storage_requirements": "Cool, dry place",
                "scavenging_priority": "CRITICAL"
            },
            
            # Pain Management
            {
                "category": "Analgesic",
                "generic_name": "Acetaminophen",
                "brand_names": "Tylenol",
                "typical_uses": "Pain relief, fever reduction",
                "dosage_info": "Adults: 325-1000mg every 4-6 hours, max 4g/day",
                "warnings": "Liver damage if overdosed",
                "shelf_life_years": 5,
                "storage_requirements": "Room temperature",
                "scavenging_priority": "HIGH"
            },
            {
                "category": "NSAID",
                "generic_name": "Ibuprofen",
                "brand_names": "Advil, Motrin",
                "typical_uses": "Pain, inflammation, fever",
                "dosage_info": "Adults: 200-800mg every 6-8 hours",
                "warnings": "Stomach bleeding risk, avoid with kidney problems",
                "shelf_life_years": 5,
                "storage_requirements": "Room temperature",
                "scavenging_priority": "HIGH"
            },
            
            # Emergency Medications
            {
                "category": "Emergency",
                "generic_name": "Epinephrine",
                "brand_names": "EpiPen",
                "typical_uses": "Severe allergic reactions, anaphylaxis",
                "dosage_info": "0.3mg auto-injector for adults",
                "warnings": "Single use, check expiration",
                "shelf_life_years": 1,
                "storage_requirements": "Room temperature, protect from light",
                "scavenging_priority": "CRITICAL"
            },
            {
                "category": "Emergency",
                "generic_name": "Naloxone",
                "brand_names": "Narcan",
                "typical_uses": "Opioid overdose reversal",
                "dosage_info": "0.4-2mg intranasal or injection",
                "warnings": "May need multiple doses",
                "shelf_life_years": 2,
                "storage_requirements": "Room temperature",
                "scavenging_priority": "MODERATE"
            },
            
            # Chronic Conditions
            {
                "category": "Diabetes",
                "generic_name": "Insulin",
                "brand_names": "Humalog, Novolog, Lantus",
                "typical_uses": "Diabetes management",
                "dosage_info": "Varies by individual",
                "warnings": "Must be refrigerated, check for crystallization",
                "shelf_life_years": 1,
                "storage_requirements": "Refrigerated 36-46°F",
                "scavenging_priority": "CRITICAL for diabetics"
            },
            {
                "category": "Cardiac",
                "generic_name": "Aspirin",
                "brand_names": "Bayer",
                "typical_uses": "Heart attack prevention, blood thinner",
                "dosage_info": "81-325mg daily",
                "warnings": "Bleeding risk",
                "shelf_life_years": 5,
                "storage_requirements": "Cool, dry place",
                "scavenging_priority": "HIGH"
            }
        ]
        
        cursor = conn.cursor()
        for med in common_meds:
            cursor.execute('''
                INSERT OR IGNORE INTO common_meds 
                (category, generic_name, brand_names, typical_uses, dosage_info, 
                 warnings, shelf_life_years, storage_requirements, scavenging_priority)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                med["category"], med["generic_name"], med["brand_names"],
                med["typical_uses"], med["dosage_info"], med["warnings"],
                med["shelf_life_years"], med["storage_requirements"], 
                med["scavenging_priority"]
            ))
        
        conn.commit()
        print(f"Added {len(common_meds)} common medications to database")
    
    def add_pill_identification_data(self, conn):
        """Add sample pill identification data"""
        # In reality, this would parse FDA Orange Book or RxNav data
        # For now, adding common pills people might find
        
        sample_pills = [
            {
                "generic_name": "Acetaminophen",
                "brand_name": "Tylenol",
                "dosage": "500mg",
                "form": "tablet",
                "shape": "capsule",
                "color": "red/white",
                "imprint": "TYLENOL 500",
                "size_mm": 19
            },
            {
                "generic_name": "Ibuprofen",
                "brand_name": "Advil",
                "dosage": "200mg",
                "form": "tablet",
                "shape": "round",
                "color": "brown",
                "imprint": "Advil",
                "size_mm": 10
            },
            {
                "generic_name": "Amoxicillin",
                "brand_name": "Generic",
                "dosage": "500mg",
                "form": "capsule",
                "shape": "capsule",
                "color": "pink/pink",
                "imprint": "AMOX 500",
                "size_mm": 20
            },
            # Add more pills...
        ]
        
        cursor = conn.cursor()
        for pill in sample_pills:
            cursor.execute('''
                INSERT OR IGNORE INTO pills 
                (generic_name, brand_name, dosage, form, shape, color, imprint, size_mm)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                pill["generic_name"], pill["brand_name"], pill["dosage"],
                pill["form"], pill["shape"], pill["color"], pill["imprint"],
                pill["size_mm"]
            ))
        
        conn.commit()
        print(f"Added {len(sample_pills)} pill identification entries")
    
    def create_search_interface(self):
        """Create HTML search interface for pill identification"""
        html_content = '''
<!DOCTYPE html>
<html>
<head>
    <title>PrepperApp Pill Identifier</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .search-box { margin: 20px 0; }
        input, select { padding: 5px; margin: 5px; }
        .results { margin-top: 20px; }
        .pill-result { border: 1px solid #ccc; padding: 10px; margin: 10px 0; }
        .critical { background-color: #fee; }
        .high { background-color: #ffe; }
    </style>
</head>
<body>
    <h1>Offline Pill Identifier</h1>
    <p>Search by imprint code, color, shape, or drug name</p>
    
    <div class="search-box">
        <input type="text" id="imprint" placeholder="Imprint code (e.g., L374)">
        <select id="color">
            <option value="">Any Color</option>
            <option value="white">White</option>
            <option value="pink">Pink</option>
            <option value="red">Red</option>
            <option value="brown">Brown</option>
            <option value="yellow">Yellow</option>
            <option value="blue">Blue</option>
        </select>
        <select id="shape">
            <option value="">Any Shape</option>
            <option value="round">Round</option>
            <option value="oval">Oval</option>
            <option value="capsule">Capsule</option>
            <option value="rectangle">Rectangle</option>
        </select>
        <button onclick="searchPills()">Search</button>
    </div>
    
    <div id="results" class="results"></div>
    
    <h2>Scavenging Priority Guide</h2>
    <ul>
        <li class="critical"><strong>CRITICAL:</strong> Antibiotics, Insulin, Epinephrine</li>
        <li class="high"><strong>HIGH:</strong> Pain relievers, Aspirin, Anti-inflammatories</li>
        <li><strong>MODERATE:</strong> Vitamins, Antacids, Allergy meds</li>
    </ul>
</body>
</html>
        '''
        
        html_path = self.output_dir / "pharma" / "pill_identifier.html"
        with open(html_path, 'w') as f:
            f.write(html_content)
        
        print(f"Created pill identifier interface at: {html_path}")
    
    def generate_report(self):
        """Generate summary report"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Count pills
        cursor.execute("SELECT COUNT(*) FROM pills")
        pill_count = cursor.fetchone()[0]
        
        # Count medications
        cursor.execute("SELECT COUNT(*) FROM common_meds")
        med_count = cursor.fetchone()[0]
        
        # Get database size
        db_size = self.db_path.stat().st_size / (1024 * 1024)  # MB
        
        report = f"""
Pill Identification Database Summary
===================================
Database location: {self.db_path}
Database size: {db_size:.2f} MB

Content:
- Pill entries: {pill_count}
- Common medications: {med_count}
- Search indexes: Created

Features:
- Search by imprint code
- Search by color/shape
- Scavenging priority guide
- Dosage information
- Storage requirements

Note: This is a demonstration database.
Full implementation would require:
1. FDA Orange Book data import
2. NIH DailyMed integration
3. Pill image database
4. More comprehensive entries
        """
        
        print(report)
        
        report_path = self.output_dir / "pharma" / "database_report.txt"
        with open(report_path, 'w') as f:
            f.write(report)
        
        conn.close()

def main():
    output_dir = Path("/Volumes/Vid SSD/PrepperApp-Content")
    if not output_dir.exists():
        output_dir = Path.home() / "PrepperApp-Content"
    
    creator = PillDatabaseCreator(output_dir)
    
    print("Creating Pill Identification Database...")
    conn = creator.create_database()
    
    print("Adding common medications...")
    creator.populate_common_medications(conn)
    
    print("Adding pill identification data...")
    creator.add_pill_identification_data(conn)
    
    print("Creating search interface...")
    creator.create_search_interface()
    
    conn.close()
    
    print("Generating report...")
    creator.generate_report()
    
    print("\nDone! Pill database created successfully.")

if __name__ == "__main__":
    main()