import os
import sys
import json
from collections import Counter

try:
    from PIL import Image
except ImportError:
    print(json.dumps({"error": "PIL not installed"}))
    sys.exit(1)

def get_dominant_colors(image_path, num_colors=3):
    try:
        img = Image.open(image_path)
        img = img.convert("RGB")
        img = img.resize((50, 50))
        pixels = [p for p in list(img.getdata()) if p[0] < 250 or p[1] < 250 or p[2] < 250] # Filter white
        if not pixels: return []
        return Counter(pixels).most_common(num_colors)
    except Exception:
        return []

def inspect_folder(target_dir):
    result = {"files": [], "palette": []}
    artifacts_dir = None
    
    for root, dirs, files in os.walk(target_dir):
        for file in files:
            full_path = os.path.join(root, file)
            rel_path = os.path.relpath(full_path, target_dir)
            result["files"].append(rel_path)
            
            if "artifacts" in root and file.lower().endswith(('.png', '.jpg', '.jpeg')):
                if artifacts_dir is None: artifacts_dir = root

    # Extract palette from the first few images in artifacts folder
    if artifacts_dir:
        images = [f for f in os.listdir(artifacts_dir) if f.lower().endswith(('.png', '.jpg'))]
        images.sort() # predictable order
        palette_counts = Counter()
        
        for img_name in images[:3]: # Check first 3 images
            img_path = os.path.join(artifacts_dir, img_name)
            colors = get_dominant_colors(img_path)
            for color, count in colors:
                palette_counts[color] += count
        
        most_common = palette_counts.most_common(2)
        result["palette"] = ["#{:02x}{:02x}{:02x}".format(c[0], c[1], c[2]) for c, _ in most_common]

    return result

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No directory provided"}))
        sys.exit(1)
    
    target = sys.argv[1]
    if not os.path.exists(target):
        print(json.dumps({"error": "Directory not found"}))
        sys.exit(1)
        
    info = inspect_folder(target)
    print(json.dumps(info, indent=2))
