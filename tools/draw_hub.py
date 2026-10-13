"""Draws the main-menu hub sprites into assets/menu: a snake-infested temple and the icons around it
(chest = packs, snakeskin book = collection, basket = deck and lanes, coiled gear = settings).
Usage: python3 tools/draw_hub.py assets/menu    Sprites are drawn in art pixels and scaled 5x."""
import sys, random
from PIL import Image, ImageDraw

S = 5
OUT = (20, 12, 28, 255)

def c(r, g, b, a=255):
    return (r, g, b, a)

STONE, STONE2, STONE3 = c(122, 116, 130), c(92, 86, 104), c(150, 144, 156)
MOSS, GREEN, GREEN2, GREEN3 = c(70, 120, 60), c(106, 190, 48), c(74, 140, 34), c(160, 225, 80)
GOLD, GOLD2 = c(240, 200, 70), c(190, 140, 40)
WOOD, WOOD2 = c(140, 85, 45), c(100, 58, 30)
RED, EYE = c(220, 40, 50), c(250, 230, 70)

def snake_line(d, pts, body=GREEN, belly=GREEN2, width=3, head=True):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.line([(x0, y0), (x1, y1)], fill=body, width=width)
        d.line([(x0, y0 + 1), (x1, y1 + 1)], fill=belly, width=1)
    if head:
        x, y = pts[-1]
        d.rectangle([x - 2, y - 2, x + 2, y + 1], fill=body)
        d.point([(x - 1, y - 1), (x + 1, y - 1)], fill=EYE)
        d.point([(x, y + 2)], fill=RED)

def finish(img, name, folder):
    """Adds the dark outline and saves at 5x."""
    px = img.load()
    w, h = img.size
    solid = {(x, y) for x in range(w) for y in range(h) if px[x, y][3] > 0}
    for x, y in solid:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in solid and 0 <= n[0] < w and 0 <= n[1] < h:
                px[n] = OUT
    img.resize((w * S, h * S), Image.NEAREST).save(f"{folder}/{name}.png")

def speckle(d, box, colours, count, seed):
    r = random.Random(seed)
    x0, y0, x1, y1 = box
    for _ in range(count):
        d.point([(r.randint(x0, x1), r.randint(y0, y1))], fill=r.choice(colours))

