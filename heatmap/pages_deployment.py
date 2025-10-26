"""
High-Resolution Houston Heat Map Generator
Creates incredibly detailed heat maps by combining fine-grained analysis
of each grid box into a massive unified heatmap.
"""

import numpy as np
import requests
import io
from PIL import Image
import json
from pathlib import Path
from typing import Dict, List, Tuple
import time
from datetime import datetime
from tqdm import tqdm
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import cv2

from classifier import HeatConcentrationClassifier


class HighResHoustonHeatMap:
    """
    Generate ultra-high-resolution heat map for Houston
    Each box is analyzed at fine detail (e.g., 64x64 pixels)
    All boxes are stitched together for incredible detail
    """
    
    # Houston bounding box - EXPANDED to Greater Houston Metro
    # Includes: Conroe (north), Galveston (south), Baytown (east), Brookshire (west)
    HOUSTON_BOUNDS = {
        'north': 30.36134,   # Conroe area
        'south': 29.25864,   # Galveston area
        'east': -94.73233,   # Baytown area
        'west': -96.00813    # Brookshire area
    }
    
    def __init__(self, grid_rows: int = 40, grid_cols: int = 40,
                 detail_grid_size: int = 64,  # Higher = more detail per box
                 images_path: str = "Images", 
                 cache_dir: str = "houston_cache"):
        """
        Initialize high-resolution heat map generator
        
        Args:
            grid_rows: Number of rows in Houston grid
            grid_cols: Number of columns in Houston grid
            detail_grid_size: Internal grid resolution per box (64x64 = 4096 cells per box!)
            images_path: Path to training images
            cache_dir: Cache directory
        """
        self.grid_rows = grid_rows
        self.grid_cols = grid_cols
        self.detail_grid_size = detail_grid_size
        self.total_boxes = grid_rows * grid_cols
        
        # Total resolution will be grid_rows * detail_grid_size x grid_cols * detail_grid_size
        self.total_resolution = (grid_rows * detail_grid_size, grid_cols * detail_grid_size)
        
        # Initialize classifier with high detail
        self.classifier = HeatConcentrationClassifier(images_path, grid_size=detail_grid_size)
        
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
        
        self.api_key = "***REMOVED***"
        
        # Create grid
        self.grid_boxes = self._create_grid()
        
        print(f"High-Resolution Houston Heat Map Generator")
        print(f"=" * 70)
        print(f"Grid configuration: {grid_rows}x{grid_cols} boxes")
        print(f"Detail per box: {detail_grid_size}x{detail_grid_size} cells")
        print(f"Total resolution: {self.total_resolution[0]}x{self.total_resolution[1]} pixels")
        print(f"  → That's {self.total_resolution[0] * self.total_resolution[1]:,} individual heat points!")
        print(f"Coverage: {self.HOUSTON_BOUNDS}")
        print(f"=" * 70)
    
    def _create_grid(self) -> List[Dict]:
        """Create grid of bounding boxes"""
        lat_step = (self.HOUSTON_BOUNDS['north'] - self.HOUSTON_BOUNDS['south']) / self.grid_rows
        lon_step = (self.HOUSTON_BOUNDS['east'] - self.HOUSTON_BOUNDS['west']) / self.grid_cols
        
        boxes = []
        for row in range(self.grid_rows):
            for col in range(self.grid_cols):
                south = self.HOUSTON_BOUNDS['south'] + (row * lat_step)
                north = south + lat_step
                west = self.HOUSTON_BOUNDS['west'] + (col * lon_step)
                east = west + lon_step
                
                center_lat = (north + south) / 2
                center_lon = (east + west) / 2
                
                boxes.append({
                    'id': f"box_{row}_{col}",
                    'row': row,
                    'col': col,
                    'bounds': {'north': north, 'south': south, 'east': east, 'west': west},
                    'center': {'lat': center_lat, 'lon': center_lon}
                })
        
        return boxes
    
    def _get_cached_image_path(self, box_id: str) -> Path:
        """Get path for cached image"""
        return self.cache_dir / f"{box_id}.jpg"
    
    def _fetch_satellite_image(self, lat: float, lon: float, box_id: str, 
                               size: int = 1280, zoom: int = 17) -> np.ndarray:
        """
        Fetch high-resolution satellite image
        
        Args:
            lat: Latitude
            lon: Longitude
            box_id: Box identifier
            size: Image size (higher = more detail, max 640 for free API)
            zoom: Zoom level (higher = more detail, 17-18 recommended)
        """
        cache_path = self._get_cached_image_path(box_id)
        if cache_path.exists():
            try:
                img = Image.open(cache_path)
                return np.array(img.convert('RGB'))
            except:
                pass
        
        try:
            # Use higher zoom for more detail
            url = "https://maps.googleapis.com/maps/api/staticmap"
            params = {
                'center': f"{lat},{lon}",
                'zoom': zoom,
                'size': '640x640',  # Max for free tier
                'maptype': 'satellite',
                'key': self.api_key,
                'scale': 2  # Get 1280x1280 image
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            image = Image.open(io.BytesIO(response.content))
            image = image.convert('RGB')
            
            # Save cache
            image.save(cache_path, 'JPEG', quality=90)
            
            return np.array(image)
            
        except Exception as e:
            print(f"\nError fetching {box_id}: {e}")
            return None
    
    def analyze_single_box(self, box: Dict) -> Dict:
        """
        Analyze single box with high detail
        
        Returns:
            Dictionary with detailed heat_map (detail_grid_size x detail_grid_size)
        """
        img_array = self._fetch_satellite_image(
            box['center']['lat'],
            box['center']['lon'],
            box['id'],
            zoom=17  # Higher zoom = more detail
        )
        
        if img_array is None:
            return None
        
        temp_path = self.cache_dir / f"temp_{box['id']}.jpg"
        Image.fromarray(img_array).save(temp_path, 'JPEG')
        
        try:
            result = self.classifier.classify_heat_concentration(str(temp_path), category=None)
            
            if result:
                return {
                    'box_id': box['id'],
                    'row': box['row'],
                    'col': box['col'],
                    'heat_map': result['heat_map'],  # This is detail_grid_size x detail_grid_size
                    'bounds': box['bounds'],
                    'center': box['center']
                }
            return None
            
        finally:
            if temp_path.exists():
                temp_path.unlink()
    
    def generate_highres_heatmap(self, output_prefix: str = "houston_highres"):
        """Generate ultra-high-resolution heat map"""
        
        print(f"\nStarting High-Resolution Heat Map Generation")
        print(f"{'='*70}")
        print(f"Total boxes: {self.total_boxes}")
        print(f"Estimated time: {self.total_boxes * 2 / 60:.1f} - {self.total_boxes * 4 / 60:.1f} minutes")
        print(f"{'='*70}\n")
        
        start_time = time.time()
        
        # Create massive heat map array
        full_heatmap = np.zeros(self.total_resolution)
        
        results = []
        failed = []
        
        # Process each box
        for box in tqdm(self.grid_boxes, desc="Analyzing Houston (high-res)", unit="box"):
            try:
                result = self.analyze_single_box(box)
                if result:
                    results.append(result)
                    
                    # Place this box's detailed heat map into the full map
                    row_start = result['row'] * self.detail_grid_size
                    row_end = row_start + self.detail_grid_size
                    col_start = result['col'] * self.detail_grid_size
                    col_end = col_start + self.detail_grid_size
                    
                    full_heatmap[row_start:row_end, col_start:col_end] = result['heat_map']
                else:
                    failed.append(box['id'])
                    
            except Exception as e:
                print(f"\nError analyzing {box['id']}: {e}")
                failed.append(box['id'])
            
            time.sleep(0.1)  # Rate limiting
        
        elapsed = time.time() - start_time
        
        print(f"\n{'='*70}")
        print(f"Analysis Complete!")
        print(f"{'='*70}")
        print(f"Successful: {len(results)}/{self.total_boxes}")
        print(f"Failed: {len(failed)}")
        print(f"Time: {elapsed/60:.1f} minutes")
        print(f"{'='*70}\n")
        
        # Export results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # 1. Save as NumPy array for later processing
        npy_path = f"{output_prefix}_{timestamp}.npy"
        np.save(npy_path, full_heatmap)
        print(f"✅ Saved NumPy array: {npy_path}")
        
        # 2. Export as ultra-high-res PNG
        png_path = f"{output_prefix}_{timestamp}.png"
        self._export_highres_png(full_heatmap, png_path)
        print(f"✅ Saved high-res PNG: {png_path}")
        
        # 3. Export downsampled version for easier viewing
        small_png_path = f"{output_prefix}_{timestamp}_preview.png"
        self._export_preview_png(full_heatmap, small_png_path)
        print(f"✅ Saved preview PNG: {small_png_path}")
        
        # 4. Export GeoJSON with bounds
        geojson_path = f"{output_prefix}_{timestamp}.geojson"
        self._export_geojson_overlay(full_heatmap, geojson_path)
        print(f"✅ Saved GeoJSON: {geojson_path}")
        
        # 5. Export metadata
        metadata = {
            'timestamp': timestamp,
            'grid_size': {'rows': self.grid_rows, 'cols': self.grid_cols},
            'detail_per_box': self.detail_grid_size,
            'total_resolution': list(self.total_resolution),
            'total_cells': int(self.total_resolution[0] * self.total_resolution[1]),
            'bounds': self.HOUSTON_BOUNDS,
            'successful_boxes': len(results),
            'failed_boxes': len(failed),
            'processing_time_minutes': elapsed / 60,
            'heat_statistics': {
                'min': float(np.min(full_heatmap)),
                'max': float(np.max(full_heatmap)),
                'mean': float(np.mean(full_heatmap)),
                'std': float(np.std(full_heatmap))
            }
        }
        
        metadata_path = f"{output_prefix}_{timestamp}_metadata.json"
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        print(f"✅ Saved metadata: {metadata_path}")
        
        print(f"\n{'='*70}")
        print(f"High-Resolution Heat Map Complete!")
        print(f"Resolution: {self.total_resolution[0]:,} x {self.total_resolution[1]:,} pixels")
        print(f"Total heat points: {self.total_resolution[0] * self.total_resolution[1]:,}")
        print(f"{'='*70}\n")
        
        return {
            'heatmap': full_heatmap,
            'metadata': metadata,
            'files': {
                'npy': npy_path,
                'png': png_path,
                'preview': small_png_path,
                'geojson': geojson_path,
                'metadata': metadata_path
            }
        }
    
    def _export_highres_png(self, heatmap: np.ndarray, output_path: str):
        """Export full resolution PNG"""
        fig, ax = plt.subplots(figsize=(32, 32), dpi=100)
        ax.axis('off')
        
        colors = ['#0066FF', '#00FFFF', '#00FF00', '#FFFF00', '#FF6600', '#FF0000']
        cmap = LinearSegmentedColormap.from_list('heat', colors, N=256)
        
        im = ax.imshow(heatmap, cmap=cmap, interpolation='bilinear', 
                      aspect='auto', vmin=0, vmax=10)
        
        cbar = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
        cbar.set_label('Heat Score', rotation=270, labelpad=20, fontsize=16)
        
        plt.tight_layout(pad=0)
        plt.savefig(output_path, dpi=150, bbox_inches='tight', pad_inches=0)
        plt.close()
    
    def _export_preview_png(self, heatmap: np.ndarray, output_path: str):
        """Export smaller preview with grid lines"""
        fig, ax = plt.subplots(figsize=(20, 20), dpi=100)
        
        colors = ['#0066FF', '#00FFFF', '#00FF00', '#FFFF00', '#FF6600', '#FF0000']
        cmap = LinearSegmentedColormap.from_list('heat', colors, N=256)
        
        im = ax.imshow(heatmap, cmap=cmap, interpolation='bilinear',
                      aspect='auto', vmin=0, vmax=10)
        
        # Add grid lines at box boundaries
        for i in range(0, self.total_resolution[0], self.detail_grid_size):
            ax.axhline(i - 0.5, color='black', linewidth=0.5, alpha=0.3)
        for j in range(0, self.total_resolution[1], self.detail_grid_size):
            ax.axvline(j - 0.5, color='black', linewidth=0.5, alpha=0.3)
        
        ax.set_title(f'Houston High-Res Heat Map\n{self.total_resolution[0]}x{self.total_resolution[1]} resolution',
                    fontsize=16, fontweight='bold')
        
        cbar = plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)
        cbar.set_label('Heat Score (0-10)', rotation=270, labelpad=25, fontsize=14)
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=150, bbox_inches='tight')
        plt.close()
    
    def _export_geojson_overlay(self, heatmap: np.ndarray, output_path: str):
        """Export as GeoJSON with image overlay reference"""
        geojson = {
            'type': 'FeatureCollection',
            'properties': {
                'name': 'Houston High-Resolution Heat Map',
                'description': 'Ultra-detailed heat map overlay',
                'resolution': list(self.total_resolution),
                'bounds': self.HOUSTON_BOUNDS
            },
            'features': [{
                'type': 'Feature',
                'geometry': {
                    'type': 'Polygon',
                    'coordinates': [[
                        [self.HOUSTON_BOUNDS['west'], self.HOUSTON_BOUNDS['south']],
                        [self.HOUSTON_BOUNDS['east'], self.HOUSTON_BOUNDS['south']],
                        [self.HOUSTON_BOUNDS['east'], self.HOUSTON_BOUNDS['north']],
                        [self.HOUSTON_BOUNDS['west'], self.HOUSTON_BOUNDS['north']],
                        [self.HOUSTON_BOUNDS['west'], self.HOUSTON_BOUNDS['south']]
                    ]]
                },
                'properties': {
                    'type': 'heatmap_overlay',
                    'resolution': list(self.total_resolution),
                    'heat_range': {
                        'min': float(np.min(heatmap)),
                        'max': float(np.max(heatmap)),
                        'mean': float(np.mean(heatmap))
                    }
                }
            }]
        }
        
        with open(output_path, 'w') as f:
            json.dump(geojson, f, indent=2)


def main():
    """Main execution"""
    print("High-Resolution Houston Heat Map Generator")
    print("=" * 70)
    
    # Create generator with 40x40 grid, but 128x128 detail per box
    # Total resolution: 5120 x 5120 = 26,214,400 heat points!
    # This matches your current image resolution
    generator = HighResHoustonHeatMap(
        grid_rows=40,
        grid_cols=40,
        detail_grid_size=128,  # Each box analyzed at 128x128 resolution (matches current data)
        images_path="Images",
        cache_dir="houston_cache"
    )
    
    # Generate
    results = generator.generate_highres_heatmap(output_prefix="houston_highres")
    
    print("Files generated:")
    for ftype, fpath in results['files'].items():
        print(f"  • {ftype}: {fpath}")


if __name__ == "__main__":
    main()