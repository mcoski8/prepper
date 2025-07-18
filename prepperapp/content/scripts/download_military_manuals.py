#!/usr/bin/env python3
"""
Download public domain US military survival manuals
These are crucial references for survival situations
"""

import os
import sys
import requests
from pathlib import Path
import time
import json

# Military manual sources (public domain)
MANUALS = [
    {
        "id": "FM-21-76",
        "title": "US Army Survival Manual",
        "url": "https://archive.org/download/FM21-76SurvivalManual/FM21-76.pdf",
        "category": "survival",
        "priority": 5,
        "description": "Comprehensive military survival guide"
    },
    {
        "id": "TC-4-02.1",
        "title": "First Aid Manual",
        "url": "https://archive.org/download/FirstAidTC4-02.1/TC_4-02.1.pdf", 
        "category": "medical",
        "priority": 5,
        "description": "Combat casualty care and first aid"
    },
    {
        "id": "FM-3-05.70",
        "title": "Survival, Evasion, and Recovery",
        "url": "https://archive.org/download/fm-3-05.70/fm3-05.70.pdf",
        "category": "survival",
        "priority": 4,
        "description": "Advanced survival techniques"
    },
    {
        "id": "TM-31-210",
        "title": "Improvised Munitions Handbook",
        "url": "https://archive.org/download/tm-31-210-improvised-munitions-handbook/TM-31-210.pdf",
        "category": "skills",
        "priority": 2,
        "description": "Field expedient tools and techniques"
    },
    {
        "id": "FM-31-70",
        "title": "Basic Cold Weather Manual",
        "url": "https://archive.org/download/BasicColdWeatherManualFM31-70/FM31-70.pdf",
        "category": "environment",
        "priority": 4,
        "description": "Cold weather operations and survival"
    }
]

OUTPUT_DIR = Path("../raw/military")

def create_directories():
    """Create necessary directories"""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"✓ Created directory: {OUTPUT_DIR}")

def download_manual(manual):
    """Download a single manual"""
    filename = f"{manual['id']}_{manual['title'].replace(' ', '_')}.pdf"
    filepath = OUTPUT_DIR / filename
    
    print(f"\nDownloading: {manual['title']}")
    print(f"ID: {manual['id']}")
    print(f"Priority: {manual['priority']}/5")
    
    # Check if already exists
    if filepath.exists():
        print(f"✓ Already downloaded: {filename}")
        return True
    
    try:
        # Download with progress
        response = requests.get(manual['url'], stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        total_size_mb = total_size / 1024 / 1024
        
        print(f"Size: {total_size_mb:.1f} MB")
        
        downloaded = 0
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    progress = (downloaded / total_size) * 100 if total_size > 0 else 0
                    print(f"\rProgress: {progress:.1f}%", end='')
        
        print(f"\n✓ Downloaded: {filename}")
        
        # Save metadata
        metadata = {
            "id": manual['id'],
            "title": manual['title'],
            "category": manual['category'],
            "priority": manual['priority'],
            "description": manual['description'],
            "filename": filename,
            "size_bytes": total_size,
            "download_date": time.strftime("%Y-%m-%d")
        }
        
        metadata_path = filepath.with_suffix('.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        return True
        
    except Exception as e:
        print(f"\n✗ Failed to download {manual['id']}: {e}")
        return False

def create_manifest():
    """Create a manifest of all downloaded manuals"""
    manifest_path = OUTPUT_DIR / "manifest.json"
    
    manifest = {
        "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_manuals": len(MANUALS),
        "categories": {
            "medical": [],
            "survival": [],
            "environment": [],
            "skills": []
        }
    }
    
    # Scan for downloaded files
    for pdf_file in OUTPUT_DIR.glob("*.pdf"):
        json_file = pdf_file.with_suffix('.json')
        if json_file.exists():
            with open(json_file, 'r') as f:
                metadata = json.load(f)
                category = metadata.get('category', 'other')
                if category in manifest['categories']:
                    manifest['categories'][category].append(metadata)
    
    # Save manifest
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)
    
    print(f"\n✓ Manifest created: {manifest_path}")
    
    # Print summary
    print("\nDownload Summary:")
    for category, items in manifest['categories'].items():
        if items:
            print(f"  {category.capitalize()}: {len(items)} manuals")

def extract_key_sections():
    """Extract high-priority sections for quick reference"""
    extracts_dir = OUTPUT_DIR / "extracts"
    extracts_dir.mkdir(exist_ok=True)
    
    # Define critical sections to extract
    critical_sections = {
        "FM-21-76": [
            "Chapter 4 - Basic Survival Medicine",
            "Chapter 5 - Shelters", 
            "Chapter 6 - Water Procurement",
            "Chapter 7 - Firecraft",
            "Chapter 8 - Food Procurement"
        ],
        "TC-4-02.1": [
            "Chapter 2 - Tactical Combat Casualty Care",
            "Chapter 3 - Airway Management",
            "Chapter 4 - Breathing",
            "Chapter 7 - Controlling Bleeding"
        ]
    }
    
    manifest_path = extracts_dir / "critical_sections.json"
    with open(manifest_path, 'w') as f:
        json.dump(critical_sections, f, indent=2)
    
    print(f"✓ Critical sections manifest created: {manifest_path}")
    print("  Note: PDF extraction requires additional processing")

def main():
    """Main download process"""
    print("=== Military Survival Manuals Downloader ===\n")
    print("Downloading public domain US military manuals...")
    print(f"Total manuals: {len(MANUALS)}\n")
    
    # Setup
    create_directories()
    
    # Download manuals
    success_count = 0
    failed = []
    
    for manual in MANUALS:
        if download_manual(manual):
            success_count += 1
        else:
            failed.append(manual['id'])
        
        # Be nice to archive.org
        time.sleep(2)
    
    # Create manifest
    create_manifest()
    
    # Prepare extraction list
    extract_key_sections()
    
    # Summary
    print(f"\n{'='*50}")
    print(f"✅ Successfully downloaded: {success_count}/{len(MANUALS)} manuals")
    
    if failed:
        print(f"❌ Failed downloads: {', '.join(failed)}")
        print("\nTo retry failed downloads:")
        print("  python download_military_manuals.py --retry")
    
    print("\nNext steps:")
    print("1. Run extract_pdf_content.py to extract text")
    print("2. Run process_military_content.py to index for search")

if __name__ == "__main__":
    main()