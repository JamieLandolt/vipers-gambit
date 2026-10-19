"""Draws the level map: a tall map of six biome bands with scenery, and one smooth snake weaving down through them.
Usage: python3 tools/draw_levels.py assets/backgrounds/LevelSnake.png LevelNodes.lua
The map is W x H art pixels saved at SCALE x. LevelNodes.lua gets the node positions (3 per biome, the last one the
biome's boss) and the biome names/centres for Render.lua."""
import math, random, sys
import numpy as np
from PIL import Image, ImageDraw

W, H, SCALE, R = 320, 660, 6, 10
BAND = H // 6
AMP, WAVE = 78, 230  # the snake's sideways swing and the height of one S
LEVELS_PER_REGION = 3
BIOMES = [  # name, ground colour, speckle colour
    ("Mossy Garden", (112, 170, 70), (84, 140, 56)),
    ("Frozen Lake", (196, 226, 236), (236, 248, 252)),
    ("Venom Swamp", (76, 112, 62), (52, 84, 52)),
    ("Haunted Ruins", (128, 112, 146), (98, 84, 118)),
    ("Scorched Desert", (236, 196, 106), (214, 166, 80)),
    ("Viper Peak", (158, 130, 104), (122, 98, 78)),
]

# ---------------------------------------------------------------- the path: a smooth sine wave down the map
ys = np.arange(26, H - 34, 0.5)
path = np.stack([W / 2 + AMP * np.sin(2 * math.pi * (ys - 26) / WAVE), ys], 1)
tangent = np.gradient(path, axis=0)
tangent /= np.linalg.norm(tangent, axis=1, keepdims=True)
arc = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])

