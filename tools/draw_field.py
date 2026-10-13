"""Draws the play-field art: eight cells (two rows x four lanes), each lane a blend of its two snake types.
Usage:
  python3 tools/draw_field.py sheet OUT.png            contact sheet: 3 options for each lane
  python3 tools/draw_field.py atlas OUT.png L W T S    every left/right pair of types, for rearranged lanes
  python3 tools/draw_field.py build OUT.png L W T S    final field using look 1-3 for each type: Land Water Tree Spirit
                                                       (the shipped field is: build assets/Sprites/Playing_field.png 1 1 3 1)
Lanes (see play.lane_types in Play.lua): 1 Land/Water, 2 Water/Tree, 3 Tree/Spirit, 4 Land/Spirit.
The layout matches assets/Sprites/Playing_field.png: 949x539, cells are 210x240 at the offsets below."""
import sys
import numpy as np
from PIL import Image, ImageDraw

SCALE, W, H = 5, 42, 48  # one art pixel is 5 screen pixels; a cell is 42x48 art pixels
COLS, ROWS = [20, 250, 490, 720], [20, 280]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16


class Art:
    def __init__(self, base, seed):
        self.a = np.zeros((H, W, 3), np.uint8)
        self.a[:] = base
        self.rng = np.random.default_rng(seed)

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.a[int(y), int(x)] = c

    def rect(self, x, y, w, h, c):
        for j in range(h):
            for i in range(w):
                self.px(x + i, y + j, c)

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for t in range(n + 1):
            self.px(round(x0 + (x1 - x0) * t / n), round(y0 + (y1 - y0) * t / n), c)

    def disc(self, cx, cy, r, c, outline=None):
        for y in range(int(cy - r - 1), int(cy + r + 2)):
            for x in range(int(cx - r - 1), int(cx + r + 2)):
                d = (x - cx) ** 2 + (y - cy) ** 2
                if d <= r * r:
                    self.px(x, y, c)
                elif outline and d <= (r + 1) ** 2:
                    self.px(x, y, outline)

    def ring(self, cx, cy, r, c):
        for k in range(int(r * 8) + 8):
            t = k / (r * 8 + 8) * 2 * np.pi
            self.px(round(cx + r * np.cos(t)), round(cy + r * np.sin(t) * 0.7), c)

    def scatter(self, n, c, size=1):
        for _ in range(n):
            self.rect(int(self.rng.integers(0, W)), int(self.rng.integers(0, H)), size, size, c)


def shade(c, k):
    return tuple(int(max(0, min(255, v * k))) for v in c)


# ---------- Land ----------
def land_dunes(seed):
    a = Art((214, 176, 106), seed)
    for k, base in enumerate(range(6, H + 8, 11)):
        phase = seed + k * 1.7
        for x in range(W):
            ridge = base + round(3 * np.sin(x * 0.17 + phase))
            a.px(x, ridge, (244, 212, 140))
            for d in range(1, 5):
                a.px(x, ridge + d, (186, 146, 80) if (x + d) % 2 == 0 or d < 3 else (214, 176, 106))
    a.scatter(7, (140, 104, 60))
    a.scatter(4, (236, 200, 128))
    for _ in range(3):
        x, y = int(a.rng.integers(2, W - 3)), int(a.rng.integers(4, H - 4))
        a.line(x, y, x, y - 2, (150, 150, 70))
        a.px(x - 1, y - 3, (150, 150, 70))
        a.px(x + 1, y - 3, (150, 150, 70))
    return a.a


