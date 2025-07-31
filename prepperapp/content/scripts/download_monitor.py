#!/usr/bin/env python3
"""
PrepperApp Download Monitor
Real-time monitoring of download progress with dashboard view
"""

import os
import sys
import json
import time
import curses
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional

REFRESH_INTERVAL = 1  # seconds

class DownloadMonitor:
    def __init__(self, status_file: str = None):
        base_dir = Path(os.environ.get('PREPPER_EXTERNAL_CONTENT', '.'))
        self.status_file = Path(status_file or base_dir / "download_status.json")
        self.screen = None
        
    def load_status(self) -> Dict:
        """Load current download status"""
        try:
            if self.status_file.exists():
                with open(self.status_file, 'r') as f:
                    return json.load(f)
        except:
            pass
        return {"downloads": {}}
    
    def format_size(self, size_bytes: int) -> str:
        """Format bytes to human readable size"""
        if size_bytes == 0:
            return "0 B"
        
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} PB"
    
    def format_speed(self, bytes_per_second: float) -> str:
        """Format download speed"""
        return f"{self.format_size(bytes_per_second)}/s"
    
    def format_time(self, seconds: float) -> str:
        """Format time duration"""
        if seconds < 60:
            return f"{int(seconds)}s"
        elif seconds < 3600:
            return f"{int(seconds/60)}m {int(seconds%60)}s"
        else:
            hours = int(seconds / 3600)
            minutes = int((seconds % 3600) / 60)
            return f"{hours}h {minutes}m"
    
    def calculate_eta(self, downloaded: int, total: int, speed: float) -> str:
        """Calculate estimated time of arrival"""
        if speed <= 0 or total <= 0 or downloaded >= total:
            return "N/A"
        
        remaining = total - downloaded
        eta_seconds = remaining / speed
        return self.format_time(eta_seconds)
    
    def get_category_stats(self, status: Dict) -> Dict[str, Dict]:
        """Get statistics by category"""
        categories = {}
        
        for file_id, info in status.get('downloads', {}).items():
            category = info.get('category', 'other')
            if category not in categories:
                categories[category] = {
                    'total': 0,
                    'completed': 0,
                    'failed': 0,
                    'downloading': 0,
                    'pending': 0,
                    'total_size': 0,
                    'downloaded_size': 0
                }
            
            categories[category]['total'] += 1
            categories[category]['total_size'] += info.get('total_size', 0)
            categories[category]['downloaded_size'] += info.get('downloaded_size', 0)
            
            status_val = info.get('status', 'pending')
            if status_val == 'completed':
                categories[category]['completed'] += 1
            elif status_val == 'failed':
                categories[category]['failed'] += 1
            elif status_val == 'downloading':
                categories[category]['downloading'] += 1
            else:
                categories[category]['pending'] += 1
        
        return categories
    
    def draw_dashboard(self, screen):
        """Draw the monitoring dashboard"""
        screen.clear()
        height, width = screen.getmaxyx()
        
        # Load current status
        status = self.load_status()
        downloads = status.get('downloads', {})
        
        # Calculate overall statistics
        total_files = len(downloads)
        completed = sum(1 for d in downloads.values() if d.get('status') == 'completed')
        failed = sum(1 for d in downloads.values() if d.get('status') == 'failed')
        downloading = sum(1 for d in downloads.values() if d.get('status') == 'downloading')
        pending = total_files - completed - failed - downloading
        
        total_size = sum(d.get('total_size', 0) for d in downloads.values())
        downloaded_size = sum(d.get('downloaded_size', 0) for d in downloads.values())
        overall_progress = (downloaded_size / total_size * 100) if total_size > 0 else 0
        
        # Header
        row = 0
        screen.addstr(row, 0, "PrepperApp Content Download Monitor", curses.A_BOLD)
        row += 1
        screen.addstr(row, 0, "=" * min(width - 1, 60))
        row += 2
        
        # Overall statistics
        screen.addstr(row, 0, "Overall Progress:", curses.A_BOLD)
        row += 1
        
        # Progress bar
        bar_width = min(width - 30, 50)
        filled = int(bar_width * overall_progress / 100)
        bar = "█" * filled + "░" * (bar_width - filled)
        screen.addstr(row, 0, f"[{bar}] {overall_progress:.1f}%")
        row += 1
        
        screen.addstr(row, 0, f"Total: {self.format_size(downloaded_size)} / {self.format_size(total_size)}")
        row += 2
        
        # File statistics
        screen.addstr(row, 0, "Files:", curses.A_BOLD)
        row += 1
        screen.addstr(row, 0, f"  Total: {total_files}")
        screen.addstr(row, 20, f"Completed: {completed} ✓", curses.color_pair(2))
        row += 1
        screen.addstr(row, 0, f"  Downloading: {downloading} ⟳", curses.color_pair(3))
        screen.addstr(row, 20, f"Failed: {failed} ✗", curses.color_pair(1))
        row += 1
        screen.addstr(row, 0, f"  Pending: {pending} ⏸")
        row += 2
        
        # Category breakdown
        screen.addstr(row, 0, "By Category:", curses.A_BOLD)
        row += 1
        
        categories = self.get_category_stats(status)
        for cat_name, cat_stats in sorted(categories.items()):
            if row >= height - 10:
                break
                
            cat_progress = (cat_stats['downloaded_size'] / cat_stats['total_size'] * 100) if cat_stats['total_size'] > 0 else 0
            screen.addstr(row, 2, f"{cat_name}:")
            screen.addstr(row, 20, f"{cat_stats['completed']}/{cat_stats['total']} files")
            screen.addstr(row, 40, f"{cat_progress:.1f}%")
            row += 1
        
        row += 1
        
        # Active downloads
        active_downloads = [(fid, info) for fid, info in downloads.items() 
                          if info.get('status') == 'downloading']
        
        if active_downloads:
            screen.addstr(row, 0, "Active Downloads:", curses.A_BOLD)
            row += 1
            
            for file_id, info in active_downloads[:5]:  # Show max 5
                if row >= height - 3:
                    break
                    
                progress = info.get('progress', 0)
                speed = info.get('speed', 0)
                downloaded = info.get('downloaded_size', 0)
                total = info.get('total_size', 0)
                eta = self.calculate_eta(downloaded, total, speed)
                
                # Progress bar for this file
                file_bar_width = min(width - 50, 30)
                file_filled = int(file_bar_width * progress / 100)
                file_bar = "█" * file_filled + "░" * (file_bar_width - file_filled)
                
                screen.addstr(row, 2, f"{file_id[:30]}:")
                row += 1
                screen.addstr(row, 4, f"[{file_bar}] {progress:.1f}%")
                screen.addstr(row, 4 + file_bar_width + 5, f"{self.format_speed(speed)}")
                screen.addstr(row, 4 + file_bar_width + 20, f"ETA: {eta}")
                row += 1
        
        # Footer
        row = height - 2
        screen.addstr(row, 0, "Press 'q' to quit, 'r' to refresh", curses.A_DIM)
        
        screen.refresh()
    
    def run(self):
        """Run the monitor"""
        try:
            # Initialize curses
            self.screen = curses.initscr()
            curses.start_color()
            curses.use_default_colors()
            
            # Define color pairs
            curses.init_pair(1, curses.COLOR_RED, -1)    # Failed
            curses.init_pair(2, curses.COLOR_GREEN, -1)  # Completed
            curses.init_pair(3, curses.COLOR_YELLOW, -1) # Downloading
            
            curses.noecho()
            curses.cbreak()
            self.screen.keypad(True)
            self.screen.nodelay(True)  # Non-blocking input
            
            last_update = 0
            while True:
                current_time = time.time()
                
                # Update display every second
                if current_time - last_update >= REFRESH_INTERVAL:
                    self.draw_dashboard(self.screen)
                    last_update = current_time
                
                # Check for user input
                key = self.screen.getch()
                if key == ord('q'):
                    break
                elif key == ord('r'):
                    self.draw_dashboard(self.screen)
                
                time.sleep(0.1)
                
        except KeyboardInterrupt:
            pass
        finally:
            # Cleanup curses
            if self.screen:
                curses.nocbreak()
                self.screen.keypad(False)
                curses.echo()
                curses.endwin()


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='PrepperApp Download Monitor')
    parser.add_argument('--status-file', help='Path to download status file')
    parser.add_argument('--simple', action='store_true', help='Simple output (no curses)')
    
    args = parser.parse_args()
    
    if args.simple:
        # Simple mode - just print status once
        base_dir = Path(os.environ.get('PREPPER_EXTERNAL_CONTENT', '.'))
        status_file = Path(args.status_file or base_dir / "download_status.json")
        
        if status_file.exists():
            with open(status_file, 'r') as f:
                status = json.load(f)
            
            downloads = status.get('downloads', {})
            total = len(downloads)
            completed = sum(1 for d in downloads.values() if d.get('status') == 'completed')
            failed = sum(1 for d in downloads.values() if d.get('status') == 'failed')
            downloading = sum(1 for d in downloads.values() if d.get('status') == 'downloading')
            
            print(f"Total: {total} | Completed: {completed} | Failed: {failed} | Downloading: {downloading}")
        else:
            print("No download status found")
    else:
        # Full monitoring mode
        monitor = DownloadMonitor(args.status_file)
        monitor.run()


if __name__ == "__main__":
    main()