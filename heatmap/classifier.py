
import numpy as np
import cv2
from PIL import Image
import matplotlib.pyplot as plt
from pathlib import Path
from typing import Dict, List
import json
from datetime import datetime

class HeatConcentrationClassifier:
    def __init__(self, images_path: str, grid_size: int = 16):
        """
        Initialize the heat concentration classifier
        """
        self.images_path = Path(images_path)
        self.grid_size = grid_size
        
        self.heat_concentration_map = {
            'river': 0.5,
            'harbor': 1.0,
            'forest': 1.5,
  
            'agricultural': 2.0,
            'golfcourse': 2.5,
            'chaparral': 3.0,
            'beach': 3.5,
            
            'sparseresidential': 4.5,
            'mediumresidential': 5.5,
            'baseballdiamond': 5.0,
            'tenniscourt': 5.5,
            
            'denseresidential': 6.5,
            'buildings': 7.0,
            'mobilehomepark': 6.0,
            
            'parkinglot': 8.5,
            'freeway': 9.0,
            'runway': 9.5,
            'intersection': 8.0,
            'overpass': 8.5,
            'storagetanks': 7.5
        }
        
        self.heat_colors = {
            'very_cool': (0, 100, 255),     
            'cool': (0, 255, 100),           
            'moderate': (0, 255, 0),         
            'warm': (255, 255, 0),           
            'hot': (255, 100, 0),            
            'very_hot': (255, 0, 0)         
        }
        
        print(f"Initialized Heat Concentration Classifier")
        print(f"Images path: {self.images_path}")
        print(f"Grid size: {self.grid_size}x{self.grid_size}")
        print(f"Categories mapped: {len(self.heat_concentration_map)}")
    
    def get_heat_category(self, heat_score: float) -> str:
        if heat_score <= 2:
            return 'very_cool'
        elif heat_score <= 4:
            return 'cool'
        elif heat_score <= 6:
            return 'moderate'
        elif heat_score <= 8:
            return 'warm'
        elif heat_score <= 9:
            return 'hot'
        else:
            return 'very_hot'
    
    def load_image(self, image_path: str) -> np.ndarray:
        try:
            img = Image.open(image_path)
            img = img.convert('RGB')
            img_array = np.array(img)
            
            img_resized = cv2.resize(img_array, (256, 256))
            
            return img_resized
        except Exception as e:
            print(f"Error loading image {image_path}: {e}")
            return None
    
    def extract_grid_features(self, image: np.ndarray) -> Dict:
        h, w = image.shape[:2]
        cell_h, cell_w = h // self.grid_size, w // self.grid_size
        
        grid_features = {
            'mean_rgb': [],
            'std_rgb': [],
            'vegetation_index': [],
            'urban_index': [],
            'brightness': []
        }
        
        for i in range(self.grid_size):
            for j in range(self.grid_size):
                cell = image[i*cell_h:(i+1)*cell_h, j*cell_w:(j+1)*cell_w]
                
                mean_rgb = np.mean(cell, axis=(0, 1))
                std_rgb = np.std(cell, axis=(0, 1))

                r, g, b = mean_rgb
                vegetation_idx = (g - r) / (g + r + 1e-6)
                
                brightness = np.mean(mean_rgb)
                urban_idx = brightness * (1 - max(0, vegetation_idx))
                
                grid_features['mean_rgb'].append(mean_rgb)
                grid_features['std_rgb'].append(std_rgb)
                grid_features['vegetation_index'].append(vegetation_idx)
                grid_features['urban_index'].append(urban_idx)
                grid_features['brightness'].append(brightness)
        
        return grid_features
    
    def classify_heat_concentration(self, image_path: str, category: str = None) -> Dict:
        image = self.load_image(image_path)
        if image is None:
            return None
        
        features = self.extract_grid_features(image)
        
        if category is None:
            path_parts = Path(image_path).parts
            for part in path_parts:
                if part in self.heat_concentration_map:
                    category = part
                    break
        
        base_heat_score = self.heat_concentration_map.get(category, 5.0)
        
        heat_map = np.zeros((self.grid_size, self.grid_size))
        
        for i in range(len(features['vegetation_index'])):
            row, col = i // self.grid_size, i % self.grid_size

            veg_idx = features['vegetation_index'][i]
            urban_idx = features['urban_index'][i]
            brightness = features['brightness'][i]
            
            vegetation_modifier = -2.0 * max(0, veg_idx)
            
            urban_modifier = 1.0 * (urban_idx / 255.0)
            
            brightness_modifier = 0.5 * (brightness / 255.0)
   
            cell_heat_score = base_heat_score + vegetation_modifier + urban_modifier + brightness_modifier
            cell_heat_score = np.clip(cell_heat_score, 0, 10)
            
            heat_map[row, col] = cell_heat_score
        
        results = {
            'image_path': image_path,
            'category': category,
            'base_heat_score': base_heat_score,
            'heat_map': heat_map,
            'mean_heat_score': np.mean(heat_map),
            'max_heat_score': np.max(heat_map),
            'min_heat_score': np.min(heat_map),
            'heat_std': np.std(heat_map),
            'features': features,
            'grid_size': self.grid_size
        }
        
        return results
    
    def analyze_category(self, category: str, max_samples: int = 10) -> Dict:
        category_path = self.images_path / category
        if not category_path.exists():
            print(f"Category path not found: {category_path}")
            return None
        
        image_files = list(category_path.glob("*.tif"))[:max_samples]
        if not image_files:
            print(f"No TIFF images found in {category_path}")
            return None
        
        print(f"\nAnalyzing {len(image_files)} images from '{category}' category...")
        
        category_results = []
        heat_maps = []
        
        for img_file in image_files:
            result = self.classify_heat_concentration(str(img_file), category)
            if result:
                category_results.append(result)
                heat_maps.append(result['heat_map'])
        
        if not category_results:
            return None
        
        all_heat_scores = [r['mean_heat_score'] for r in category_results]
        all_heat_maps = np.array(heat_maps)
        
        analysis = {
            'category': category,
            'base_heat_score': self.heat_concentration_map.get(category, 5.0),
            'num_samples': len(category_results),
            'mean_heat_score': np.mean(all_heat_scores),
            'std_heat_score': np.std(all_heat_scores),
            'min_heat_score': np.min(all_heat_scores),
            'max_heat_score': np.max(all_heat_scores),
            'mean_heat_map': np.mean(all_heat_maps, axis=0),
            'individual_results': category_results
        }
        
        return analysis
    
    def create_heat_visualization(self, heat_map: np.ndarray, title: str = "Heat Concentration Map") -> plt.Figure:
        fig, ax = plt.subplots(figsize=(10, 8))
        
        im = ax.imshow(heat_map, cmap='RdYlBu_r', vmin=0, vmax=10, interpolation='nearest')
        
        cbar = plt.colorbar(im, ax=ax, shrink=0.8)
        cbar.set_label('Heat Concentration Score', rotation=270, labelpad=20)
        
        ax.set_title(title, fontsize=14, fontweight='bold')
        ax.set_xlabel('Grid Column')
        ax.set_ylabel('Grid Row')
        
        ax.set_xticks(range(0, heat_map.shape[1], 2))
        ax.set_yticks(range(0, heat_map.shape[0], 2))
        ax.grid(True, alpha=0.3)
        
        plt.tight_layout()
        return fig
    
    def compare_categories(self, categories: List[str], max_samples: int = 5) -> Dict:

        category_analyses = {}
        for category in categories:
            analysis = self.analyze_category(category, max_samples)
            if analysis:
                category_analyses[category] = analysis
        
        if not category_analyses:
            return None
        
        comparison = {
            'categories': list(category_analyses.keys()),
            'analyses': category_analyses,
            'ranking': sorted(category_analyses.keys(), 
                            key=lambda x: category_analyses[x]['mean_heat_score'], 
                            reverse=True)
        }
        
        return comparison
    
    def create_comparison_visualization(self, comparison_results: Dict) -> plt.Figure:

        categories = comparison_results['categories']
        analyses = comparison_results['analyses']
        
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 12))
        
        mean_scores = [analyses[cat]['mean_heat_score'] for cat in categories]
        base_scores = [analyses[cat]['base_heat_score'] for cat in categories]
        
        x_pos = np.arange(len(categories))
        ax1.bar(x_pos, mean_scores, alpha=0.7, label='Actual Mean Score', color='red')
        ax1.bar(x_pos, base_scores, alpha=0.5, label='Base Category Score', color='blue')
        ax1.set_xlabel('Category')
        ax1.set_ylabel('Heat Score')
        ax1.set_title('Mean Heat Concentration by Category')
        ax1.set_xticks(x_pos)
        ax1.set_xticklabels(categories, rotation=45, ha='right')
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        
        heat_score_data = []
        labels = []
        for cat in categories:
            scores = [r['mean_heat_score'] for r in analyses[cat]['individual_results']]
            heat_score_data.extend(scores)
            labels.extend([cat] * len(scores))
        
        box_data = [np.array([r['mean_heat_score'] for r in analyses[cat]['individual_results']]) 
                   for cat in categories]
        
        ax2.boxplot(box_data, labels=categories)
        ax2.set_xlabel('Category')
        ax2.set_ylabel('Heat Score')
        ax2.set_title('Heat Score Distribution by Category')
        ax2.tick_params(axis='x', rotation=45)
        ax2.grid(True, alpha=0.3)
        
        heat_categories = ['very_cool', 'cool', 'moderate', 'warm', 'hot', 'very_hot']
        cat_counts = {cat: {hc: 0 for hc in heat_categories} for cat in categories}
        
        for cat in categories:
            for result in analyses[cat]['individual_results']:
                heat_cat = self.get_heat_category(result['mean_heat_score'])
                cat_counts[cat][heat_cat] += 1
        
        bottom = np.zeros(len(categories))
        colors = ['blue', 'cyan', 'green', 'yellow', 'orange', 'red']
        
        for i, heat_cat in enumerate(heat_categories):
            values = [cat_counts[cat][heat_cat] for cat in categories]
            ax3.bar(categories, values, bottom=bottom, label=heat_cat, color=colors[i], alpha=0.7)
            bottom += values
        
        ax3.set_xlabel('Category')
        ax3.set_ylabel('Number of Images')
        ax3.set_title('Heat Category Distribution')
        ax3.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
        ax3.tick_params(axis='x', rotation=45)
        
        hottest_cats = comparison_results['ranking'][:3]
        
        ax4.remove()
        gs = fig.add_gridspec(2, 2)
        
        for i, cat in enumerate(hottest_cats):
            ax_hm = fig.add_subplot(gs[1, i if i < 2 else 1])
            heat_map = analyses[cat]['mean_heat_map']
            im = ax_hm.imshow(heat_map, cmap='RdYlBu_r', vmin=0, vmax=10)
            ax_hm.set_title(f'{cat}\n(Score: {analyses[cat]["mean_heat_score"]:.2f})', fontsize=10)
            ax_hm.set_xticks([])
            ax_hm.set_yticks([])
        
        plt.tight_layout()
        return fig
    
    def save_results(self, results: Dict, output_path: str):
        def convert_numpy(obj):
            if isinstance(obj, np.ndarray):
                return obj.tolist()
            elif isinstance(obj, dict):
                return {k: convert_numpy(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_numpy(item) for item in obj]
            else:
                return obj
        
        json_results = convert_numpy(results)
        json_results['timestamp'] = datetime.now().isoformat()
        json_results['classifier_info'] = {
            'grid_size': self.grid_size,
            'heat_concentration_map': self.heat_concentration_map
        }
        
        with open(output_path, 'w') as f:
            json.dump(json_results, f, indent=2)
        
        print(f"Results saved to: {output_path}")