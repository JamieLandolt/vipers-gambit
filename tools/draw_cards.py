"""Draws Viper's Gambit snake cards in the existing pixel-art style.

Usage: python3 tools/draw_cards.py <out_dir>
Writes one PNG per card plus numbered contact sheets (sheet1.png, ...) for review.
Cards are built on assets/Snake_Cards/Snake.png, so corner numbers match the game's font.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

S, W, H = 5, 33, 48  # one art pixel = 5x5 screen pixels, card = 33x48 art pixels
BG = (118, 66, 138)
CARDS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "Snake_Cards") + "/"
GREEN, RED, BLUE, GOLD = (153, 229, 80), (235, 17, 17), (91, 110, 225), (199, 169, 9)
BLACK, YEL = (0, 0, 0), (251, 242, 54)
CANVAS, HEIGHT = 15, 35  # snake canvas width / rows between the card's top and bottom icons

FONT = {
    "0": ["111", "101", "101", "101", "111"], "1": ["1"] * 5,
    "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "001", "001", "001"],
    "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
}


# ----- card grid helpers -----
def load(name):
    im = Image.open(CARDS + name).convert("RGB")
    return [[im.getpixel((x * S + 2, y * S + 2)) for x in range(W)] for y in range(H)]


def save(grid, path):
    im = Image.new("RGB", (W * S, H * S))
    for y in range(H):
        for x in range(W):
            im.paste(grid[y][x], (x * S, y * S, x * S + S, y * S + S))
    im.save(path)


def in_corner(x, y):
    return x < 10 and y < 10


def fill(grid, x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = BG


def clear_art(grid):
    for y in range(2, 37):
        for x in range(2, 31):
            if not in_corner(x, y):
                grid[y][x] = BG


def draw_text(grid, text, x, y, color):
    for ch in text:
        for dy, row in enumerate(FONT[ch]):
            for dx, bit in enumerate(row):
                if bit == "1":
                    grid[y + dy][x + dx] = color
        x += len(FONT[ch][0]) + 1


def draw_stats(grid, cost, attack, defense, rarity):
    fill(grid, 3, 2, 5, 6)
    fill(grid, 3, 41, 7, 45)
    fill(grid, 26, 41, 30, 45)
    fill(grid, 13, 41, 19, 45)
    draw_text(grid, str(cost), 3, 2, GREEN)
    draw_text(grid, str(attack), 3, 41, RED)
    draw_text(grid, str(defense), 26 if defense > 9 else 27, 41, BLUE)
    for x in {1: [16], 2: [15, 17], 3: [14, 16, 18], 4: [13, 15, 17, 19]}[rarity]:
        for y in range(41, 45):
            grid[y][x] = GOLD


def stamp(grid, rows, top):
    """rows: lists of colours (None = transparent), centred horizontally on the card."""
    for dy, row in enumerate(rows):
        left = 16 - len(row) // 2
        for dx, c in enumerate(row):
            if c is not None:
                assert not in_corner(left + dx, top + dy), "art hits the cost corner"
                grid[top + dy][left + dx] = c


# ----- snake generator -----
def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def pad(row, offset):
    out = [None] * CANVAS
    left = (CANVAS - len(row)) // 2 + offset
    for i, c in enumerate(row):
        out[left + i] = c
    return out


def sway(i, amp, speed):
    return round(amp * math.sin(i * speed))


def body_row(i, w, spec, full_w):
    """One body row of inner width w; the pattern stays aligned to the full body width."""
    skip = (full_w - w) // 2
    inner = []
    for j in range(w):
        c = spec["pattern"](i, j + skip, full_w)
        inner.append(shade(c, 1.2) if j == 0 and w > 1 else shade(c, 0.8) if j == w - 1 and w > 1 else c)
    return [spec["outline"]] + inner + [spec["outline"]]


def head_rows(spec):
    B = spec["w"] + 2
    if spec.get("shape", "round") == "round":
        widths, er = [B - 2, B, B, B], 1
    else:
        widths, er = [B - 2, B, B + 2, B + 2, B + 2, B, B], 2
    base, out = spec.get("head", spec["pattern"](0, 0, spec["w"])), spec["outline"]
    rows = []
    for r, wr in enumerate(widths):
        row = [out] * wr if r == 0 else [out] + [base] * (wr - 2) + [out]
        if r == er:
            row[1] = row[-2] = spec["eye"]
            if wr >= 7 and spec.get("pupil", True):
                row[2] = row[-3] = BLACK
        rows.append(row)
    return rows, er


def make_snake(spec):
    w = spec["w"]
    rows, tongue = [], spec.get("tongue")
    if tongue:
        t = lambda s: [tongue if ch == "r" else None for ch in s]
        rows += [t("......r.r......"), t(".......r.......")]
    head, er = head_rows(spec)
    top = len(rows)
    rows += [pad(r, 0) for r in head]
    if spec.get("horns"):
        for side, sgn in ((0, -1), (1, 1)):
            wr = len(head[er])
            cx = (CANVAS - wr) // 2 + (1 if side == 0 else wr - 2)
            rows[top + er - 1][cx + sgn] = spec["horns"]
            rows[top + er - 2][cx + 2 * sgn] = spec["horns"]
    tail = spec.get("tail") or {7: [5, 5, 3, 3, 1, 1], 5: [3, 3, 1, 1], 3: [1, 1, 1]}[w]
    nbody = spec.get("height", HEIGHT) - len(rows) - len(tail) - 1
    amp, speed = spec.get("amp", 2), spec.get("speed", 0.45)
    for i in range(nbody):
        rows.append(pad(body_row(i, w, spec, w), sway(i, amp, speed)))
    for k, tw in enumerate(tail):
        i = nbody + k
        rows.append(pad(body_row(i, tw, spec, w), sway(i, amp, speed)))
    rows.append(pad([spec["outline"]], sway(nbody + len(tail), amp, speed)))
    return rows


def solid(c):
    return lambda i, j, w: c


def hash_(i, j, a, b, m):
    return (i * a + j * b) % m


# ----- patterns: (row, column, width) -> colour -----
def garter(i, j, w):
    return (240, 230, 120) if j == w // 2 else (50, 110, 40) if i % 3 == 0 and j in (1, w - 2) else (90, 170, 60)


def kingsnake(i, j, w):
    return (240, 236, 225) if i % 4 < 2 else (34, 28, 40)


def boa(i, j, w):
    k = i % 6
    return (200, 70, 40) if k == 3 and j == w // 2 else (100, 60, 32) if k in (2, 3, 4) and 0 < j < w - 1 else (170, 130, 80)


def ball_python(i, j, w):
    return (205, 150, 60) if hash_(i, j, 7, 13, 11) < 3 else (52, 38, 26)


def tree_boa(i, j, w):
    k, c = i % 4, w // 2
    on = (k == 0 and j == c) or (k == 1 and abs(j - c) == 1) or (k == 2 and abs(j - c) == 2)
    return (240, 245, 230) if on else (60, 190, 90)


def sea_snake(i, j, w):
    return (30, 60, 130) if i % 4 < 2 else (230, 230, 210)


def golden(i, j, w):
    return (255, 232, 120) if (i + j) % 3 == 0 else (190, 135, 25) if i % 4 == 2 and j % 2 else (232, 190, 50)


def mamba(i, j, w):
    return (120, 128, 140) if j == w // 2 else (82, 88, 98)


def horned(i, j, w):
    return (130, 90, 50) if i % 4 == 0 else (214, 180, 120)


def gaboon(i, j, w):
    k, c = i % 6, w // 2
    return (110, 70, 60) if abs(j - c) <= min(k, 5 - k) else (80, 50, 55) if j in (0, w - 1) and k in (2, 3) else (200, 160, 115)


def vine(i, j, w):
    return (215, 245, 110) if j == w // 2 else (150, 215, 50)


def lava(i, j, w):
    return (255, 225, 70) if hash_(i, j, 3, 7, 17) == 0 else (255, 130, 20) if hash_(i, j, 5, 11, 9) < 2 else (52, 26, 26)


def shadow(i, j, w):
    return (70, 46, 104) if hash_(i, j, 5, 3, 7) == 0 else (36, 24, 56)


def skeleton(i, j, w):
    return (250, 248, 235) if j == w // 2 else (170, 160, 130) if i % 2 == 0 else (235, 228, 205)


def ghost(i, j, w):
    return (238, 246, 255) if (i + j) % 4 == 0 else (200, 225, 245)


def toxic(i, j, w):
    return (160, 40, 210) if hash_(i, j, 7, 5, 9) < 2 else (110, 230, 70)


def corn(i, j, w):
    return (170, 40, 30) if i % 4 in (1, 2) and 0 < j < w - 1 else (235, 130, 40)


# ----- cards -----
T = RED
SNAKES = {  # name: (cost, attack, defense, rarity, spec)
    "Garter_Snake": (1, 2, 3, 1, dict(w=5, pattern=garter, outline=(24, 60, 20), eye=YEL, tongue=T)),
    "Kingsnake": (3, 5, 6, 2, dict(w=5, pattern=kingsnake, outline=(10, 6, 14), head=(34, 28, 40), eye=(255, 255, 255), pupil=False, tongue=T)),
    "Boa_Constrictor": (5, 7, 14, 3, dict(w=7, pattern=boa, outline=(60, 36, 20), head=(170, 130, 80), eye=YEL, tongue=T)),
    "Ball_Python": (3, 3, 9, 2, dict(w=7, pattern=ball_python, outline=(24, 16, 10), head=(52, 38, 26), eye=YEL, tongue=T)),
    "Tree_Boa": (4, 7, 6, 2, dict(w=5, pattern=tree_boa, outline=(20, 90, 50), head=(60, 190, 90), eye=YEL, tongue=T)),
    "Sea_Snake": (2, 4, 3, 1, dict(w=5, pattern=sea_snake, outline=(14, 30, 70), head=(30, 60, 130), eye=(255, 255, 255), pupil=False, tail=[5, 5, 5, 7, 7, 5, 3], tongue=T)),
    "Golden_Snake": (6, 10, 10, 3, dict(w=5, pattern=golden, outline=(120, 80, 10), head=(232, 190, 50), eye=(40, 200, 120), tongue=T)),
    "Black_Mamba": (4, 11, 3, 3, dict(w=5, pattern=mamba, outline=(20, 22, 28), head=(82, 88, 98), eye=(255, 240, 120), amp=1, speed=0.3, tongue=T)),
    "Horned_Viper": (3, 6, 4, 2, dict(w=5, pattern=horned, outline=(90, 60, 30), head=(214, 180, 120), shape="viper", horns=(240, 225, 190), eye=YEL, tongue=T)),
    "Gaboon_Viper": (6, 12, 11, 3, dict(w=7, pattern=gaboon, outline=(60, 36, 36), head=(200, 160, 115), shape="viper", eye=YEL, amp=1, speed=0.35, tongue=T)),
    "Vine_Snake": (1, 4, 1, 1, dict(w=3, pattern=vine, outline=(70, 110, 20), head=(150, 215, 50), eye=YEL, tongue=T)),
    "Lava_Snake": (5, 11, 6, 3, dict(w=5, pattern=lava, outline=(24, 10, 10), head=(52, 26, 26), eye=(255, 255, 150), tongue=(255, 130, 20))),
    "Shadow_Snake": (4, 9, 7, 3, dict(w=5, pattern=shadow, outline=(12, 6, 22), head=(36, 24, 56), eye=(255, 120, 255), pupil=False, tongue=(200, 60, 200))),
    "Skeleton_Snake": (2, 5, 5, 2, dict(w=5, pattern=skeleton, outline=(60, 52, 40), head=(235, 228, 205), eye=BLACK, pupil=False, amp=1)),
    "Ghost_Snake": (3, 4, 8, 2, dict(w=5, pattern=ghost, outline=(110, 140, 185), head=(200, 225, 245), eye=(40, 40, 100), pupil=False)),
    "Toxic_Snake": (3, 8, 4, 2, dict(w=5, pattern=toxic, outline=(30, 70, 20), head=(110, 230, 70), eye=YEL, tongue=(160, 40, 210))),
    "Corn_Snake": (2, 4, 3, 1, dict(w=5, pattern=corn, outline=(90, 30, 20), head=(235, 130, 40), eye=YEL, tongue=T)),
}

DULL = dict(eye=BLACK, pupil=False, amp=1, speed=0.35)
T1 = {  # plain tier-1 snakes: one flat colour, no pattern, no tongue
    "Grass_Snake": (1, 1, 2, 1, dict(w=5, pattern=solid((104, 150, 70)), outline=(50, 74, 34), **DULL)),
    "Brown_Snake": (1, 2, 1, 1, dict(w=5, pattern=solid((140, 100, 66)), outline=(70, 48, 30), **DULL)),
    "Grey_Snake": (1, 1, 3, 1, dict(w=5, pattern=solid((140, 144, 150)), outline=(70, 72, 80), **DULL)),
    "Dirt_Snake": (2, 2, 3, 1, dict(w=5, pattern=solid((170, 128, 84)), outline=(90, 62, 36), **DULL)),
    "Sand_Snake": (1, 2, 2, 1, dict(w=5, pattern=solid((214, 194, 140)), outline=(120, 104, 68), **DULL)),
    "Mud_Snake": (2, 2, 4, 1, dict(w=5, pattern=solid((84, 70, 48)), outline=(36, 28, 18), eye=(230, 230, 200), pupil=False, amp=1, speed=0.35)),
    "Pale_Snake": (1, 1, 1, 1, dict(w=5, pattern=solid((226, 208, 200)), outline=(130, 108, 104), **DULL)),
    "Worm_Snake": (1, 1, 2, 1, dict(w=3, pattern=solid((190, 140, 130)), outline=(100, 66, 60), height=22, **DULL)),
}

# Rattlesnake has a rattle, so it is drawn from strings; corners come from Copperhead's template
RATTLE_LEGEND = dict(o=(86, 62, 38), t=(186, 156, 100), l=(222, 198, 140), d=(120, 86, 48),
                     e=BLACK, g=YEL, r=RED, y=(232, 214, 150), s=(170, 140, 80))
RATTLE_HEAD = [
    "......r.r......", ".......r.......", ".....ooooo.....", "....ottttto....", "...ottttttto...",
    "..otgetttegto..", "..ottttttttto..", "...ottttttto...", "....ottttto....",
]
RATTLE_DIAMOND = ["ottttto", "otdddto", "oddlddo", "otdddto"]


def rattlesnake():
    row = lambda s: [RATTLE_LEGEND.get(ch) for ch in s]
    rows = [row(s) for s in RATTLE_HEAD]
    for i in range(15):
        rows.append(pad(row(RATTLE_DIAMOND[i % 4]), sway(i, 1, 0.35)))
    off = sway(15, 1, 0.35)
    for s in ["ottto", "ottto", "ottto", "oto", "oto", "ooo", "oyo", "oso", "ooo", "oyo", "oso"]:
        rows.append(pad(row(s), off))
    return rows


# Coral snake: red touches yellow
CORAL_BANDS = {
    "K": ((60, 52, 68), (36, 28, 40), (20, 14, 24)),
    "Y": ((255, 240, 110), (245, 220, 60), (200, 168, 20)),
    "R": ((240, 90, 80), (214, 42, 42), (160, 24, 24)),
}
CORAL_OUT = (10, 6, 14)


def coral_row(width, key):
    hi, base, shade_ = CORAL_BANDS[key]
    inner = {5: [hi, base, base, base, shade_], 3: [hi, base, shade_], 1: [base]}[width]
    return [CORAL_OUT] + inner + [CORAL_OUT]


def coral_snake():
    c = dict(o=CORAL_OUT, k=CORAL_BANDS["K"][1], w=(255, 255, 255), r=RED)
    head = ["......r.r......", ".......r.......", ".....ooooo.....", "....okkkkko....", "....okwkwko....", "....okkkkko...."]
    rows = [[c.get(ch) for ch in s] for s in head]
    seq = ["Y"] + ["R"] * 4 + ["Y"] + ["K"] * 2
    for i in range(22):
        rows.append(pad(coral_row(5, seq[i % len(seq)]), sway(i, 2, 0.4)))
    off = sway(22, 2, 0.4)
    for i, w in enumerate([3, 3, 3, 1, 1]):
        rows.append(pad(coral_row(w, seq[(22 + i) % len(seq)]), off))
    rows += [pad([CORAL_OUT] * 3, off), pad([CORAL_OUT], off)]
    return rows


# Hooded cobras are recolours of Cobra: (hood edge, hood, belly light, belly dark, eye)
COBRA_KEYS = [(62, 53, 77), (46, 39, 58), (173, 143, 103), (143, 121, 70), (251, 242, 54)]
COBRAS = {  # all cobras are T4
    "Cobra": ((4, 8, 15, 4), COBRA_KEYS),
    "King_Cobra": ((4, 8, 15, 4), [(128, 136, 60), (92, 104, 44)] + COBRA_KEYS[2:]),
    "Albino_Cobra": ((4, 9, 12, 4), [(250, 240, 235), (232, 215, 210), (240, 180, 170), (220, 150, 145), RED]),
    "Blood_Cobra": ((5, 12, 8, 4), [(170, 30, 40), (120, 16, 28), (110, 60, 60), (86, 44, 44), YEL]),
    "Frost_Cobra": ((4, 6, 14, 4), [(150, 210, 235), (100, 170, 215), (230, 245, 255), (190, 220, 240), (255, 255, 255)]),
}


def build(name):
    """Returns (grid, stats) for a card name."""
    if name in COBRAS:
        stats, colours = COBRAS[name]
        g, mapping = load("Cobra.png"), dict(zip(COBRA_KEYS, colours))
        for y in range(6, 37):
            for x in range(W):
                if not in_corner(x, y) and g[y][x] in mapping:
                    g[y][x] = mapping[g[y][x]]
        draw_stats(g, *stats)
        return g, stats
    if name == "Rattlesnake":
        g = load("Copperhead.png"); clear_art(g); stamp(g, rattlesnake(), 2)
        return g, None
    if name == "Coral_Snake":
        g = load("Snake.png"); clear_art(g); stamp(g, coral_snake(), 2)
        return g, None
    cost, atk, dfn, rar, spec = {**SNAKES, **T1}[name]
    g = load("Snake.png"); clear_art(g)
    stamp(g, make_snake(spec), 2 + (HEIGHT - spec.get("height", HEIGHT)) // 2)
    draw_stats(g, cost, atk, dfn, rar)
    return g, (cost, atk, dfn, rar)


def contact_sheet(names, first_no, path):
    font = ImageFont.load_default(size=16)
    sheet = Image.new("RGB", (W * S * 5, (H * S + 30) * 2), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    for k, name in enumerate(names):
        x, y = (k % 5) * W * S, (k // 5) * (H * S + 30)
        d.text((x + 8, y + 3), f"{first_no + k}  {name.replace('_', ' ')}", fill=(255, 255, 255), font=font)
        sheet.paste(Image.open(os.path.join(os.path.dirname(path), name + ".png")), (x, y + 30))
    sheet.save(path)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    names = ["Rattlesnake", "Coral_Snake"] + list(COBRAS) + list(SNAKES) + list(T1)
    for name in names:
        grid, stats = build(name)
        save(grid, os.path.join(out, name + ".png"))
        print(name, stats)
    for n in range(0, len(names), 10):
        contact_sheet(names[n:n + 10], n + 1, os.path.join(out, f"sheet{n // 10 + 1}.png"))
