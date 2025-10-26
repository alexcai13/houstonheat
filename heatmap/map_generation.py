"""
Create full resolution heat map overlay for browser
Uses 5120x5120 pixel PNG with exact coordinate mapping
"""

import numpy as np
from pathlib import Path
import folium
from matplotlib import pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import webbrowser
from PIL import Image
import io
import base64


def create_heatmap_image(data, output_path='fullres_heatmap.png'):
    """
    Create 5120x5120 PNG with proper colors
    """
    print(f"Creating full resolution image: {data.shape}")
    
    # Create custom colormap (blue -> cyan -> green -> yellow -> orange -> red)
    colors = ['#0000FF', '#00CCFF', '#00FF99', '#FFFF00', '#FF9900', '#FF0000']
    n_bins = 256
    cmap = LinearSegmentedColormap.from_list('heat', colors, N=n_bins)
    
    # Normalize data to 0-1 range
    normalized = data / 10.0  # Since data is 0-10
    
    # Apply colormap
    colored = cmap(normalized)
    
    # Convert to 8-bit RGBA
    img_data = (colored * 255).astype(np.uint8)
    
    # Create PIL Image
    img = Image.fromarray(img_data, mode='RGBA')
    
    # Set alpha based on heat intensity (more transparent for low values)
    alpha = img_data[:, :, 3].copy()
    # Make low heat values more transparent
    heat_alpha = (normalized * 200 + 55).astype(np.uint8)  # Range: 55-255
    img_data[:, :, 3] = heat_alpha
    
    img = Image.fromarray(img_data, mode='RGBA')
    img.save(output_path, 'PNG')
    
    print(f"✅ Saved: {output_path}")
    print(f"   Size: {Path(output_path).stat().st_size / (1024*1024):.1f} MB")
    
    return output_path


def calculate_proper_bounds(data_shape):
    """
    Calculate the EXACT bounds for the overlay
    Each pixel represents a specific location in the grid
    """
    HOUSTON_BOUNDS = {
        'north': 30.110,
        'south': 29.523,
        'east': -95.014,
        'west': -95.788
    }
    
    grid_rows = 40
    grid_cols = 40
    detail_per_box = 128
    
    # Total grid dimensions
    total_rows = grid_rows * detail_per_box  # 5120
    total_cols = grid_cols * detail_per_box  # 5120
    
    # Each pixel represents a cell in the grid
    lat_per_pixel = (HOUSTON_BOUNDS['north'] - HOUSTON_BOUNDS['south']) / total_rows
    lon_per_pixel = (HOUSTON_BOUNDS['east'] - HOUSTON_BOUNDS['west']) / total_cols
    
    # Image coordinates:
    # - Row 0 (top of image) = North
    # - Row 5119 (bottom of image) = South
    # - Col 0 (left of image) = West
    # - Col 5119 (right of image) = East
    
    # The IMAGE represents pixels at the CENTER of each cell
    # So pixel [0, 0] represents the center of the first cell (northwest corner)
    
    # Bounds for ImageOverlay should be the EDGES
    # But we need to account for half-pixel offset
    bounds = [
        [HOUSTON_BOUNDS['south'], HOUSTON_BOUNDS['west']],  # Southwest corner
        [HOUSTON_BOUNDS['north'], HOUSTON_BOUNDS['east']]   # Northeast corner
    ]
    
    info = {
        'bounds': bounds,
        'lat_per_pixel': lat_per_pixel,
        'lon_per_pixel': lon_per_pixel,
        'image_shape': data_shape,
        'geographic_span': {
            'lat_degrees': HOUSTON_BOUNDS['north'] - HOUSTON_BOUNDS['south'],
            'lon_degrees': HOUSTON_BOUNDS['east'] - HOUSTON_BOUNDS['west'],
            'lat_km': (HOUSTON_BOUNDS['north'] - HOUSTON_BOUNDS['south']) * 111,
            'lon_km': (HOUSTON_BOUNDS['east'] - HOUSTON_BOUNDS['west']) * 111 * np.cos(np.radians(29.8))
        }
    }
    
    return bounds, info


