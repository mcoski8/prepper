#!/bin/bash

# Download FDA Orange Book and NIH DailyMed data for comprehensive pill database

CONTENT_DIR="/Volumes/Vid SSD/PrepperApp-Content"
PHARMA_DIR="$CONTENT_DIR/pharma"
mkdir -p "$PHARMA_DIR/fda_data"

echo "=== Downloading FDA Orange Book Data ==="
echo "This contains all approved drug products with therapeutic equivalence"

# FDA Orange Book - Products file
echo "Downloading FDA Orange Book products..."
curl -L -o "$PHARMA_DIR/fda_data/orange_book_products.zip" \
    "https://www.fda.gov/media/76860/download"

# FDA Orange Book - Patent and Exclusivity
echo "Downloading FDA Orange Book patent data..."
curl -L -o "$PHARMA_DIR/fda_data/orange_book_patent.zip" \
    "https://www.fda.gov/media/76862/download"

echo
echo "=== Downloading NIH DailyMed Resources ==="
echo "This contains detailed drug labeling and pill images"

# DailyMed provides comprehensive drug labeling
# Note: Full DailyMed download requires their data dump service
echo "For comprehensive DailyMed data, visit:"
echo "https://dailymed.nlm.nih.gov/dailymed/spl-resources.cfm"

# Download sample pill image database structure
mkdir -p "$PHARMA_DIR/pill_images"

echo
echo "=== Creating Enhanced Pill Database ==="

# Create enhanced database creation script
cat > "$PHARMA_DIR/process_fda_data.py" << 'EOF'
#!/usr/bin/env python3
"""
Process FDA Orange Book data into searchable pill database
"""

import zipfile
import csv
import sqlite3
from pathlib import Path
import json

def process_orange_book(pharma_dir):
    """Extract and process FDA Orange Book data"""
    
    # Extract products data
    products_zip = pharma_dir / "fda_data" / "orange_book_products.zip"
    if products_zip.exists():
        print("Extracting Orange Book products...")
        with zipfile.ZipFile(products_zip, 'r') as zip_ref:
            zip_ref.extractall(pharma_dir / "fda_data")
    
    # Connect to database
    db_path = pharma_dir / "pill_id_comprehensive.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Create comprehensive pills table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS fda_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ingredient TEXT,
            df_route TEXT,
            trade_name TEXT,
            applicant TEXT,
            strength TEXT,
            appl_type TEXT,
            appl_no TEXT,
            product_no TEXT,
            te_code TEXT,
            approval_date TEXT,
            rld TEXT,
            type TEXT,
            applicant_full_name TEXT,
            UNIQUE(appl_no, product_no)
        )
    ''')
    
    # Load products.txt from Orange Book
    products_file = pharma_dir / "fda_data" / "products.txt"
    if products_file.exists():
        print("Loading FDA products data...")
        with open(products_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='~')
            count = 0
            for row in reader:
                try:
                    cursor.execute('''
                        INSERT OR IGNORE INTO fda_products
                        (ingredient, df_route, trade_name, applicant, strength,
                         appl_type, appl_no, product_no, te_code, approval_date,
                         rld, type, applicant_full_name)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''', (
                        row.get('Ingredient', ''),
                        row.get('DF;Route', ''),
                        row.get('Trade_Name', ''),
                        row.get('Applicant', ''),
                        row.get('Strength', ''),
                        row.get('Appl_Type', ''),
                        row.get('Appl_No', ''),
                        row.get('Product_No', ''),
                        row.get('TE_Code', ''),
                        row.get('Approval_Date', ''),
                        row.get('RLD', ''),
                        row.get('Type', ''),
                        row.get('Applicant_Full_Name', '')
                    ))
                    count += 1
                except Exception as e:
                    print(f"Error inserting row: {e}")
        
        print(f"Loaded {count} FDA products")
    
    # Create indexes for fast searching
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_fda_ingredient ON fda_products(ingredient)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_fda_trade_name ON fda_products(trade_name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_fda_strength ON fda_products(strength)')
    
    conn.commit()
    
    # Generate statistics
    cursor.execute("SELECT COUNT(DISTINCT ingredient) FROM fda_products")
    unique_ingredients = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(DISTINCT trade_name) FROM fda_products")
    unique_brands = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM fda_products")
    total_products = cursor.fetchone()[0]
    
    print(f"\nDatabase Statistics:")
    print(f"- Total products: {total_products}")
    print(f"- Unique ingredients: {unique_ingredients}")
    print(f"- Unique brand names: {unique_brands}")
    
    # Create common medications lookup
    print("\nCreating common medications reference...")
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS common_survival_meds AS
        SELECT DISTINCT
            ingredient,
            trade_name,
            strength,
            df_route
        FROM fda_products
        WHERE 
            ingredient LIKE '%amoxicillin%' OR
            ingredient LIKE '%ciprofloxacin%' OR
            ingredient LIKE '%doxycycline%' OR
            ingredient LIKE '%metronidazole%' OR
            ingredient LIKE '%azithromycin%' OR
            ingredient LIKE '%cephalexin%' OR
            ingredient LIKE '%ibuprofen%' OR
            ingredient LIKE '%acetaminophen%' OR
            ingredient LIKE '%aspirin%' OR
            ingredient LIKE '%epinephrine%' OR
            ingredient LIKE '%insulin%' OR
            ingredient LIKE '%prednisone%' OR
            ingredient LIKE '%albuterol%' OR
            ingredient LIKE '%diphenhydramine%'
        ORDER BY ingredient, strength
    ''')
    
    conn.commit()
    conn.close()
    
    print(f"\nComprehensive pill database created at: {db_path}")
    print(f"Size: {db_path.stat().st_size / (1024*1024):.2f} MB")

