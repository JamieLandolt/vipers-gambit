"""The five legendary (tier 5) snake cards, drawn with richer palettes, dithered shading, auras and sparkles.

Imported by draw_more_cards.py. Each LEGENDARY entry has a build() returning a card grid.
"""
import math

from draw_cards import BG, BLACK, GOLD, RED, BLUE, fill, draw_stats, draw_text, GREEN, in_corner
from draw_cards import load, clear_art
from snake_engine import (PATS, catmull, render, finish, hx, lerp, dither, hsv, noise, setpx, at, side, smooth,
                          p_arc, p_coil, p_spiral)

GOLD_HI, GOLD_B = (255, 244, 150), (255, 210, 60)


def art_pixels():
    return [(x, y) for y in range(2, 38) for x in range(2, 31) if not in_corner(x, y)]


def nonbg(g):
    return {(x, y) for x, y in art_pixels() if g[y][x] != BG}


def draw_stats5(g, cost, atk, dfn):
    draw_stats(g, cost, atk, dfn, 4)
    fill(g, 11, 39, 21, 45)
    for x in (12, 14, 16, 18, 20):
        for y in range(41, 45):
            g[y][x] = GOLD_B if y > 41 else GOLD_HI
    for x in (12, 16, 20):
        g[40][x] = GOLD_B
    g[39][16] = GOLD_HI


def aura(g, mask, col, rmax=6.0, strength=0.9):
    """Dithered glow around the mask. col may be a colour or f(x, y) -> colour."""
    pts = list(mask)
    for x, y in art_pixels():
        if (x, y) in mask or g[y][x] != BG:
            continue
        d = min(math.hypot(x - a, y - b) for a, b in pts)
        if d > rmax:
            continue
        f = ((1 - d / rmax) ** 1.5) * strength
        c = col(x, y) if callable(col) else col
        ladder = [BG, lerp(BG, c, 0.22), lerp(BG, c, 0.45), lerp(BG, c, 0.75)]
        lev = min(2.999, f * 3.3)
        i = int(lev)
        g[y][x] = dither(ladder[i], ladder[i + 1], lev - i, x, y)


def sparkles(g, mask, cols, n, dmin=2.5, dmax=8.0, spacing=5.0, seed=1, big=2):
    pts = list(mask)
    cand = []
    for x, y in art_pixels():
        if (x, y) in mask or in_corner(x + 1, y + 1) or in_corner(x - 1, y - 1) and False:
            continue
        d = min(math.hypot(x - a, y - b) for a, b in pts)
        if dmin <= d <= dmax and 4 <= x <= 28 and 4 <= y <= 36:
            cand.append((noise(x, y, seed), x, y))
    cand.sort()
    chosen = []
    for _, x, y in cand:
        if all(math.hypot(x - a, y - b) >= spacing for a, b in chosen):
            chosen.append((x, y))
        if len(chosen) >= n:
            break
    for i, (x, y) in enumerate(chosen):
        c = cols[i % len(cols)]
        put(g, mask, x, y, (255, 255, 255) if i % 3 == 0 else c)
        if i < big:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                put(g, mask, x + dx, y + dy, c)
            for k in (2,):
                for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                    put(g, mask, x + dx, y + dy, lerp(BG, c, 0.55))
    return chosen


def put(g, mask, x, y, c):
    if (x, y) not in mask and 2 <= x <= 30 and 2 <= y <= 37 and not in_corner(x, y):
        g[y][x] = c


def feather(g, x, y, ang, length, bend, cols, width=2, outline=None):
    """Curved plume; colour runs through cols from base to tip."""
    px, py = x, y
    a = math.radians(ang)
    for k in range(length):
        t = k / max(1, length - 1)
        i = t * (len(cols) - 1)
        j = min(len(cols) - 2, int(i))
        c = dither(cols[j], cols[j + 1], i - j, int(px), int(py))
        setpx(g, px, py, c)
        if width > 1 and t < 0.75:
            setpx(g, px - math.sin(a) * 0.9, py + math.cos(a) * 0.9, lerp(c, (255, 255, 255), 0.18))
        if width > 2 and t < 0.4:
            setpx(g, px + math.sin(a) * 0.9, py - math.cos(a) * 0.9, shade_(c, 0.8))
        px += math.cos(a) * 0.9
        py += math.sin(a) * 0.9
        a += math.radians(bend)
    if outline:
        setpx(g, px, py, outline)