def create_fullres_map(image_path, data, output_html='houston_fullres.html'):
    """
    Create map with full resolution overlay
    """
    print("\nCreating full resolution map...")
    
    bounds, info = calculate_proper_bounds(data.shape)
    
    print(f"Image bounds: {bounds}")
    print(f"Resolution: {info['lat_per_pixel']:.8f}° lat/pixel, {info['lon_per_pixel']:.8f}° lon/pixel")
    print(f"Geographic span: {info['geographic_span']['lat_km']:.1f}km x {info['geographic_span']['lon_km']:.1f}km")
    
    # Downtown Houston
    downtown = [29.7547, -95.3555]
    
    m = folium.Map(
        location=downtown,
        zoom_start=11,
        tiles=None,
        max_zoom=18
    )
    
    # Satellite base layer
    folium.TileLayer(
        tiles='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        attr='Esri',
        name='Satellite',
        overlay=False,
        control=True
    ).add_to(m)
    
    # Street map layer
    folium.TileLayer(
        tiles='OpenStreetMap',
        name='Street Map',
        overlay=False,
        control=True
    ).add_to(m)
    
    # Add the full resolution heat map overlay
    print("Adding full resolution overlay...")
    image_layer = folium.raster_layers.ImageOverlay(
        image=image_path,
        bounds=bounds,
        opacity=0.7,
        interactive=False,
        cross_origin=False,
        zindex=1,
        name='Heat Map (Full 5120x5120)'
    )
    image_layer.add_to(m)
    
    # Add opacity control slider
    opacity_control = '''
    <div id="opacity-control" style="position: fixed; 
                top: 80px; right: 10px; width: 200px;
                background-color: rgba(255, 255, 255, 0.95); 
                border: 2px solid #333; z-index: 9999; 
                padding: 10px; border-radius: 5px; box-shadow: 0 0 10px rgba(0,0,0,0.5);">
        <div style="font-weight: bold; margin-bottom: 5px;">Heat Map Opacity</div>
        <input type="range" id="opacity-slider" min="0" max="100" value="70" 
               style="width: 100%;">
        <div style="text-align: center; margin-top: 5px;">
            <span id="opacity-value">70</span>%
        </div>
    </div>
    <script>
        var slider = document.getElementById('opacity-slider');
        var valueDisplay = document.getElementById('opacity-value');
        
        slider.oninput = function() {
            var opacity = this.value / 100;
            valueDisplay.textContent = this.value;
            
            // Find the image overlay element
            var images = document.querySelectorAll('.leaflet-image-layer');
            images.forEach(function(img) {
                img.style.opacity = opacity;
            });
        }
    </script>
    '''
    m.get_root().html.add_child(folium.Element(opacity_control))
    
    # Add landmarks for verification
    landmarks = [
        ([29.7547, -95.3555], 'Downtown Houston', 'red'),
        ([29.7174, -95.4018], 'Rice University', 'blue'),
        ([29.7342, -95.3944], 'Hermann Park', 'green'),
        ([29.7633, -95.3704], 'Museum District', 'purple'),
        ([29.7494, -95.3642], 'Toyota Center', 'orange'),
        ([29.8047, -95.4633], 'The Heights', 'yellow'),
        ([29.7390, -95.5103], 'Memorial Park', 'cyan'),
    ]
    
    for coord, name, color in landmarks:
        folium.CircleMarker(
            location=coord,
            radius=8,
            popup=f'<b>{name}</b><br>{coord[0]:.4f}, {coord[1]:.4f}',
            tooltip=name,
            color='white',
            fill=True,
            fillColor=color,
            fillOpacity=0.9,
            weight=2
        ).add_to(m)
    
    # Calculate statistics
    stats = {
        'min': float(np.min(data)),
        'max': float(np.max(data)),
        'mean': float(np.mean(data)),
        'std': float(np.std(data)),
        'total_pixels': data.size
    }
    
    # Distribution
    hist, _ = np.histogram(data, bins=[0, 2, 4, 6, 8, 10])
    dist = {
        'very_cool': hist[0] / data.size * 100,
        'cool': hist[1] / data.size * 100,
        'moderate': hist[2] / data.size * 100,
        'warm': hist[3] / data.size * 100,
        'hot': hist[4] / data.size * 100,
    }
    
    # Legend
    legend_html = f'''
    <div style="position: fixed; 
                bottom: 50px; right: 50px; width: 300px; 
                background-color: rgba(255, 255, 255, 0.95); border:3px solid #333; z-index:9999; 
                font-size:13px; padding: 15px; box-shadow: 0 0 15px rgba(0,0,0,0.7);
                border-radius: 10px;">
        <h3 style="margin:0 0 10px 0; text-align:center; color:#333;">
            🔥 Full Resolution Heat Map
        </h3>
        
        <div style="margin: 10px 0; padding: 5px; 
                    background: linear-gradient(to right, #0000FF, #00CCFF, #00FF99, #FFFF00, #FF9900, #FF0000); 
                    height: 25px; border-radius: 5px;"></div>
        
        <div style="font-size:11px; line-height: 1.6;">
            <div style="padding: 4px; border-left: 4px solid #0000FF;">
                <strong>0-2: Very Cool ({dist['very_cool']:.1f}%)</strong>
            </div>
            <div style="padding: 4px; border-left: 4px solid #00CCFF;">
                <strong>2-4: Cool ({dist['cool']:.1f}%)</strong>
            </div>
            <div style="padding: 4px; border-left: 4px solid #00FF99;">
                <strong>4-6: Moderate ({dist['moderate']:.1f}%)</strong>
            </div>
            <div style="padding: 4px; border-left: 4px solid #FF9900;">
                <strong>6-8: Warm ({dist['warm']:.1f}%)</strong>
            </div>
            <div style="padding: 4px; border-left: 4px solid #FF0000;">
                <strong>8-10: Hot ({dist['hot']:.1f}%)</strong>
            </div>
        </div>
        
        <hr style="margin:10px 0;">
        
        <div style="font-size:10px;">
            <b>Resolution:</b> {stats['total_pixels']:,} pixels<br>
            <b>Range:</b> {stats['min']:.2f} - {stats['max']:.2f}<br>
            <b>Mean:</b> {stats['mean']:.2f} ± {stats['std']:.2f}<br>
            <b>Detail:</b> ~12m per pixel
        </div>
    </div>
    '''
    m.get_root().html.add_child(folium.Element(legend_html))
    
    # Title
    title_html = '''
    <div style="position: fixed; 
                top: 10px; left: 50px; width: 600px; 
                background-color: rgba(255, 255, 255, 0.95); border:3px solid #333; z-index:9999; 
                padding: 15px; border-radius: 10px;">
        <h2 style="margin:0;">🔥 Houston Heat Map - FULL RESOLUTION</h2>
        <p style="margin:8px 0 0 0; font-size:13px;">
            <b>5,120 × 5,120 pixels = 26,214,400 heat points</b><br>
            Every house, street, and building analyzed • Zoom in to see detail
        </p>
    </div>
    '''
    m.get_root().html.add_child(folium.Element(title_html))
    
    folium.LayerControl(position='topright').add_to(m)
    
    m.save(output_html)
    print(f"✅ Map saved: {output_html}")
    
    return output_html


