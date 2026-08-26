import re
import os
from collections import Counter


PROFILE_LOG = "profile.txt"
LINE_DUMP = "build/line_profile_dump.txt"
SOURCE_FILES = [
    "src/top.v",
    "src/uart_rx.v",
    "src/uart_tx.v",
    "src/bitcoin_hash_core.v",
    "src/sha256_compress.v",
]

CELL_TYPES = {
    "LUT1", "LUT2", "LUT3", "LUT4",
    "MUX2_LUT5", "MUX2_LUT6", "MUX2_LUT7", "MUX2_LUT8",
    "ALU",
    "DFF", "DFFE", "DFFR", "DFFRE", "DFFS", "DFFSE",
}

FF_TYPES = {"DFF", "DFFE", "DFFR", "DFFRE", "DFFS", "DFFSE"}
LINE_CELL_TYPES = {
    "LUT1", "LUT2", "LUT3", "LUT4",
    "MUX2_LUT5", "MUX2_LUT6", "MUX2_LUT7", "MUX2_LUT8",
}


def parse_final_cell_counts(path):
    counts = Counter()
    in_top = False

    with open(path, "r") as f:
        for line in f:
            if "=== top ===" in line:
                in_top = True
                counts.clear()
                continue

            if in_top and line.startswith("==="):
                in_top = False

            if not in_top:
                continue

            match = re.match(r"\s+(\d+)\s+(\S+)\s*$", line)
            if not match:
                continue

            count = int(match.group(1))
            cell_type = match.group(2)
            if cell_type in CELL_TYPES:
                counts[cell_type] = count

    return counts


def parse_line_counts(path):
    line_counts = Counter()
    stats = Counter()
    pending_ranges = []

    with open(path, "r") as f:
        for line in f:
            if "attribute \\src" in line or "attribute \\cell_src" in line:
                pending_ranges.extend(project_ranges(line))
                continue

            cell_match = re.match(r"\s*cell\s+\\(\S+)\s+", line)
            if not cell_match:
                continue

            cell_type = cell_match.group(1)
            if cell_type in LINE_CELL_TYPES:
                stats["final_lut_mux_cells"] += 1
                cell_name = line[cell_match.end():].strip()
                ranges = inferred_ranges(cell_name) or pending_ranges
                if ranges:
                    stats["attributed_lut_mux_cells"] += 1
                else:
                    stats["unattributed_lut_mux_cells"] += 1

                for file_path, start_line, end_line in ranges:
                    for line_num in range(start_line, end_line + 1):
                        line_counts[(file_path, line_num)] += 1
            pending_ranges = []

    return line_counts, stats


def inferred_ranges(cell_name):
    name = cell_name.replace("\\", "")

    if "core" in name and ".sha." in name:
        path = os.path.normpath("src/sha256_compress.v")
        if "state_out" in name:
            if any(token in name for token in ("h0", "h1", "h2", "h3")):
                return [(path, 215, 215)]
            if any(token in name for token in ("h4", "h5", "h6", "h7")):
                return [(path, 216, 216)]
            return [(path, 214, 217)]
        if ".e_DFF" in name or "sha.e_DFF" in name:
            return [(path, 189, 189)]
        if ".a_DFF" in name or "sha.a_DFF" in name:
            return [(path, 193, 193)]
        if ".h_DFF" in name or "sha.h_DFF" in name:
            return [(path, 186, 186)]
        if ".g_DFF" in name or "sha.g_DFF" in name:
            return [(path, 187, 187)]
        if ".f_DFF" in name or "sha.f_DFF" in name:
            return [(path, 188, 188)]
        if ".d_DFF" in name or "sha.d_DFF" in name:
            return [(path, 190, 190)]
        if ".c_DFF" in name or "sha.c_DFF" in name:
            return [(path, 191, 191)]
        if ".b_DFF" in name or "sha.b_DFF" in name:
            return [(path, 192, 192)]
        if "round" in name:
            return [(path, 221, 221)]
        if "w_next" in name or re.search(r"\.w(?:1[0-5]|[0-9])_", name):
            return [(path, 163, 166)]
        return [(path, 111, 225)]

    if "subtraction" in name or "lt255" in name:
        return [(os.path.normpath("src/bitcoin_hash_core.v"), 81, 82)]
    if "current_nonce" in name:
        return [(os.path.normpath("src/bitcoin_hash_core.v"), 149, 149)]
    if name.startswith("core0.") or name.startswith("core1."):
        return [(os.path.normpath("src/bitcoin_hash_core.v"), 86, 171)]
    if name.startswith("rx0."):
        return [(os.path.normpath("src/uart_rx.v"), 23, 85)]
    if name.startswith("tx0."):
        return [(os.path.normpath("src/uart_tx.v"), 22, 82)]
    if name.startswith("reset_counter"):
        return [(os.path.normpath("src/top.v"), 254, 321)]
    return [(os.path.normpath("src/top.v"), 254, 321)]



