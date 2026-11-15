#!/usr/bin/env python3
# Scales SwiftDraw symbol templates so Phosphor glyphs match the optical size of SF Symbols.
#
# Add an icon:
#   curl -sfO https://unpkg.com/@phosphor-icons/core@2.1.1/assets/bold/<name>-bold.svg
#   swiftdraw <name>-bold.svg --format sfsymbol --size medium --output ph-<name>.svg
#   scripts/scale-phosphor-symbols.py ph-<name>.svg
# Then put ph-<name>.svg in App/Assets.xcassets/ph-<name>.symbolset with a Contents.json.

import re
import sys

# SF Symbols circles overshoot the cap line and baseline; SwiftDraw fits glyphs inside them, so scale up to match.
SCALE = 1.2
# Glyph y center between Capline-M (76) and Baseline-M (146) in the variant group's local coordinates.
CENTER_Y = 111.0

def scale_template(text):
    for variant in ["Ultralight-M", "Regular-M", "Black-M"]:
        left = re.search(rf'id="left-margin-{variant}" d="M([\d.]+),', text)
        right = re.search(rf'id="right-margin-{variant}" d="M([\d.]+),', text)
        if not (left and right):
            continue
        left_x, right_x = float(left.group(1)), float(right.group(1))
        center_x = (left_x + right_x) / 2
        scale_x = lambda value: center_x + (value - center_x) * SCALE
        text = text.replace(left.group(0), f'id="left-margin-{variant}" d="M{scale_x(left_x):.3f},')
        text = text.replace(right.group(0), f'id="right-margin-{variant}" d="M{scale_x(right_x):.3f},')
        group_start = text.index(f'id="{variant}"')
        group_end = text.index("</g>", group_start)
        group = text[group_start:group_end]
        def scale_path(match):
            numbers = [float(n) for n in re.findall(r"-?\d+\.?\d*(?:e-?\d+)?", match.group(1))]
            commands = re.findall(r"[MLCZ][^MLCZ]*", match.group(1))
            out = []
            for command in commands:
                letter, values = command[0], [float(n) for n in re.findall(r"-?\d+\.?\d*(?:e-?\d+)?", command[1:])]
                pairs = [f"{scale_x(values[i]):.3f},{CENTER_Y + (values[i + 1] - CENTER_Y) * SCALE:.3f}" for i in range(0, len(values), 2)]
                out.append(letter + " ".join(pairs))
            return f' d="{" ".join(out)}"'
        text = text[:group_start] + re.sub(r' d="([^"]+)"', scale_path, group) + text[group_end:]
    return text

for path in sys.argv[1:]:
    scaled = scale_template(open(path).read())
    open(path, "w").write(scaled)
