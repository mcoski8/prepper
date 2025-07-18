#!/usr/bin/env python3
"""
Create distribution manifest for PrepperApp content modules
Generates manifest.json with download URLs, checksums, and metadata
"""

import json
import hashlib
import os
from pathlib import Path
from datetime import datetime
import argparse
from typing import Dict, List

class ManifestGenerator:
    def __init__(self, base_url: str, content_dir: str = "../processed"):
        self.base_url = base_url.rstrip('/')
        self.content_dir = Path(content_dir)
        self.output_dir = self.content_dir / "distribution"
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def calculate_file_hash(self, file_path: Path) -> str:
        """Calculate SHA256 hash of a file"""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()
    
    def get_file_size(self, file_path: Path) -> int:
        """Get file size in bytes"""
        return file_path.stat().st_size
    
    def format_size(self, size_bytes: int) -> str:
        """Format size in human readable format"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} TB"
    
    def create_module_info(self, module_name: str, module_path: Path) -> Dict:
        """Create module information for manifest"""
        module_info = {
            "name": module_name,
            "version": "1.0.0",
            "created": datetime.now().isoformat(),
            "files": {}
        }
        
        # Find ZIM file
        zim_files = list(module_path.glob("*.zim"))
        if zim_files:
            zim_file = zim_files[0]
            zim_info = {
                "filename": zim_file.name,
                "size": self.get_file_size(zim_file),
                "size_human": self.format_size(self.get_file_size(zim_file)),
                "sha256": self.calculate_file_hash(zim_file),
                "url": f"{self.base_url}/modules/{module_name}/{zim_file.name}"
            }
            module_info["zim"] = zim_info
            module_info["files"]["content"] = zim_info
        
        # Find index files
        index_path = module_path / "index"
        if index_path.exists():
            # Create tar.gz of index directory
            import tarfile
            index_archive = module_path / f"{module_name}_index.tar.gz"
            
            with tarfile.open(index_archive, "w:gz") as tar:
                tar.add(index_path, arcname="index")
            
            index_info = {
                "filename": index_archive.name,
                "size": self.get_file_size(index_archive),
                "size_human": self.format_size(self.get_file_size(index_archive)),
                "sha256": self.calculate_file_hash(index_archive),
                "url": f"{self.base_url}/modules/{module_name}/{index_archive.name}"
            }
            module_info["index"] = index_info
            module_info["files"]["index"] = index_info
        
        # Add metadata
        metadata_file = module_path / "metadata.json"
        if metadata_file.exists():
            with open(metadata_file, 'r') as f:
                metadata = json.load(f)
                module_info["metadata"] = metadata
        
        # Calculate total size
        total_size = sum(file_info["size"] for file_info in module_info["files"].values())
        module_info["total_size"] = total_size
        module_info["total_size_human"] = self.format_size(total_size)
        
        return module_info
    
    def create_manifest(self, modules: List[str] = None) -> Dict:
        """Create complete manifest for all modules"""
        manifest = {
            "version": "1.0",
            "created": datetime.now().isoformat(),
            "app_version": "1.0.0",
            "base_url": self.base_url,
            "modules": {}
        }
        
        # Find all modules if not specified
        if not modules:
            modules = []
            for item in self.content_dir.iterdir():
                if item.is_dir() and not item.name.startswith('.'):
                    modules.append(item.name)
        
        # Process each module
        for module_name in modules:
            module_path = self.content_dir / module_name
            if module_path.exists():
                print(f"Processing module: {module_name}")
                module_info = self.create_module_info(module_name, module_path)
                manifest["modules"][module_name] = module_info
            else:
                print(f"Warning: Module path not found: {module_path}")
        
        # Special handling for core module
        if "curated" in manifest["modules"]:
            manifest["core"] = manifest["modules"]["curated"]
            manifest["core"]["name"] = "core"
            manifest["core"]["description"] = "Essential survival medical content"
            manifest["core"]["priority"] = 0
        
        # Add module recommendations
        manifest["recommended_order"] = [
            "core",
            "medical_advanced", 
            "water_purification",
            "shelter_building",
            "plant_identification"
        ]
        
        # Add download instructions
        manifest["download_instructions"] = {
            "sequential": "Download modules one at a time in recommended order",
            "concurrent": "Maximum 2 concurrent downloads recommended",
            "retry": "Use exponential backoff for failed downloads",
            "verification": "Always verify SHA256 after download"
        }
        
        return manifest
    
    def save_manifest(self, manifest: Dict, output_file: str = None):
        """Save manifest to file"""
        if not output_file:
            output_file = self.output_dir / "manifest.json"
        else:
            output_file = Path(output_file)
        
        with open(output_file, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print(f"\n✓ Manifest saved to: {output_file}")
        print(f"  Total modules: {len(manifest['modules'])}")
        
        # Print summary
        total_size = 0
        for module_name, module_info in manifest['modules'].items():
            size = module_info.get('total_size', 0)
            total_size += size
            print(f"  - {module_name}: {module_info.get('total_size_human', 'N/A')}")
        
        print(f"  Total size: {self.format_size(total_size)}")
        
        return output_file
    
    def create_module_packages(self, manifest: Dict):
        """Create distribution packages for each module"""
        print("\nCreating distribution packages...")
        
        for module_name, module_info in manifest['modules'].items():
            module_dir = self.output_dir / module_name
            module_dir.mkdir(exist_ok=True)
            
            # Create module-specific manifest
            module_manifest = {
                "module": module_info,
                "base_url": self.base_url,
                "created": manifest["created"]
            }
            
            module_manifest_file = module_dir / "module_manifest.json"
            with open(module_manifest_file, 'w') as f:
                json.dump(module_manifest, f, indent=2)
            
            print(f"✓ Created package for: {module_name}")
    
    def generate_html_index(self, manifest: Dict):
        """Generate HTML index page for manual downloads"""
        html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>PrepperApp Content Downloads</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; }}
        .module {{ border: 1px solid #ddd; padding: 15px; margin: 10px 0; }}
        .file {{ margin: 10px 0; padding: 10px; background: #f5f5f5; }}
        .hash {{ font-family: monospace; font-size: 0.8em; color: #666; }}
        h1 {{ color: #333; }}
        h2 {{ color: #666; }}
        .download {{ 
            background: #4CAF50; 
            color: white; 
            padding: 10px 20px; 
            text-decoration: none; 
            display: inline-block;
            margin: 5px;
        }}
    </style>
</head>
<body>
    <h1>PrepperApp Content Downloads</h1>
    <p>Generated: {manifest['created']}</p>
    <p>Total Modules: {len(manifest['modules'])}</p>
    
    <h2>Download Instructions</h2>
    <ol>
        <li>Download the manifest.json first</li>
        <li>Download core module (required)</li>
        <li>Download additional modules as needed</li>
        <li>Verify SHA256 checksums after download</li>
    </ol>
    
    <div class="module">
        <h3>Manifest</h3>
        <a class="download" href="manifest.json">Download manifest.json</a>
    </div>
"""
        
        for module_name, module_info in manifest['modules'].items():
            priority_badge = "⭐ REQUIRED" if module_name == "core" else ""
            html_content += f"""
    <div class="module">
        <h3>{module_name} {priority_badge}</h3>
        <p>Total size: {module_info.get('total_size_human', 'N/A')}</p>
"""
            
            for file_type, file_info in module_info.get('files', {}).items():
                html_content += f"""
        <div class="file">
            <h4>{file_type.title()} File</h4>
            <p>Filename: {file_info['filename']}</p>
            <p>Size: {file_info['size_human']}</p>
            <p class="hash">SHA256: {file_info['sha256']}</p>
            <a class="download" href="{file_info['url']}">Download</a>
        </div>
"""
            
            html_content += "    </div>\n"
        
        html_content += """
</body>
</html>"""
        
        index_file = self.output_dir / "index.html"
        with open(index_file, 'w') as f:
            f.write(html_content)
        
        print(f"✓ Generated HTML index: {index_file}")