def land_canyon(seed):
    a = Art((150, 82, 52), seed)
    for y in range(H):
        wobble = round(1.5 * np.sin(y * 0.5 + seed))
        for x in range(W):
            band = (y // 6) % 2
            c = (168, 96, 60) if band else (132, 70, 44)
            if (x + y) % 5 == 0 and a.rng.random() < 0.3:
                c = shade(c, 1.2)
            a.px(x + wobble, y, c)
    for _ in range(5):
        x, y = int(a.rng.integers(0, W)), int(a.rng.integers(0, H))
        for _ in range(int(a.rng.integers(4, 9))):
            a.px(x, y, (74, 34, 26))
            x += int(a.rng.integers(-1, 2))
            y += int(a.rng.integers(0, 2))
    a.scatter(6, (200, 130, 84))
    return a.a


def land_ruins(seed):
    a = Art((176, 150, 110), seed)
    for ty in range(0, H, 8):
        for tx in range(-(ty // 8 % 2) * 5, W, 10):
            tile = shade((176, 150, 110), 0.9 + 0.2 * a.rng.random())
            a.rect(tx, ty, 10, 8, tile)
            a.rect(tx, ty, 10, 1, (206, 182, 140))
            a.rect(tx, ty + 7, 10, 1, (120, 98, 70))
            a.rect(tx + 9, ty, 1, 8, (120, 98, 70))
    for _ in range(3):
        x, y = int(a.rng.integers(1, W - 5)), int(a.rng.integers(1, H - 3))
        for i in range(4):
            a.px(x + i, y + (i % 2), (74, 130, 60))
    a.scatter(6, (96, 78, 56), 2)
    return a.a


# ---------- Water ----------
def water_waves(seed):
    a = Art((38, 92, 176), seed)
    for row in range(2, H, 6):
        for x in range(W):
            y = row + round(1.5 * np.sin(x * 0.45 + row * 0.7 + seed))
            a.px(x, y + 1, (30, 76, 150))
            if (x // 3 + row) % 3 != 0:
                a.px(x, y, (150, 210, 245))
            else:
                a.px(x, y, (60, 124, 206))
    return a.a


def water_deep(seed):
    a = Art((24, 52, 128), seed)
    for y in range(H):
        for x in range(W):
            if BAYER[y % 4][x % 4] < y / H * 0.6:
                a.px(x, y, (14, 32, 90))
    for _ in range(6):
        a.ring(int(a.rng.integers(4, W - 4)), int(a.rng.integers(4, H - 4)), int(a.rng.integers(3, 7)), (46, 92, 170))
    for _ in range(9):
        x, y = int(a.rng.integers(2, W - 2)), int(a.rng.integers(2, H - 2))
        a.disc(x, y, 1, (150, 205, 240))
        a.px(x, y, (230, 245, 255))
    return a.a


def water_pond(seed):
    a = Art((30, 120, 130), seed)
    for y in range(H):
        for x in range(W):
            if BAYER[y % 4][x % 4] < 0.25 + 0.15 * np.sin(x * 0.2 + y * 0.3 + seed):
                a.px(x, y, (44, 142, 150))
    for _ in range(4):
        x, y = int(a.rng.integers(5, W - 5)), int(a.rng.integers(5, H - 5))
        a.disc(x, y, 4, (70, 150, 60), (30, 90, 50))
        a.line(x, y, x + 5, y - 2, (30, 120, 130))
        a.px(x - 1, y - 1, (240, 150, 190))
    for x in range(1, W, 6):
        h = int(a.rng.integers(5, 10))
        a.line(x, H - 1, x + 1, H - h, (24, 84, 50))
        a.rect(x + 1, H - h - 2, 1, 2, (110, 70, 40))
    return a.a


# ---------- Tree ----------
def tree_canopy(seed):
    a = Art((24, 70, 36), seed)
    blobs = sorted([(int(a.rng.integers(0, H)), int(a.rng.integers(0, W))) for _ in range(34)])
    for y, x in blobs:
        r = int(a.rng.integers(3, 6))
        a.disc(x, y + 1, r, (22, 62, 34))
        a.disc(x, y, r, (44, 120, 56))
        a.disc(x - 1, y - 1, max(r - 2, 1), (74, 164, 72))
        a.px(x - 1, y - 2, (118, 200, 100))
    return a.a


def tree_vines(seed):
    a = Art((36, 48, 32), seed)
    for tx in (4, 17, 31):
        x = tx + int(a.rng.integers(-1, 2))
        a.rect(x, 0, 7, H, (92, 62, 40))
        a.rect(x, 0, 2, H, (126, 88, 56))
        a.rect(x + 5, 0, 2, H, (58, 38, 26))
        for y in range(2, H, 7):
            a.px(x + 3, y, (58, 38, 26))
    for vx in range(3, W, 5):
        length = int(a.rng.integers(10, 34))
        for y in range(length):
            x = vx + round(1.2 * np.sin(y * 0.4 + vx))
            a.px(x, y, (60, 150, 60))
            if y % 5 == 4:
                a.px(x + 1, y, (110, 200, 90))
                a.px(x - 1, y + 1, (84, 176, 76))
    return a.a


def tree_roots(seed):
    a = Art((52, 102, 52), seed)
    for y in range(H):
        for x in range(W):
            if BAYER[y % 4][x % 4] < 0.3 + 0.2 * np.sin(x * 0.3 + y * 0.2 + seed):
                a.px(x, y, (74, 128, 62))
    for k in range(4):
        y0 = int(a.rng.integers(4, H - 4))
        for x in range(W):
            y = y0 + round(4 * np.sin(x * 0.2 + k * 2 + seed))
            a.px(x, y, (84, 56, 36))
            a.px(x, y + 1, (60, 40, 28))
            a.px(x, y - 1, (118, 82, 52))
    for _ in range(3):
        x, y = int(a.rng.integers(3, W - 3)), int(a.rng.integers(3, H - 3))
        a.rect(x, y, 1, 3, (230, 220, 200))
        a.rect(x - 1, y - 2, 3, 2, (214, 56, 50))
        a.px(x, y - 2, (250, 240, 230))
    return a.a


# ---------- Spirit ----------
def spirit_fog(seed):
    a = Art((60, 36, 110), seed)
    for y in range(H):
        for x in range(W):
            if BAYER[y % 4][x % 4] < y / H * 0.7:
                a.px(x, y, (96, 62, 154))
    for row in range(4, H, 9):
        for x in range(W):
            y = row + round(2 * np.sin(x * 0.25 + row + seed))
            if BAYER[y % 4][x % 4] < 0.6:
                a.px(x, y, (150, 112, 212))
    for _ in range(6):
        x, y = int(a.rng.integers(2, W - 2)), int(a.rng.integers(6, H - 2))
        a.px(x, y, (240, 230, 255))
        a.px(x, y + 1, (190, 160, 240))
        a.px(x, y + 2, (130, 96, 200))
    return a.a


def spirit_graves(seed):
    a = Art((44, 28, 76), seed)
    for y in range(H // 2, H):
        for x in range(W):
            if BAYER[y % 4][x % 4] < (y - H / 2) / H * 1.1:
                a.px(x, y, (88, 62, 130))
    for x0 in (6, 22, 34):
        y0 = int(a.rng.integers(14, H - 12))
        a.rect(x0, y0 + 2, 7, 9, (124, 118, 142))
        a.rect(x0 + 1, y0, 5, 2, (124, 118, 142))
        a.rect(x0, y0 + 2, 1, 9, (160, 154, 178))
        a.rect(x0 + 6, y0 + 2, 1, 9, (84, 78, 104))
        a.rect(x0 + 3, y0 + 3, 1, 4, (60, 54, 80))
        a.rect(x0 + 2, y0 + 4, 3, 1, (60, 54, 80))
    for _ in range(4):
        x, y = int(a.rng.integers(2, W - 4)), int(a.rng.integers(4, H - 3))
        a.line(x, y, x + 3, y + 2, (232, 226, 210))
        a.line(x, y + 2, x + 3, y, (232, 226, 210))
    return a.a


def spirit_void(seed):
    a = Art((22, 14, 44), seed)
    a.scatter(16, (150, 130, 210))
    a.scatter(5, (240, 235, 255))
    cx, cy = int(W * 0.74), H // 2
    for r, c in ((10, (70, 40, 130)), (8, (110, 70, 190)), (6, (170, 120, 240))):
        a.ring(cx, cy, r, c)
    pts = [(cx + round(5 * np.sin(k * 4 * np.pi / 5)), cy - round(5 * np.cos(k * 4 * np.pi / 5))) for k in range(6)]
    for p, q in zip(pts, pts[1:]):
        a.line(p[0], p[1], q[0], q[1], (200, 160, 255))
    a.disc(cx, cy, 2, (240, 220, 255))
    return a.a


LAND = [land_dunes, land_canyon, land_ruins]
WATER = [water_waves, water_deep, water_pond]
TREE = [tree_canopy, tree_vines, tree_roots]
SPIRIT = [spirit_fog, spirit_graves, spirit_void]
LANES = [(LAND, WATER), (WATER, TREE), (TREE, SPIRIT), (LAND, SPIRIT)]


def blend(left, right, seed):
    """Left type fades into the right one across a wavy, dithered seam in the middle"""
    out = left.copy()
    for y in range(H):
        seam = W / 2 + 2 * np.sin(y * 0.45 + seed)
        for x in range(W):
            d = x - seam
            if d > 3 or (d >= -3 and BAYER[y % 4][x % 4] < (d + 3) / 6):
                out[y, x] = right[y, x]
    return out


def cell(lane, option, row):
    left, right = LANES[lane]
    seed = lane * 10 + row * 3 + option
    return blend(left[option](seed), right[option](seed + 100), seed)


def upscale(a):
    return np.kron(a, np.ones((SCALE, SCALE, 1), np.uint8))


def build(land, water, tree, spirit):
    looks = {id(LAND): land, id(WATER): water, id(TREE): tree, id(SPIRIT): spirit}
    img = np.zeros((539, 949, 3), np.uint8)
    for lane, (left, right) in enumerate(LANES):
        for row, y in enumerate(ROWS):
            seed = lane * 10 + row * 3
            a = blend(left[looks[id(left)]](seed), right[looks[id(right)]](seed + 100), seed)
            img[y:y + H * SCALE, COLS[lane]:COLS[lane] + W * SCALE] = upscale(a)
    return Image.fromarray(img).convert("RGBA")


def atlas(land, water, tree, spirit):
    """Every ordered pair of types as a lane cell, for lanes the player rearranges (Lane_Tiles.png).
    The tile for (left, right) in row r is at x = (left * 2 + r) * 210, y = right * 240, with the types
    numbered Land 0, Water 1, Tree 2, Spirit 3."""
    types, looks = [LAND, WATER, TREE, SPIRIT], [land, water, tree, spirit]
    img = np.zeros((4 * H * SCALE, 8 * W * SCALE, 3), np.uint8)
    for left in range(4):
        for right in range(4):
            for row in range(2):
                seed = (left * 4 + right) * 10 + row * 3
                a = blend(types[left][looks[left]](seed), types[right][looks[right]](seed + 100), seed)
                x, y = (left * 2 + row) * W * SCALE, right * H * SCALE
                img[y:y + H * SCALE, x:x + W * SCALE] = upscale(a)
    return Image.fromarray(img).convert("RGBA")


def sheet():
    names = [["Dunes + Waves", "Canyon + Deep water", "Ruins + Lily pond"],
             ["Waves + Canopy", "Deep water + Vines", "Lily pond + Mossy roots"],
             ["Canopy + Fog", "Vines + Graveyard", "Mossy roots + Void runes"],
             ["Dunes + Fog", "Canyon + Graveyard", "Ruins + Void runes"]]
    gap, label = 16, 22
    cw, ch = W * SCALE, H * SCALE
    img = Image.new("RGB", (3 * cw + 4 * gap, 4 * (ch + label) + 5 * gap), (20, 16, 32))
    d = ImageDraw.Draw(img)
    for lane in range(4):
        for option in range(3):
            x, y = gap + option * (cw + gap), gap + lane * (ch + label + gap)
            d.text((x, y + 2), f"Lane {lane + 1} option {option + 1}: {names[lane][option]}", fill=(255, 255, 255))
            img.paste(Image.fromarray(upscale(cell(lane, option, 0))), (x, y + label))
    return img


if __name__ == "__main__":
    mode, out = sys.argv[1], sys.argv[2]
    if mode == "sheet":
        sheet().save(out)
    elif mode == "atlas":
        picks = [int(p) - 1 for p in sys.argv[3:7]]
        atlas(*(picks if len(picks) == 4 else [0, 0, 0, 0])).save(out)
    else:
        picks = [int(p) - 1 for p in sys.argv[3:7]]
        build(*(picks if len(picks) == 4 else [0, 0, 0, 0])).save(out)
