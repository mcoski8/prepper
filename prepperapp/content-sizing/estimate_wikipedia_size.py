#!/usr/bin/env python3
"""
Estimate Wikipedia offline content size for PrepperApp
"""

import json
from pathlib import Path

def estimate_wikipedia_sizes():
    """Estimate various Wikipedia offline options"""
    
    print("\n📚 Wikipedia Offline Size Estimates")
    print("="*60)
    
    # Based on Kiwix ZIM file sizes (compressed)
    wikipedia_options = {
        "Wikipedia Medical (full)": {
            "size_gb": 6.8,
            "articles": "50,000+",
            "images": "Yes",
            "current": True
        },
        "Wikipedia Mini (text only)": {
            "size_gb": 1.2,
            "articles": "50,000 most important",
            "images": "No",
            "current": False
        },
        "Wikipedia Top 1M Articles": {
            "size_gb": 15.0,
            "articles": "1 million",
            "images": "Thumbnails only",
            "current": False
        },
        "Wikipedia Full (no images)": {
            "size_gb": 22.0,
            "articles": "6+ million",
            "images": "No",
            "current": False
        },
        "Wikipedia Full (with images)": {
            "size_gb": 87.0,
            "articles": "6+ million", 
            "images": "Yes",
            "current": False
        }
    }
    
    print("\nAvailable Wikipedia Offline Options:")
    for name, details in wikipedia_options.items():
        current = " (CURRENT APPROACH)" if details["current"] else ""
        print(f"\n{name}{current}:")
        print(f"  Size: {details['size_gb']} GB")
        print(f"  Articles: {details['articles']}")
        print(f"  Images: {details['images']}")
    
    # Our recommended approach
    print("\n🎯 Recommended Modular Approach:")
    print("  1. Core medical content: 582 MB (already extracted)")
    print("  2. Extended medical: 6.2 GB (rest of Wikipedia Medical)")
    print("  3. Survival-relevant: ~2 GB (curated subset)")
    print("  4. General reference: 15 GB (top 1M articles)")
    
    # Total with different configurations
    print("\n📊 Total Storage Requirements:")
    
    configs = {
        "Minimal (medical only)": 3.5,  # From our analysis
        "Standard (medical + survival)": 5.5,
        "Extended (+ Wikipedia medical full)": 10.3,
        "Comprehensive (+ top articles)": 25.3,
        "Full Reference (everything)": 90.0
    }
    
    for config, size_gb in configs.items():
        print(f"  {config}: {size_gb} GB")
    
    # Architecture implications
    print("\n🏗️  Architecture Impact:")
    if configs["Standard (medical + survival)"] < 10:
        print("  ✅ Standard config fits in VERY LARGE APP category")
        print("  - Can use module system with download manager")
        print("  - External storage recommended but not required")
    
    print("\n  ⚠️  Extended/Comprehensive configs require:")
    print("  - PLATFORM APP architecture")
    print("  - Mandatory external storage")
    print("  - Selective sync/streaming")
    print("  - Consider peer-to-peer sharing")
    
    return configs

def update_final_report():
    """Update our report with Wikipedia estimates"""
    
    report_path = Path("content-sizing/reports/content_sizing_report.json")
    
    # Load existing report
    with open(report_path, 'r') as f:
        report = json.load(f)
    
    # Add Wikipedia estimates
    report["wikipedia_estimates"] = {
        "medical_only_gb": 6.8,
        "mini_gb": 1.2,
        "top_articles_gb": 15.0,
        "full_text_gb": 22.0,
        "full_with_images_gb": 87.0
    }
    
    # Update recommendations
    report["final_recommendations"] = {
        "minimal_config": {
            "size_gb": 3.5,
            "architecture": "LARGE_APP",
            "description": "Core medical + maps for local region"
        },
        "standard_config": {
            "size_gb": 5.5,
            "architecture": "VERY_LARGE_APP",
            "description": "Medical + survival guides + regional maps"
        },
        "extended_config": {
            "size_gb": 10.3,
            "architecture": "PLATFORM_APP",
            "description": "Full Wikipedia medical + all content"
        }
    }
    
    # Save updated report
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"\n📄 Updated report: {report_path}")

if __name__ == "__main__":
    configs = estimate_wikipedia_sizes()
    update_final_report()