"""Draws the six fictional charmer portraits. Usage: python3 tools/draw_charmers.py assets/characters
Each portrait is 71x87 art pixels scaled 5x (355x435, like the friend photos)."""
import sys
from PIL import Image, ImageDraw

W, H, SCALE = 71, 87, 5
OUTLINE = (20, 12, 28, 255)
WHITE, BLACK = (250, 245, 230, 255), (25, 20, 30, 255)
GREEN, GREEN2 = (106, 190, 48, 255), (74, 140, 34, 255)


def snake(d, pts, body=GREEN, belly=GREEN2, head_dir=1):
    """A chunky snake along pts (a list of (x, y)); the last point gets a head with eyes."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d.line([(x0, y0), (x1, y1)], fill=body, width=4)
        d.line([(x0, y0 + 1), (x1, y1 + 1)], fill=belly, width=1)
    x, y = pts[-1]
    d.rectangle([x - 3, y - 3, x + 3, y + 2], fill=body)
    d.point([(x - 1, y - 1), (x + 2, y - 1)], fill=BLACK)
    d.point([(x + 3 * head_dir, y + 3)], fill=(220, 40, 50, 255))


def person(d, skin, shade, cloth, cloth2, eye=BLACK, mouth=(150, 60, 60, 255)):
    d.ellipse([4, 62, 66, 120], fill=cloth)  # shoulders
    d.rectangle([14, 70, 56, 90], fill=cloth)
    d.line([(35, 64), (35, 90)], fill=cloth2, width=2)  # collar seam
    d.rectangle([29, 50, 41, 66], fill=shade)  # neck
    d.ellipse([19, 20, 51, 58], fill=skin)  # head
    d.rectangle([18, 36, 19, 41], fill=skin)  # ears
    d.rectangle([51, 36, 52, 41], fill=skin)
    d.rectangle([26, 36, 29, 37], fill=eye)
    d.rectangle([41, 36, 44, 37], fill=eye)
    d.point([(27, 36), (42, 36)], fill=WHITE)
    d.rectangle([34, 40, 36, 45], fill=shade)  # nose
    d.rectangle([31, 49, 39, 49], fill=mouth)


def raja(d):  # turban and pungi flute
    person(d, (190, 130, 85, 255), (160, 105, 65, 255), (200, 80, 40, 255), (150, 50, 25, 255))
    d.ellipse([15, 6, 55, 34], fill=(240, 180, 40, 255))  # turban
    d.rectangle([17, 24, 53, 31], fill=(210, 140, 30, 255))
    d.rectangle([33, 12, 37, 16], fill=(210, 30, 60, 255))  # jewel
    d.rectangle([30, 49, 40, 51], fill=(40, 25, 20, 255))  # moustache
    d.line([(46, 80), (58, 52)], fill=(120, 80, 40, 255), width=3)  # pungi
    d.ellipse([54, 44, 62, 54], fill=(240, 200, 60, 255))
    snake(d, [(60, 64), (62, 52), (66, 44), (66, 30)], head_dir=-1)


def yuki(d):  # frost scarf, ice crown, silver flute
    person(d, (235, 205, 190, 255), (205, 170, 160, 255), (60, 100, 170, 255), (30, 60, 120, 255), eye=(30, 90, 170, 255))
    d.rectangle([17, 18, 53, 26], fill=(235, 240, 250, 255))  # white hair
    d.rectangle([15, 22, 20, 52], fill=(235, 240, 250, 255))
    d.rectangle([50, 22, 55, 52], fill=(235, 240, 250, 255))
    for x in (20, 28, 35, 42, 50):  # ice crown
        d.polygon([(x - 3, 19), (x, 8 if x == 35 else 12), (x + 3, 19)], fill=(150, 220, 245, 255))
    d.rectangle([12, 56, 58, 66], fill=(120, 200, 235, 255))  # scarf
    d.rectangle([12, 62, 20, 82], fill=(120, 200, 235, 255))
    for x in range(14, 58, 6):
        d.rectangle([x, 58, x + 2, 59], fill=(220, 245, 255, 255))
    d.line([(28, 76), (52, 70)], fill=(210, 215, 230, 255), width=3)  # flute
    snake(d, [(8, 80), (6, 70), (10, 62), (8, 50)], body=(150, 215, 245, 255), belly=(90, 160, 210, 255), head_dir=1)


def moss(d):  # hooded, bearded hermit
    person(d, (215, 170, 130, 255), (180, 135, 100, 255), (70, 110, 55, 255), (40, 75, 35, 255))
    d.rectangle([29, 50, 41, 56], fill=(215, 170, 130, 255))
    d.polygon([(35, 3), (63, 36), (60, 62), (10, 62), (7, 36)], fill=(70, 110, 55, 255))  # hood
    d.ellipse([19, 20, 51, 58], fill=(215, 170, 130, 255))
    d.rectangle([26, 36, 29, 37], fill=BLACK)
    d.rectangle([41, 36, 44, 37], fill=BLACK)
    d.rectangle([34, 40, 36, 45], fill=(180, 135, 100, 255))
    d.rectangle([22, 18, 48, 24], fill=(70, 110, 55, 255))
    d.polygon([(20, 46), (50, 46), (46, 66), (35, 72), (24, 66)], fill=(225, 225, 215, 255))  # beard
    d.rectangle([31, 50, 39, 51], fill=(150, 60, 60, 255))
    d.rectangle([22, 28, 30, 29], fill=(225, 225, 215, 255))  # brows
    d.rectangle([40, 28, 48, 29], fill=(225, 225, 215, 255))
    snake(d, [(56, 84), (60, 74), (56, 66), (58, 58)], body=(150, 200, 70, 255), belly=(100, 150, 50, 255), head_dir=-1)


def fang(d):  # plague-doctor mask with goggles, purple coat
    person(d, (220, 180, 140, 255), (180, 140, 110, 255), (110, 50, 150, 255), (70, 25, 100, 255))
    d.ellipse([17, 14, 53, 40], fill=(40, 30, 55, 255))  # top hat brim and crown
    d.rectangle([22, 2, 48, 18], fill=(40, 30, 55, 255))
    d.rectangle([22, 12, 48, 14], fill=(160, 220, 60, 255))
    d.ellipse([20, 30, 50, 52], fill=(225, 215, 190, 255))  # mask
    d.polygon([(30, 42), (40, 42), (35, 62)], fill=(225, 215, 190, 255))  # beak
    for x in (21, 37):  # goggles
        d.ellipse([x, 31, x + 12, 41], fill=(30, 30, 40, 255))
        d.ellipse([x + 2, 33, x + 10, 39], fill=(120, 230, 70, 255))
        d.point([(x + 4, 35)], fill=WHITE)
    d.rectangle([33, 34, 37, 36], fill=(30, 30, 40, 255))
    snake(d, [(10, 86), (8, 74), (14, 66), (16, 54)], body=(160, 80, 200, 255), belly=(110, 50, 150, 255), head_dir=1)


def zora(d):  # veil, forehead gem, hypnotic eyes
    person(d, (170, 110, 80, 255), (140, 85, 60, 255), (150, 30, 90, 255), (100, 15, 60, 255), eye=(250, 220, 60, 255))
    d.polygon([(35, 4), (60, 30), (58, 60), (12, 60), (10, 30)], fill=(85, 40, 150, 255))  # headscarf
    d.ellipse([19, 20, 51, 56], fill=(170, 110, 80, 255))
    d.rectangle([22, 22, 48, 26], fill=(85, 40, 150, 255))
    d.rectangle([33, 24, 37, 28], fill=(60, 230, 220, 255))  # gem
    for x in (24, 39):  # kohl eyes
        d.rectangle([x, 34, x + 6, 38], fill=(30, 20, 40, 255))
        d.rectangle([x + 2, 35, x + 4, 37], fill=(250, 220, 60, 255))
    d.rectangle([34, 40, 36, 45], fill=(140, 85, 60, 255))
    d.polygon([(19, 44), (51, 44), (51, 60), (35, 66), (19, 60)], fill=(130, 60, 190, 255))  # veil
    d.rectangle([22, 66, 48, 68], fill=(250, 220, 60, 255))
    snake(d, [(60, 86), (64, 76), (58, 68), (62, 58)], body=(250, 200, 60, 255), belly=(200, 140, 30, 255), head_dir=-1)


def baba(d):  # desert elder, fez, white moustache, snake over shoulders
    person(d, (150, 100, 65, 255), (120, 78, 50, 255), (215, 190, 130, 255), (170, 140, 80, 255))
    d.rectangle([22, 6, 48, 22], fill=(190, 40, 40, 255))  # fez
    d.rectangle([20, 20, 50, 24], fill=(120, 20, 25, 255))
    d.rectangle([34, 0, 36, 6], fill=(240, 200, 40, 255))
    d.rectangle([22, 28, 30, 29], fill=(240, 240, 235, 255))
    d.rectangle([40, 28, 48, 29], fill=(240, 240, 235, 255))
    d.polygon([(24, 46), (35, 44), (46, 46), (42, 51), (35, 49), (28, 51)], fill=(240, 240, 235, 255))  # moustache
    d.rectangle([28, 53, 42, 56], fill=(240, 240, 235, 255))
    snake(d, [(2, 80), (8, 68), (22, 64), (35, 68), (48, 64), (60, 68), (66, 60)], head_dir=-1)


FIGURES = {"raja": raja, "yuki": yuki, "moss": moss, "fang": fang, "zora": zora, "baba": baba}
BACKDROPS = {
    "raja": ((250, 170, 70), (200, 90, 50)),
    "yuki": ((190, 230, 250), (90, 140, 200)),
    "moss": ((150, 200, 110), (60, 100, 70)),
    "fang": ((190, 120, 230), (80, 40, 120)),
    "zora": ((240, 100, 160), (110, 30, 100)),
    "baba": ((245, 215, 150), (200, 140, 80)),
}


def render(name, folder):
    figure = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    FIGURES[name](ImageDraw.Draw(figure))
    px = figure.load()
    solid = {(x, y) for x in range(W) for y in range(H) if px[x, y][3] > 0}
    for x, y in solid:  # outline pass
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in solid and 0 <= n[0] < W and 0 <= n[1] < H:
                px[n] = OUTLINE
    top, bottom = BACKDROPS[name]
    img = Image.new("RGBA", (W, H))
    bp = img.load()
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(H):
        for x in range(W):  # dithered vertical gradient backdrop
            t = y / H + (bayer[y % 4][x % 4] / 16 - 0.5) * 0.25
            bp[x, y] = (*(top if t < 0.5 else bottom), 255)
    img.alpha_composite(figure)
    img.convert("RGB").resize((W * SCALE, H * SCALE), Image.NEAREST).save(f"{folder}/{name}.png")


if __name__ == "__main__":
    for name in FIGURES:
        render(name, sys.argv[1] if len(sys.argv) > 1 else "assets/characters")
