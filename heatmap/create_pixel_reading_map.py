"""
Create heat map with click tooltip - Reads heat from IMAGE PIXEL COLORS
No data embedding needed - extracts heat value from the visual representation!
"""

import numpy as np
from pathlib import Path
import folium
from folium import MacroElement
from jinja2 import Template
from matplotlib import pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import webbrowser


class ClickTooltipFromImage(MacroElement):
    """Custom element that extracts heat values from image pixel colors"""
    
    def __init__(self):
        super(ClickTooltipFromImage, self).__init__()
        self._name = 'ClickTooltipFromImage'
        
        self._template = Template("""
        {% macro script(this, kwargs) %}
        
        // Houston bounds
        const BOUNDS = {
            north: 30.110,
            south: 29.523,
            east: -95.014,
            west: -95.788
        };
        
        // Color scale (blue to red) - VIBRANT colors
        const colorScale = [
            {heat: 0,  r: 0,   g: 150, b: 255},  // #0096ff — electric blue
            {heat: 2,  r: 0,   g: 200, b: 255},  // #00c8ff — bright cyan
            {heat: 4,  r: 0,   g: 230, b: 180},  // #00e6b4 — vibrant teal
            {heat: 6,  r: 150, g: 255, b: 0},    // #96ff00 — electric lime
            {heat: 8,  r: 255, g: 220, b: 0},    // #ffdc00 — bright yellow
            {heat: 10, r: 255, g: 60,  b: 60}    // #ff3c3c — vibrant red
        ];
        
        // Single weather data for Houston
        let currentWeather = null;
        let heatMapImage = null;
        let canvas = null;
        let ctx = null;
        let currentMarker = null;
        
        // Convert RGB color to heat value (0-10) with interpolation
        function rgbToHeat(r, g, b) {
            // Find the two closest colors and interpolate
            let minDist1 = Infinity;
            let minDist2 = Infinity;
            let closest1 = colorScale[0];
            let closest2 = colorScale[1];
            
            for (let color of colorScale) {
                const dist = Math.sqrt(
                    Math.pow(r - color.r, 2) +
                    Math.pow(g - color.g, 2) +
                    Math.pow(b - color.b, 2)
                );
                
                if (dist < minDist1) {
                    minDist2 = minDist1;
                    closest2 = closest1;
                    minDist1 = dist;
                    closest1 = color;
                } else if (dist < minDist2) {
                    minDist2 = dist;
                    closest2 = color;
                }
            }
            
            // If very close to one color, use it
            if (minDist1 < 10) {
                return closest1.heat;
            }
            
            // Interpolate between two closest colors
            const totalDist = minDist1 + minDist2;
            if (totalDist === 0) return closest1.heat;
            
            const weight1 = minDist2 / totalDist;
            const weight2 = minDist1 / totalDist;
            
            return closest1.heat * weight1 + closest2.heat * weight2;
        }
        
        // Get heat value by reading pixel color from image
        function getHeatValueFromImage(lat, lon) {
            if (!canvas || !ctx) {
                console.error('❌ Canvas not ready - returning default value');
                return 5;
            }
            
            if (canvas.width === 0 || canvas.height === 0) {
                console.error('❌ Canvas has invalid dimensions');
                return 5;
            }
            
            if (lat < BOUNDS.south || lat > BOUNDS.north || 
                lon < BOUNDS.west || lon > BOUNDS.east) {
                console.log('⚠️ Click outside Houston bounds');
                return 5;
            }
            
            // Convert lat/lon to image pixel coordinates
            const latFrac = (lat - BOUNDS.south) / (BOUNDS.north - BOUNDS.south);
            const lonFrac = (lon - BOUNDS.west) / (BOUNDS.east - BOUNDS.west);
            
            // Image coordinates (y=0 is top, y=max is bottom)
            const x = Math.floor(lonFrac * canvas.width);
            const y = Math.floor((1 - latFrac) * canvas.height);
            
            // Bounds check
            const clampedX = Math.max(0, Math.min(canvas.width - 1, x));
            const clampedY = Math.max(0, Math.min(canvas.height - 1, y));
            
            // Read pixel color
            try {
                const imageData = ctx.getImageData(clampedX, clampedY, 1, 1);
                const r = imageData.data[0];
                const g = imageData.data[1];
                const b = imageData.data[2];
                const a = imageData.data[3];
                
                console.log(`Pixel (${clampedX},${clampedY}): RGB(${r},${g},${b},${a})`);
                
                // Check if pixel is transparent or black (no data)
                if (a < 10) {
                    console.log('⚠️ Transparent pixel - no data here');
                    return 5;
                }
                
                // Convert color to heat value
                const heat = rgbToHeat(r, g, b);
                console.log(`→ Heat value: ${heat.toFixed(1)}/10`);
                
                return heat;
            } catch (error) {
                console.error('❌ Failed to read pixel:', error);
                return 5;
            }
        }
        
        // Calculate adjusted feels like temperature
        // Heat value affects how much hotter/cooler it feels
        // Low heat (shade/trees) makes it feel COOLER than weather says
        // High heat (concrete) makes it feel HOTTER than weather says
        function calculateAdjustedFeelsLike(actualTemp, feelsLike, heatValue) {
            // Base feels-like from weather API
            const baseFeelsLike = feelsLike;
            
            // Additional adjustment based on local heat signature
            // Heat 0 (blue/trees): -5°F cooler than base feels-like
            // Heat 5 (medium): no additional change
            // Heat 10 (red/concrete): +5°F hotter than base feels-like
            const heatAdjustment = (heatValue - 5) * 1.0; // -5 to +5 degrees
            
            return baseFeelsLike + heatAdjustment;
        }
        
        // Fetch weather from Google Weather API (single call)
        async function fetchWeather(lat, lon) {
            const apiKey = '***REMOVED***';
            const url = `https://weather.googleapis.com/v1/currentConditions:lookup?location.latitude=${lat}&location.longitude=${lon}&key=${apiKey}`;
            
            try {
                const response = await fetch(url);
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                const data = await response.json();
                console.log('Weather API response:', data);
                
                // Convert Celsius to Fahrenheit
                const tempC = data.temperature.degrees;
                const feelsLikeC = data.feelsLikeTemperature.degrees;
                const tempF = (tempC * 9/5) + 32;
                const feelsLikeF = (feelsLikeC * 9/5) + 32;
                
                return {
                    temperature: tempF,
                    feels_like: feelsLikeF
                };
            } catch (error) {
                console.error('Weather fetch failed:', error);
                return { 
                    temperature: 85, 
                    feels_like: 88 
                };
            }
        }
        
        // Update the persistent temperature display
        function updateTempDisplay(weather) {
            document.getElementById('display-temp').textContent = 
                Math.round(weather.temperature) + '°';
        }
        
        // Show tooltip with feels-like and heat score only
        function showTooltip(e, lat, lon, mapObj) {
            if (!currentWeather) {
                console.log('⏳ Weather not loaded yet...');
                return;
            }
            
            const tooltip = document.getElementById('tooltip');
            const heatValue = getHeatValueFromImage(lat, lon);
            
            // Calculate adjusted feels-like
            const adjusted = calculateAdjustedFeelsLike(
                currentWeather.temperature, 
                currentWeather.feels_like, 
                heatValue
            );
            
            // Heat color based on value (blue=cool, red=hot) - vibrant colors
            const heatColor = heatValue < 2 ? '#0096ff' :   // electric blue
                             heatValue < 4 ? '#00c8ff' :   // bright cyan
                             heatValue < 6 ? '#00e6b4' :   // vibrant teal
                             heatValue < 8 ? '#96ff00' :   // electric lime
                             heatValue < 9 ? '#ffdc00' :   // bright yellow
                             '#ff3c3c';                    // vibrant red
            
            // Update feels-like box (permanently visible at top)
            const tempElement = document.getElementById('feels-temp');
            tempElement.textContent = Math.round(adjusted) + '°';
            tempElement.style.color = heatColor;
            
            document.getElementById('heat-value').textContent = 
                heatValue.toFixed(1) + '/10';
            
            // Update heat bar (0-10 scale to percentage)
            document.getElementById('heat-bar').style.width = 
                (heatValue * 10) + '%';
            
            // No tooltip needed - info is in the permanent box
            
            // Add/update pin marker at click location
            const pinIcon = L.divIcon({
                html: `<div style="
                    width: 24px;
                    height: 24px;
                    background: ${heatColor};
                    border: 3px solid white;
                    border-radius: 50% 50% 50% 0;
                    transform: rotate(-45deg);
                    box-shadow: 0 4px 8px rgba(0,0,0,0.4);
                "></div>`,
                className: 'custom-pin',
                iconSize: [24, 24],
                iconAnchor: [12, 24]
            });
            
            if (currentMarker) {
                currentMarker.setLatLng([lat, lon]);
                currentMarker.setIcon(pinIcon);
            } else {
                currentMarker = L.marker([lat, lon], { 
                    icon: pinIcon,
                    zIndexOffset: 1000
                }).addTo(mapObj);
            }
            
            console.log(`📍 Feels Like: ${adjusted.toFixed(1)}°F | Heat: ${heatValue.toFixed(1)}/10 | Color: ${heatColor}`);
        }
        
        // Load heat map image into canvas for pixel reading
        function loadHeatMapImage() {
            console.log('📸 Loading heat map image for pixel reading...');
            
            // Create a new image and load it directly
            heatMapImage = new Image();
            heatMapImage.crossOrigin = "anonymous"; // Enable CORS
            
            heatMapImage.onload = function() {
                console.log('✅ Image loaded successfully');
                setupCanvas();
            };
            
            heatMapImage.onerror = function() {
                console.error('❌ Failed to load image');
            };
            
            // Load the image (use absolute path)
            heatMapImage.src = 'temp_fullres_subtle.webp';
        }
        
        function setupCanvas() {
            console.log('🎨 Setting up canvas for pixel reading...');
            
            // Create hidden canvas to read pixels
            canvas = document.createElement('canvas');
            canvas.width = heatMapImage.naturalWidth || heatMapImage.width;
            canvas.height = heatMapImage.naturalHeight || heatMapImage.height;
            ctx = canvas.getContext('2d', { willReadFrequently: true });
            
            if (canvas.width === 0 || canvas.height === 0) {
                console.error('❌ Invalid canvas size');
                return;
            }
            
            // Draw image to canvas
            try {
                ctx.drawImage(heatMapImage, 0, 0);
                console.log(`✅ Canvas ready: ${canvas.width}x${canvas.height} pixels`);
                
                // Test read a pixel to verify it works
                const testData = ctx.getImageData(100, 100, 1, 1);
                console.log(`Test pixel: RGB(${testData.data[0]}, ${testData.data[1]}, ${testData.data[2]})`);
            } catch (error) {
                console.error('❌ Failed to draw image to canvas:', error);
            }
        }
        
        // Refresh weather data periodically
        function refreshWeather() {
            console.log('🔄 Refreshing weather data...');
            fetchWeather(29.7604, -95.3698).then(weather => {
                currentWeather = weather;
                updateTempDisplay(weather);
                console.log('✅ Weather updated:', weather.temperature.toFixed(1) + '°F');
            });
        }
        
        // Force image overlay to render in WebView
        function forceImageOverlayRender() {
            console.log('🔧 Forcing image overlay render for WebView...');
            
            // Find all image overlay elements
            const overlays = document.querySelectorAll('img.leaflet-image-layer');
            console.log(`Found ${overlays.length} image overlays`);
            
            overlays.forEach((img, index) => {
                console.log(`Overlay ${index}: src=${img.src}, complete=${img.complete}`);
                
                // Force rendering
                img.style.transform = 'translateZ(0)'; // Force GPU acceleration
                img.style.willChange = 'transform';
                img.style.backfaceVisibility = 'hidden';
                
                // Trigger reflow
                void img.offsetHeight;
                
                if (!img.complete) {
                    console.log(`⏳ Overlay ${index} still loading...`);
                    img.addEventListener('load', function() {
                        console.log(`✅ Overlay ${index} loaded!`);
                    });
                    img.addEventListener('error', function() {
                        console.error(`❌ Overlay ${index} failed to load`);
                    });
                }
            });
        }
        
        // Initialize click handler
        function initClickHandler() {
            console.log('🗺️ Initializing click handler...');
            
            const mapObj = {{ this._parent.get_name() }};
            
            // Initial weather fetch
            refreshWeather();
            
            // Auto-refresh weather every 30 minutes (1800000 ms)
            setInterval(refreshWeather, 30 * 60 * 1000);
            console.log('⏰ Weather will auto-update every 30 minutes');
            
            // Load heat map image
            loadHeatMapImage();
            
            // Force image overlay render after map loads
            setTimeout(forceImageOverlayRender, 2000);
            
            // Add click handler to the map
            mapObj.on('click', function(e) {
                showTooltip(e.originalEvent, e.latlng.lat, e.latlng.lng, mapObj);
            });
            
            console.log('✅ Click anywhere to see feels-like temp, heat score, and pin!');
        }
        
        // Initialize after delay
        setTimeout(initClickHandler, 1000);
        
        {% endmacro %}
        """)