def shade_(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def sparkle_body(g, info, out_col, cols, p, seed):
    """Light flecks on the body for a glittering, scaled look."""
    for (x, y) in info["owner"]:
        if g[y][x] != out_col and noise(x, y, seed) < p:
            g[y][x] = cols[int(noise(y, x, seed + 3) * len(cols))]


def fins(g, path, info, cols, step=4.5, length=3, s0=None, s1=None):
    hl, L = info["hl"], info["L"]
    s = hl + 4 if s0 is None else s0
    s1 = L * 0.82 if s1 is None else s1
    while s < s1:
        r = info["rfun"](s)
        for sgn in (-1, 1):
            for k in range(length):
                bx, by = side(path, s + k * 0.9, sgn * (r + 0.8 + k))
                setpx(g, bx, by, cols[min(k, len(cols) - 1)])
                if k < length - 1:
                    bx, by = side(path, s + k * 0.9 + 1.0, sgn * (r + 0.8 + k))
                    setpx(g, bx, by, shade_(cols[min(k, len(cols) - 1)], 0.75))
        s += step


# ---------------------------------------------------------------- Jormungandr
def jormungandr():
    g = load("Snake.png")
    clear_art(g)
    for y, c1, c2 in ((33, (60, 120, 200), (150, 200, 245)), (34, (40, 90, 170), (90, 150, 220)),
                      (35, (30, 70, 150), (60, 110, 190)), (36, (24, 56, 130), (40, 80, 160)), (37, (20, 44, 110), (30, 60, 130))):
        for x in range(2, 31):
            g[y][x] = c2 if (x + (y % 2) * 2) % 6 < 2 else c1
    pts = [(21, 5), (21, 11), (25, 16), (19, 20), (9, 21), (7, 27), (15, 31), (25, 31), (23, 36)]
    path = catmull(pts)
    stops = [hx("0a1c48"), hx("1c4a9c"), hx("2a8ac8"), hx("6ad0e8"), hx("e8fbff")]
    spec = dict(base=hx("1c4a9c"), alt=hx("6ad0e8"), pat="grad", pp=dict(stops=stops, k=1.05), rb=3.6, head="viper", hl=6, rh=5.6,
                tail="paddle", rim=hx("c8f4ff"), outline=hx("050d2a"), glow=True, eye=hx("d8ffff"), tongue=hx("9ae8ff"),
                acc=["horns"], accol=hx("e8fbff"), pupil=False)
    info = render(g, path, spec, 11)
    # icy belly scales and frost flecks
    for (x, y), idx in info["owner"].items():
        s = path[idx][2]
        u = ((x - path[idx][0]) * -path[idx][4] + (y - path[idx][1]) * path[idx][3]) / max(info["rfun"](s), .5)
        if g[y][x] != spec["outline"] and u > 0.25 and (int(s / 1.7) + int((u + 1) * 2)) % 2 == 0 and s > 7:
            g[y][x] = lerp(g[y][x], (200, 240, 255), 0.35)
    sparkle_body(g, info, spec["outline"], [hx("e8fbff"), hx("9ae8ff")], 0.05, 5)
    fins(g, path, info, [hx("9ae8ff"), hx("d8f8ff"), hx("ffffff")], step=4.2, length=3)
    finish(g, path, info, spec)
    # jaw spikes / frost crown behind the head
    t0 = at(path, 0)
    for sgn in (-1, 1):
        for k, (o, b) in enumerate([(5.0, 4), (6.5, 6), (7.5, 8.5)]):
            bx, by = side(path, b, sgn * o)
            for j in range(2):
                setpx(g, bx, by + j * 0.9 * -1, hx("d8f8ff") if j == 0 else hx("6ad0e8"))
    mask = nonbg(g)
    aura(g, mask, hx("3ad8ff"), rmax=6.5)
    sparkles(g, mask, [hx("ffffff"), hx("9ae8ff"), hx("c8f4ff")], 9, seed=3)
    draw_stats5(g, 9, 14, 19)
    return g


# ---------------------------------------------------------------- Quetzalcoatl
def quetzalcoatl():
    g = load("Snake.png")
    clear_art(g)
    wing_cols = [hx("14784a"), hx("22b08a"), hx("38d8d0"), hx("f4d048"), hx("ee5a3a")]
    # wings (behind body)
    hx0, hy0 = 19, 14
    for sgn in (-1, 1):
        for k, dang in enumerate((-62, -42, -22, -2, 18, 36, 52)):
            ang = dang if sgn == 1 else 180 - dang
            ln = 12 - abs(k - 3) + (1 if k == 3 else 0)
            feather(g, hx0 + sgn * 1.5, hy0 + k * 0.8 - 2, ang, ln, 2.0 * sgn, wing_cols, width=3)
    pts = [(18, 5), (20, 11), (21, 19), (22, 26)]
    sp = p_spiral(cx=16, cy=27, R0=6.5, R1=2, turns=1.7, a0=0, d=1, n=40)
    path = catmull(pts + sp[1:])
    stops = [hx("0d5a3a"), hx("1f9a5a"), hx("2ed0a8"), hx("7af0d8")]
    spec = dict(base=hx("1f9a5a"), alt=hx("f4d048"), pat="grad", pp=dict(stops=stops, k=1.4), rb=3.1, head="spade", hl=6, rh=4.8,
                tail="taper", rim=hx("b8ffe8"), outline=hx("04281a"), glow=True, eye=hx("ffe45a"), tongue=hx("ee3a3a"), pupil=False)
    info = render(g, path, spec, 21)
    # golden diamond scales along the back, ruby throat
    for (x, y), idx in info["owner"].items():
        cx, cy, s, tx, ty = path[idx]
        u = ((x - cx) * -ty + (y - cy) * tx) / max(info["rfun"](s), .5)
        if g[y][x] != spec["outline"] and s > 8:
            if abs(u) < 0.34 and int(s / 2) % 2 == 0:
                g[y][x] = hx("f4d048") if abs(u) < 0.2 else hx("d8a030")
            elif abs(u) > 0.5 and int(s / 1.5) % 2 == 0:
                g[y][x] = lerp(g[y][x], hx("38d8d0"), 0.4)
    finish(g, path, info, spec)
    # plumed crest sweeping back from the head
    for sgn in (-1, 1):
        for k, (ang, ln) in enumerate(((235, 6), (205, 7), (170, 7))):
            a = ang if sgn == -1 else 180 - ang
            feather(g, 18 + sgn * 2, 5 + k * 0.6, a, ln, sgn * 1.6, [hx("ee5a3a"), hx("f4d048"), hx("38d8d0")], width=2)
    mask = nonbg(g)
    aura(g, mask, hx("7affc0"), rmax=6.0)
    sparkles(g, mask, [hx("fff6a0"), hx("b8ffe8"), hx("ffffff")], 9, seed=7)
    draw_stats5(g, 8, 15, 17)
    return g


# ---------------------------------------------------------------- Apophis
def apophis():
    g = load("Snake.png")
    clear_art(g)
    pts = p_arc(cx=16, cy=22, R=10.5, a0=-1.25, a1=-1.25 + 2 * math.pi - 0.75, n=60)
    path = catmull(pts)
    stops = [hx("1a0c2c"), hx("2e1448"), hx("4a1c64"), hx("6a2a78")]
    spec = dict(base=hx("2e1448"), alt=hx("e02a46"), pat="cracks", pp={}, rb=3.4, head="viper", hl=6, rh=5.2, tail="taper", tf=0.5,
                rim=hx("c07af0"), outline=hx("0a0414"), glow=True, eye=hx("ff3a2a"), tongue=hx("ff3a2a"), pupil=False,
                acc=["horns"], accol=hx("6a2a78"))
    # shadow wisps rising from the body (behind)
    for i in range(16):
        k = int(noise(i, 3, 9) * (len(path) - 1))
        x, y, s, tx, ty = path[k]
        nx, ny = -ty, tx
        d = 1 if noise(i, 4, 9) < 0.5 else -1
        px, py = x + nx * d * 3.5, y + ny * d * 3.5
        ln = 4 + int(noise(i, 5, 9) * 5)
        for j in range(ln):
            c = lerp(hx("5a2a86"), hx("2a1448"), j / ln)
            setpx(g, px + nx * d * j * 0.6 + math.sin(j * 0.9 + i) * 0.8, py + ny * d * j * 0.6 - j * 0.45, c)
    info = render(g, path, spec, 31)
    # crimson sigil veins lit on the lit side
    sparkle_body(g, info, spec["outline"], [hx("e02a46"), hx("ff6a5a")], 0.035, 8)
    finish(g, path, info, spec)
    # big glowing eyes: add white-hot cores
    for sgn in (-1, 1):
        ex, ey = side(path, spec["hl"] * 0.55, sgn * max(1.0, info["rfun"](spec["hl"] * 0.55) * 0.62))
        setpx(g, ex, ey, hx("fff0a0"))
    mask = nonbg(g)
    aura(g, mask, hx("e0203c"), rmax=6.0, strength=0.8)
    sparkles(g, mask, [hx("ff8a7a"), hx("c07af0"), hx("ffffff")], 8, seed=4, dmin=3, dmax=8)
    draw_stats5(g, 8, 16, 14)
    return g


# ---------------------------------------------------------------- Ouroboros
def ouro_pat(s, u, x, y, c, turns=1.0):
    base = hsv((s / c.L * turns) % 1.0, 0.62, 0.98)
    base = tuple(round(v / 17) * 17 for v in base)
    return base if (int(s / 1.8) + int((u + 1) * 2)) % 2 == 0 else tuple(int(v * 0.82) for v in base)


PATS["ouro"] = ouro_pat


def ouroboros():
    g = load("Snake.png")
    clear_art(g)
    a0 = -1.5 + 0.25
    pts = p_arc(cx=16, cy=21, R=10.3, a0=a0, a1=a0 + 2 * math.pi - 0.62, n=90)
    path = catmull(pts)
    spec = dict(base=hx("ff6a6a"), alt=hx("6a6aff"), pat="ouro", pp=dict(turns=1.0), rb=3.0, head="viper", hl=5, rh=4.6, tail="taper", tf=0.28,
                rim=hx("ffffff"), outline=hx("2a1038"), glow=True, eye=hx("fff6a0"), tongue=None, pupil=False,
                headcol=hx("ff6a6a"), acc=["crown"], accol=GOLD_HI)
    # inner dotted ring and rune
    for k in range(18):
        a = 2 * math.pi * k / 18
        setpx(g, 16 + 5.8 * math.cos(a), 21 + 5.8 * math.sin(a), tuple(int(v) for v in hsv(k / 18, 0.55, 1.0)))
    for dx, dy, c in ((0, 0, GOLD_HI), (1, 0, GOLD_B), (-1, 0, GOLD_B), (0, 1, GOLD_B), (0, -1, GOLD_B), (2, 0, (200, 150, 30)), (-2, 0, (200, 150, 30)), (0, 2, (200, 150, 30)), (0, -2, (200, 150, 30))):
        setpx(g, 16 + dx, 21 + dy, c)
    info = render(g, path, spec, 41)
    sparkle_body(g, info, spec["outline"], [hx("ffffff"), hx("fff6a0")], 0.06, 12)
    finish(g, path, info, spec)
    mask = nonbg(g)
    aura(g, mask, lambda x, y: tuple(int(v) for v in hsv((math.atan2(y - 21, x - 16) / (2 * math.pi)) % 1.0, 0.55, 1.0)), rmax=5.0, strength=0.95)
    sparkles(g, mask, [hx("ffffff"), hx("fff6a0"), hx("a0f0ff")], 8, seed=9, dmin=2, dmax=5, spacing=4.5)
    draw_stats5(g, 9, 13, 19)
    return g


# ---------------------------------------------------------------- Nagaraja
def nagaraja():
    g = load("Snake.png")
    clear_art(g)
    stops = [hx("fff4b8"), hx("f2c840"), hx("d89a20"), hx("9a5a10")]
    base = dict(base=hx("e8b82e"), alt=hx("fff0a0"), pat="grad", pp=dict(stops=stops, k=1.25), rim=hx("fffbd0"), outline=hx("3e2204"),
                glow=True, eye=hx("ff2a2a"), tongue=hx("ee3a3a"), pupil=False, head="round", hl=4)
    infos = []
    # coiled trunk
    trunk = catmull([(16, 20), (17, 26), (12, 30), (18, 34), (22, 36)])
    render(g, trunk, dict(base, rb=4.3, tail="taper", tf=0.5, head="round", hl=0, glow=False), 51)
    necks = [  # head, control points down to the trunk, rb, hood
        ([(5, 18), (7, 23), (12, 26), (16, 29)], 2.0, 2.0),
        ([(27, 18), (25, 23), (20, 26), (16, 29)], 2.0, 2.0),
        ([(10, 10), (11, 17), (13, 23), (16, 27)], 2.1, 2.4),
        ([(22, 10), (21, 17), (19, 23), (16, 27)], 2.1, 2.4),
        ([(16, 5), (16, 12), (16, 20), (16, 27)], 2.4, 3.0),
    ]
    for i, (pts, rb, hood) in enumerate(necks):
        path = catmull(pts)
        spec = dict(base, rb=rb, hood=hood, hoodlen=10, tail="none", hoodcol=None, acc=["crown"] if i == 4 else [], accol=hx("ff4a4a"))
        info = render(g, path, spec, 60 + i)
        # spectacle mark on hood
        for (x, y), idx in info["owner"].items():
            cx, cy, s, tx, ty = path[idx]
            u = ((x - cx) * -ty + (y - cy) * tx) / max(info["rfun"](s), .5)
            if g[y][x] != spec["outline"] and s > 8:
                if abs(u) < 0.22 and 9 < s < 16:
                    g[y][x] = hx("8a4a0c")
                elif abs(u) > 0.62:
                    g[y][x] = lerp(g[y][x], hx("fff6c8"), 0.35)
        finish(g, path, info, spec)
    sparkle_gold = [hx("fff6a0"), hx("ffffff"), hx("ffd23c")]
    mask = nonbg(g)
    aura(g, mask, hx("ffc830"), rmax=6.0)
    sparkles(g, mask, sparkle_gold, 10, seed=2, dmin=2.5, dmax=7)
    draw_stats5(g, 7, 12, 18)
    return g


LEGENDARY = [
    dict(name="Jormungandr", typ="Water", cost=9, atk=14, **{"def": 19}, border="Rainbow", build=jormungandr,
         lore="The sea serpent that circles the world, and its frozen breath sinks fleets."),
    dict(name="Quetzalcoatl", typ="Tree", cost=8, atk=15, **{"def": 17}, border="Gold", build=quetzalcoatl,
         lore="The feathered serpent who brought the rain and the dawn on emerald wings."),
    dict(name="Apophis", typ="Spirit", cost=8, atk=16, **{"def": 14}, border="Shadow", build=apophis,
         lore="Every night it swallows the sun, and every dawn the sun barely escapes."),
    dict(name="Ouroboros", typ="Rainbow", cost=9, atk=13, **{"def": 19}, border="Rainbow", build=ouroboros,
         lore="It devours its own tail and is reborn in every colour of light."),
    dict(name="Nagaraja", typ="Land", cost=7, atk=12, **{"def": 18}, border="Gold", build=nagaraja,
         lore="The golden serpent king whose many hoods shelter the mountain of the sun."),
]
