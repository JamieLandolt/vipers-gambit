"""Turns one variant from a generated 2x2 portrait sheet into a game portrait: shrunk to the 71x87 art grid, reduced to a small
palette, set on the backdrop of the portrait it replaces, and scaled 5x (355x435).
Usage: python3 tools/convert_portrait.py SHEET.png VARIANT TARGET.png [STAND.png]
       python3 tools/convert_portrait.py --skins SHEET.png FOLDER BASE     (all four as BASE_1..4.png for the charmer screen)
VARIANT is 0-3 (top left, top right, bottom left, bottom right). The target's old backdrop is reused, so keep a copy of it
if you convert the same target twice. STAND.png, if given, also gets a cut-out of the figure on transparency (the charmer standing on the menu)."""
import sys
from PIL import Image

W, H, S = 71, 87, 5

def backdrop(old):
    bg = Image.new("RGB", (W, H))
    for y in range(H):
        for x in range(W):
            sx = x if x < 8 else (W - 1 - x if x > W - 9 else 0)  # the dither band lives in the outer 8 columns
            bg.putpixel((x, y), old.getpixel((sx * S + 2, y * S + 2)))
    return bg

def convert(sheet, variant, target, stand=None):
    im = Image.open(sheet).convert("RGBA")
    cell = im.width // 2
    qx, qy = (variant % 2) * cell, (variant // 2) * cell
    q = im.crop((qx, qy, qx + cell, qy + cell))
    q = q.crop(q.getbbox())
    scale = min((W - 2) / q.width, (H - 2) / q.height)
    nw, nh = round(q.width * scale), round(q.height * scale)
    small = q.resize((nw, nh), Image.BOX)
    mask = small.getchannel("A").point(lambda v: 255 if v > 100 else 0)
    rgb = small.convert("RGB").quantize(colors=22, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGB")
    pos = ((W - nw) // 2, H - nh)
    out = backdrop(Image.open(target).convert("RGB"))
    out.paste(rgb, pos, mask)
    out.resize((W * S, H * S), Image.NEAREST).save(target)
    if stand:
        cut = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cut.paste(rgb, pos, mask)
        cut.resize((W * S, H * S), Image.NEAREST).save(stand)

def skins(sheet, folder, base, old=None):
    """All four variants of a sheet as <base>_1..4.png (with stand_<base>_1..4.png cut-outs): players pick their look on the
    charmer screen. <base>.png (the default) becomes variant 1. `old` is the portrait whose backdrop to reuse (default: <base>.png)."""
    import os, shutil
    old = old or f"{folder}/{base}.png"
    keep = old + ".bak"
    shutil.copy(old, keep)
    for v in range(4):
        shutil.copy(keep, f"{folder}/{base}_{v + 1}.png")
        convert(sheet, v, f"{folder}/{base}_{v + 1}.png", f"{folder}/stand_{base}_{v + 1}.png")
    shutil.copy(f"{folder}/{base}_1.png", f"{folder}/{base}.png")
    shutil.copy(f"{folder}/stand_{base}_1.png", f"{folder}/stand_{base}.png")
    os.remove(keep)

if __name__ == "__main__":
    if sys.argv[1] == "--skins":  # --skins SHEET.png FOLDER BASE
        skins(sys.argv[2], sys.argv[3], sys.argv[4])
        sys.exit()
    convert(sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