def temple():
    img = Image.new("RGBA", (112, 96), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # stepped body
    d.rectangle([6, 70, 105, 92], fill=STONE2)
    d.rectangle([14, 50, 97, 72], fill=STONE)
    d.rectangle([24, 30, 87, 52], fill=STONE3)
    d.rectangle([36, 14, 75, 32], fill=STONE)
    d.polygon([(30, 14), (56, 0), (82, 14)], fill=STONE2)
    for y, x0, x1 in ((70, 6, 105), (50, 14, 97), (30, 24, 87), (14, 36, 75)):  # brick lines
        for x in range(x0 + 4, x1, 10):
            d.line([(x, y), (x, y + 3)], fill=STONE2)
    speckle(d, (8, 52, 104, 90), [MOSS, STONE2], 160, 1)
    # doorway with a sickly glow
    d.rectangle([46, 54, 66, 92], fill=c(20, 10, 30))
    d.ellipse([46, 48, 66, 62], fill=c(20, 10, 30))
    for i in range(6):
        d.rectangle([49 + i, 58 + i * 5, 63 - i, 60 + i * 5], fill=c(60 + i * 20, 200 - i * 10, 90))
    d.rectangle([52, 64, 60, 92], fill=c(110, 240, 120))
    d.rectangle([54, 70, 58, 92], fill=c(200, 255, 190))
    # stairs
    for i in range(4):
        d.rectangle([40 - i * 3, 88 + i, 72 + i * 3, 92 + i], fill=STONE3 if i % 2 == 0 else STONE)
    # pillars wrapped by snakes
    for x in (24, 80):
        d.rectangle([x, 52, x + 8, 90], fill=STONE3)
        d.rectangle([x, 52, x + 2, 90], fill=STONE2)
    snake_line(d, [(22, 88), (34, 80), (22, 72), (34, 64), (22, 56)], GREEN, GREEN2, 3)
    snake_line(d, [(90, 88), (78, 80), (90, 72), (78, 64), (90, 56)], c(190, 90, 220), c(130, 50, 160), 3)
    # snakes crawling along the tiers and peeking from the roof
    snake_line(d, [(2, 82), (14, 74), (26, 78), (40, 70), (50, 74)], GREEN2, GREEN, 2)
    snake_line(d, [(108, 66), (96, 60), (84, 64), (72, 56)], c(240, 180, 40), c(190, 120, 20), 2)
    snake_line(d, [(30, 40), (40, 34), (50, 38), (56, 30), (62, 16)], GREEN3, GREEN, 3)
    snake_line(d, [(80, 46), (72, 40), (64, 44), (58, 28)], c(60, 170, 200), c(30, 110, 150), 2)
    d.ellipse([52, 4, 60, 12], fill=GOLD)  # gem on the roof
    d.point([(55, 7)], fill=c(255, 250, 200))
    for (x, y) in ((6, 70), (100, 70), (14, 50), (92, 50), (26, 32), (84, 32)):  # vines
        d.line([(x, y), (x + 1, y + 10)], fill=MOSS)
    finish(img, "temple", sys.argv[1])

def chest():
    img = Image.new("RGBA", (44, 40), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 18, 40, 36], fill=WOOD)
    for x in (10, 18, 26, 34):
        d.line([(x, 18), (x, 36)], fill=WOOD2)
    d.polygon([(4, 18), (7, 8), (37, 8), (40, 18)], fill=WOOD2)   # open lid
    d.rectangle([4, 17, 40, 20], fill=c(80, 80, 95))               # iron band
    d.rectangle([4, 30, 40, 33], fill=c(80, 80, 95))
    d.rectangle([20, 20, 24, 28], fill=GOLD)                        # lock
    d.point([(22, 23)], fill=OUT)
    d.polygon([(8, 18), (36, 18), (32, 10), (12, 10)], fill=c(255, 230, 120))  # glow inside
    for x in (12, 18, 24, 30):                                       # coins
        d.ellipse([x, 12, x + 4, 16], fill=GOLD if x % 12 else GOLD2)
    snake_line(d, [(36, 38), (40, 30), (34, 24), (38, 16)], GREEN, GREEN2, 3)
    snake_line(d, [(6, 38), (2, 30), (8, 24)], c(240, 100, 60), c(180, 50, 40), 2)
    finish(img, "chest", sys.argv[1])

