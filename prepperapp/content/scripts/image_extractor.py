#!/usr/bin/env python3
"""
Image extraction module for PrepperApp PDF processing
Handles image extraction, compression, and WebP conversion
"""

import logging
import os
from pathlib import Path
from typing import List, Dict, Optional, Tuple
import fitz  # PyMuPDF - alternative to pdf2image
from PIL import Image
import io

logger = logging.getLogger(__name__)


class ImageExtractor:
    """Extract and process images from PDFs"""
    
    def __init__(self, pdf_path: Path, output_dir: Path):
        self.pdf_path = pdf_path
        self.images_dir = output_dir / "images" / pdf_path.stem
        self.images_dir.mkdir(parents=True, exist_ok=True)
        
    def extract_images_pymupdf(self) -> List[Dict]:
        """Extract images using PyMuPDF (doesn't require poppler)"""
        logger.info("Extracting images using PyMuPDF...")
        extracted_images = []
        
        try:
            pdf_document = fitz.open(self.pdf_path)
            
            for page_num in range(len(pdf_document)):
                page = pdf_document[page_num]
                image_list = page.get_images()
                
                if not image_list:
                    continue
                    
                logger.info(f"Found {len(image_list)} images on page {page_num + 1}")
                
                for img_index, img in enumerate(image_list):
                    # Extract image
                    xref = img[0]
                    pix = fitz.Pixmap(pdf_document, xref)
                    
                    # Convert to PIL Image
                    if pix.n - pix.alpha < 4:  # GRAY or RGB
                        img_data = pix.tobytes("png")
                    else:  # CMYK
                        pix1 = fitz.Pixmap(fitz.csRGB, pix)
                        img_data = pix1.tobytes("png")
                        pix1 = None
                    
                    # Open with PIL
                    image = Image.open(io.BytesIO(img_data))
                    
                    # Skip tiny images (likely decorative)
                    if image.width < 100 or image.height < 100:
                        continue
                    
                    # Generate filenames
                    base_name = f"page{page_num+1}_img{img_index+1}"
                    
                    # Save in multiple formats and sizes
                    image_info = self._save_image_variants(image, base_name, page_num + 1)
                    if image_info:
                        extracted_images.append(image_info)
                    
                    pix = None
                    
            pdf_document.close()
            
        except Exception as e:
            logger.error(f"PyMuPDF extraction failed: {e}")
            
        return extracted_images
    
    def _save_image_variants(self, image: Image.Image, base_name: str, page_num: int) -> Optional[Dict]:
        """Save image in multiple sizes and formats"""
        try:
            # Original size (max 1600px)
            full_image = self._resize_image(image, 1600)
            
            # Mobile size (max 800px)
            mobile_image = self._resize_image(image, 800)
            
            # Thumbnail (max 150px)
            thumb_image = self._resize_image(image, 150)
            
            # Save WebP versions
            webp_path = self.images_dir / f"{base_name}.webp"
            mobile_webp_path = self.images_dir / f"{base_name}_mobile.webp"
            thumb_webp_path = self.images_dir / f"{base_name}_thumb.webp"
            
            full_image.save(webp_path, "WEBP", quality=85, method=6)
            mobile_image.save(mobile_webp_path, "WEBP", quality=80, method=6)
            thumb_image.save(thumb_webp_path, "WEBP", quality=70, method=6)
            
            # Also save PNG for compatibility
            png_path = self.images_dir / f"{base_name}.png"
            full_image.save(png_path, "PNG", optimize=True)
            
            logger.info(f"Saved {base_name} in multiple formats")
            
            return {
                "filename": webp_path.name,
                "mobile_filename": mobile_webp_path.name,
                "thumb_filename": thumb_webp_path.name,
                "png_filename": png_path.name,
                "page": page_num,
                "width": image.width,
                "height": image.height,
                "size_kb": os.path.getsize(webp_path) // 1024
            }
            
        except Exception as e:
            logger.error(f"Failed to save image variants: {e}")
            return None
    
    def _resize_image(self, image: Image.Image, max_size: int) -> Image.Image:
        """Resize image maintaining aspect ratio"""
        if image.width <= max_size and image.height <= max_size:
            return image.copy()
            
        # Calculate new size
        ratio = min(max_size / image.width, max_size / image.height)
        new_size = (int(image.width * ratio), int(image.height * ratio))
        
        # Use high-quality resampling
        return image.resize(new_size, Image.Resampling.LANCZOS)
    
    def analyze_image_content(self, image_path: Path) -> Dict:
        """Basic image analysis for content type detection"""
        # This is a placeholder for more sophisticated analysis
        # In production, could use computer vision to detect:
        # - Diagrams vs photos
        # - Plant identification images
        # - Medical procedure illustrations
        # - Charts and graphs
        
        return {
            "type": "unknown",
            "has_text": False,  # Could use OCR here
            "is_diagram": False,
            "is_photo": True
        }
    
    def extract_page_screenshots(self, pages: List[int] = None) -> List[Dict]:
        """Extract full page screenshots for specific pages"""
        logger.info("Extracting page screenshots...")
        screenshots = []
        
        try:
            pdf_document = fitz.open(self.pdf_path)
            
            if pages is None:
                # Default to first 5 pages for testing
                pages = list(range(min(5, len(pdf_document))))
            
            for page_num in pages:
                if page_num >= len(pdf_document):
                    continue
                    
                page = pdf_document[page_num]
                
                # Render page to image
                mat = fitz.Matrix(2, 2)  # 2x zoom for clarity
                pix = page.get_pixmap(matrix=mat)
                img_data = pix.tobytes("png")
                
                # Convert to PIL
                image = Image.open(io.BytesIO(img_data))
                
                # Save variants
                base_name = f"page{page_num+1}_full"
                image_info = self._save_image_variants(image, base_name, page_num + 1)
                
                if image_info:
                    image_info["is_screenshot"] = True
                    screenshots.append(image_info)
                
            pdf_document.close()
            
        except Exception as e:
            logger.error(f"Page screenshot extraction failed: {e}")
            
        return screenshots


def main():
    """Test image extraction"""
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python image_extractor.py <pdf_file> [output_dir]")
        sys.exit(1)
    
    pdf_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "./extracted")
    
    if not pdf_path.exists():
        logger.error(f"PDF not found: {pdf_path}")
        sys.exit(1)
    
    extractor = ImageExtractor(pdf_path, output_dir)
    
    # Extract embedded images
    images = extractor.extract_images_pymupdf()
    print(f"\nExtracted {len(images)} embedded images")
    
    # Extract page screenshots
    screenshots = extractor.extract_page_screenshots([0, 1, 2])
    print(f"Created {len(screenshots)} page screenshots")
    
    # Summary
    print(f"\nImages saved to: {extractor.images_dir}")
    total_size = sum(img.get("size_kb", 0) for img in images + screenshots)
    print(f"Total size: {total_size / 1024:.1f} MB")


if __name__ == "__main__":
    main()