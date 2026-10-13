"""Draws the 33x48 purple base cards for the brews and spells in Brews.lua (art, cost and tier bars; no attack/defense).
Usage: python3 tools/draw_brews.py SRC_DIR stats.json OUT_DIR
SRC_DIR holds the original purple snake cards (one is used as the frame template), stats.json comes from tools/dump_stats.lua.
Then run tools/recolour_cards.py on OUT_DIR together with the snake cards (see that file)."""
import json, math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_cards
from PIL import Image, ImageDraw

def c(r, g, b, a=255):
    return (r, g, b, a)

GLASS, GLASS2, CORK = c(214, 232, 240), c(150, 176, 190), c(150, 100, 60)
INK = c(30, 20, 40)

def bottle(d, liquid, emblem):
    d.rectangle([14, 11, 18, 16], fill=GLASS2)                 # neck
    d.rectangle([13, 9, 19, 11], fill=CORK)                    # cork
    d.ellipse([7, 15, 25, 36], fill=GLASS2)                    # glass
    d.ellipse([8, 16, 24, 35], fill=GLASS)
    d.ellipse([9, 21, 23, 35], fill=liquid)                    # potion
    d.rectangle([9, 24, 23, 28], fill=liquid)
    d.point([(11, 19), (11, 20)], fill=c(255, 255, 255))       # glint
    emblem(d)
    d.line([(9, 21), (23, 21)], fill=tuple(min(255, v + 50) for v in liquid[:3]) + (255,))

def put(d, pts, colour):
    d.point(pts, fill=colour)

def e_stone(d):
    for (x, y) in ((13, 26), (17, 28), (15, 31), (19, 25), (12, 30)):
        d.rectangle([x, y, x + 2, y + 1], fill=c(90, 90, 100))

def e_plus(d):
    d.rectangle([15, 24, 17, 31], fill=c(240, 255, 240))
    d.rectangle([12, 27, 20, 28], fill=c(240, 255, 240))

def e_skull(d):
    d.ellipse([12, 24, 20, 31], fill=c(240, 235, 220))
    d.rectangle([14, 31, 18, 33], fill=c(240, 235, 220))
    put(d, [(14, 27), (15, 27), (17, 27), (18, 27)], INK)

def e_swirl(d):
    d.arc([11, 23, 21, 33], 0, 270, fill=c(235, 235, 240), width=1)
    d.arc([14, 26, 18, 30], 90, 360, fill=c(235, 235, 240), width=1)

def e_flame(d):
    d.polygon([(16, 22), (21, 29), (19, 34), (13, 34), (11, 29)], fill=c(255, 220, 90))
    d.polygon([(16, 26), (19, 31), (17, 34), (14, 34), (13, 31)], fill=c(255, 120, 40))

def e_flake(d):
    for a in range(0, 180, 60):
        r = math.radians(a)
        d.line([(16 - 5 * math.cos(r), 28 - 5 * math.sin(r)), (16 + 5 * math.cos(r), 28 + 5 * math.sin(r))], fill=c(235, 250, 255))

def e_ghost(d):
    d.ellipse([12, 23, 20, 31], fill=c(250, 252, 255))
    d.rectangle([12, 27, 20, 34], fill=c(250, 252, 255))
    d.polygon([(12, 34), (14, 32), (16, 34), (18, 32), (20, 34)], fill=GLASS)
    put(d, [(14, 27), (14, 28), (18, 27), (18, 28)], INK)

# ---- spell art (drawn straight onto the card) ----
def eye(d):
    d.ellipse([5, 17, 27, 33], fill=c(245, 245, 235))
    d.ellipse([11, 18, 21, 32], fill=c(80, 110, 230))
    d.ellipse([14, 21, 18, 29], fill=INK)
    d.point([(13, 21)], fill=c(255, 255, 255))
    for x in (8, 12, 16, 20, 24):
        d.line([(x, 14), (x, 11)], fill=c(200, 210, 255))

def well(d):
    d.ellipse([5, 22, 27, 36], fill=c(60, 40, 90))
    d.ellipse([7, 24, 25, 34], fill=c(170, 80, 230))
    d.ellipse([10, 26, 22, 32], fill=c(120, 40, 180))
    d.polygon([(16, 10), (21, 20), (16, 25), (11, 20)], fill=c(200, 120, 255))
    d.point([(14, 18)], fill=c(255, 255, 255))

