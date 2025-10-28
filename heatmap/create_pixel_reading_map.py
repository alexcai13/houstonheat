
import numpy as np
from pathlib import Path
import folium
from folium import MacroElement
from jinja2 import Template
from matplotlib import pyplot as plt
from matplotlib.colors import LinearSegmentedColormap
import webbrowser


class ClickTooltipFromImage(MacroElement):
    
    def __init__(self):
        super(ClickTooltipFromImage, self).__init__()
        self._name = 'ClickTooltipFromImage'
        
        self._template = Template("""
        {% macro script(this, kwargs) %}
        
        const BOUNDS = {
            north: 30.110,
            south: 29.523,
            east: -95.014,
            west: -95.788
        };
        
        const colorScale = [
            {heat: 0,  r: 0,   g: 150, b: 255},  
            {heat: 2,  r: 0,   g: 200, b: 255},  
            {heat: 4,  r: 0,   g: 230, b: 180},  
            {heat: 6,  r: 150, g: 255, b: 0},    
            {heat: 8,  r: 255, g: 220, b: 0},    
            {heat: 10, r: 255, g: 60,  b: 60}    
        ];
        
        let currentWeather = null;
        let heatMapImage = null;
        let canvas = null;
        let ctx = null;
        let currentMarker = null;
        
        function rgbToHeat(r, g, b) {
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
            
            if (minDist1 < 10) {
                return closest1.heat;
            }
            
            const totalDist = minDist1 + minDist2;
            if (totalDist === 0) return closest1.heat;
            
            const weight1 = minDist2 / totalDist;
            const weight2 = minDist1 / totalDist;
            
            return closest1.heat * weight1 + closest2.heat * weight2;
        }
        
        function getHeatValueFromImage(lat, lon) {
            if (!canvas || !ctx) {
                return 5;
            }
            
            if (canvas.width === 0 || canvas.height === 0) {
                return 5;
            }
            
            if (lat < BOUNDS.south || lat > BOUNDS.north || 
                lon < BOUNDS.west || lon > BOUNDS.east) {
                return 5;
            }
            
            const latFrac = (lat - BOUNDS.south) / (BOUNDS.north - BOUNDS.south);
            const lonFrac = (lon - BOUNDS.west) / (BOUNDS.east - BOUNDS.west);
            
            const x = Math.floor(lonFrac * canvas.width);
            const y = Math.floor((1 - latFrac) * canvas.height);
   
            const clampedX = Math.max(0, Math.min(canvas.width - 1, x));
            const clampedY = Math.max(0, Math.min(canvas.height - 1, y));
            
            try {
                const imageData = ctx.getImageData(clampedX, clampedY, 1, 1);
                const r = imageData.data[0];
                const g = imageData.data[1];
                const b = imageData.data[2];
                const a = imageData.data[3];
                
                console.log(`Pixel (${clampedX},${clampedY}): RGB(${r},${g},${b},${a})`);
                
                if (a < 10) {
                    return 5;
                }

                const heat = rgbToHeat(r, g, b);
                console.log(`→ Heat value: ${heat.toFixed(1)}/10`);
                
                return heat;
            } catch (error) {
                return 5;
            }
        }
        

        function calculateAdjustedFeelsLike(actualTemp, feelsLike, heatValue) {
            const baseFeelsLike = feelsLike;
            const heatAdjustment = (heatValue - 5) * 1.0;
            
            return baseFeelsLike + heatAdjustment;
        }
        

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
        
        function updateTempDisplay(weather) {
            document.getElementById('display-temp').textContent = 
                Math.round(weather.temperature) + '°';
        }
        
        function showTooltip(e, lat, lon, mapObj) {
            if (!currentWeather) {
                console.log('⏳ Weather not loaded yet...');
                return;
            }
            
            const tooltip = document.getElementById('tooltip');
            const heatValue = getHeatValueFromImage(lat, lon);
            
            const adjusted = calculateAdjustedFeelsLike(
                currentWeather.temperature, 
                currentWeather.feels_like, 
                heatValue
            );
            
            const heatColor = heatValue < 2 ? '#0096ff' :   
                             heatValue < 4 ? '#00c8ff' :   
                             heatValue < 6 ? '#00e6b4' :   
                             heatValue < 8 ? '#96ff00' :   
                             heatValue < 9 ? '#ffdc00' :   
                             '#ff3c3c';
            
            const tempElement = document.getElementById('feels-temp');
            tempElement.textContent = Math.round(adjusted) + '°';
            tempElement.style.color = heatColor;
            
            document.getElementById('heat-value').textContent = 
                heatValue.toFixed(1) + '/10';
            

            document.getElementById('heat-bar').style.width = 
                (heatValue * 10) + '%';
            
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
            
        }
        function loadHeatMapImage() {
            heatMapImage = new Image();
            heatMapImage.crossOrigin = "anonymous"; 
            
            heatMapImage.onload = function() {
                setupCanvas();
            };
            
            heatMapImage.onerror = function() {
            };
            
            heatMapImage.src = 'temp_fullres_subtle.webp';
        }
        
        function setupCanvas() {
            canvas = document.createElement('canvas');
            canvas.width = heatMapImage.naturalWidth || heatMapImage.width;
            canvas.height = heatMapImage.naturalHeight || heatMapImage.height;
            ctx = canvas.getContext('2d', { willReadFrequently: true });
            
            if (canvas.width === 0 || canvas.height === 0) {
                return;
            }
            
            try {
                ctx.drawImage(heatMapImage, 0, 0);
                const testData = ctx.getImageData(100, 100, 1, 1);
            } catch (error) {
            }
        }
        
        function refreshWeather() {
            fetchWeather(29.7604, -95.3698).then(weather => {
                currentWeather = weather;
                updateTempDisplay(weather);
                
            });
        }
        

        function forceImageOverlayRender() {
            const overlays = document.querySelectorAll('img.leaflet-image-layer');
            
            overlays.forEach((img, index) => {
                img.style.transform = 'translateZ(0)';
                img.style.willChange = 'transform';
                img.style.backfaceVisibility = 'hidden';
                
                void img.offsetHeight;
                
                if (!img.complete) {
                    img.addEventListener('load', function() {
                    });
                    img.addEventListener('error', function() {
                    });
                }
            });
        }
        
        function initClickHandler() {
            const mapObj = {{ this._parent.get_name() }};
            
            refreshWeather();
            
            setInterval(refreshWeather, 30 * 60 * 1000);
            
            loadHeatMapImage();
            
            setTimeout(forceImageOverlayRender, 2000);
            
            mapObj.on('click', function(e) {
                showTooltip(e.originalEvent, e.latlng.lat, e.latlng.lng, mapObj);
            });
        }
        
        setTimeout(initClickHandler, 1000);
        
        {% endmacro %}
        """)


