#!/usr/bin/env python3
"""
Chunked download manager with resume support for PrepperApp
Handles large file downloads with network failure recovery
"""

import os
import json
import time
import hashlib
import requests
from pathlib import Path
from typing import Optional, Set, Dict
from datetime import datetime
import argparse

class ChunkedDownloader:
    """Download manager with chunked downloads and resume capability"""
    
    # 4MB chunks as recommended by Gemini for mobile networks
    CHUNK_SIZE = 4 * 1024 * 1024
    
    # Retry configuration
    MAX_RETRIES = 3
    RETRY_DELAY = 5  # seconds
    
    def __init__(self, chunk_size: int = None):
        self.chunk_size = chunk_size or self.CHUNK_SIZE
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'PrepperApp/1.0 Content Downloader'
        })
    
    def get_file_info(self, url: str) -> Dict:
        """Get file size and verify server supports range requests"""
        try:
            # Follow redirects to get final URL
            response = self.session.head(url, allow_redirects=True)
            response.raise_for_status()
            
            final_url = response.url
            content_length = int(response.headers.get('content-length', 0))
            accept_ranges = response.headers.get('accept-ranges', '').lower() == 'bytes'
            
            return {
                'final_url': final_url,
                'size': content_length,
                'supports_resume': accept_ranges,
                'headers': dict(response.headers)
            }
        except Exception as e:
            raise Exception(f"Failed to get file info: {e}")
    
    def load_metadata(self, meta_path: Path) -> Dict:
        """Load download metadata"""
        if meta_path.exists():
            with open(meta_path, 'r') as f:
                return json.load(f)
        return {
            'chunks_completed': [],
            'file_info': {},
            'download_started': datetime.now().isoformat()
        }
    
    def save_metadata(self, meta_path: Path, metadata: Dict):
        """Save download metadata"""
        metadata['last_updated'] = datetime.now().isoformat()
        with open(meta_path, 'w') as f:
            json.dump(metadata, f, indent=2)
    
    def calculate_chunk_hash(self, data: bytes) -> str:
        """Calculate SHA256 hash of chunk"""
        return hashlib.sha256(data).hexdigest()
    
    def download_chunk_with_retry(self, url: str, start_byte: int, end_byte: int, 
                                 max_retries: int = None) -> bytes:
        """Download a chunk with retry logic"""
        max_retries = max_retries or self.MAX_RETRIES
        last_error = None
        
        for attempt in range(max_retries):
            try:
                headers = {'Range': f'bytes={start_byte}-{end_byte}'}
                response = self.session.get(url, headers=headers, timeout=30)
                
                if response.status_code == 206:  # Partial Content
                    return response.content
                elif response.status_code == 200:
                    # Server doesn't support range requests
                    raise Exception("Server doesn't support partial downloads")
                else:
                    response.raise_for_status()
                    
            except Exception as e:
                last_error = e
                if attempt < max_retries - 1:
                    wait_time = self.RETRY_DELAY * (2 ** attempt)  # Exponential backoff
                    print(f"  Retry {attempt + 1}/{max_retries} after {wait_time}s: {e}")
                    time.sleep(wait_time)
        
        raise Exception(f"Failed after {max_retries} attempts: {last_error}")
    
    def download_with_resume(self, url: str, dest_path: str, 
                           verify_hash: Optional[str] = None) -> bool:
        """Download file with resume capability"""
        dest_path = Path(dest_path)
        meta_path = Path(f"{dest_path}.meta")
        temp_path = Path(f"{dest_path}.tmp")
        
        # Create destination directory
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        
        print(f"Downloading: {url}")
        print(f"Destination: {dest_path}")
        
        # Get file info
        print("Getting file information...")
        file_info = self.get_file_info(url)
        final_url = file_info['final_url']
        file_size = file_info['size']
        
        if not file_info['supports_resume']:
            print("Warning: Server doesn't support resume. Download will restart if interrupted.")
        
        print(f"File size: {file_size:,} bytes ({file_size / (1024*1024):.1f} MB)")
        
        # Load existing metadata
        metadata = self.load_metadata(meta_path)
        metadata['file_info'] = file_info
        
        # Calculate total chunks
        total_chunks = (file_size + self.chunk_size - 1) // self.chunk_size
        chunks_completed = set(metadata.get('chunks_completed', []))
        
        print(f"Total chunks: {total_chunks}")
        print(f"Chunks completed: {len(chunks_completed)}")
        
        # Open temp file for writing
        mode = 'r+b' if temp_path.exists() else 'wb'
        with open(temp_path, mode) as f:
            # Ensure file is correct size
            if mode == 'wb':
                f.seek(file_size - 1)
                f.write(b'\0')
            
            # Download remaining chunks
            for chunk_num in range(total_chunks):
                if chunk_num in chunks_completed:
                    continue
                
                start_byte = chunk_num * self.chunk_size
                end_byte = min(start_byte + self.chunk_size - 1, file_size - 1)
                
                # Progress indicator
                progress = len(chunks_completed) / total_chunks * 100
                print(f"\rDownloading chunk {chunk_num + 1}/{total_chunks} ({progress:.1f}%)", 
                     end='', flush=True)
                
                # Download chunk
                try:
                    chunk_data = self.download_chunk_with_retry(
                        final_url, start_byte, end_byte
                    )
                    
                    # Write chunk to file
                    f.seek(start_byte)
                    f.write(chunk_data)
                    f.flush()
                    
                    # Mark chunk as completed
                    chunks_completed.add(chunk_num)
                    metadata['chunks_completed'] = list(chunks_completed)
                    
                    # Save metadata every 10 chunks
                    if len(chunks_completed) % 10 == 0:
                        self.save_metadata(meta_path, metadata)
                        
                except Exception as e:
                    print(f"\nError downloading chunk {chunk_num}: {e}")
                    self.save_metadata(meta_path, metadata)
                    return False
        
        print("\n✓ Download complete!")
        
        # Verify file if hash provided
        if verify_hash:
            print("Verifying file integrity...")
            calculated_hash = self.calculate_file_hash(temp_path)
            if calculated_hash.lower() != verify_hash.lower():
                print(f"Error: Hash mismatch!")
                print(f"  Expected: {verify_hash}")
                print(f"  Got: {calculated_hash}")
                return False
            print("✓ File integrity verified")
        
        # Move temp file to final destination
        temp_path.rename(dest_path)
        
        # Clean up metadata
        meta_path.unlink()
        
        print(f"✓ File saved to: {dest_path}")
        return True
    
    def calculate_file_hash(self, file_path: Path) -> str:
        """Calculate SHA256 hash of entire file"""
        sha256_hash = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
        return sha256_hash.hexdigest()
    
    def download_manifest(self, manifest_url: str, dest_dir: str) -> Dict:
        """Download and parse manifest file"""
        manifest_path = Path(dest_dir) / "manifest.json"
        
        print("Downloading manifest...")
        response = self.session.get(manifest_url)
        response.raise_for_status()
        
        manifest = response.json()
        
        # Save manifest locally
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        with open(manifest_path, 'w') as f:
            json.dump(manifest, f, indent=2)
        
        print("✓ Manifest downloaded")
        return manifest
    
    def download_content_package(self, manifest_url: str, dest_dir: str, 
                               module: Optional[str] = None) -> bool:
        """Download content package based on manifest"""
        try:
            # Download manifest
            manifest = self.download_manifest(manifest_url, dest_dir)
            
            # Select module to download
            if module:
                if module not in manifest.get('modules', {}):
                    print(f"Error: Module '{module}' not found in manifest")
                    print(f"Available modules: {', '.join(manifest.get('modules', {}).keys())}")
                    return False
                modules_to_download = {module: manifest['modules'][module]}
            else:
                # Download core module by default
                if 'core' in manifest:
                    modules_to_download = {'core': manifest['core']}
                else:
                    print("Error: No core module found in manifest")
                    return False
            
            # Download each module
            success = True
            for module_name, module_info in modules_to_download.items():
                print(f"\n=== Downloading module: {module_name} ===")
                
                # Download ZIM file
                if 'zim_url' in module_info:
                    zim_path = Path(dest_dir) / module_name / module_info['zim_filename']
                    zim_hash = module_info.get('zim_sha256')
                    
                    if not self.download_with_resume(
                        module_info['zim_url'], 
                        str(zim_path),
                        zim_hash
                    ):
                        success = False
                        continue
                
                # Download index
                if 'index_url' in module_info:
                    index_path = Path(dest_dir) / module_name / module_info['index_filename']
                    index_hash = module_info.get('index_sha256')
                    
                    if not self.download_with_resume(
                        module_info['index_url'],
                        str(index_path),
                        index_hash
                    ):
                        success = False
            
            return success
            
        except Exception as e:
            print(f"Error downloading content package: {e}")
            return False