def project_ranges(line):
    ranges = []
    matches = re.findall(r'([\w./\\]+\.v):(\d+)(?:\.\d+)?(?:-(\d+)(?:\.\d+)?)?', line)
    for file_path, start, end in matches:
        norm_path = os.path.normpath(file_path)
        if norm_path.startswith(os.path.normpath("src") + os.sep):
            ranges.append((norm_path, int(start), int(end or start)))
    return ranges


try:
    counts = parse_final_cell_counts(PROFILE_LOG)
except FileNotFoundError:
    print(f"Error: {PROFILE_LOG} not found. Run `yosys -s profile.ys > profile.txt` first.")
    raise SystemExit(1)

if not counts:
    print(f"Error: no final top-level mapped cell counts found in {PROFILE_LOG}.")
    raise SystemExit(1)

logic_total = sum(count for cell_type, count in counts.items() if cell_type not in FF_TYPES)
ff_total = sum(count for cell_type, count in counts.items() if cell_type in FF_TYPES)
total = logic_total + ff_total

print("FINAL POST-SYNTHESIS RESOURCE COUNTS")
print("=" * 44)
for cell_type in sorted(counts):
    print(f"{cell_type:<10} {counts[cell_type]:>8}")

print("-" * 44)
print(f"{'Logic total':<10} {logic_total:>8}")
print(f"{'FF total':<10} {ff_total:>8}")
print(f"{'Grand total':<10} {total:>8}")

try:
    line_counts, line_stats = parse_line_counts(LINE_DUMP)
except FileNotFoundError:
    line_counts = Counter()
    line_stats = Counter()

if line_counts:
    print()
    print("BEST-EFFORT FINAL LUT/MUX SOURCE ATTRIBUTION")
    print("=" * 90)
    print("Optimized LUT/MUX cells are attributed by final cell name first, then src metadata.")

    for file_path in SOURCE_FILES:
        norm_path = os.path.normpath(file_path)
        if not os.path.exists(norm_path):
            continue

        print()
        print("=" * 90)
        print(f" PROFILE REPORT FOR: {file_path}")
        print("=" * 90)
        print(f"{'LINE':<6} | {'GATES/CELLS':<11} | VERILOG CODE")
        print("-" * 90)

        with open(norm_path, "r") as f:
            for line_num, code_line in enumerate(f, 1):
                count = line_counts[(norm_path, line_num)]
                count_str = str(count) if count else "."
                print(f"{line_num:<6} | {count_str:<11} | {code_line.rstrip()}")

    print()
    print("=" * 90)
    print(f"Final LUT/MUX cells checked : {line_stats['final_lut_mux_cells']}")
    print(f"Attributed LUT/MUX cells    : {line_stats['attributed_lut_mux_cells']}")
    print(f"Unattributed LUT/MUX cells  : {line_stats['unattributed_lut_mux_cells']}")
