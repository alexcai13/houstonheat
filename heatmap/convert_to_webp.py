

from PIL import Image
from pathlib import Path

def convert_to_webp(input_png, output_webp, quality=90):

    original_size = Path(input_png).stat().st_size / (1024 * 1024)  
    
    img = Image.open(input_png)
    img.save(output_webp, 'WebP', quality=quality, method=6)
    
    new_size = Path(output_webp).stat().st_size / (1024 * 1024)  
    reduction = ((original_size - new_size) / original_size) * 100

    return True

if __name__ == '__main__':
    input_file = 'temp_fullres_subtle.png'
    output_file = 'temp_fullres_subtle.webp'
    convert_to_webp(input_file, output_file, quality=90)
    

