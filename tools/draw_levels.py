"""Draws the level map: a parchment with six regions (each with its own scenery) and the snake winding round them.
Usage: python3 tools/draw_levels.py assets/backgrounds/LevelSnake.png LevelNodes.lua
The map is W x H art pixels saved at SCALE x. LevelNodes.lua gets the node positions (3 per region, the last one the
region's boss) and the region names/centres for Render.lua. Change SEED for a different, equally tangled path."""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

W, H, SCALE, R = 300, 960, 6, 10
SEED = 3
REGIONS = [  # name, centre, ground colour
    ("Mossy Garden", (105, 125), (112, 170, 70)),
    ("Frozen Lake", (195, 275), (196, 226, 236)),
    ("Venom Swamp", (105, 430), (76, 112, 62)),
    ("Haunted Ruins", (195, 585), (128, 112, 146)),
    ("Scorched Desert", (105, 740), (236, 196, 106)),
    ("Viper Peak", (195, 880), (158, 130, 104)),
]
PARCHMENT = [(232, 176, 76), (226, 168, 66), (238, 186, 90)]
LEVELS_PER_REGION = 3


def spline(points, step=0.6):
    p = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(p) - 2):
        for t in np.linspace(0, 1, 40, endpoint=False):
            a, b, c, d = (np.array(p[i + k], float) for k in (-1, 0, 1, 2))
            out.append(0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    out.append(np.array(points[-1], float))
    path = [out[0]]
    for q in out[1:]:
        if np.linalg.norm(q - path[-1]) >= step:
            path.append(q)
    return np.array(path)


def make_path(seed):
    """Round each region's scenery in a big loop, clockwise then anticlockwise; returns the path and each region's (first, last) waypoint index."""
    rng = random.Random(seed)
    pts, spans = [(150.0, 30.0)], []
    for r, (_, (cx, cy), _) in enumerate(REGIONS):
        sign = 1 if r % 2 == 0 else -1
        start = math.radians(200 if r % 2 == 0 else -20) + rng.uniform(-0.2, 0.2)
        first = len(pts)
        for k in range(9):
            angle = start + sign * math.radians(k * 36)
            rad = 58 + rng.uniform(-4, 6)
            pts.append((cx + rad * math.cos(angle), cy + rad * math.sin(angle) * 1.12))
        spans.append((first, len(pts) - 1))
    return pts, spans


def clear_enough(path):
    arc = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
    sub, sub_arc = path[::6], arc[::6]
    d = np.linalg.norm(sub[:, None] - sub[None], axis=2)
    far = np.abs(sub_arc[:, None] - sub_arc[None]) > 6 * R
    return d[far].min() > 2 * R + 4


for seed in range(SEED, SEED + 200):
    waypoints, spans = make_path(seed)
    path = spline(waypoints)
    inside = (path[:, 0] > 30).all() and (path[:, 0] < W - 30).all() and (path[:, 1] < H - 60).all()
    if inside and clear_enough(path):
        break
tangent = np.gradient(path, axis=0)
tangent /= np.linalg.norm(tangent, axis=1, keepdims=True)
arc = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])


