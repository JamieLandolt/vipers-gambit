"""Moves the picture on every card in assets/Snake_Cards down by ROWS art rows (the name plate in CardText.lua moves down the
same amount), so the art and its name sit more in the middle between the top and bottom icons. The card's own background
pattern is repainted where the picture was. Run once (running it again moves the pictures down again).
Usage: python3 tools/shift_art.py [ROWS]"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import recolour_cards as rc

S = rc.S

def shift(path, kind, rows):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    frame, bgs, fn = rc.STYLES[kind]
    cells = {}
    for gy in range(2, 42):
        for gx in range(2, 31):
            colour = px[gx * S + 2, gy * S + 2][:3]
            if colour != bgs[fn(gx, gy)] and colour != frame:
                cells[(gx, gy)] = [px[gx * S + dx, gy * S + dy] for dy in range(S) for dx in range(S)]
    for (gx, gy) in cells:
        for dy in range(S):
            for dx in range(S):
                px[gx * S + dx, gy * S + dy] = bgs[fn(gx, gy)] + (255,)
    for (gx, gy), colours in cells.items():
        for i, colour in enumerate(colours):
            px[gx * S + i % S, (gy + rows) * S + i // S] = colour
    img.save(path)

if __name__ == "__main__":
    rows = int(sys.argv[1]) if len(sys.argv) > 1 else 4
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    types = rc.type_of_cards()
    for f in sorted(os.listdir("assets/Snake_Cards")):
        if f.endswith(".png"):
            shift(os.path.join("assets/Snake_Cards", f), types[f[:-4].lower()], rows)