def book():
    img = Image.new("RGBA", (40, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([4, 4, 36, 44], fill=c(30, 90, 60))                  # snakeskin cover
    for y in range(5, 44, 4):
        for x in range(5 + (y // 4 % 2) * 2, 36, 4):
            d.arc([x - 1, y - 1, x + 3, y + 3], 0, 180, fill=c(60, 140, 90))
    d.rectangle([4, 4, 7, 44], fill=c(20, 60, 40))                   # spine
    d.rectangle([36, 6, 38, 42], fill=c(230, 220, 190))              # pages
    for (x, y) in ((6, 6), (34, 6), (6, 42), (34, 42)):              # gold corners
        d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=GOLD)
    d.ellipse([13, 14, 27, 28], fill=GOLD)                           # eldritch eye
    d.ellipse([15, 17, 25, 25], fill=c(250, 245, 220))
    d.rectangle([19, 16, 21, 26], fill=c(20, 10, 20))                # slit pupil
    for x in range(10, 31, 4):                                       # runes
        d.line([(x, 33), (x, 37)], fill=GOLD2)
        d.line([(x, 35), (x + 2, 33)], fill=GOLD2)
    snake_line(d, [(2, 44), (8, 36), (2, 30), (10, 22)], GREEN, GREEN2, 2)
    snake_line(d, [(38, 4), (32, 10), (38, 16)], c(190, 90, 220), c(130, 50, 160), 2, head=False)
    finish(img, "book", sys.argv[1])

def basket():
    img = Image.new("RGBA", (48, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # cobra rising from the basket
    d.rectangle([21, 24, 27, 42], fill=GREEN)
    d.polygon([(24, 6), (36, 18), (32, 30), (24, 34), (16, 30), (12, 18)], fill=GREEN2)   # hood
    d.polygon([(24, 12), (31, 20), (28, 28), (24, 30), (20, 28), (17, 20)], fill=GREEN3)
    d.rectangle([20, 8, 28, 16], fill=GREEN)
    d.point([(22, 11), (26, 11)], fill=EYE)
    d.point([(24, 15)], fill=RED)
    d.line([(24, 16), (24, 21)], fill=RED)
    # wicker basket
    d.polygon([(6, 38), (42, 38), (38, 58), (10, 58)], fill=c(210, 160, 90))
    for y in range(40, 58, 4):
        d.line([(8, y), (40, y)], fill=c(160, 110, 55))
    for x in range(10, 40, 5):
        d.line([(x, 38), (x - 1 if x < 24 else x + 1, 58)], fill=c(235, 190, 120))
    d.rectangle([5, 35, 43, 40], fill=c(180, 125, 60))
    snake_line(d, [(8, 56), (2, 50), (6, 44)], c(240, 180, 40), c(190, 120, 20), 2)
    finish(img, "basket", sys.argv[1])

def gear():
    img = Image.new("RGBA", (44, 44), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    import math
    for i in range(10):
        a = i * math.pi / 5
        x, y = 22 + 17 * math.cos(a), 22 + 17 * math.sin(a)
        d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=c(150, 150, 165))
    d.ellipse([6, 6, 38, 38], fill=c(150, 150, 165))
    d.ellipse([10, 10, 34, 34], fill=c(110, 110, 125))
    d.ellipse([16, 16, 28, 28], fill=c(40, 36, 50))
    d.arc([6, 6, 38, 38], 200, 290, fill=c(210, 210, 225), width=2)
    snake_line(d, [(2, 36), (10, 40), (20, 34), (30, 40), (40, 30), (36, 20), (40, 10)], GREEN, GREEN2, 3)
    finish(img, "gear", sys.argv[1])

def altar():
    """A stone sacrificial bowl with a red flame, a snake coiled round its pedestal (the Sacrifice icon)."""
    img = Image.new("RGBA", (44, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 40, 36, 46], fill=STONE2)                        # base
    d.rectangle([15, 26, 29, 41], fill=STONE)                        # pedestal
    d.rectangle([17, 26, 19, 41], fill=STONE3)
    d.polygon([(4, 18), (40, 18), (34, 28), (10, 28)], fill=STONE)   # bowl
    d.polygon([(4, 18), (40, 18), (38, 21), (6, 21)], fill=STONE3)
    d.ellipse([7, 15, 37, 21], fill=c(60, 20, 30))                   # dark offering inside
    for x, y, w, h, col in ((15, 4, 14, 13, RED), (18, 1, 9, 12, c(255, 130, 40)), (20, 5, 5, 8, GOLD)):  # flame
        d.polygon([(x, y + h), (x + w // 2, y), (x + w, y + h)], fill=col)
    snake_line(d, [(30, 44), (14, 41), (30, 36), (14, 32), (28, 28)], GREEN, GREEN2, 3)
    speckle(d, (8, 40, 36, 46), [MOSS, STONE3], 14, 3)
    finish(img, "altar", sys.argv[1])

if __name__ == "__main__":
    for f in (temple, chest, book, basket, gear, altar):
        f()


def charmer_cutouts(folder="assets/characters"):
    """Stand-up versions of the pickable charmers' portraits (backdrop removed by flood fill up to the outline), saved as stand_<file>."""
    from collections import deque
    for name in ("raja", "yuki", "moss", "fang", "zora", "baba"):
        img = Image.open(f"{folder}/{name}.png").convert("RGBA")
        px = img.load()
        w, h = img.size
        seen = {(0, 0)}
        queue = deque([(0, 0)])
        while queue:
            x, y = queue.popleft()
            px[x, y] = (0, 0, 0, 0)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and px[n][:3] != OUT[:3]:
                    seen.add(n)
                    queue.append(n)
        img.save(f"{folder}/stand_{name}.png")
