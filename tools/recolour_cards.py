"""Gives every card in assets/Snake_Cards a background and frame by the lane type it fits, and writes CardStyles.lua
(the colours the board shader cuts out). Run on the ORIGINAL purple cards (git revision 1b9c4a9 and earlier) after tools/redraw_stats.py has put the real numbers on them;
running it on its own output would add the panel twice.
Cards are 33x48 art pixels at 5x, so patterns are computed on the art grid.
Usage: python3 tools/recolour_cards.py SRC_DIR [OUT_DIR]   (OUT_DIR defaults to assets/Snake_Cards)"""
import re, sys, os
from PIL import Image

BG, FRAME = (118, 66, 138), (63, 63, 116)
S = 5
EXTRA, PANEL_AT = 16, 38  # rows added to the card, and the row they are inserted at

# type -> (frame colour, background colours, function (gx, gy) -> index into the colours)
STYLES = {
    # dunes: wavy diagonal bands
    "Land": ((104, 70, 40), [(200, 164, 106), (186, 148, 92)], lambda x, y: ((x + y + (x * 3 // 8) % 2) // 3) % 2),
    # water: rows of ripples
    "Water": ((18, 38, 92), [(40, 92, 156), (50, 108, 172)], lambda x, y: 1 if (y % 4 == 0 and (x + y // 4 * 3) % 6 < 3) else 0),
    # leaf litter: scattered darker flecks
    "Tree": ((26, 62, 38), [(54, 122, 72), (44, 104, 62)], lambda x, y: 1 if (x * 7 + y * 13) % 11 == 0 or (x * 5 + y * 3) % 17 == 0 else 0),
    # mist: soft violet with pale sparkles
    "Spirit": ((48, 42, 98), [(96, 84, 152), (112, 100, 170)], lambda x, y: 1 if (x * 11 + y * 7) % 19 == 0 else 0),
    # brews: amber with rising bubbles
    "Brew": ((92, 52, 22), [(196, 122, 52), (214, 142, 66)], lambda x, y: 1 if (x * 5 + y * 9) % 23 == 0 or (x * 3 + y * 7) % 29 == 0 else 0),
    # spells: night sky with stars
    "Spell": ((30, 22, 84), [(52, 42, 134), (240, 230, 160)], lambda x, y: 1 if (x * 13 + y * 7) % 37 == 0 else 0),
    # rainbow: muted diagonal stripes
    "Rainbow": ((46, 46, 60), [(176, 84, 84), (192, 140, 70), (180, 168, 80), (84, 150, 96), (80, 120, 180), (130, 96, 170)],
                lambda x, y: ((x + y) // 4) % 6),
}

def type_of_cards():
    types = {}
    # (file names and CardData names differ in case for a few snakes)
    cd = open("CardData.lua").read()
    for t, body in re.findall(r"^\t(\w+) = \{ (.*?) \}", cd, re.M):
        for n in re.findall(r'"(\w+)"', body):
            types[n.lower()] = t
    for n, t in re.findall(r'name = "(\w+)".*?type = "(\w+)"', open("NewCards.lua").read()):
        types[n.lower()] = t
    for n, kind in re.findall(r'name = "(\w+)", kind = "(\w+)"', open("Brews.lua").read()):
        types[n.lower()] = kind.capitalize()
    return types

NOT_SNAKE = {BG, FRAME, (95, 205, 228), (199, 169, 9)}  # background, frame, the cyan corner curves and the rarity bars


def centre_snake(img):
    """Moves the snake (everything in the art area that is not card furniture) so its bounding box is centred in the
    art area (columns 2-30, rows 2-36 of the 33x48 art grid), a little low. The corner with the cost is left alone."""
    px = img.load()
    cells = {}
    for y in range(2, 37):
        for x in range(2, 31):
            if (x < 10 and y < 10) or px[x * S + 2, y * S + 2][:3] in NOT_SNAKE:
                continue
            cells[(x, y)] = [px[x * S + dx, y * S + dy] for dy in range(S) for dx in range(S)]
    if not cells:
        return
    xs, ys = [c[0] for c in cells], [c[1] for c in cells]
    move_x, move_y = int(16.5 - (min(xs) + max(xs) + 1) / 2), int(21.5 - (min(ys) + max(ys) + 1) / 2)
    move_y = min(move_y, 37 - max(ys))  # (sits a little low: the cost icon takes the top corner, the text panel the bottom)
    if move_x == 0 and move_y == 0:
        return
    for (x, y) in cells:
        for dy in range(S):
            for dx in range(S):
                px[x * S + dx, y * S + dy] = BG + (255,)
    for (x, y), colours in cells.items():
        for i, colour in enumerate(colours):
            px[(x + move_x) * S + i % S, (y + move_y) * S + i // S] = colour


def recolour(img, kind):
    frame, bgs, fn = STYLES[kind]
    img = img.convert("RGBA")
    centre_snake(img)
    # taller card: a text panel of EXTRA art rows goes in above the corner icons, with the frame carried down the sides
    cut = PANEL_AT * S
    tall = Image.new("RGBA", (img.width, img.height + EXTRA * S))
    tall.paste(img.crop((0, 0, img.width, cut)), (0, 0))
    tall.paste(img.crop((0, cut, img.width, img.height)), (0, cut + EXTRA * S))
    for y in range(cut, cut + EXTRA * S):
        for x in range(img.width):
            src = (x, cut - 1) if x < 2 * S or x >= img.width - 2 * S else (-1, -1)  # sides: frame; middle: background
            tall.putpixel((x, y), img.getpixel(src) if src[0] != -1 else BG + (255,))
    img = tall
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if (r, g, b) == BG:
                px[x, y] = bgs[fn(x // S, y // S)] + (a,)
            elif (r, g, b) == FRAME:
                px[x, y] = frame + (a,)
    # rounded corners: clear a 3-pixel chamfer (art pixels) at each corner
    w, h = img.width // S, img.height // S
    for gx, gy in [(0, 0), (1, 0), (0, 1)]:
        for cx, cy in [(gx, gy), (w - 1 - gx, gy), (gx, h - 1 - gy), (w - 1 - gx, h - 1 - gy)]:
            for dy in range(S):
                for dx in range(S):
                    px[cx * S + dx, cy * S + dy] = (0, 0, 0, 0)
    round_corners(img)
    return img


CORNER = 20  # corner radius in pixels, matched by the border frames in Borders.lua


def round_corners(img):
    """Cut a smooth quarter circle out of each corner (safe to repeat)."""
    px = img.load()
    for y in range(CORNER):
        for x in range(CORNER):
            d = ((CORNER - x - 0.5) ** 2 + (CORNER - y - 0.5) ** 2) ** 0.5
            if d > CORNER:
                for ux, uy in [(x, y), (img.width - 1 - x, y), (x, img.height - 1 - y), (img.width - 1 - x, img.height - 1 - y)]:
                    px[ux, uy] = (0, 0, 0, 0)

if __name__ == "__main__":
    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "assets/Snake_Cards"
    os.makedirs(out, exist_ok=True)
    types = type_of_cards()
    for f in sorted(os.listdir(src)):
        if f.endswith(".png"):
            recolour(Image.open(os.path.join(src, f)), types[f[:-4].lower()]).save(os.path.join(out, f))
    if out == "assets/Snake_Cards":
        rows = []
        for kind, (frame, bgs, _) in STYLES.items():
            c = lambda v: "{ %d, %d, %d }" % v
            rows.append("\t%s = { frame = %s, bgs = { %s } }," % (kind, c(frame), ", ".join(c(b) for b in bgs)))
        open("CardStyles.lua", "w").write("-- Generated by tools/recolour_cards.py: the background and frame colours of each lane type's cards (0-255)\nreturn {\n" + "\n".join(rows) + "\n}\n")