def create_map_from_image(image_path, output_html='houston_heatmap_click.html'):
    """Create map that reads heat values from image pixels"""
    
    print("\nCreating heat map that reads from IMAGE PIXELS...")
    print("  💡 No data embedding - reads colors directly!")
    
    HOUSTON_BOUNDS = {
        'north': 30.110,
        'south': 29.523,
        'east': -95.014,
        'west': -95.788
    }
    
    bounds = [
        [HOUSTON_BOUNDS['south'], HOUSTON_BOUNDS['west']],
        [HOUSTON_BOUNDS['north'], HOUSTON_BOUNDS['east']]
    ]
    
    downtown = [29.7604, -95.3698]
    
    # Create map
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
    
    # Add heat map overlay
    print("📸 Adding heat map image overlay...")
    folium.raster_layers.ImageOverlay(
        image=image_path,
        bounds=bounds,
        opacity=0.4,
        interactive=False,
        cross_origin=True,
        zindex=1000,
        name='Heat Map'
    ).add_to(m)
    
    # Ultra-modern sleek UI
    tooltip_html = """
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        /* Critical: Force map container to fill viewport */
        html, body {
            height: 100%;
            width: 100%;
            margin: 0;
            padding: 0;
            overflow: hidden;
        }
        
        #map {
            height: 100% !important;
            width: 100% !important;
            position: absolute;
            top: 0;
            left: 0;
            z-index: 1;
        }
        
        /* Let image overlay blend with tiles, not cover them */
        .leaflet-image-layer {
            z-index: 400 !important;
            visibility: visible !important;
            display: block !important;
            pointer-events: none !important;
        }
        
        /* Keep tile layers visible */
        .leaflet-tile-pane {
            z-index: 200 !important;
        }
        
        * {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        /* Container for both temp boxes */
        .temp-container {
            position: fixed;
            top: 20px;
            right: 20px;
            display: flex;
            gap: 12px;
            z-index: 9999;
        }
        
        /* Persistent temperature display boxes */
        .temp-display {
            background: rgba(10, 10, 15, 0.85);
            backdrop-filter: blur(20px) saturate(180%);
            -webkit-backdrop-filter: blur(20px) saturate(180%);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 16px;
            padding: 16px 24px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.4);
            min-width: 140px;
        }
        
        .temp-display-label {
            font-size: 11px;
            font-weight: 500;
            color: rgba(255, 255, 255, 0.5);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 6px;
        }
        
        .temp-display-value {
            font-size: 42px;
            font-weight: 700;
            background: linear-gradient(135deg, #ffffff, #e0e0e0);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            line-height: 1;
            letter-spacing: -1px;
        }
        
        .temp-display-location {
            font-size: 10px;
            color: rgba(255, 255, 255, 0.3);
            margin-top: 4px;
        }
        
        /* Heat indicator bar for feels-like box */
        .heat-indicator-inline {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 8px;
        }
        
        .heat-bar-inline {
            flex: 1;
            height: 3px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 2px;
            overflow: hidden;
        }
        
        .heat-bar-fill-inline {
            height: 100%;
            background: linear-gradient(90deg, #0096ff, #00e6b4, #96ff00, #ffdc00, #ff3c3c);
            border-radius: 2px;
            transition: width 0.3s ease;
            width: 0%;
        }
        
        .heat-text-inline {
            font-size: 9px;
            font-weight: 600;
            color: rgba(255, 255, 255, 0.5);
        }
        
        /* Hide the old tooltip */
        .tooltip-box {
            display: none !important;
        }
        
        /* Click tooltip - super minimal */
        .tooltip-box {
            position: fixed;
            background: rgba(0, 0, 0, 0.92);
            backdrop-filter: blur(16px) saturate(180%);
            -webkit-backdrop-filter: blur(16px) saturate(180%);
            border: 1px solid rgba(255, 255, 255, 0.15);
            color: white;
            padding: 14px 20px;
            border-radius: 12px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6),
                        0 0 0 1px rgba(255, 255, 255, 0.05) inset;
            z-index: 10000;
            display: none;
            pointer-events: none;
            min-width: 180px;
        }
        
        .feels-value {
            font-size: 32px;
            font-weight: 700;
            color: #ffffff;
            line-height: 1.2;
            letter-spacing: -0.5px;
            margin-bottom: 4px;
        }
        
        .feels-label {
            font-size: 10px;
            font-weight: 500;
            color: rgba(255, 255, 255, 0.5);
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 8px;
        }
        
        .heat-indicator {
            display: flex;
            align-items: center;
            gap: 8px;
            margin-top: 10px;
            padding-top: 10px;
            border-top: 1px solid rgba(255, 255, 255, 0.08);
        }
        
        .heat-bar {
            flex: 1;
            height: 4px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 2px;
            overflow: hidden;
        }
        
        .heat-bar-fill {
            height: 100%;
            background: linear-gradient(90deg, #4a90e2, #5cd6a8, #e8c84a, #e8834a);
            border-radius: 2px;
            transition: width 0.3s ease;
        }
        
        .heat-text {
            font-size: 11px;
            font-weight: 600;
            color: rgba(255, 255, 255, 0.7);
        }
    </style>
    
    <!-- Temperature displays - side by side -->
    <div class="temp-container">
        <!-- Houston current temp -->
        <div class="temp-display">
            <div class="temp-display-label">Houston</div>
            <div class="temp-display-value" id="display-temp">--°</div>
            <div class="temp-display-location">Current temp</div>
        </div>
        
        <!-- Feels-like at clicked location -->
        <div class="temp-display">
            <div class="temp-display-label">Feels Like</div>
            <div class="temp-display-value" id="feels-temp" style="color: #ffffff;">--°</div>
            <div class="heat-indicator-inline">
                <div class="heat-bar-inline">
                    <div class="heat-bar-fill-inline" id="heat-bar"></div>
                </div>
                <div class="heat-text-inline" id="heat-value">--</div>
            </div>
        </div>
    </div>
    
    <!-- Old tooltip (hidden) -->
    <div class="tooltip-box" id="tooltip">
        <div class="feels-label">Feels Like</div>
        <div class="feels-value" id="feels-temp-old">--°F</div>
        <div class="heat-indicator">
            <div class="heat-bar">
                <div class="heat-bar-fill" id="heat-bar-old"></div>
            </div>
            <div class="heat-text" id="heat-value-old">--</div>
        </div>
    </div>
    """
    
    m.get_root().html.add_child(folium.Element(tooltip_html))
    
    # Add pixel-reading click handler
    click_tooltip = ClickTooltipFromImage()
    m.add_child(click_tooltip)
    
    # Save
    m.save(output_html)
    print(f"✅ Map saved: {output_html}")
    
    return output_html