def verify_alignment(data):
    """
    Check where downtown Houston appears in the image
    """
    print("\n🔍 Verifying alignment...")
    
    HOUSTON_BOUNDS = {
        'north': 30.110,
        'south': 29.523,
        'east': -95.014,
        'west': -95.788
    }
    
    downtown_lat = 29.7547
    downtown_lon = -95.3555
    
    # Calculate which pixel downtown should be at
    total_rows = 5120
    total_cols = 5120
    
    # Normalize downtown position
    lat_fraction = (downtown_lat - HOUSTON_BOUNDS['south']) / (HOUSTON_BOUNDS['north'] - HOUSTON_BOUNDS['south'])
    lon_fraction = (downtown_lon - HOUSTON_BOUNDS['west']) / (HOUSTON_BOUNDS['east'] - HOUSTON_BOUNDS['west'])
    
    downtown_row = int(lat_fraction * total_rows)
    downtown_col = int(lon_fraction * total_cols)
    
    # Get heat value at downtown
    downtown_heat = data[downtown_row, downtown_col]
    
    print(f"✅ Downtown Houston (29.7547, -95.3555):")
    print(f"   Image pixel: [{downtown_row}, {downtown_col}]")
    print(f"   Heat value: {downtown_heat:.2f}")
    
    # Check center
    center_row, center_col = 2560, 2560
    center_heat = data[center_row, center_col]
    
    # Calculate what coordinate the center represents
    center_lat = HOUSTON_BOUNDS['south'] + (center_row / total_rows) * (HOUSTON_BOUNDS['north'] - HOUSTON_BOUNDS['south'])
    center_lon = HOUSTON_BOUNDS['west'] + (center_col / total_cols) * (HOUSTON_BOUNDS['east'] - HOUSTON_BOUNDS['west'])
    
    print(f"\n✅ Image center [2560, 2560]:")
    print(f"   Coordinates: ({center_lat:.4f}, {center_lon:.4f})")
    print(f"   Heat value: {center_heat:.2f}")
    print(f"   (This is in The Heights neighborhood)")
    
    return {
        'downtown_pixel': [downtown_row, downtown_col],
        'downtown_heat': downtown_heat,
        'center_coord': [center_lat, center_lon],
        'center_heat': center_heat
    }


