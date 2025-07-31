#!/usr/bin/env python3
"""
Safe content checking script for PrepperApp
Designed to work around Claude Code bug #1452 which crashes on large files

This script provides a safe way to check downloaded content without exposing
full paths to large files that would cause Claude Code to crash.
"""

import os
import sys
from pathlib import Path
import json
from datetime import datetime
import subprocess

# Size threshold for hiding paths (1GB)
LARGE_FILE_THRESHOLD_MB = 1024

def get_safe_file_info(filepath: Path) -> dict:
    """Get file info without exposing paths for large files"""
    info = {
        "name": filepath.name,
        "exists": filepath.exists(),
        "size_mb": 0,
        "location": "unknown",
        "last_modified": None
    }
    
    if info["exists"]:
        try:
            stat = filepath.stat()
            info["size_mb"] = stat.st_size / (1024 * 1024)
            info["last_modified"] = datetime.fromtimestamp(stat.st_mtime).isoformat()
            
            # Determine location type without exposing full path
            path_str = str(filepath)
            if "/Volumes/" in path_str:
                info["location"] = "external_drive"
            elif path_str.startswith(os.path.expanduser("~")):
                info["location"] = "home_directory"
            else:
                info["location"] = "project_directory"
                
        except Exception as e:
            info["error"] = str(e)
    
    return info

def check_content_via_env():
    """Check content using environment variable to avoid path exposure"""
    print("Safe PrepperApp Content Check")
    print("=" * 50)
    
    # Check if external content path is set
    external_path = os.environ.get('PREPPER_EXTERNAL_CONTENT')
    if not external_path:
        print("\n⚠️  PREPPER_EXTERNAL_CONTENT environment variable not set")
        print("   Set it to check external drive content:")
        print("   export PREPPER_EXTERNAL_CONTENT='/Volumes/Vid SSD/PrepperApp-Content'")
        print()
    
    # Tier definitions
    tiers = {
        "Tier 1 - Critical (72hr)": [
            "zimgit-post-disaster_en_2024-05.zim",
            "zimgit-water_en_2024-08.zim", 
            "zimgit-medicine_en_2024-08.zim",
            "wikipedia_en_medicine_maxi_2025-07.zim"
        ],
        "Tier 2 - Essential": [
            "ifixit_en_all_2025-06.zim",
            "wikiversity_en_all_nopic_2025-06.zim",
            "appropedia_en_all_maxi_2025-05.zim"
        ],
        "Tier 3 - Comprehensive": [
            "wikipedia_en_all_maxi_2024-01.zim",
            "wikibooks_en_all_maxi_2025-06.zim",
            "wikihow_en_maxi_2025-06.zim"
        ]
    }
    
    # Search locations
    search_paths = [
        Path("."),
        Path("./data"),
        Path("./content"),
        Path("./prepperapp/content"),
        Path("./prepperapp/content/raw"),
        Path("./prepperapp/content/raw/kiwix"),
        Path.home() / "Downloads"
    ]
    
    if external_path:
        search_paths.append(Path(external_path))
    
    # Find all ZIM files
    found_files = {}
    for base_path in search_paths:
        if not base_path.exists():
            continue
            
        try:
            # Use a subprocess to list files safely
            if base_path.is_dir():
                result = subprocess.run(
                    ["find", str(base_path), "-name", "*.zim", "-type", "f"],
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                
                if result.returncode == 0:
                    for line in result.stdout.strip().split('\n'):
                        if line:
                            filepath = Path(line)
                            if filepath.name not in found_files:
                                found_files[filepath.name] = get_safe_file_info(filepath)
                                
        except subprocess.TimeoutExpired:
            print(f"Warning: Timeout searching {base_path}")
        except Exception as e:
            print(f"Warning: Error searching {base_path}: {e}")
    
    # Display results by tier
    print("\nContent Status by Tier:")
    print("-" * 50)
    
    total_size_mb = 0
    total_found = 0
    
    for tier_name, tier_files in tiers.items():
        print(f"\n{tier_name}:")
        tier_size = 0
        
        for filename in tier_files:
            if filename in found_files:
                info = found_files[filename]
                total_found += 1
                tier_size += info["size_mb"]
                total_size_mb += info["size_mb"]
                
                size_str = f"{info['size_mb']:.1f} MB"
                if info["size_mb"] > 1024:
                    size_str = f"{info['size_mb']/1024:.1f} GB"
                
                print(f"  ✓ {filename}: {size_str} [{info['location']}]")
            else:
                print(f"  ✗ {filename}: NOT FOUND")
    
    # Summary
    print("\n" + "=" * 50)
    print("SUMMARY:")
    print(f"  Total files found: {total_found}")
    print(f"  Total size: {total_size_mb/1024:.1f} GB")
    
    # List additional files
    known_files = set()
    for tier_files in tiers.values():
        known_files.update(tier_files)
    
    extra_files = [f for f in found_files.keys() if f not in known_files]
    if extra_files:
        print(f"\n  Additional ZIM files found: {len(extra_files)}")
        for f in extra_files[:5]:  # Limit display
            info = found_files[f]
            print(f"    - {f}: {info['size_mb']:.1f} MB")
        if len(extra_files) > 5:
            print(f"    ... and {len(extra_files) - 5} more")
    
    # Safety check
    large_files = [f for f, info in found_files.items() if info["size_mb"] > LARGE_FILE_THRESHOLD_MB]
    if large_files:
        print(f"\n⚠️  Found {len(large_files)} large files (>1GB) - paths hidden for safety")
        print("   These files can crash Claude Code if full paths are displayed")

if __name__ == "__main__":
    try:
        check_content_via_env()
    except KeyboardInterrupt:
        print("\n\nCheck interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\nError during check: {e}")
        sys.exit(1)