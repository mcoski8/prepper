#!/usr/bin/env python3
"""
Simple download verification script for PrepperApp content
Checks if files exist and reports their sizes without freezing

WARNING: This script includes workarounds for Claude Code bug #1452
which causes it to crash when encountering large files (>1GB) in outputs.
"""

import os
import sys
from pathlib import Path
import json
import hashlib

# Expected downloads based on download-status-report.md
EXPECTED_DOWNLOADS = {
    "tier1_critical": [
        {
            "name": "post-disaster",
            "filename": "zimgit-post-disaster_en_2024-05.zim",
            "size_mb": 615,
            "url": "https://download.kiwix.org/zim/other/zimgit-post-disaster_en_2024-05.zim"
        },
        {
            "name": "water",
            "filename": "zimgit-water_en_2024-08.zim",
            "size_mb": 20,
            "url": "https://download.kiwix.org/zim/other/zimgit-water_en_2024-08.zim"
        },
        {
            "name": "medicine",
            "filename": "zimgit-medicine_en_2024-08.zim",
            "size_mb": 67,
            "url": "https://download.kiwix.org/zim/other/zimgit-medicine_en_2024-08.zim"
        },
        {
            "name": "wikipedia-medical",
            "filename": "wikipedia_en_medicine_maxi_2025-07.zim",
            "size_mb": 2048,  # 2GB
            "url": "https://download.kiwix.org/zim/wikipedia/wikipedia_en_medicine_maxi_2025-07.zim"
        }
    ],
    "tier2_essential": [
        {
            "name": "ifixit",
            "filename": "ifixit_en_all_2025-06.zim",
            "size_mb": 3277,  # 3.2GB
            "url": "https://download.kiwix.org/zim/ifixit/ifixit_en_all_2025-06.zim"
        },
        {
            "name": "wikiversity",
            "filename": "wikiversity_en_all_nopic_2025-06.zim",
            "size_mb": 1536,  # 1.5GB
            "url": "https://download.kiwix.org/zim/wikiversity/wikiversity_en_all_nopic_2025-06.zim"
        },
        {
            "name": "appropedia",
            "filename": "appropedia_en_all_maxi_2025-05.zim",
            "size_mb": 200,  # Estimate
            "url": "https://download.kiwix.org/zim/other/appropedia_en_all_maxi_2025-05.zim"
        }
    ]
}

def check_file(filepath: Path, safe_mode: bool = True) -> dict:
    """Check if file exists and get its size
    
    Args:
        filepath: Path to check
        safe_mode: If True, avoid exposing full paths for large files to prevent Claude Code crashes
    """
    result = {
        "exists": filepath.exists(),
        "path": str(filepath),
        "size_bytes": 0,
        "size_mb": 0,
        "safe_path": None
    }
    
    if result["exists"]:
        try:
            result["size_bytes"] = filepath.stat().st_size
            result["size_mb"] = result["size_bytes"] / (1024 * 1024)
            
            # WORKAROUND for Claude Code bug #1452
            # For files > 1GB, use a hash instead of full path
            if safe_mode and result["size_mb"] > 1024:  # 1GB threshold
                path_hash = hashlib.md5(str(filepath).encode()).hexdigest()[:8]
                result["safe_path"] = f"<large_file_{path_hash}>/{filepath.name}"
                result["path"] = result["safe_path"]
                result["full_path_hidden"] = True
                
        except Exception as e:
            result["error"] = str(e)
    
    return result

def find_downloads(base_dirs: list, safe_mode: bool = True) -> dict:
    """Search for downloaded files in common locations
    
    Args:
        base_dirs: List of directories to search
        safe_mode: If True, use workarounds for Claude Code large file bug
    """
    found_files = {}
    
    # Add external drive paths via environment variable if set
    external_content = os.environ.get('PREPPER_EXTERNAL_CONTENT')
    if external_content and external_content not in base_dirs:
        base_dirs.append(external_content)
    
    for base_dir in base_dirs:
        base_path = Path(base_dir)
        if not base_path.exists():
            continue
            
        # Search for ZIM files
        try:
            for zim_file in base_path.rglob("*.zim"):
                filename = zim_file.name
                if filename not in found_files:
                    found_files[filename] = check_file(zim_file, safe_mode)
        except Exception as e:
            print(f"Warning: Error searching {base_dir}: {e}")
            continue
    
    return found_files