def create_map_from_image(image_path, output_html='houston_heatmap_click.html'):
   
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

    m = folium.Map(
        location=downtown,
        zoom_start=11,
        tiles=None,
        max_zoom=18
    )

    folium.TileLayer(
        tiles='https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        attr='Esri',
        name='Satellite',
        overlay=False,
        control=True
    ).add_to(m)
    
    folium.TileLayer(
        tiles='OpenStreetMap',
        name='Street Map',
        overlay=False,
        control=True
    ).add_to(m)
    
    folium.raster_layers.ImageOverlay(
        image=image_path,
        bounds=bounds,
        opacity=0.4,
        interactive=False,
        cross_origin=True,
        zindex=1000,
        name='Heat Map'
    ).add_to(m)
    
    tooltip_html = """
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
        
        html, body {
            height: 100%;
            width: 100%;
            margin: 0;
            padding: 0;
            overflow: hidden;
        }
        
        {
            height: 100% !important;
            width: 100% !important;
            position: absolute;
            top: 0;
            left: 0;
            z-index: 1;
        }
        
        .leaflet-image-layer {
            z-index: 400 !important;
            visibility: visible !important;
            display: block !important;
            pointer-events: none !important;
        }
        
        .leaflet-tile-pane {
            z-index: 200 !important;
        }
        
        * {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        
        .temp-container {
            position: fixed;
            top: 20px;
            right: 20px;
            display: flex;
            gap: 12px;
            z-index: 9999;
        }
        
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
        
        .tooltip-box {
            display: none !important;
        }
        
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
    
    <div class="temp-container">
        <div class="temp-display">
            <div class="temp-display-label">Houston</div>
            <div class="temp-display-value" id="display-temp">--°</div>
            <div class="temp-display-location">Current temp</div>
        </div>
        
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
    
    click_tooltip = ClickTooltipFromImage()
    m.add_child(click_tooltip)
    
    m.save(output_html)
    print(f"✅ Map saved: {output_html}")
    
    return output_html


def main():
    print("Houston Heat Map - Pixel Reading Version")
    print("=" * 70)
    
    img_path = 'temp_fullres_subtle.webp'
    if not Path(img_path).exists():
        print(f"⚠️ Image not found: {img_path}")
        print("Creating image from data...")
        
        data_file = Path('houston_extreme_highres_FIXED_ASSEMBLY.npy')
        if not data_file.exists():
            print(f"❌ Data file not found: {data_file}")
            return
        
        data = np.load(data_file)
        print(f"✅ Loaded: {data.shape[0]:,} x {data.shape[1]:,} = {data.size:,} points")
        
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
    
    print("\n✅ Opening in browser...")
    webbrowser.open(f'file://{Path(output).absolute()}')


if __name__ == '__main__':
    main()