if __name__ == "__main__":
    pharma_dir = Path("/Volumes/Vid SSD/PrepperApp-Content/pharma")
    process_orange_book(pharma_dir)
EOF

chmod +x "$PHARMA_DIR/process_fda_data.py"

echo
echo "FDA data downloaded!"
echo "To process into database: python3 $PHARMA_DIR/process_fda_data.py"

# Create pill identification guide
cat > "$PHARMA_DIR/pill_id_guide.md" << 'EOF'
# Pill Identification Guide for Scavenging

## Priority Medications for SHTF Scenarios

### CRITICAL (Life-Saving)
1. **Antibiotics**
   - Amoxicillin (pink/red capsules, "AMOX" imprint)
   - Ciprofloxacin (white tablets, "CIPRO" imprint)
   - Doxycycline (yellow capsules)
   - Azithromycin (Z-pack, pink tablets)

2. **Emergency Meds**
   - Epinephrine (EpiPen auto-injectors)
   - Insulin (vials must be refrigerated)
   - Albuterol inhalers (for asthma)

### HIGH PRIORITY
1. **Pain/Fever**
   - Ibuprofen (brown/orange tablets, "Advil" or "I-2")
   - Acetaminophen (white/red capsules, "TYLENOL")
   - Aspirin (white tablets, often with cross score)

2. **Chronic Conditions**
   - Blood pressure meds (various)
   - Diabetes medications
   - Thyroid medications

### IDENTIFICATION TIPS
- Check imprint codes against database
- Note color and shape
- Check expiration dates (most meds good 5+ years past date)
- Store in cool, dry place
- NEVER mix different pills in same container

### WARNING SIGNS
- No imprint = possibly vitamins or foreign
- Damaged/wet pills = reduced potency
- Unusual smell = likely degraded
- Injectable meds = require training

## Storage After Scavenging
1. Keep in original containers when possible
2. Label everything immediately
3. Store antibiotics separately
4. Protect from moisture and heat
5. Create inventory with expiration dates
EOF

echo "Pill identification guide created at: $PHARMA_DIR/pill_id_guide.md"