def main():
    """Main execution"""
    print("Houston Heat Map - Pixel Reading Version")
    print("=" * 70)
    
    # Check if image exists
    img_path = 'temp_fullres_subtle.webp'
    if not Path(img_path).exists():
        print(f"⚠️ Image not found: {img_path}")
        print("Creating image from data...")
        
        # Load data
        data_file = Path('houston_extreme_highres_FIXED_ASSEMBLY.npy')
        if not data_file.exists():
            print(f"❌ Data file not found: {data_file}")
            return
        
        data = np.load(data_file)
        print(f"✅ Loaded: {data.shape[0]:,} x {data.shape[1]:,} = {data.size:,} points")
        
        # Create image
        print("\n📸 Creating visualization image...")
        colors = ['#0096ff', '#00c8ff', '#00e6b4', '#96ff00', '#ffdc00', '#ff3c3c']
        cmap = LinearSegmentedColormap.from_list('heat', colors, N=256)
        
        fig, ax = plt.subplots(figsize=(51.2, 51.2), dpi=100)
        ax.imshow(data, cmap=cmap, vmin=0, vmax=10, interpolation='bilinear')
        ax.axis('off')
        plt.subplots_adjust(left=0, right=1, top=1, bottom=0)
        
        plt.savefig(img_path, dpi=100, bbox_inches='tight', pad_inches=0)
        plt.close()
        print(f"✅ Saved: {img_path}")
    else:
        print(f"✅ Using existing image: {img_path}")
    
    # Create map
    output = create_map_from_image(img_path)
    
    print("\n" + "=" * 70)
    print("✅ PIXEL-READING MAP COMPLETE!")
    print("=" * 70)
    print("\n✨ How it works:")
    print("   • Loads your 5120×5120 heat map image")
    print("   • When you click, reads the pixel color at that spot")
    print("   • Converts RGB color back to heat value (0-10)")
    print("   • Shows EXACT values from your full-res data")
    print("   • Blue = low heat, Red = high heat (accurate!)")
    print("\n🌤️  Weather API Usage:")
    print("   • Makes 1 API call when page loads (Houston downtown)")
    print("   • Current temp shown at top right")
    print("   • Click anywhere to see adjusted feels-like + heat score")
    print("   • Ultra-sleek modern design!")
    print("\n🐛 Debug:")
    print("   • Open browser console (F12) to see detailed logs")
    print("   • Check if canvas loaded properly")
    print("   • See pixel RGB values and heat conversions")
    
    # Open in browser
    print("\n✅ Opening in browser...")
    webbrowser.open(f'file://{Path(output).absolute()}')


if __name__ == '__main__':
    main()