# ---------------------------------------------------------------- ground
rng = random.Random(5)
wobble = [rng.uniform(0, 6.28) for _ in range(3)]
base = Image.new("RGB", (W, H))
bd = ImageDraw.Draw(base)
for y in range(H):
    for x in range(W):
        yy = y + 5 * math.sin(x / 23 + wobble[0]) + 3 * math.sin(x / 9 + wobble[1])  # wavy borders between biomes
        b = min(5, max(0, int(yy // BAND)))
        ground, speck = BIOMES[b][1], BIOMES[b][2]
        near = abs(yy - (b + 1) * BAND) < 2 and b < 5
        bd.point((x, y), fill=tuple(int(v * 0.8) for v in ground) if near else (speck if (x * 7 + y * 13 + x * y // 5) % 19 == 0 else ground))


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




def band_of(y):
    return min(5, int(y // BAND))


def scatter(biome, items, count):
    """Drops `count` random pieces of scenery in a biome, clear of the snake and of each other."""
    placed = []
    for _ in range(count * 40):
        if len(placed) >= count:
            break
        x, y = rng.randrange(14, W - 14), rng.randrange(biome * BAND + 14, (biome + 1) * BAND - 4)
        if np.linalg.norm(path - (x, y), axis=1).min() < R + 9 or any(math.hypot(x - a, y - b) < 15 for a, b in placed):
            continue
        placed.append((x, y))
    for x, y in sorted(placed, key=lambda p: p[1]):
        rng.choice(items)(x, y)


def lake(x, y):
    bd.ellipse([x - 13, y - 5, x + 13, y + 5], fill=(150, 200, 230), outline=(90, 140, 190))
    bd.ellipse([x - 8, y - 3, x + 2, y + 1], fill=(190, 226, 244))


def pond(x, y):
    bd.ellipse([x - 11, y - 5, x + 11, y + 5], fill=(60, 100, 56), outline=(30, 56, 36))
    bd.ellipse([x - 7, y - 3, x + 3, y + 1], fill=(86, 140, 70))


def bush(x, y):
    bd.ellipse([x - 5, y - 5, x + 5, y + 1], fill=(52, 124, 56), outline=(24, 70, 36))
    bd.point([(x - 2, y - 3), (x + 2, y - 2)], fill=(250, 120, 150))


def rock(x, y):
    bd.ellipse([x - 4, y - 4, x + 4, y + 1], fill=(140, 134, 142), outline=(70, 64, 80))


def snowman(x, y):
    bd.ellipse([x - 4, y - 5, x + 4, y + 1], fill=(250, 252, 255), outline=(120, 150, 190))
    bd.ellipse([x - 3, y - 10, x + 3, y - 4], fill=(250, 252, 255), outline=(120, 150, 190))
    bd.point([(x - 1, y - 8), (x + 1, y - 8)], fill=(30, 30, 40))


def lava(x, y):
    bd.ellipse([x - 6, y - 3, x + 6, y + 3], fill=(214, 70, 40), outline=(120, 30, 20))
    bd.ellipse([x - 3, y - 1, x + 2, y + 1], fill=(255, 190, 70))


def crystals(x, y):
    crystal(x, y, 14)
    crystal(x + 6, y + 2, 9)


def trees2(x, y):
    tree(x, y, 12)


def pines(x, y):
    bd.polygon([(x - 5, y), (x, y - 14), (x + 5, y)], fill=(34, 96, 66), outline=(16, 52, 40))
    bd.polygon([(x - 4, y - 5), (x, y - 17), (x + 4, y - 5)], fill=(46, 120, 80), outline=(16, 52, 40))


def snowy_pine(x, y):
    pines(x, y)
    bd.polygon([(x - 2, y - 12), (x, y - 17), (x + 2, y - 12)], fill=(250, 252, 255))


def sand_mound(x, y):
    bd.arc([x - 9, y - 5, x + 9, y + 5], 190, 350, fill=(196, 150, 70), width=2)


def small_pyramid(x, y):
    pyramid(x, y, 14)


def peak(x, y):
    mountain(x, y + 2, 16, 22)


def big_peak(x, y):
    mountain(x, y + 2, 20, 28)


SCENES = [
    (0, [trees2, trees2, trees2, bush, bush, rock], 34),
    (1, [snowy_pine, snowy_pine, crystals, crystals, lake, snowman, rock], 30),
    (2, [dead_tree, dead_tree, pond, lily, mushroom, mushroom, lily], 34),
    (3, [pillar, lambda x, y: pillar(x, y, 12, True), gravestone, gravestone, dead_tree, rock], 32),
    (4, [cactus, cactus, small_pyramid, sand_mound, sand_mound, skull, rock], 30),
    (5, [peak, big_peak, peak, lava, rock, rock], 26),
]
for biome, items, count in SCENES:
    scatter(biome, items, count)
temple(W - 54 if path[-1][0] < W / 2 else 54, H - 58)

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

# Nodes: three per biome, evenly spaced along the snake's part of that biome; the last one is the biome's boss
nodes = []
for b in range(6):
    ks = np.where((path[:, 1] >= b * BAND) & (path[:, 1] < (b + 1) * BAND))[0]
    a, z = arc[ks[0]], arc[ks[-1]]
    for f in (1 / 6, 3 / 6, 5 / 6):
        k = int(np.abs(arc - (a + (z - a) * f)).argmin())
        nodes.append((float(path[k][0]), float(path[k][1])))
with open(sys.argv[2], "w") as f:
    f.write("-- Generated by tools/draw_levels.py: the level map's size, where each level's node sits and its regions (art pixels)\n")
    f.write("-- Every region has %d levels; the last one is the region's boss.\n" % LEVELS_PER_REGION)
    f.write("return { width = %d, height = %d, scale = %d, per_region = %d,\n\tnodes = {\n" % (W, H, SCALE, LEVELS_PER_REGION))
    for x, y in nodes:
        f.write("\t\t{ %.1f, %.1f },\n" % (x, y))
    f.write("\t},\n\tregions = {\n")
    for b, (name, _, _) in enumerate(BIOMES):
        f.write('\t\t{ name = "%s", x = %d, y = %d },\n' % (name, W // 2, b * BAND + BAND // 2))
    f.write("\t},\n}\n")
print("length", int(arc[-1]))
