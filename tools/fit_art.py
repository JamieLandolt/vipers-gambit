"""Shrinks the picture on snake cards whose art fills the card's whole width (the head or tail touches the frame), so it sits
inside with a margin. The picture is resampled on the card's 5 px art grid and centred; the background pattern is repainted
where it was. Cards already narrower than MAX_W art pixels are left alone, so running it twice changes nothing.
Usage: python3 tools/fit_art.py [MAX_W]    (the legendary snakes keep their full-card art)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image
import recolour_cards as rc

S = rc.S
LEGENDARY = {"Ouroboros", "Apophis", "Quetzalcoatl", "Nagaraja", "Jormungandr"}
TRIGGER, CENTRE_COL = 26, 16  # art wider than this many art pixels is shrunk; the interior's middle column


def fit(path, kind, max_w):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    frame, bgs, fn = rc.STYLES[kind]
    cells = {}
    for gy in range(2, 62):
        for gx in range(2, 31):
            colour = px[gx * S + 2, gy * S + 2]
            if colour[:3] != bgs[fn(gx, gy)] and colour[:3] != frame:
                cells[(gx, gy)] = colour
    if not cells:
        return False
    x0, x1 = min(g[0] for g in cells), max(g[0] for g in cells)
    y0, y1 = min(g[1] for g in cells), max(g[1] for g in cells)
    w, h = x1 - x0 + 1, y1 - y0 + 1
    if w < TRIGGER:
        return False
    k = max_w / w
    w2, h2 = max_w, max(1, round(h * k))
    for (gx, gy) in cells:
        for dy in range(S):
            for dx in range(S):
                px[gx * S + dx, gy * S + dy] = bgs[fn(gx, gy)] + (255,)
    nx0 = CENTRE_COL - w2 // 2
    ny0 = round((y0 + y1) / 2 - h2 / 2)
    for j in range(h2):
        for i in range(w2):
            colour = cells.get((x0 + int((i + 0.5) / k), y0 + int((j + 0.5) / k)))
            if colour:
                for dy in range(S):
                    for dx in range(S):
                        px[(nx0 + i) * S + dx, (ny0 + j) * S + dy] = colour
    img.save(path)
    return True


if __name__ == "__main__":
    max_w = int(sys.argv[1]) if len(sys.argv) > 1 else 23
    os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    types = rc.type_of_cards()
    for f in sorted(os.listdir("assets/Snake_Cards")):
        name, kind = f[:-4], types.get(f[:-4].lower())
        if f.endswith(".png") and kind not in (None, "Brew", "Spell") and name not in LEGENDARY:
            if fit(os.path.join("assets/Snake_Cards", f), kind, max_w):
                print("fitted", name)
