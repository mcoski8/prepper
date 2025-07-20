#!/usr/bin/env python3
"""
Content Sizing Analysis for PrepperApp
Samples various content types and extrapolates total storage requirements
"""

import json
import os
import random
import sqlite3
import zstandard as zstd
from pathlib import Path
import requests
import hashlib
from typing import Dict, List, Tuple
import sys

class ContentSizer:
    def __init__(self, output_dir: Path):
        self.output_dir = Path(output_dir)
        self.samples_dir = self.output_dir / "samples"
        self.samples_dir.mkdir(parents=True, exist_ok=True)
        
        self.compressor = zstd.ZstdCompressor(level=3)
        self.results = {
            "wikipedia_medical": {},
            "survival_manuals": {},
            "maps": {},
            "images": {},
            "other_content": {}
        }
    
    def sample_wikipedia_medical(self, jsonl_path: Path, sample_rate: float = 0.01):
        """Sample 1% of Wikipedia medical articles"""
        print(f"\n📊 Sampling Wikipedia Medical Content ({sample_rate*100}%)")
        
        if not jsonl_path.exists():
            print(f"❌ JSONL file not found: {jsonl_path}")
            print("   Run SPRINT5_RUNNER.sh first to extract content")
            return
        
        # Count total articles
        total_articles = sum(1 for _ in open(jsonl_path))
        sample_size = int(total_articles * sample_rate)
        
        print(f"   Total articles: {total_articles:,}")
        print(f"   Sample size: {sample_size:,}")
        
        # Randomly sample articles
        sample_indices = set(random.sample(range(total_articles), sample_size))
        
        sampled_articles = []
        original_size = 0
        compressed_size = 0
        
        with open(jsonl_path, 'r') as f:
            for idx, line in enumerate(f):
                if idx in sample_indices:
                    article = json.loads(line)
                    sampled_articles.append(article)
                    
                    # Measure sizes
                    content = article.get('content', '')
                    original = content.encode('utf-8')
                    compressed = self.compressor.compress(original)
                    
                    original_size += len(original)
                    compressed_size += len(compressed)
        
        # Calculate compression ratio
        compression_ratio = compressed_size / original_size if original_size > 0 else 0
        
        # Extrapolate to full dataset
        extrapolated_original = (original_size / sample_size) * total_articles
        extrapolated_compressed = (compressed_size / sample_size) * total_articles
        
        self.results["wikipedia_medical"] = {
            "sample_size": sample_size,
            "total_articles": total_articles,
            "sample_original_mb": original_size / (1024 * 1024),
            "sample_compressed_mb": compressed_size / (1024 * 1024),
            "compression_ratio": compression_ratio,
            "extrapolated_original_mb": extrapolated_original / (1024 * 1024),
            "extrapolated_compressed_mb": extrapolated_compressed / (1024 * 1024),
            "articles_by_priority": self._count_priorities(sampled_articles)
        }
        
        print(f"   Compression ratio: {compression_ratio:.2%}")
        print(f"   Extrapolated size: {extrapolated_compressed / (1024 * 1024):.1f} MB")
    
    def _count_priorities(self, articles: List[Dict]) -> Dict[int, int]:
        """Count articles by priority"""
        counts = {0: 0, 1: 0, 2: 0}
        for article in articles:
            priority = article.get('priority', 2)
            counts[priority] += 1
        return counts
    
    def sample_survival_manuals(self):
        """Download and measure sample survival manual content"""
        print("\n📚 Sampling Survival Manuals")
        
        # Sample URLs for public domain military manuals
        manual_samples = [
            {
                "name": "FM 21-76 Survival Manual",
                "url": "https://www.bits.de/NRANEU/others/amd-us-archive/FM21-76%281992%29.pdf",
                "pages": 287
            },
            # Add more manual URLs here
        ]
        
        total_size = 0
        compressed_total = 0
        
        print("   Note: Using estimated sizes for military manuals")
        print("   Typical manual: 5-10MB PDF, 80% text extractable")
        
        # Estimate based on typical manual sizes
        estimated_manuals = 20  # Common survival/medical manuals
        avg_manual_size = 7  # MB per manual
        text_ratio = 0.8  # 80% extractable as text
        compression_ratio = 0.25  # Text compresses to 25%
        
        estimated_text = estimated_manuals * avg_manual_size * text_ratio
        estimated_compressed = estimated_text * compression_ratio
        
        self.results["survival_manuals"] = {
            "estimated_count": estimated_manuals,
            "avg_size_mb": avg_manual_size,
            "text_extraction_ratio": text_ratio,
            "compression_ratio": compression_ratio,
            "estimated_original_mb": estimated_text,
            "estimated_compressed_mb": estimated_compressed
        }
        
        print(f"   Estimated compressed size: {estimated_compressed:.1f} MB")
    
    def sample_maps(self):
        """Estimate map storage requirements"""
        print("\n🗺️  Estimating Map Storage")
        
        # OpenStreetMap vector tiles for offline use
        # Based on MBTiles format typical sizes
        regions = {
            "US State (avg)": 500,  # MB per state
            "Major City": 100,      # MB per city
            "Rural County": 50      # MB per county
        }
        
        # Estimate user needs
        typical_coverage = {
            "Home State": 1 * 500,
            "Neighboring States": 2 * 500,
            "Major Cities": 5 * 100,
            "Rural Areas": 10 * 50
        }
        
        total_maps = sum(typical_coverage.values())
        
        self.results["maps"] = {
            "coverage_mb": typical_coverage,
            "total_mb": total_maps,
            "format": "MBTiles (vector)",
            "compression": "Already optimized"
        }
        
        print(f"   Typical user map needs: {total_maps:,} MB")
    
    def sample_images(self):
        """Estimate medical diagram/image requirements"""
        print("\n🏥 Estimating Medical Images")
        
        # Medical procedure diagrams, anatomy charts, etc.
        image_categories = {
            "CPR/First Aid Diagrams": {"count": 50, "avg_size_kb": 200},
            "Anatomy References": {"count": 100, "avg_size_kb": 300},
            "Wound Care Photos": {"count": 200, "avg_size_kb": 150},
            "Plant ID (poisonous)": {"count": 500, "avg_size_kb": 100},
            "Emergency Procedures": {"count": 100, "avg_size_kb": 250}
        }
        
        total_images = 0
        total_size_mb = 0
        
        for category, specs in image_categories.items():
            size_mb = (specs["count"] * specs["avg_size_kb"]) / 1024
            total_images += specs["count"]
            total_size_mb += size_mb
        
        # JPEG compression already applied, minimal further compression
        self.results["images"] = {
            "categories": image_categories,
            "total_images": total_images,
            "original_mb": total_size_mb,
            "compressed_mb": total_size_mb * 0.9  # 10% additional compression
        }
        
        print(f"   Total images: {total_images:,}")
        print(f"   Estimated size: {total_size_mb:.1f} MB")
    
    def estimate_other_content(self):
        """Estimate other content types"""
        print("\n📖 Estimating Other Content")
        
        other_content = {
            "Where There Is No Doctor": 50,  # MB
            "Where There Is No Dentist": 30,
            "Red Cross First Aid": 20,
            "Edible Plants Guides": 100,
            "Radio/Comms Guides": 40,
            "Water Purification": 20,
            "Shelter Building": 30
        }
        
        total_other = sum(other_content.values())
        compressed_other = total_other * 0.3  # Assume 70% compression
        
        self.results["other_content"] = {
            "items": other_content,
            "original_mb": total_other,
            "compressed_mb": compressed_other
        }
        
        print(f"   Total other content: {compressed_other:.1f} MB")
    
    def calculate_search_overhead(self):
        """Estimate search index overhead"""
        print("\n🔍 Calculating Search Index Overhead")
        
        # Tantivy index is typically 20-30% of text content
        text_content_mb = (
            self.results.get("wikipedia_medical", {}).get("extrapolated_compressed_mb", 0) +
            self.results.get("survival_manuals", {}).get("estimated_compressed_mb", 0) +
            self.results.get("other_content", {}).get("compressed_mb", 0)
        )
        
        # Basic indexing (no positions) = 20% overhead
        # Full indexing (with positions) = 40% overhead
        basic_overhead = text_content_mb * 0.20
        full_overhead = text_content_mb * 0.40
        
        self.results["search_index"] = {
            "text_content_mb": text_content_mb,
            "basic_index_mb": basic_overhead,
            "full_index_mb": full_overhead,
            "current_approach": "basic"
        }
        
        print(f"   Text content: {text_content_mb:.1f} MB")
        print(f"   Index overhead (basic): {basic_overhead:.1f} MB")
    
    def generate_report(self):
        """Generate final sizing report"""
        print("\n" + "="*60)
        print("📊 CONTENT SIZING SUMMARY")
        print("="*60)
        
        # Calculate totals
        totals = {
            "text_compressed": 0,
            "images": 0,
            "maps": 0,
            "search_index": 0
        }
        
        # Add up all content
        if "wikipedia_medical" in self.results:
            totals["text_compressed"] += self.results["wikipedia_medical"].get("extrapolated_compressed_mb", 0)
        
        if "survival_manuals" in self.results:
            totals["text_compressed"] += self.results["survival_manuals"].get("estimated_compressed_mb", 0)
        
        if "other_content" in self.results:
            totals["text_compressed"] += self.results["other_content"].get("compressed_mb", 0)
        
        if "images" in self.results:
            totals["images"] = self.results["images"].get("compressed_mb", 0)
        
        if "maps" in self.results:
            totals["maps"] = self.results["maps"].get("total_mb", 0)
        
        if "search_index" in self.results:
            totals["search_index"] = self.results["search_index"].get("basic_index_mb", 0)
        
        # Content breakdown
        print("\n📁 Content Breakdown:")
        print(f"   Wikipedia Medical: {self.results.get('wikipedia_medical', {}).get('extrapolated_compressed_mb', 0):.1f} MB")
        print(f"   Survival Manuals: {self.results.get('survival_manuals', {}).get('estimated_compressed_mb', 0):.1f} MB")
        print(f"   Other Guides: {self.results.get('other_content', {}).get('compressed_mb', 0):.1f} MB")
        print(f"   Medical Images: {totals['images']:.1f} MB")
        print(f"   Offline Maps: {totals['maps']:.1f} MB")
        print(f"   Search Index: {totals['search_index']:.1f} MB")
        
        # Module sizes
        print("\n📦 Proposed Module Sizes:")
        p0_size = self.results.get("wikipedia_medical", {}).get("extrapolated_compressed_mb", 0) * 0.3  # 30% is P0
        p1_size = self.results.get("wikipedia_medical", {}).get("extrapolated_compressed_mb", 0) * 0.35  # 35% is P1
        p2_size = self.results.get("wikipedia_medical", {}).get("extrapolated_compressed_mb", 0) * 0.35  # 35% is P2
        
        print(f"   P0 Emergency (30%): {p0_size:.1f} MB")
        print(f"   P1 Important (35%): {p1_size:.1f} MB")
        print(f"   P2 Extended (35%): {p2_size:.1f} MB")
        print(f"   Survival Manuals: {self.results.get('survival_manuals', {}).get('estimated_compressed_mb', 0):.1f} MB")
        print(f"   Images Module: {totals['images']:.1f} MB")
        print(f"   Maps (per region): ~500 MB")
        
        # Total estimates
        core_total = p0_size + totals["search_index"] * 0.3  # P0 index
        standard_total = core_total + p1_size + totals["images"] + self.results.get('survival_manuals', {}).get('estimated_compressed_mb', 0)
        full_total = sum(totals.values())
        
        print("\n🎯 Storage Requirement Estimates:")
        print(f"   Core App (P0 only): {core_total:.1f} MB")
        print(f"   Standard Install: {standard_total:.1f} MB")
        print(f"   Full Content (no maps): {full_total:.1f} MB")
        print(f"   With Regional Maps: {full_total + 2500:.1f} MB")  # ~5 states
        
        # Architecture recommendation
        print("\n🏗️  Architecture Recommendation:")
        if full_total < 4000:
            print("   ✅ LARGE APP (<4GB): Standard architecture with optional downloads")
            print("      - Single app with modular content")
            print("      - Optional external storage")
            print("      - Simple download management")
        elif full_total < 10000:
            print("   ⚠️  VERY LARGE APP (4-10GB): Mandatory module system required")
            print("      - Small loader app (~100MB)")
            print("      - Required external storage support")
            print("      - Sophisticated download manager")
        else:
            print("   🚨 PLATFORM APP (>10GB): Content platform architecture")
            print("      - Minimal base app")
            print("      - All content as modules")
            print("      - Streaming/selective sync")
        
        # Save detailed results
        report_path = self.output_dir / "reports" / "content_sizing_report.json"
        report_path.parent.mkdir(exist_ok=True)
        
        with open(report_path, 'w') as f:
            json.dump({
                "summary": {
                    "core_mb": core_total,
                    "standard_mb": standard_total,
                    "full_mb": full_total,
                    "with_maps_mb": full_total + 2500
                },
                "detailed_results": self.results,
                "recommendations": {
                    "architecture": "LARGE_APP" if full_total < 4000 else "VERY_LARGE_APP" if full_total < 10000 else "PLATFORM_APP"
                }
            }, f, indent=2)
        
        print(f"\n📄 Detailed report saved to: {report_path}")
        
        return totals

def main():
    # Set up paths
    base_dir = Path("/Users/michaelchang/Documents/claudecode/prepper/prepperapp")
    sizing_dir = base_dir / "content-sizing"
    data_dir = base_dir / "data"
    
    # Create sizer
    sizer = ContentSizer(sizing_dir)
    
    # Run sampling
    print("🚀 PrepperApp Content Sizing Analysis")
    print("="*60)
    
    # 1. Sample Wikipedia medical content
    jsonl_path = data_dir / "processed" / "articles.jsonl"
    sizer.sample_wikipedia_medical(jsonl_path)
    
    # 2. Estimate survival manuals
    sizer.sample_survival_manuals()
    
    # 3. Estimate maps
    sizer.sample_maps()
    
    # 4. Estimate images
    sizer.sample_images()
    
    # 5. Estimate other content
    sizer.estimate_other_content()
    
    # 6. Calculate search overhead
    sizer.calculate_search_overhead()
    
    # Generate report
    sizer.generate_report()

if __name__ == "__main__":
    main()