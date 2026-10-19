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


# ---- more bottle emblems (colour given) ----
def ec(f):
    return lambda col: (lambda d: f(d, col))

def em_shield(d, col):
    d.polygon([(11, 24), (21, 24), (21, 30), (16, 35), (11, 30)], fill=col)
def em_up(d, col):
    d.polygon([(16, 23), (21, 29), (18, 29), (18, 34), (14, 34), (14, 29), (11, 29)], fill=col)
def em_heart(d, col):
    d.ellipse([11, 24, 16, 29], fill=col); d.ellipse([16, 24, 21, 29], fill=col)
    d.polygon([(11, 27), (21, 27), (16, 34)], fill=col)
def em_drop(d, col):
    d.polygon([(16, 22), (20, 29), (12, 29)], fill=col); d.ellipse([12, 27, 20, 34], fill=col)
def em_bolt(d, col):
    d.polygon([(17, 22), (12, 29), (16, 29), (14, 35), (21, 27), (17, 27), (19, 22)], fill=col)
def em_thorn(d, col):
    for x in (12, 16, 20):
        d.polygon([(x - 2, 34), (x, 25), (x + 2, 34)], fill=col)
def em_fang(d, col):
    d.polygon([(11, 24), (15, 24), (13, 34)], fill=col); d.polygon([(17, 24), (21, 24), (19, 34)], fill=col)
def em_sun(d, col):
    d.ellipse([12, 24, 20, 32], fill=col)
    for a in range(0, 360, 45):
        r = math.radians(a); d.line([(16 + 6 * math.cos(r), 28 + 6 * math.sin(r)), (16 + 8 * math.cos(r), 28 + 8 * math.sin(r))], fill=col)
def em_leaf(d, col):
    d.polygon([(11, 33), (13, 25), (21, 24), (19, 32)], fill=col); d.line([(11, 33), (20, 25)], fill=c(60, 40, 20))
def em_shell(d, col):
    d.ellipse([10, 24, 22, 35], fill=col)
    for x in (13, 16, 19):
        d.line([(x, 25), (x, 34)], fill=c(120, 80, 50))
def em_coin(d, col):
    d.ellipse([11, 23, 21, 33], fill=col); d.ellipse([13, 25, 19, 31], outline=c(170, 120, 20))
def em_flame(d, col):
    d.polygon([(16, 22), (21, 29), (19, 34), (13, 34), (11, 29)], fill=col)
def em_diamond(d, col):
    d.polygon([(16, 22), (22, 28), (16, 35), (10, 28)], fill=col); d.line([(16, 22), (16, 35)], fill=c(255, 255, 255))
def em_star(d, col):
    pts = []
    for i in range(10):
        r = 7 if i % 2 == 0 else 3; a = math.radians(-90 + i * 36); pts.append((16 + r * math.cos(a), 28 + r * math.sin(a)))
    d.polygon(pts, fill=col)

# ---- more spell art ----
def sp_burst(d, col):
    for a in range(0, 360, 30):
        r = math.radians(a); d.line([(16, 24), (16 + (13 if a % 60 == 0 else 8) * math.cos(r), 24 + (13 if a % 60 == 0 else 8) * math.sin(r))], fill=col, width=2)
    d.ellipse([11, 19, 21, 29], fill=c(255, 255, 255))
def sp_heart(d, col):
    d.ellipse([5, 14, 16, 25], fill=col); d.ellipse([16, 14, 27, 25], fill=col)
    d.polygon([(5, 22), (27, 22), (16, 36)], fill=col)
    d.rectangle([14, 19, 18, 29], fill=c(255, 255, 255)); d.rectangle([11, 22, 21, 26], fill=c(255, 255, 255))
def sp_sword(d, col):
    d.polygon([(21, 6), (25, 10), (11, 28), (8, 25)], fill=col)
    d.rectangle([6, 25, 14, 28], fill=c(150, 100, 40)); d.polygon([(7, 27), (11, 27), (7, 33), (5, 31)], fill=c(120, 70, 30))
def sp_candle(d, col):
    d.rectangle([12, 22, 20, 36], fill=c(245, 235, 210))
    d.polygon([(16, 8), (20, 16), (18, 22), (14, 22), (12, 16)], fill=col)
    d.polygon([(16, 13), (18, 18), (17, 22), (15, 22), (14, 18)], fill=c(255, 255, 200))
def sp_mist(d, col):
    for i, y in enumerate((14, 20, 26, 32)):
        d.ellipse([4 + (i % 2) * 6, y, 22 + (i % 2) * 6, y + 5], fill=col)
def sp_dart(d, col):
    d.polygon([(5, 32), (22, 14), (24, 16), (7, 34)], fill=c(120, 80, 40)); d.polygon([(22, 10), (28, 12), (26, 20)], fill=col)
    d.polygon([(5, 32), (9, 30), (7, 34)], fill=col); d.polygon([(5, 32), (7, 28), (10, 31)], fill=col)
