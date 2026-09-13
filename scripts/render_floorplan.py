import re
import os
import hashlib
from PIL import Image, ImageDraw, ImageFont

# 1. Define Canvas Size
scale = 6
img_width, img_height = 2400, 1600
img = Image.new("RGB", (img_width, img_height), (10, 10, 12)) # Deep slate background
draw = ImageDraw.Draw(img)

# Dictionaries to track cell coordinate running sums for calculating the average (centroid)
pblock_coords = {} # Format: { pblock_name: { 'sum_x': 0, 'sum_y': 0, 'count': 0 } }

# Helper function to automatically turn any Pblock name into a distinct RGB color
def get_core_color(pblock_name):
    if not pblock_name:
        return (100, 100, 100) # Muted grey for unassigned global interconnect
    hash_object = hashlib.md5(pblock_name.encode())
    hex_dig = hash_object.hexdigest()
    r = (int(hex_dig[0:2], 16) % 180) + 75
    g = (int(hex_dig[2:4], 16) % 180) + 75
    b = (int(hex_dig[4:6], 16) % 180) + 75
    return (r, g, b)

# 2. Open and parse the unfiltered text matrix
with open("./build_vivado/placement_dump.txt", "r") as f:
    for line in f:
        if not line.strip():
            continue
        tokens = line.strip().split("|")
        
        # --- PARSE AND DRAW ALL PLACED PRIMITIVES ---
        if tokens[0] == "CELL" and len(tokens) > 4:
            cell_type = tokens[2]
            loc_string = tokens[3]
            pblock_name = tokens[4] # The Pblock this cell belongs to
            
            loc_match = re.search(r'X(\d+)Y(\d+)', loc_string)
            if loc_match:
                cx = int(loc_match.group(1))
                cy = int(loc_match.group(2))
                px, py = cx * scale, img_height - (cy * scale)
                
                # --- TRACK DATA FOR THE MATHEMATICAL AVERAGE ---
                if pblock_name: 
                    if pblock_name not in pblock_coords:
                        pblock_coords[pblock_name] = {'sum_x': 0, 'sum_y': 0, 'count': 0}
                    
                    # Accumulate screen-space pixel coordinates for averaging later
                    pblock_coords[pblock_name]['sum_x'] += px
                    pblock_coords[pblock_name]['sum_y'] += py
                    pblock_coords[pblock_name]['count'] += 1
                
                # Draw the cell pixels with checkerboard texture
                base_color = get_core_color(pblock_name)
                if (cx + cy) % 2 == 0:
                    pixel_color = tuple(min(c + 35, 255) for c in base_color)
                else:
                    pixel_color = tuple(max(c - 35, 0) for c in base_color)
                
                if "FF" in cell_type or "FD" in cell_type:
                    pixel_color = (pixel_color[0], min(pixel_color[1] + 40, 255), pixel_color[2])
                
                draw.rectangle([px + 1, py + 1, px + 4, py + 4], fill=pixel_color)

# =====================================================================
# 3. TEXT ENGINE LOADING
# =====================================================================
font_paths = [
    "arial.ttf",                                              
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",  
    "/usr/share/fonts/liberation/LiberationSans-Bold.ttf"
]

font_large = None
font_small = None
for path in font_paths:
    try:
        font_large = ImageFont.truetype(path, 42)
        font_small = ImageFont.truetype(path, 28)
        break
    except IOError:
        continue

if font_large is None:
    font_large = ImageFont.load_default()
    font_small = ImageFont.load_default()

# =====================================================================
# 4. OVERLAY CORE LABELS (CALCULATED BY CENTROID / AVERAGE LOCATION)
# =====================================================================
for pb_name, data in pblock_coords.items():
    if data['count'] == 0:
        continue
        
    core_number_match = re.search(r'\d+', pb_name)
    core_label = core_number_match.group(0) if core_number_match else pb_name
    
    # Calculate the true mathematical center of all elements in this cluster
    avg_x = data['sum_x'] // data['count']
    avg_y = data['sum_y'] // data['count']
    
    try:
        left, top, right, bottom = draw.textbbox((0, 0), core_label, font=font_large)
        text_w, text_h = right - left, bottom - top
    except AttributeError:
        text_w, text_h = draw.textsize(core_label, font=font_large)
        
    # Render pure white numbers perfectly balanced over the center of the mass
    draw.text((avg_x - (text_w // 2), avg_y - (text_h // 2)), core_label, fill=(255, 255, 255), font=font_large)

# =====================================================================
# 5. DYNAMIC SUMMARY LABEL (ALL THE WAY BOTTOM LEFT, MINIMALIST WHITE)
# =====================================================================
core_count = len(pblock_coords)
summary_text = f"Kintex-7 {core_count} cores found"

sum_x = 20
try:
    left, top, right, bottom = draw.textbbox((0, 0), summary_text, font=font_small)
    text_h = bottom - top
except AttributeError:
    text_h = draw.textsize(summary_text, font=font_small)

sum_y = img_height - text_h - 20
draw.text((sum_x, sum_y), summary_text, fill=(255, 255, 255), font=font_small)

# 6. Output Final Master Render
img.save("./build_vivado/chip_floorplan.png")
print(f"[INFO] Floorplan generated perfectly with {core_count} core tags positioned by cluster density!")