# ---------------------------------------------------------------- scenery
rng = random.Random(5)
base = Image.new("RGB", (W, H))
bd = ImageDraw.Draw(base)
for y in range(H):  # mottled parchment
    for x in range(W):
        bd.point((x, y), fill=PARCHMENT[(x * 7 + y * 13 + (x * y) // 9) % 17 // 6 % 3])
for _ in range(900):
    x, y = rng.randrange(W), rng.randrange(H)
    bd.ellipse([x, y, x + rng.randint(2, 5), y + rng.randint(1, 3)], fill=(214, 156, 58))


def blob(cx, cy, rx, ry, colour):
    for k in range(7):
        a = rng.uniform(0, 6.28)
        d = rng.uniform(0, 0.25)
        bd.ellipse([cx + rx * d * math.cos(a) - rx * (1 - d), cy + ry * d * math.sin(a) - ry * (1 - d),
                    cx + rx * d * math.cos(a) + rx * (1 - d), cy + ry * d * math.sin(a) + ry * (1 - d)], fill=colour)


def tree(x, y, size=9, leaf=(40, 112, 52), trunk=(88, 58, 36)):
    bd.rectangle([x - 1, y, x + 1, y + size // 2 + 2], fill=trunk)
    bd.ellipse([x - size // 2 - 1, y - size, x + size // 2 + 1, y + 1], fill=(20, 60, 30))
    bd.ellipse([x - size // 2, y - size, x + size // 2, y], fill=leaf)
    bd.ellipse([x - size // 4, y - size + 1, x, y - size // 2], fill=(76, 150, 76))


def dead_tree(x, y, h=14):
    c = (46, 34, 38)
    bd.line([(x, y), (x, y - h)], fill=c, width=2)
    bd.line([(x, y - h // 2), (x - 5, y - h + 1)], fill=c)
    bd.line([(x, y - h // 2 - 2), (x + 5, y - h)], fill=c)
    bd.line([(x, y - h), (x - 2, y - h - 4)], fill=c)


def crystal(x, y, h=18):
    bd.polygon([(x - 5, y), (x, y - h), (x + 5, y)], fill=(90, 170, 232), outline=(40, 90, 160))
    bd.polygon([(x - 1, y), (x, y - h), (x + 5, y)], fill=(150, 214, 250))


def pillar(x, y, h=14, broken=False):
    bd.rectangle([x - 3, y - h, x + 3, y], fill=(150, 144, 160), outline=(70, 64, 86))
    bd.rectangle([x - 4, y - h - 2, x + 4, y - h], fill=(176, 170, 186), outline=(70, 64, 86))
    if broken:
        bd.polygon([(x - 3, y - h), (x + 3, y - h), (x, y - h + 5)], fill=(128, 112, 146))


def gravestone(x, y):
    bd.rectangle([x - 3, y - 8, x + 3, y], fill=(170, 166, 180), outline=(70, 64, 86))
    bd.ellipse([x - 3, y - 11, x + 3, y - 5], fill=(170, 166, 180), outline=(70, 64, 86))
    bd.line([(x, y - 7), (x, y - 3)], fill=(80, 76, 96))


def pyramid(x, y, s=22):
    bd.polygon([(x - s, y), (x, y - s), (x + s, y)], fill=(222, 178, 90), outline=(130, 90, 40))
    bd.polygon([(x, y - s), (x + s, y), (x + 4, y)], fill=(188, 142, 66))


def cactus(x, y):
    g, o = (62, 140, 70), (24, 70, 38)
    bd.rectangle([x - 2, y - 12, x + 2, y], fill=g, outline=o)
    bd.rectangle([x - 6, y - 8, x - 3, y - 6], fill=g, outline=o)
    bd.rectangle([x - 6, y - 12, x - 4, y - 7], fill=g, outline=o)
    bd.rectangle([x + 3, y - 6, x + 6, y - 4], fill=g, outline=o)
    bd.rectangle([x + 5, y - 10, x + 7, y - 5], fill=g, outline=o)


def mountain(x, y, w=26, h=30, snow=True):
    bd.polygon([(x - w, y), (x, y - h), (x + w, y)], fill=(122, 98, 78), outline=(56, 40, 36))
    bd.polygon([(x, y - h), (x + w, y), (x + 5, y)], fill=(92, 72, 58))
    if snow:
        bd.polygon([(x - 7, y - h + 10), (x, y - h), (x + 7, y - h + 10), (x + 3, y - h + 8), (x, y - h + 12), (x - 3, y - h + 8)], fill=(246, 246, 250))


def mushroom(x, y):
    bd.rectangle([x - 1, y - 3, x + 1, y], fill=(236, 226, 200))
    bd.ellipse([x - 4, y - 8, x + 4, y - 2], fill=(190, 50, 70))
    bd.point([(x - 2, y - 6), (x + 1, y - 5)], fill=(255, 255, 255))


def lily(x, y):
    bd.ellipse([x - 4, y - 2, x + 4, y + 2], fill=(86, 170, 76), outline=(30, 80, 40))
    bd.point((x + 2, y), fill=(255, 150, 190))


def temple(x, y):
    bd.rectangle([x - 12, y - 10, x + 12, y], fill=(228, 190, 70), outline=(120, 80, 20))
    bd.polygon([(x - 15, y - 10), (x, y - 22), (x + 15, y - 10)], fill=(200, 150, 40), outline=(120, 80, 20))
    bd.rectangle([x - 3, y - 7, x + 3, y], fill=(40, 20, 30))


def skull(x, y):
    bd.ellipse([x - 4, y - 6, x + 4, y], fill=(240, 236, 220), outline=(120, 110, 90))
    bd.point([(x - 2, y - 4), (x + 1, y - 4)], fill=(40, 30, 30))


names = {n: (c, g) for n, c, g in REGIONS}
for name, (cx, cy), ground in REGIONS:
    blob(cx, cy, 88, 84, tuple(int(v * 0.85) for v in ground))
    blob(cx, cy, 78, 74, ground)

(cx, cy), _ = names["Mossy Garden"]
for dx, dy in [(-24, -14), (-8, -26), (14, -22), (26, -6), (-26, 10), (22, 16), (-6, 22), (6, 4), (-14, -2)]:
    tree(cx + dx, cy + dy, 12 + (dx % 3))
bd.rectangle([cx - 8, cy + 6, cx + 8, cy + 9], fill=(150, 100, 56), outline=(70, 40, 20))
bd.rectangle([cx - 8, cy + 9, cx - 6, cy + 14], fill=(70, 40, 20))
bd.rectangle([cx + 6, cy + 9, cx + 8, cy + 14], fill=(70, 40, 20))

(cx, cy), _ = names["Frozen Lake"]
bd.ellipse([cx - 40, cy - 16, cx + 40, cy + 32], fill=(150, 200, 230), outline=(90, 140, 190))
bd.ellipse([cx - 30, cy - 8, cx + 14, cy + 14], fill=(190, 226, 244))
for dx, dy, h in [(-22, -10, 18), (-8, -18, 26), (6, -8, 22), (24, -14, 16), (-30, 8, 12), (30, 12, 14)]:
    crystal(cx + dx, cy + dy + 20, h)

(cx, cy), _ = names["Venom Swamp"]
bd.ellipse([cx - 38, cy - 14, cx + 38, cy + 30], fill=(60, 100, 56), outline=(30, 56, 36))
bd.ellipse([cx - 28, cy - 6, cx + 20, cy + 20], fill=(86, 140, 70))
for dx, dy in [(-22, 4), (-6, 12), (10, 2), (22, 14), (-12, -2)]:
    lily(cx + dx, cy + dy)
for dx, dy in [(-34, -4), (-20, -22), (6, -26), (30, -14), (36, 22), (-34, 20)]:
    dead_tree(cx + dx, cy + dy)
for dx, dy in [(-4, 34), (16, 30), (-30, 34), (30, 32)]:
    mushroom(cx + dx, cy + dy)

(cx, cy), _ = names["Haunted Ruins"]
for dx, dy, h, b in [(-26, -4, 18, False), (-12, -14, 22, True), (4, -8, 16, True), (20, -16, 24, False), (30, 0, 12, True)]:
    pillar(cx + dx, cy + dy + 14, h, b)
for dx, dy in [(-24, 22), (-8, 26), (10, 24), (28, 22)]:
    gravestone(cx + dx, cy + dy)
bd.line([(cx - 2, cy - 30), (cx - 2, cy - 14)], fill=(56, 40, 46), width=2)
bd.line([(cx - 7, cy - 25), (cx + 3, cy - 25)], fill=(56, 40, 46), width=2)

(cx, cy), _ = names["Scorched Desert"]
for dx, dy, w in [(-30, 22, 24), (6, 28, 30), (-6, -22, 22)]:
    bd.arc([cx + dx - w, cy + dy - 8, cx + dx + w, cy + dy + 12], 190, 350, fill=(196, 150, 70), width=2)
pyramid(cx + 4, cy + 6, 24)
pyramid(cx - 22, cy + 10, 14)
for dx, dy in [(-30, -8), (28, -10), (-4, 26), (34, 16)]:
    cactus(cx + dx, cy + dy)
skull(cx + 20, cy + 26)

(cx, cy), _ = names["Viper Peak"]
for dx, dy, w, h in [(-26, 12, 26, 28), (22, 14, 24, 24), (-4, 8, 30, 40)]:
    mountain(cx + dx, cy + dy, w, h)
temple(cx - 4, cy - 28)
bd.ellipse([cx + 30, cy + 22, cx + 44, cy + 30], fill=(214, 70, 40), outline=(120, 30, 20))  # lava pool

# frame
bd.rectangle([0, 0, W - 1, H - 1], outline=(52, 112, 56), width=6)
bd.rectangle([5, 5, W - 6, H - 6], outline=(34, 80, 40), width=1)

# ---------------------------------------------------------------- the snake
img = np.array(base)
GREEN, SHADE, TAN, TAN2, BLACK = (106, 190, 48), (94, 163, 28), (240, 208, 135), (189, 151, 66), (0, 0, 0)
xs = np.arange(W)
for y in range(H):
    pts = np.stack([xs, np.full(W, y)], 1)
    d = np.linalg.norm(pts[:, None, :] - path[None, ::2], axis=2)
    i, dist = d.argmin(1) * 2, d.min(1)
    for x in range(W):
        n, k = dist[x], min(i[x], len(path) - 1)
        if n > R:
            if n <= R + 2:  # a soft shadow beside the body
                img[y, x] = (img[y, x] * 0.72).astype(np.uint8)
            continue
        side = tangent[k][0] * (y - path[k][1]) - tangent[k][1] * (x - path[k][0])
        if n > R - 1:
            img[y, x] = BLACK
        elif side > R - 4:
            img[y, x] = TAN if int(arc[k] // 3) % 2 else TAN2
        elif side < -(R - 2):
            img[y, x] = SHADE
        else:
            img[y, x] = GREEN

end, t = path[-1], tangent[-1]
nrm = np.array([-t[1], t[0]])
for y in range(max(0, int(end[1]) - 30), min(H, int(end[1]) + 30)):
    for x in range(max(0, int(end[0]) - 30), min(W, int(end[0]) + 30)):
        v = np.array([x, y]) - end
        u, w = v @ t, v @ nrm
        e = ((u - 6) / 17) ** 2 + (w / 16) ** 2
        if u > -4 and e <= 1:
            img[y, x] = GREEN if e <= 0.82 else BLACK


def dot(u, w, colour, size=1):
    c = end + t * u + nrm * w
    img[int(c[1]) - size + 1:int(c[1]) + size + 1, int(c[0]) - size + 1:int(c[0]) + size + 1] = colour


for w in (-8, 8):
    dot(2, w, (255, 255, 255), 2)
    dot(3, w, BLACK, 1)
for u in range(24, 36):
    dot(u, 0, (214, 25, 25), 1)
for k in range(5):
    dot(36 + k, -2 - k, (214, 25, 25), 1)
    dot(36 + k, 2 + k, (214, 25, 25), 1)

Image.fromarray(img).resize((W * SCALE, H * SCALE), Image.NEAREST).save(sys.argv[1])

# Nodes: three per region along its loop, the last one at the loop's end (the region's boss)
def index_near(wp):
    return int(np.linalg.norm(path - np.array(wp), axis=1).argmin())


nodes = []
for first, last in spans:
    a, b = arc[index_near(waypoints[first])], arc[index_near(waypoints[last])]
    for f in (0.12, 0.52, 1.0):
        k = int(np.abs(arc - (a + (b - a) * f)).argmin())
        nodes.append((float(path[k][0]), float(path[k][1])))
with open(sys.argv[2], "w") as f:
    f.write("-- Generated by tools/draw_levels.py: the level map's size, where each level's node sits and its regions (art pixels)\n")
    f.write("-- Every region has %d levels; the last one is the region's boss.\n" % LEVELS_PER_REGION)
    f.write("return { width = %d, height = %d, scale = %d, per_region = %d,\n\tnodes = {\n" % (W, H, SCALE, LEVELS_PER_REGION))
    for x, y in nodes:
        f.write("\t\t{ %.1f, %.1f },\n" % (x, y))
    f.write("\t},\n\tregions = {\n")
    for name, (cx, cy), _ in REGIONS:
        f.write('\t\t{ name = "%s", x = %d, y = %d },\n' % (name, cx, cy))
    f.write("\t},\n}\n")
print("seed", seed, "length", int(arc[-1]))
