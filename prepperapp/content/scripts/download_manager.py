#!/usr/bin/env python3
"""
PrepperApp Content Download Manager
Manages downloads with progress tracking, resume support, and status monitoring
"""

import os
import sys
import json
import time
import subprocess
import hashlib
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

# Configuration
DOWNLOAD_STATUS_FILE = "download_status.json"
DOWNLOAD_LOG_FILE = "download_log.txt"
MAX_RETRIES = 3
CHUNK_SIZE = 1024 * 1024  # 1MB chunks
MAX_CONCURRENT_DOWNLOADS = 3

class DownloadManager:
    def __init__(self, base_dir: str = None):
        self.base_dir = Path(base_dir or os.environ.get('PREPPER_EXTERNAL_CONTENT', '.'))
        self.status_file = self.base_dir / DOWNLOAD_STATUS_FILE
        self.log_file = self.base_dir / DOWNLOAD_LOG_FILE
        self.status = self.load_status()
        
    def load_status(self) -> Dict:
        """Load download status from file"""
        if self.status_file.exists():
            with open(self.status_file, 'r') as f:
                return json.load(f)
        return {
            "downloads": {},
            "total_size": 0,
            "downloaded_size": 0,
            "start_time": datetime.now().isoformat()
        }
    
    def save_status(self):
        """Save download status to file"""
        with open(self.status_file, 'w') as f:
            json.dump(self.status, f, indent=2)
    
    def log(self, message: str):
        """Log message to console and file"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}"
        print(log_entry)
        
        with open(self.log_file, 'a') as f:
            f.write(log_entry + "\n")
    
    def format_size(self, size_bytes: int) -> str:
        """Format bytes to human readable size"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} PB"
    
    def format_speed(self, bytes_per_second: float) -> str:
        """Format download speed"""
        return f"{self.format_size(bytes_per_second)}/s"
    
    def get_file_info(self, url: str) -> Dict:
        """Get file size and resume support info"""
        try:
            req = urllib.request.Request(url, method='HEAD')
            req.add_header('User-Agent', 'PrepperApp/1.0')
            
            with urllib.request.urlopen(req, timeout=10) as response:
                size = int(response.headers.get('Content-Length', 0))
                accepts_ranges = response.headers.get('Accept-Ranges', '') == 'bytes'
                
                return {
                    "size": size,
                    "supports_resume": accepts_ranges,
                    "headers": dict(response.headers)
                }
        except Exception as e:
            self.log(f"Error getting file info for {url}: {e}")
            return {"size": 0, "supports_resume": False, "headers": {}}
    
    def download_with_progress(self, url: str, dest_path: Path, file_id: str) -> bool:
        """Download file with progress tracking and resume support"""
        dest_path.parent.mkdir(parents=True, exist_ok=True)
        temp_path = dest_path.with_suffix('.tmp')
        
        # Get file info
        file_info = self.get_file_info(url)
        total_size = file_info['size']
        supports_resume = file_info['supports_resume']
        
        # Check if partial download exists
        start_pos = 0
        if temp_path.exists() and supports_resume:
            start_pos = temp_path.stat().st_size
            self.log(f"Resuming download from {self.format_size(start_pos)}")
        
        # Update status
        self.status['downloads'][file_id].update({
            'total_size': total_size,
            'downloaded_size': start_pos,
            'status': 'downloading',
            'start_time': datetime.now().isoformat()
        })
        self.save_status()
        
        # Prepare request
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'PrepperApp/1.0')
        if start_pos > 0:
            req.add_header('Range', f'bytes={start_pos}-')
        
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                mode = 'ab' if start_pos > 0 else 'wb'
                
                with open(temp_path, mode) as f:
                    downloaded = start_pos
                    last_update = time.time()
                    last_downloaded = downloaded
                    
                    while True:
                        chunk = response.read(CHUNK_SIZE)
                        if not chunk:
                            break
                        
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Update progress every second
                        current_time = time.time()
                        if current_time - last_update >= 1.0:
                            speed = (downloaded - last_downloaded) / (current_time - last_update)
                            progress = (downloaded / total_size * 100) if total_size > 0 else 0
                            
                            self.status['downloads'][file_id].update({
                                'downloaded_size': downloaded,
                                'speed': speed,
                                'progress': progress
                            })
                            self.save_status()
                            
                            # Log progress
                            self.log(f"{file_id}: {progress:.1f}% "
                                   f"({self.format_size(downloaded)}/{self.format_size(total_size)}) "
                                   f"@ {self.format_speed(speed)}")
                            
                            last_update = current_time
                            last_downloaded = downloaded
            
            # Move temp file to final destination
            temp_path.rename(dest_path)
            
            # Update final status
            self.status['downloads'][file_id].update({
                'status': 'completed',
                'downloaded_size': total_size,
                'progress': 100,
                'end_time': datetime.now().isoformat()
            })
            self.save_status()
            
            self.log(f"✓ Completed: {file_id}")
            return True
            
        except Exception as e:
            self.log(f"✗ Error downloading {file_id}: {e}")
            self.status['downloads'][file_id]['status'] = 'failed'
            self.status['downloads'][file_id]['error'] = str(e)
            self.save_status()
            return False
    
    def download_file(self, file_info: Dict) -> bool:
        """Download a single file with retries"""
        file_id = file_info['id']
        url = file_info['url']
        category = file_info.get('category', 'other')
        filename = file_info['filename']
        
        # Determine destination path
        dest_dir = self.base_dir / category
        dest_path = dest_dir / filename
        
        # Check if already downloaded
        if dest_path.exists():
            size = dest_path.stat().st_size
            expected_size = file_info.get('size_bytes', 0)
            
            if expected_size > 0 and abs(size - expected_size) < 1024 * 1024:  # Within 1MB
                self.log(f"✓ Already downloaded: {file_id}")
                self.status['downloads'][file_id] = {
                    'status': 'completed',
                    'total_size': size,
                    'downloaded_size': size,
                    'progress': 100
                }
                self.save_status()
                return True
        
        # Initialize download status
        self.status['downloads'][file_id] = {
            'url': url,
            'filename': filename,
            'category': category,
            'status': 'pending',
            'attempts': 0
        }
        
        # Try downloading with retries
        for attempt in range(MAX_RETRIES):
            self.status['downloads'][file_id]['attempts'] = attempt + 1
            self.log(f"Downloading {file_id} (attempt {attempt + 1}/{MAX_RETRIES})")
            
            if self.download_with_progress(url, dest_path, file_id):
                return True
            
            if attempt < MAX_RETRIES - 1:
                wait_time = 2 ** attempt  # Exponential backoff
                self.log(f"Retrying in {wait_time} seconds...")
                time.sleep(wait_time)
        
        return False
    
    def download_all(self, download_list: List[Dict], concurrent: bool = True):
        """Download all files from the list"""
        self.log(f"Starting download of {len(download_list)} files")
        
        if concurrent and len(download_list) > 1:
            with ThreadPoolExecutor(max_workers=MAX_CONCURRENT_DOWNLOADS) as executor:
                futures = {
                    executor.submit(self.download_file, file_info): file_info 
                    for file_info in download_list
                }
                
                for future in as_completed(futures):
                    file_info = futures[future]
                    try:
                        success = future.result()
                        if not success:
                            self.log(f"Failed to download {file_info['id']}")
                    except Exception as e:
                        self.log(f"Exception downloading {file_info['id']}: {e}")
        else:
            for file_info in download_list:
                self.download_file(file_info)
    
    def get_summary(self) -> Dict:
        """Get download summary statistics"""
        total_files = len(self.status['downloads'])
        completed = sum(1 for d in self.status['downloads'].values() if d.get('status') == 'completed')
        failed = sum(1 for d in self.status['downloads'].values() if d.get('status') == 'failed')
        in_progress = sum(1 for d in self.status['downloads'].values() if d.get('status') == 'downloading')
        pending = total_files - completed - failed - in_progress
        
        total_size = sum(d.get('total_size', 0) for d in self.status['downloads'].values())
        downloaded_size = sum(d.get('downloaded_size', 0) for d in self.status['downloads'].values())
        
        return {
            'total_files': total_files,
            'completed': completed,
            'failed': failed,
            'in_progress': in_progress,
            'pending': pending,
            'total_size': total_size,
            'downloaded_size': downloaded_size,
            'overall_progress': (downloaded_size / total_size * 100) if total_size > 0 else 0
        }
    
    def print_status(self):
        """Print current download status"""
        summary = self.get_summary()
        
        print("\n" + "="*60)
        print("PrepperApp Content Download Status")
        print("="*60)
        print(f"Total Files: {summary['total_files']}")
        print(f"Completed: {summary['completed']} ✓")
        print(f"Failed: {summary['failed']} ✗")
        print(f"In Progress: {summary['in_progress']} ⟳")
        print(f"Pending: {summary['pending']} ⏸")
        print(f"\nTotal Size: {self.format_size(summary['total_size'])}")
        print(f"Downloaded: {self.format_size(summary['downloaded_size'])}")
        print(f"Overall Progress: {summary['overall_progress']:.1f}%")
        print("="*60)
        
        # Show current downloads
        if summary['in_progress'] > 0:
            print("\nActive Downloads:")
            for file_id, info in self.status['downloads'].items():
                if info.get('status') == 'downloading':
                    progress = info.get('progress', 0)
                    speed = info.get('speed', 0)
                    print(f"  {file_id}: {progress:.1f}% @ {self.format_speed(speed)}")
        
        # Show failed downloads
        if summary['failed'] > 0:
            print("\nFailed Downloads:")
            for file_id, info in self.status['downloads'].items():
                if info.get('status') == 'failed':
                    error = info.get('error', 'Unknown error')
                    print(f"  {file_id}: {error}")


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='PrepperApp Content Download Manager')
    parser.add_argument('--base-dir', help='Base directory for downloads')
    parser.add_argument('--status', action='store_true', help='Show download status')
    parser.add_argument('--list', help='JSON file with download list')
    parser.add_argument('--sequential', action='store_true', help='Download files sequentially')
    
    args = parser.parse_args()
    
    # Initialize manager
    manager = DownloadManager(args.base_dir)
    
    if args.status:
        manager.print_status()
    elif args.list:
        # Load download list
        with open(args.list, 'r') as f:
            data = json.load(f)
            # Handle both list format and object with 'downloads' key
            if isinstance(data, dict) and 'downloads' in data:
                download_list = data['downloads']
            else:
                download_list = data
        
        # Start downloads
        manager.download_all(download_list, concurrent=not args.sequential)
        manager.print_status()
    else:
        parser.print_help()


if __name__ == "__main__":
    main()