#!/usr/bin/env python3
"""
Process USDA plant data for PrepperApp
Creates searchable database focused on poisonous plants and safe edibles
"""

import os
import csv
import json
from pathlib import Path
from collections import defaultdict

def load_plant_list(file_path):
    """Load USDA plant list"""
    plants = {}
    
    with open(file_path, 'r', encoding='latin-1') as f:
        # Skip header
        next(f)
        
        for line in f:
            parts = line.strip().split(',')
            if len(parts) >= 5:
                symbol = parts[0].strip('"')
                scientific_name = parts[2].strip('"')
                common_name = parts[3].strip('"') if len(parts) > 3 else ""
                family = parts[4].strip('"') if len(parts) > 4 else ""
                
                plants[symbol] = {
                    'symbol': symbol,
                    'scientific_name': scientific_name,
                    'common_name': common_name,
                    'family': family,
                    'characteristics': {}
                }
    
    return plants

def load_characteristics(file_path, plants):
    """Load plant characteristics and merge with plant data"""
    
    with open(file_path, 'r', encoding='latin-1') as f:
        reader = csv.DictReader(f)
        
        for row in reader:
            symbol = row.get('Accepted Symbol', '').strip('"')
            
            if symbol in plants:
                # Extract relevant characteristics
                plants[symbol]['characteristics'] = {
                    'growth_habit': row.get('Growth Habit', ''),
                    'native_status': row.get('Native Status', ''),
                    'toxicity': row.get('Toxicity', 'None'),
                    'palatable_human': row.get('Palatable Human', ''),
                    'flower_color': row.get('Flower Color', ''),
                    'fruit_color': row.get('Fruit/Seed Color', ''),
                    'shape': row.get('Shape and Orientation', ''),
                    'active_growth': row.get('Active Growth Period', ''),
                    'foliage_color': row.get('Foliage Color', ''),
                    'height_mature': row.get('Height, Mature (feet)', ''),
                }
    
    return plants

def categorize_plants(plants):
    """Categorize plants by safety and use"""
    categories = {
        'poisonous': [],
        'edible': [],
        'medicinal': [],
        'unknown': []
    }
    
    # Priority poisonous plants (common ones that are dangerous)
    known_poisonous = {
        'poison ivy', 'poison oak', 'poison sumac', 'foxglove', 'hemlock',
        'nightshade', 'oleander', 'castor', 'jimson', 'pokeweed',
        'death camas', 'water hemlock', 'monkshood', 'angel trumpet'
    }
    
    # Known edibles (conservative list)
    known_edible = {
        'dandelion', 'clover', 'plantain', 'violet', 'rose',
        'blackberry', 'raspberry', 'elderberry', 'mulberry',
        'acorn', 'cattail', 'wild garlic', 'wild onion'
    }
    
    for symbol, plant in plants.items():
        common_lower = plant['common_name'].lower()
        scientific_lower = plant['scientific_name'].lower()
        toxicity = plant['characteristics'].get('toxicity', '').lower()
        
        # Check toxicity field first
        if toxicity and toxicity != 'none':
            categories['poisonous'].append(plant)
        # Check known poisonous names
        elif any(poison in common_lower or poison in scientific_lower 
                for poison in known_poisonous):
            categories['poisonous'].append(plant)
        # Check known edibles
        elif any(edible in common_lower for edible in known_edible):
            categories['edible'].append(plant)
        else:
            categories['unknown'].append(plant)
    
    return categories

