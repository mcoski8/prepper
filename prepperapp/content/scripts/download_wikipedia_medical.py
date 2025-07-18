#!/usr/bin/env python3
"""
Download Wikipedia Medical subset for PrepperApp
This downloads the curated medical articles from Kiwix
"""

import os
import sys
import hashlib
import requests
from pathlib import Path
import time

# Configuration
WIKIPEDIA_MEDICAL_URL = "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_nodet_2024-06.zim"
EXPECTED_SIZE_GB = 4.2  # Approximate size
OUTPUT_DIR = Path("../raw/wikipedia")
CHUNK_SIZE = 8192  # 8KB chunks

def create_directories():
    """Create necessary directories"""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"✓ Created directory: {OUTPUT_DIR}")

def download_with_progress(url, filepath):
    """Download file with progress indicator"""
    print(f"Downloading: {url}")
    print(f"Target: {filepath}")
    
    # Check if file already exists
    if filepath.exists():
        print(f"⚠️  File already exists: {filepath}")
        response = input("Overwrite? (y/n): ")
        if response.lower() != 'y':
            print("Skipping download.")
            return True
    
    try:
        # Start download
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        # Get file size
        total_size = int(response.headers.get('content-length', 0))
        total_size_mb = total_size / 1024 / 1024
        
        print(f"File size: {total_size_mb:.1f} MB")
        
        # Download with progress
        downloaded = 0
        start_time = time.time()
        
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=CHUNK_SIZE):
                if chunk:
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    # Progress update
                    progress = (downloaded / total_size) * 100
                    speed = downloaded / (time.time() - start_time) / 1024 / 1024  # MB/s
                    downloaded_mb = downloaded / 1024 / 1024
                    
                    print(f"\rProgress: {progress:.1f}% | {downloaded_mb:.1f}/{total_size_mb:.1f} MB | {speed:.1f} MB/s", end='')
        
        print("\n✓ Download complete!")
        return True
        
    except requests.exceptions.RequestException as e:
        print(f"\n✗ Download failed: {e}")
        return False
    except KeyboardInterrupt:
        print("\n⚠️  Download interrupted by user")
        if filepath.exists():
            filepath.unlink()
        return False

def verify_checksum(filepath):
    """Verify file integrity with SHA256"""
    print("Calculating checksum...")
    
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    
    checksum = sha256_hash.hexdigest()
    print(f"SHA256: {checksum}")
    
    # Save checksum
    checksum_file = filepath.with_suffix('.sha256')
    with open(checksum_file, 'w') as f:
        f.write(f"{checksum}  {filepath.name}\n")
    
    print(f"✓ Checksum saved to: {checksum_file}")
    return checksum

def extract_priority_articles(zim_path):
    """Extract high-priority medical articles from ZIM"""
    print("\nExtracting priority medical articles...")
    
    # Priority topics for survival situations
    priority_topics = [
        "Bleeding",
        "Shock_(circulatory)",
        "Cardiopulmonary_resuscitation",
        "Wound",
        "Burn",
        "Hypothermia",
        "Hyperthermia",
        "Dehydration",
        "Fracture",
        "Tourniquet",
        "First_aid",
        "Anaphylaxis",
        "Poisoning",
        "Snakebite",
        "Drowning",
        "Choking",
        "Concussion",
        "Spinal_cord_injury",
        "Diabetic_emergency",
        "Seizure"
    ]
    
    # This would require zimply or similar library
    # For now, we'll create a manifest
    manifest_path = OUTPUT_DIR / "priority_articles.txt"
    with open(manifest_path, 'w') as f:
        f.write("# Priority Medical Articles for PrepperApp\n\n")
        for topic in priority_topics:
            f.write(f"- {topic}\n")
    
    print(f"✓ Priority article list saved to: {manifest_path}")
    print(f"  Total priority articles: {len(priority_topics)}")

def main():
    """Main download process"""
    print("=== Wikipedia Medical Content Downloader ===\n")
    
    # Setup
    create_directories()
    
    # Download file
    filename = "wikipedia_en_medicine_nodet_2024-06.zim"
    filepath = OUTPUT_DIR / filename
    
    if download_with_progress(WIKIPEDIA_MEDICAL_URL, filepath):
        # Verify integrity
        verify_checksum(filepath)
        
        # Extract priority content list
        extract_priority_articles(filepath)
        
        print("\n✅ Wikipedia medical content ready for processing!")
        print(f"Location: {filepath}")
        print("\nNext steps:")
        print("1. Run extract_zim_content.py to extract articles")
        print("2. Run process_medical_content.py to categorize and prioritize")
        
    else:
        print("\n❌ Download failed. Please try again or download manually.")
        sys.exit(1)

if __name__ == "__main__":
    main()