def rain(d):
    d.ellipse([4, 12, 18, 24], fill=c(200, 215, 230))
    d.ellipse([11, 10, 27, 24], fill=c(225, 235, 245))
    d.rectangle([6, 20, 26, 24], fill=c(225, 235, 245))
    for x, y in ((8, 27), (13, 30), (18, 27), (23, 31), (10, 34), (20, 35)):
        d.line([(x, y), (x - 1, y + 3)], fill=c(80, 200, 160), width=1)

def ward(d):
    d.polygon([(6, 13), (26, 13), (26, 26), (16, 36), (6, 26)], fill=c(190, 140, 40))
    d.polygon([(8, 15), (24, 15), (24, 25), (16, 33), (8, 25)], fill=c(255, 215, 80))
    d.rectangle([15, 17, 17, 31], fill=c(190, 140, 40))
    d.rectangle([10, 21, 22, 23], fill=c(190, 140, 40))

def nova(d):
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.line([(16, 24), (16 + 12 * math.cos(r), 24 + 12 * math.sin(r))], fill=c(150, 225, 255), width=2 if a % 90 == 0 else 1)
    d.ellipse([12, 20, 20, 28], fill=c(235, 250, 255))

def storm(d):
    d.ellipse([4, 11, 18, 22], fill=c(80, 80, 100))
    d.ellipse([11, 10, 27, 22], fill=c(100, 100, 125))
    d.rectangle([6, 17, 26, 22], fill=c(100, 100, 125))
    d.polygon([(17, 20), (11, 28), (16, 28), (13, 37), (23, 25), (17, 25), (20, 20)], fill=c(255, 240, 80))

def meteor(d):
    d.polygon([(4, 12), (9, 14), (20, 24), (15, 29)], fill=c(255, 160, 60))      # tail
    d.polygon([(7, 8), (12, 12), (22, 24), (17, 28)], fill=c(255, 110, 40))
    d.ellipse([15, 21, 28, 34], fill=c(110, 60, 40))
    d.ellipse([17, 23, 26, 32], fill=c(180, 90, 50))
    d.point([(19, 25), (23, 28), (21, 30)], fill=c(255, 200, 120))

ART = {
    "Stoneskin_Tonic": lambda d: bottle(d, c(130, 135, 150), e_stone),
    "Regrowth_Brew": lambda d: bottle(d, c(70, 200, 100), e_plus),
    "Venom_Elixir": lambda d: bottle(d, c(160, 70, 210), e_skull),
    "Smoke_Draught": lambda d: bottle(d, c(90, 90, 100), e_swirl),
    "Rage_Draught": lambda d: bottle(d, c(220, 50, 40), e_flame),
    "Frostbrew": lambda d: bottle(d, c(90, 190, 240), e_flake),
    "Ghost_Tonic": lambda d: bottle(d, c(190, 200, 235), e_ghost),
    "Arcane_Insight": eye, "Venom_Well": well, "Healing_Rain": rain, "Guardian_Ward": ward,
    "Frost_Nova": nova, "Lightning_Storm": storm, "Meteor_Strike": meteor,
}

if __name__ == "__main__":
    src, stats_file, out = sys.argv[1:4]
    stats = json.load(open(stats_file))
    draw_cards.CARDS = src.rstrip("/") + "/"
    os.makedirs(out, exist_ok=True)
    for name, art in ART.items():
        cost, _, _, rarity, kind = stats[name]
        grid = draw_cards.load("Brown_Snake.png")
        draw_cards.clear_art(grid)
        draw_cards.fill(grid, 3, 2, 5, 6)
        draw_cards.fill(grid, 3, 41, 7, 45)
        draw_cards.fill(grid, 26, 41, 30, 45)
        draw_cards.fill(grid, 13, 41, 19, 45)
        draw_cards.draw_text(grid, str(cost), 3, 2, draw_cards.GREEN)
        for x in {1: [16], 2: [15, 17], 3: [14, 16, 18], 4: [13, 15, 17, 19]}[rarity]:
            for y in range(41, 45):
                grid[y][x] = draw_cards.GOLD
        layer = Image.new("RGBA", (33, 48), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        art(d)
        px = layer.load()
        # an outline around the art keeps it readable on any card colour
        solid = {(x, y) for x in range(33) for y in range(48) if px[x, y][3] > 0}
        for x, y in list(solid):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n not in solid and 0 <= n[0] < 33 and 0 <= n[1] < 48:
                    px[n] = (20, 12, 28, 255)
        for y in range(2, 38):
            for x in range(2, 31):
                if px[x, y][3] > 0 and not draw_cards.in_corner(x, y):
                    grid[y][x] = px[x, y][:3]
        draw_cards.save(grid, os.path.join(out, name + ".png"))