def sp_flake(d, col):
    for a in range(0, 180, 30):
        r = math.radians(a); d.line([(16 - 12 * math.cos(r), 24 - 12 * math.sin(r)), (16 + 12 * math.cos(r), 24 + 12 * math.sin(r))], fill=col, width=2)
    d.ellipse([13, 21, 19, 27], fill=c(255, 255, 255))
def sp_fire(d, col):
    d.polygon([(16, 6), (25, 20), (22, 33), (10, 33), (7, 20)], fill=col)
    d.polygon([(16, 14), (21, 24), (19, 33), (13, 33), (11, 24)], fill=c(255, 230, 100))
def sp_skull(d, col):
    d.ellipse([7, 10, 25, 28], fill=col); d.rectangle([11, 26, 21, 34], fill=col)
    d.ellipse([10, 17, 14, 22], fill=INK); d.ellipse([18, 17, 22, 22], fill=INK); d.polygon([(16, 22), (14, 26), (18, 26)], fill=INK)
def sp_blood(d, col):
    d.polygon([(16, 7), (24, 22), (8, 22)], fill=col); d.ellipse([8, 17, 24, 34], fill=col)
    d.point([(12, 24), (12, 25)], fill=c(255, 255, 255))
def sp_cross(d, col):
    d.line([(7, 10), (25, 34)], fill=col, width=3); d.line([(25, 10), (7, 34)], fill=col, width=3)
    d.ellipse([12, 17, 20, 27], outline=c(255, 255, 255))
def sp_pact(d, col):
    d.ellipse([5, 10, 27, 34], outline=col, width=2)
    d.polygon([(16, 13), (24, 29), (8, 29)], outline=col, width=2); d.ellipse([13, 21, 19, 27], fill=col)
def sp_loop(d, col):
    d.arc([6, 12, 26, 32], 30, 320, fill=col, width=3); d.polygon([(22, 9), (28, 18), (19, 18)], fill=col)
def sp_banner(d, col):
    d.rectangle([7, 8, 9, 36], fill=c(150, 100, 40)); d.polygon([(9, 9), (26, 9), (22, 16), (26, 23), (9, 23)], fill=col)
def sp_plus(d, col):
    d.ellipse([4, 9, 28, 33], fill=col); d.rectangle([14, 13, 18, 29], fill=c(255, 255, 255)); d.rectangle([10, 19, 22, 23], fill=c(255, 255, 255))
def sp_wall(d, col):
    for r, y in enumerate(range(10, 36, 7)):
        for x in range(4 - (r % 2) * 5, 28, 10):
            x0, x1 = max(x, 4), min(x + 8, 28)
            if x1 > x0:
                d.rectangle([x0, y, x1, y + 5], fill=col)
def sp_cloud(d, col):
    d.ellipse([4, 12, 18, 24], fill=col); d.ellipse([11, 8, 27, 22], fill=col); d.rectangle([6, 17, 26, 24], fill=col)
    for x, y in ((8, 28), (14, 32), (20, 28)):
        d.ellipse([x, y, x + 3, y + 3], fill=c(200, 255, 100))
def sp_star(d, col):
    d.polygon([(26, 6), (22, 12), (10, 28), (6, 30)], fill=col)
    pts = []
    for i in range(10):
        r = 8 if i % 2 == 0 else 3.5; a = math.radians(-90 + i * 36); pts.append((19 + r * math.cos(a), 26 + r * math.sin(a)))
    d.polygon(pts, fill=c(255, 255, 255))
def sp_book(d, col):
    d.polygon([(4, 12), (16, 15), (16, 34), (4, 31)], fill=col); d.polygon([(28, 12), (16, 15), (16, 34), (28, 31)], fill=c(235, 225, 200))
    for y in (18, 22, 26): d.line([(19, y), (26, y - 1)], fill=c(120, 100, 80))
def sp_quake(d, col):
    d.polygon([(2, 24), (10, 12), (16, 22), (22, 10), (30, 24)], fill=col)
    d.rectangle([2, 24, 30, 36], fill=c(110, 80, 50)); d.line([(14, 24), (17, 28), (13, 31), (18, 36)], fill=INK, width=2)
def sp_sun(d, col):
    d.ellipse([9, 15, 23, 29], fill=col)
    for a in range(0, 360, 30):
        r = math.radians(a); d.line([(16 + 9 * math.cos(r), 22 + 9 * math.sin(r)), (16 + 14 * math.cos(r), 22 + 14 * math.sin(r))], fill=col, width=2)