def main():
    parser = argparse.ArgumentParser(description='PrepperApp content downloader')
    parser.add_argument('action', choices=['download', 'resume', 'manifest'],
                       help='Action to perform')
    parser.add_argument('--url', help='URL to download')
    parser.add_argument('--manifest', help='Manifest URL for content package')
    parser.add_argument('--dest', default='../raw/', help='Destination directory')
    parser.add_argument('--module', help='Specific module to download')
    parser.add_argument('--hash', help='Expected SHA256 hash for verification')
    parser.add_argument('--chunk-size', type=int, help='Chunk size in bytes')
    
    args = parser.parse_args()
    
    downloader = ChunkedDownloader(chunk_size=args.chunk_size)
    
    if args.action == 'download':
        if args.manifest:
            # Download from manifest
            success = downloader.download_content_package(
                args.manifest, args.dest, args.module
            )
        elif args.url:
            # Direct download
            filename = os.path.basename(args.url.split('?')[0])
            dest_path = Path(args.dest) / filename
            success = downloader.download_with_resume(
                args.url, str(dest_path), args.hash
            )
        else:
            print("Error: Either --url or --manifest required")
            success = False
        
        sys.exit(0 if success else 1)
    
    elif args.action == 'resume':
        print("Resume functionality is built into download action")
        print("Just run the same download command again")
    
    elif args.action == 'manifest':
        if not args.manifest:
            print("Error: --manifest URL required")
            sys.exit(1)
        
        manifest = downloader.download_manifest(args.manifest, args.dest)
        print("\nManifest contents:")
        print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    import sys
    main()