def create_emergency_database(plants, categories, output_dir):
    """Create emergency-focused plant database"""
    
    # Priority 1: Poisonous plants to avoid
    poisonous_db = {
        'title': 'Poisonous Plants - NEVER EAT',
        'warning': 'These plants can cause illness or death. Teach children to avoid.',
        'plants': []
    }
    
    for plant in sorted(categories['poisonous'], 
                       key=lambda p: p['common_name']):
        poisonous_db['plants'].append({
            'common_name': plant['common_name'],
            'scientific_name': plant['scientific_name'],
            'identifying_features': {
                'growth_habit': plant['characteristics'].get('growth_habit', ''),
                'flower_color': plant['characteristics'].get('flower_color', ''),
                'fruit_color': plant['characteristics'].get('fruit_color', ''),
                'foliage_color': plant['characteristics'].get('foliage_color', ''),
                'height': plant['characteristics'].get('height_mature', '')
            },
            'toxicity': plant['characteristics'].get('toxicity', 'Toxic'),
            'notes': 'Avoid all parts of this plant'
        })
    
    # Priority 2: Safe edibles (conservative list)
    edible_db = {
        'title': 'Emergency Edible Plants',
        'warning': 'Only eat if 100% certain of identification. When in doubt, do not eat.',
        'plants': []
    }
    
    for plant in sorted(categories['edible'], 
                       key=lambda p: p['common_name']):
        edible_db['plants'].append({
            'common_name': plant['common_name'],
            'scientific_name': plant['scientific_name'],
            'identifying_features': {
                'growth_habit': plant['characteristics'].get('growth_habit', ''),
                'flower_color': plant['characteristics'].get('flower_color', ''),
                'fruit_color': plant['characteristics'].get('fruit_color', ''),
                'native_status': plant['characteristics'].get('native_status', '')
            },
            'edible_parts': 'Research before consuming',
            'preparation': 'Wash thoroughly, cook if unsure'
        })
    
    # Save databases
    with open(output_dir / 'poisonous_plants.json', 'w') as f:
        json.dump(poisonous_db, f, indent=2)
    
    with open(output_dir / 'edible_plants.json', 'w') as f:
        json.dump(edible_db, f, indent=2)
    
    # Create quick reference
    quick_ref = {
        'total_plants': len(plants),
        'poisonous_count': len(categories['poisonous']),
        'edible_count': len(categories['edible']),
        'top_dangerous': [p['common_name'] for p in categories['poisonous'][:20]],
        'safe_basics': [p['common_name'] for p in categories['edible'][:20]]
    }
    
    with open(output_dir / 'plant_quick_reference.json', 'w') as f:
        json.dump(quick_ref, f, indent=2)
    
    return poisonous_db, edible_db, quick_ref

def main():
    # Setup paths
    content_dir = Path(os.environ.get('PREPPER_EXTERNAL_CONTENT', '.'))
    plants_dir = content_dir / 'plants'
    
    if not plants_dir.exists():
        print(f"Error: Plants directory not found at {plants_dir}")
        return
    
    # Load data
    print("Loading USDA plant data...")
    plants = load_plant_list(plants_dir / 'usda_plantlst.txt')
    print(f"Loaded {len(plants)} plants")
    
    print("Loading characteristics...")
    plants = load_characteristics(plants_dir / 'usda_characteristics.csv', plants)
    
    print("Categorizing plants...")
    categories = categorize_plants(plants)
    
    print(f"\nCategorization results:")
    print(f"  Poisonous: {len(categories['poisonous'])}")
    print(f"  Edible: {len(categories['edible'])}")
    print(f"  Unknown: {len(categories['unknown'])}")
    
    print("\nCreating emergency databases...")
    poisonous_db, edible_db, quick_ref = create_emergency_database(
        plants, categories, plants_dir
    )
    
    print("\nEmergency plant database created!")
    print(f"  Poisonous plants: {quick_ref['poisonous_count']}")
    print(f"  Safe edibles: {quick_ref['edible_count']}")
    print("\nTop dangerous plants to avoid:")
    for i, plant in enumerate(quick_ref['top_dangerous'][:10], 1):
        print(f"  {i}. {plant}")
    
    print("\nFiles created in", plants_dir)
    print("  - poisonous_plants.json")
    print("  - edible_plants.json")
    print("  - plant_quick_reference.json")
    
    print("\nNext steps:")
    print("1. Add plant images from iNaturalist")
    print("2. Create visual identification cards")
    print("3. Add regional variations")
    print("4. Integrate with crisis navigation UI")

if __name__ == "__main__":
    main()