def sp_hourglass(d, col):
    d.rectangle([7, 8, 25, 10], fill=c(150, 100, 40)); d.rectangle([7, 34, 25, 36], fill=c(150, 100, 40))
    d.polygon([(9, 11), (23, 11), (16, 22)], fill=c(235, 245, 255)); d.polygon([(16, 22), (9, 33), (23, 33)], fill=col)
    d.line([(16, 22), (16, 30)], fill=col)

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
    "Iron_Tonic": lambda d: bottle(d, c(120, 135, 175), ec(em_shield)(c(235, 240, 255))),
    "Bitter_Tea": lambda d: bottle(d, c(130, 90, 40), ec(em_leaf)(c(120, 200, 80))),
    "Hearty_Broth": lambda d: bottle(d, c(230, 130, 60), ec(em_heart)(c(255, 240, 230))),
    "Honey_Mead": lambda d: bottle(d, c(240, 190, 60), ec(em_drop)(c(255, 250, 210))),
    "Antidote": lambda d: bottle(d, c(150, 235, 215), e_plus),
    "Swift_Tonic": lambda d: bottle(d, c(255, 235, 110), ec(em_bolt)(c(255, 255, 255))),
    "Thorn_Tonic": lambda d: bottle(d, c(170, 50, 70), ec(em_thorn)(c(255, 225, 225))),
    "Leech_Brew": lambda d: bottle(d, c(160, 30, 100), ec(em_fang)(c(255, 230, 240))),
    "Sunrise_Elixir": lambda d: bottle(d, c(255, 160, 70), ec(em_sun)(c(255, 250, 190))),
    "Berserk_Brew": lambda d: bottle(d, c(150, 20, 30), ec(em_up)(c(255, 170, 120))),
    "Shell_Brew": lambda d: bottle(d, c(220, 180, 130), ec(em_shell)(c(250, 235, 210))),
    "Vigour_Brew": lambda d: bottle(d, c(120, 215, 90), ec(em_up)(c(240, 255, 230))),
    "Gold_Draught": lambda d: bottle(d, c(240, 200, 50), ec(em_coin)(c(255, 240, 150))),
    "Fire_Draught": lambda d: bottle(d, c(240, 100, 30), ec(em_flame)(c(255, 235, 120))),
    "Giant_Brew": lambda d: bottle(d, c(80, 150, 70), ec(em_up)(c(255, 240, 120))),
    "Warding_Brew": lambda d: bottle(d, c(255, 245, 190), ec(em_shield)(c(230, 170, 50))),
    "Siphon_Brew": lambda d: bottle(d, c(190, 30, 60), ec(em_drop)(c(255, 200, 200))),
    "Blight_Brew": lambda d: bottle(d, c(170, 210, 50), e_skull),
    "Numbing_Brew": lambda d: bottle(d, c(170, 210, 250), e_flake),
    "Adamant_Draught": lambda d: bottle(d, c(110, 120, 200), ec(em_diamond)(c(220, 230, 255))),
    "Titan_Tonic": lambda d: bottle(d, c(130, 70, 190), ec(em_star)(c(255, 230, 140))),
    "Phoenix_Elixir": lambda d: bottle(d, c(255, 140, 50), ec(em_heart)(c(255, 230, 120))),
    "Dragon_Blood": lambda d: bottle(d, c(170, 20, 20), ec(em_diamond)(c(255, 120, 80))),
    "Spark": ec(sp_burst)(c(255, 235, 90)), "Mend": ec(sp_heart)(c(90, 210, 120)), "Sharpen": ec(sp_sword)(c(210, 220, 240)),
    "Candle_Whisper": ec(sp_candle)(c(255, 170, 60)), "Mist_Veil": ec(sp_mist)(c(200, 220, 240)), "Poison_Dart": ec(sp_dart)(c(120, 220, 40)),
    "Cold_Snap": ec(sp_flake)(c(150, 225, 255)), "Fireball": ec(sp_fire)(c(255, 110, 40)), "Execute": ec(sp_skull)(c(235, 235, 225)),
    "Drain_Life": ec(sp_blood)(c(200, 20, 70)), "Dispel": ec(sp_cross)(c(190, 150, 255)), "Blood_Pact": ec(sp_pact)(c(220, 40, 60)),
    "Encore": ec(sp_loop)(c(255, 160, 220)), "Battle_Cry": ec(sp_banner)(c(230, 60, 50)), "Mass_Heal": ec(sp_plus)(c(70, 210, 110)),
    "Iron_Wall": ec(sp_wall)(c(150, 160, 185)), "Plague": ec(sp_cloud)(c(120, 160, 40)), "Starfall": ec(sp_star)(c(140, 170, 255)),
    "Scholars_Gift": ec(sp_book)(c(70, 90, 210)), "Blizzard": ec(sp_flake)(c(215, 240, 255)), "Earthquake": ec(sp_quake)(c(170, 120, 70)),
    "Renewal": ec(sp_sun)(c(255, 215, 90)), "Time_Warp": ec(sp_hourglass)(c(170, 130, 255)),
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