def verify_downloads(safe_mode: bool = True):
    """Main verification function
    
    Args:
        safe_mode: If True, use workarounds for Claude Code large file bug
    """
    print("PrepperApp Content Download Verification")
    print("=" * 50)
    
    if safe_mode:
        print("\n[SAFE MODE] Large file paths will be obscured to prevent Claude Code crashes")
        print("Set PREPPER_EXTERNAL_CONTENT env var to include external drives")
        print("Example: export PREPPER_EXTERNAL_CONTENT='/Volumes/Vid SSD/PrepperApp-Content'")
    
    # Common download locations
    search_dirs = [
        ".",
        "./data",
        "./content",
        "./prepperapp/content",
        "./prepperapp/content/raw",
        "./prepperapp/content/raw/kiwix",
        os.path.expanduser("~/Downloads")
    ]
    
    print("\nSearching for downloaded files...")
    found_files = find_downloads(search_dirs, safe_mode)
    
    print(f"\nFound {len(found_files)} ZIM files:")
    for filename, info in found_files.items():
        if info["exists"]:
            if info.get("full_path_hidden"):
                print(f"  ✓ {filename}: {info['size_mb']:.1f} MB [path hidden due to size]")
            else:
                print(f"  ✓ {filename}: {info['size_mb']:.1f} MB")
    
    # Check against expected downloads
    print("\n" + "=" * 50)
    print("Verification against expected downloads:\n")
    
    all_expected = []
    for tier_name, tier_files in EXPECTED_DOWNLOADS.items():
        print(f"\n{tier_name.upper()}:")
        for expected in tier_files:
            all_expected.append(expected)
            filename = expected["filename"]
            
            if filename in found_files and found_files[filename]["exists"]:
                actual_size = found_files[filename]["size_mb"]
                expected_size = expected["size_mb"]
                size_diff = abs(actual_size - expected_size)
                size_percent = (size_diff / expected_size) * 100
                
                if size_percent < 10:  # Within 10% of expected size
                    print(f"  ✓ {expected['name']}: FOUND ({actual_size:.1f} MB)")
                else:
                    print(f"  ⚠ {expected['name']}: SIZE MISMATCH (expected {expected_size} MB, got {actual_size:.1f} MB)")
            else:
                print(f"  ✗ {expected['name']}: MISSING")
                print(f"    Download with: wget -c {expected['url']}")
    
    # Summary
    print("\n" + "=" * 50)
    print("SUMMARY:")
    
    found_count = sum(1 for e in all_expected if e["filename"] in found_files and found_files[e["filename"]]["exists"])
    total_count = len(all_expected)
    
    print(f"  Downloaded: {found_count}/{total_count} files")
    print(f"  Missing: {total_count - found_count} files")
    
    # List all found files not in expected list
    unexpected = [f for f in found_files.keys() if f not in [e["filename"] for e in all_expected]]
    if unexpected:
        print(f"\n  Additional files found:")
        for f in unexpected:
            print(f"    - {f}")

if __name__ == "__main__":
    try:
        # Check for command line arguments
        safe_mode = "--unsafe" not in sys.argv
        
        if "--help" in sys.argv:
            print("Usage: python verify_downloads.py [--unsafe]")
            print("  --unsafe: Disable Claude Code crash protection (shows full paths)")
            print("\nEnvironment variables:")
            print("  PREPPER_EXTERNAL_CONTENT: Path to external content directory")
            sys.exit(0)
            
        verify_downloads(safe_mode)
    except KeyboardInterrupt:
        print("\n\nVerification interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError during verification: {e}")
        sys.exit(1)