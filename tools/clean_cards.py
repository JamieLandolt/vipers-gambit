"""Removes the cyan corner curves and gold rarity bars left over from the original card art (CardText draws the cost, tier and
stats now), painting those cells with the card's own background pattern. Run on assets/Snake_Cards (safe to repeat).
Usage: python3 tools/clean_cards.py [DIR]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import recolour_cards as rc

LEFTOVER = {(95, 205, 228), (199, 169, 9)}

def clean(path, kind):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    _, bgs, fn = rc.STYLES[kind]
    S = rc.S
    for gy in range(img.height // S):
        for gx in range(img.width // S):
            if px[gx * S + 2, gy * S + 2][:3] in LEFTOVER:
                for dy in range(S):
                    for dx in range(S):
                        px[gx * S + dx, gy * S + dy] = bgs[fn(gx, gy)] + (255,)
    img.save(path)

if __name__ == "__main__":
    folder = sys.argv[1] if len(sys.argv) > 1 else "assets/Snake_Cards"
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    types = rc.type_of_cards()
    for f in sorted(os.listdir(folder)):
        if f.endswith(".png"):
            clean(os.path.join(folder, f), types[f[:-4].lower()])
