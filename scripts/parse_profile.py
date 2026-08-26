import re
import os
from collections import defaultdict

# 1. Nested dictionary layout: data[filename][line_number] = gate_count
profile_data = defaultdict(lambda: defaultdict(int))

# 2. Parse the Yosys dump file
try:
    with open("build/line_profile_dump.txt", "r") as f:
        for line in f:
            # Match patterns like: src/sha256_compress.v:42
            # Matches any alphanumeric, underscore, dot or slash followed by a colon and a number
            match = re.search(r'([\w./\\]+\.v):(\d+)', line)
            if match:
                file_path = match.group(1)
                # Normalize path separators (handles mixed / and \ on Windows/Linux)
                norm_path = os.path.normpath(file_path)
                line_num = int(match.group(2))
                profile_data[norm_path][line_num] += 1
except FileNotFoundError:
    print("Error: build/line_profile_dump.txt not found. Run Yosys first!")
    exit(1)

# 3. List of your project source files to display
source_files = [
    "src/top.v",
    "src/uart_rx.v",
    "src/uart_tx.v",
    "src/bitcoin_hash_core.v",
    "src/sha256_compress.v"
]

# 4. Generate the line-by-line report for each file
for file_path in source_files:
    norm_path = os.path.normpath(file_path)
    
    if not os.path.exists(norm_path):
        print(f"\n⚠️ Skipping {file_path} (File not found locally)")
        continue
        
    print("\n" + "=" * 90)
    print(f" PROFILE REPORT FOR: {file_path}")
    print("=" * 90)
    print(f"{'LINE':<6} | {'GATES/CELLS':<11} | {'VERILOG CODE'}")
    print("-" * 90)
    
    with open(norm_path, "r") as f:
        for idx, code_line in enumerate(f, 1):
            cells_on_line = profile_data[norm_path][idx]
            count_str = str(cells_on_line) if cells_on_line > 0 else "."
            print(f"{idx:<6} | {count_str:<11} | {code_line.rstrip()}")