def main():
    parser = argparse.ArgumentParser(description='Generate PrepperApp distribution manifest')
    parser.add_argument('--base-url', required=True,
                       help='Base URL for content downloads (e.g., https://content.prepperapp.com)')
    parser.add_argument('--content-dir', default='../processed',
                       help='Content directory path')
    parser.add_argument('--modules', nargs='+',
                       help='Specific modules to include (default: all)')
    parser.add_argument('--output', help='Output manifest file path')
    parser.add_argument('--create-packages', action='store_true',
                       help='Create distribution packages')
    parser.add_argument('--html-index', action='store_true',
                       help='Generate HTML download index')
    
    args = parser.parse_args()
    
    generator = ManifestGenerator(args.base_url, args.content_dir)
    
    # Create manifest
    manifest = generator.create_manifest(args.modules)
    
    # Save manifest
    manifest_file = generator.save_manifest(manifest, args.output)
    
    # Create packages if requested
    if args.create_packages:
        generator.create_module_packages(manifest)
    
    # Generate HTML index if requested
    if args.html_index:
        generator.generate_html_index(manifest)
    
    print("\n✅ Manifest generation complete!")
    print(f"\nNext steps:")
    print(f"1. Upload content files to: {args.base_url}")
    print(f"2. Upload manifest to: {args.base_url}/manifest.json")
    print(f"3. Test downloads with: ./chunked_downloader.py manifest --manifest {args.base_url}/manifest.json")

if __name__ == "__main__":
    main()