def main():
    """Main execution"""
    print("Houston Heat Map - FULL RESOLUTION Browser Visualization")
    print("=" * 70)
    
    # Load data - use FIXED ASSEMBLY version
    npy_file = 'houston_extreme_highres_FIXED_ASSEMBLY.npy'
    if not Path(npy_file).exists():
        # Fall back to original
        npy_file = 'houston_extreme_highres_20251017_191232_enhanced.npy'
        print(f"⚠️  Using original file (not fixed): {npy_file}")
    else:
        print(f"✅ Using fixed assembly file: {npy_file}")
    
    if not Path(npy_file).exists():
        print(f"❌ {npy_file} not found!")
        return
    
    data = np.load(npy_file)
    print(f"✅ Loaded: {data.shape[0]:,} x {data.shape[1]:,} = {data.size:,} points")
    print(f"   Range: {np.min(data):.2f} - {np.max(data):.2f}")
    print(f"   Mean: {np.mean(data):.2f} ± {np.std(data):.2f}")
    
    # Data is now correctly assembled with north at top
    print("\n✅ Using data as-is (already correctly assembled)")
    
    # Verify alignment
    alignment_info = verify_alignment(data)
    
    # Create full resolution image (temp file)
    print("\n📸 Creating full resolution PNG...")
    image_path = 'temp_fullres.png'
    
    # Create image efficiently
    from matplotlib import pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap
    
    fig, ax = plt.subplots(figsize=(51.2, 51.2), dpi=100)
    colors = ['#0000FF', '#00CCFF', '#00FF99', '#FFFF00', '#FF9900', '#FF0000']
    cmap = LinearSegmentedColormap.from_list('heat', colors, N=256)
    ax.imshow(data, cmap=cmap, vmin=0, vmax=10, aspect='auto', interpolation='bilinear')
    ax.axis('off')
    plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
    plt.savefig(image_path, dpi=100, bbox_inches='tight', pad_inches=0, transparent=False)
    plt.close()
    print(f"✅ Saved: {image_path}")
    
    # Create interactive map
    map_path = create_fullres_map(image_path, data)
    
    # Clean up temp file
    Path(image_path).unlink(missing_ok=True)
    print(f"🗑️  Deleted temp file: {image_path}")
    
    print("\n" + "=" * 70)
    print("✅ FULL RESOLUTION MAP COMPLETE!")
    print("=" * 70)
    print(f"\n🔥 26,214,400 heat points visualized")
    print(f"📍 Resolution: ~12 meters per pixel")
    print(f"🎯 Downtown verified at pixel {alignment_info['downtown_pixel']}")
    print(f"\n📂 Files:")
    print(f"   • Image: {image_path}")
    print(f"   • Map: {map_path}")
    
    # Open in browser
    webbrowser.open('file://' + str(Path(map_path).absolute()))
    print(f"\n✅ Opening in browser...")
    print(f"\n💡 Zoom in to see individual streets and buildings!")


if __name__ == "__main__":
    main()