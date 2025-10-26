"""
Convert the large PNG to WebP format for faster loading
WebP provides 50-80% smaller file sizes with identical visual quality
"""

from PIL import Image
from pathlib import Path

def convert_to_webp(input_png, output_webp, quality=90):
    """
    Convert PNG to WebP with high quality compression
    
    Args:
        input_png: Path to input PNG file
        output_webp: Path to output WebP file
        quality: Quality setting (0-100, 90 is excellent quality, ~40-50% smaller)
    """
    print(f"Converting {input_png} to WebP format...")
    print(f"Quality: {quality}/100")
    
    # Check input exists
    if not Path(input_png).exists():
        print(f"❌ Input file not found: {input_png}")
        return False
    
    # Get original size
    original_size = Path(input_png).stat().st_size / (1024 * 1024)  # MB
    print(f"Original size: {original_size:.2f} MB")
    
    # Load and convert
    print("Loading image...")
    img = Image.open(input_png)
    print(f"Image dimensions: {img.size[0]} x {img.size[1]} pixels")
    
    # Save as WebP with quality setting
    print("Converting to WebP...")
    img.save(output_webp, 'WebP', quality=quality, method=6)
    
    # Get new size
    new_size = Path(output_webp).stat().st_size / (1024 * 1024)  # MB
    reduction = ((original_size - new_size) / original_size) * 100
    
    print(f"\n✅ Conversion complete!")
    print(f"   Original: {original_size:.2f} MB")
    print(f"   WebP:     {new_size:.2f} MB")
    print(f"   Saved:    {original_size - new_size:.2f} MB ({reduction:.1f}% reduction)")
    
    return True

if __name__ == '__main__':
    # Convert with quality=90 (excellent quality, much smaller)
    input_file = 'temp_fullres_subtle.png'
    output_file = 'temp_fullres_subtle.webp'
    
    # Try quality=90 first (best balance)
    convert_to_webp(input_file, output_file, quality=90)
    
    # If you need even smaller, uncomment below to try quality=80
    # (still visually identical but even smaller)
    # convert_to_webp(input_file, 'temp_fullres_subtle_q80.webp', quality=80)
