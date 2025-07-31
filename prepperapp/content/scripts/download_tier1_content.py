#!/usr/bin/env python3
"""
Download Tier 1 critical content for PrepperApp
Safe wrapper that uses environment variables to avoid Claude Code crashes
"""

import os
import sys
import json
import subprocess
from pathlib import Path

# Check for external content directory
EXTERNAL_CONTENT = os.environ.get('PREPPER_EXTERNAL_CONTENT')
if not EXTERNAL_CONTENT:
    print("ERROR: PREPPER_EXTERNAL_CONTENT environment variable not set")
    print("Please set: export PREPPER_EXTERNAL_CONTENT='/Volumes/Vid SSD/prepperapp-content'")
    sys.exit(1)

# Load tier 1 manifest
manifest_path = Path(__file__).parent.parent / "tier1_downloads.json"
if not manifest_path.exists():
    print(f"ERROR: Manifest not found at {manifest_path}")
    sys.exit(1)

with open(manifest_path, 'r') as f:
    manifest = json.load(f)

print("PrepperApp Tier 1 Content Downloader")
print("=" * 60)
print(f"External content directory: {EXTERNAL_CONTENT}")
print(f"Total downloads: {len(manifest['downloads'])}")
print("=" * 60)

# Use the existing download manager
download_manager = Path(__file__).parent / "download_manager.py"
if not download_manager.exists():
    print(f"ERROR: Download manager not found at {download_manager}")
    sys.exit(1)

# Create temporary manifest for download manager
temp_manifest = Path(EXTERNAL_CONTENT) / "tier1_download_list.json"
with open(temp_manifest, 'w') as f:
    json.dump({"downloads": manifest['downloads']}, f, indent=2)

# Execute download manager with safe environment
cmd = [
    sys.executable,
    str(download_manager),
    "--base-dir", EXTERNAL_CONTENT,
    "--list", str(temp_manifest)
]

print("\nStarting downloads...")
print("This will download approximately 4GB of critical survival content")
print("Press Ctrl+C to cancel\n")

try:
    # Run download manager
    result = subprocess.run(cmd, env=os.environ.copy())
    
    if result.returncode == 0:
        print("\n✓ Downloads completed successfully!")
        print("\nNext steps:")
        print("1. Process WikiHow content (requires manual curation)")
        print("2. Download plant images from USDA")
        print("3. Create quick reference cards")
        print("4. Build crisis navigation UI")
    else:
        print(f"\n✗ Download manager exited with code {result.returncode}")
        
except KeyboardInterrupt:
    print("\n\nDownloads cancelled by user")
except Exception as e:
    print(f"\n✗ Error running download manager: {e}")

# Clean up temp manifest
if temp_manifest.exists():
    temp_manifest.unlink()

print("\nTo check download status, run:")
print(f"python {download_manager} --base-dir '{EXTERNAL_CONTENT}' --status")