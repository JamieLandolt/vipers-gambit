"""Free-form pixel snake renderer used by draw_more_cards.py.

A snake is a smooth path (Catmull-Rom through control points) swept with discs of varying radius.
Every body pixel remembers its arc length s and lateral offset u so patterns can follow the body.
"""
import colorsys
import math

from draw_cards import BG, BLACK, YEL, RED, W, H, in_corner, shade

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hx(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def dither(c1, c2, t, x, y):
    """c1 -> c2 as t goes 0..1, ordered dither."""
    return c2 if t > (BAYER[y % 4][x % 4] + 0.5) / 16 else c1


def hsv(h, s, v):
    return tuple(int(c * 255) for c in colorsys.hsv_to_rgb(h % 1.0, s, v))


def noise(x, y, seed=0):
    n = (x * 374761393 + y * 668265263 + seed * 144665) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def setpx(g, x, y, c):
    x, y = int(round(x)), int(round(y))
    if 2 <= x <= 30 and 2 <= y <= 37 and not in_corner(x, y):
        g[y][x] = c
        return True
    return False


# ---------------------------------------------------------------- paths
def catmull(pts, step=0.25):
    P = [pts[0]] + list(pts) + [pts[-1]]
    dense = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        n = max(4, int(math.dist(p1, p2) / 0.15))
        for k in range(n):
            t = k / n
            dense.append(tuple(0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t * t
                                      + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t ** 3) for j in (0, 1)))
    dense.append(tuple(pts[-1]))
    out, acc, last = [(dense[0][0], dense[0][1], 0.0)], 0.0, dense[0]
    nxt = step
    for p in dense[1:]:
        d = math.dist(p, last)
        while acc + d >= nxt and d > 0:
            f = (nxt - acc) / d
            out.append((last[0] + (p[0] - last[0]) * f, last[1] + (p[1] - last[1]) * f, nxt))
            nxt += step
        acc += d
        last = p
    res = []
    for i, (x, y, s) in enumerate(out):
        a, b = out[max(0, i - 3)], out[min(len(out) - 1, i + 3)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        nrm = math.hypot(tx, ty) or 1
        res.append((x, y, s, tx / nrm, ty / nrm))
    return res


def transform(pts, flip=False, mirror=False):
    return [((32 - x) if mirror else x, (39 - y) if flip else y) for x, y in pts]


# ---------------------------------------------------------------- poses
def p_wave(amp=5, cycles=1.5, cx=16, y0=5, y1=36, phase=0.0, ramp=0.2, n=40):
    return [(cx + amp * math.sin(2 * math.pi * cycles * i / n + phase) * min(1, i / n / ramp), y0 + (y1 - y0) * i / n) for i in range(n + 1)]


def p_hwave(amp=5, cycles=1.5, cy=22, x0=4, x1=29, phase=0.0, n=40):
    return [(x0 + (x1 - x0) * i / n, cy + amp * math.sin(2 * math.pi * cycles * i / n + phase)) for i in range(n + 1)]


def p_spiral(cx=16, cy=22, R0=12, R1=2.5, turns=2.0, a0=-math.pi / 2, d=1, n=60):
    return [(cx + (R0 - (R0 - R1) * i / n) * math.cos(a0 + d * turns * 2 * math.pi * i / n),
             cy + (R0 - (R0 - R1) * i / n) * math.sin(a0 + d * turns * 2 * math.pi * i / n)) for i in range(n + 1)]


def p_coil(cx=16, cy=28, R0=8, R1=2.5, turns=1.6, a0=0.0, d=1, head=(22, 5), mid=None):
    sp = p_spiral(cx, cy, R0, R1, turns, a0, d, 40)
    mid = mid or ((head[0] + sp[0][0]) / 2, (head[1] + sp[0][1]) / 2 - 2)
    return [head, mid] + sp


def p_zig(xl=9, xr=23, y0=6, y1=35, n=4, x0=None):
    pts = []
    for i in range(n + 1):
        y = y0 + (y1 - y0) * i / n
        pts.append(((xl if i % 2 else xr) if x0 is None or i else x0, y))
    return pts


def p_arch(cx=16, base=34, R=10, H_=22, tail=6, hx_=None):
    pts = [(cx - R, base - 1)]
    for i in range(0, 13):
        a = math.pi - math.pi * i / 12
        pts.append((cx + R * math.cos(a), base - H_ * math.sin(a)))
    pts.append((cx + R, base))
    pts.append((cx + R - 3, base + 2 - tail))
    return pts


def p_arc(cx=16, cy=21, R=11, a0=-math.pi / 2, a1=math.pi * 1.1, n=30):
    return [(cx + R * math.cos(a0 + (a1 - a0) * i / n), cy + R * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def p_loop(cx=16, y0=5, a=4.6, b=7.5, loops=1, n=70):
    pts = []
    for i in range(n + 1):
        f = 2 * math.pi * loops * i / n
        pts.append((cx + b * math.sin(f) * min(1, i / 6), y0 + a * f - b * math.cos(f) + b))
    return pts


def p_fig8(cx=16, cy=21, A=8, B=14, t0=-math.pi / 2 + 0.5, t1=1.5 * math.pi - 0.7, n=60):
    return [(cx + A * math.sin(2 * (t0 + (t1 - t0) * i / n)), cy + B * math.sin(t0 + (t1 - t0) * i / n)) for i in range(n + 1)]


def p_line(x0, y0, x1, y1, amp=0.0, cycles=1.0, n=30):
    L = math.hypot(x1 - x0, y1 - y0)
    nx, ny = -(y1 - y0) / L, (x1 - x0) / L
    pts = []
    for i in range(n + 1):
        t = i / n
        o = amp * math.sin(2 * math.pi * cycles * t) * min(1, t * 5)
        pts.append((x0 + (x1 - x0) * t + nx * o, y0 + (y1 - y0) * t + ny * o))
    return pts


def p_pts(*pts):
    return list(pts)


POSES = dict(wave=p_wave, hwave=p_hwave, spiral=p_spiral, coil=p_coil, zig=p_zig, arch=p_arch, arc=p_arc,
             loop=p_loop, fig8=p_fig8, line=p_line, pts=p_pts)


# ---------------------------------------------------------------- patterns: f(s, u, x, y, C)
class C:  # colour context
    pass


def pat_solid(s, u, x, y, c):
    return c.base


def pat_bands(s, u, x, y, c, period=6, duty=0.5):
    return c.alt if (s % period) < period * duty else c.base


def pat_stripe(s, u, x, y, c, w=0.3):
    return c.alt if abs(u) < w else c.base


def pat_stripes2(s, u, x, y, c, at=0.55, w=0.22):
    return c.alt if abs(abs(u) - at) < w else c.base


def pat_diamonds(s, u, x, y, c, period=7):
    f = (s / period) % 1.0
    return c.alt if abs(u) < 1.05 - 2 * abs(f - 0.5) * 1.5 and abs(f - .5) < 0.34 else c.base


def pat_spots(s, u, x, y, c, p=0.25, size=2.0):
    return c.alt if noise(int(s / size), int((u + 1) * 1.4), c.seed) < p else c.base


def pat_rings(s, u, x, y, c, period=4, th=1):
    return c.alt if (s % period) < th else c.base


def pat_scales(s, u, x, y, c, k=2.0):
    return shade(c.base, 1.0) if (int(s / 1.5) + int((u + 1) * k)) % 2 == 0 else shade(c.alt if c.alt else c.base, 1.0)


def pat_grad(s, u, x, y, c, stops=None, k=1.0):
    st = stops or [c.base, c.alt]
    t = min(0.999, max(0.0, s / c.L * k)) * (len(st) - 1)
    i = int(t)
    return dither(st[i], st[i + 1], t - i, x, y)


def pat_speckle(s, u, x, y, c, p=0.2):
    return c.alt if noise(x, y, c.seed) < p else c.base


def pat_saddles(s, u, x, y, c, period=8, duty=0.55, w=0.55):
    return c.alt if abs(u) < w and (s % period) < period * duty else c.base


def pat_zigzag(s, u, x, y, c, period=6, w=0.35):
    f = (s / period) % 1.0
    tri = abs(f * 2 - 1) * 2 - 1
    return c.alt if abs(u - tri * 0.6) < w else c.base


def pat_chevron(s, u, x, y, c, period=5, duty=0.4):
    return c.alt if ((s + abs(u) * 3.2) % period) < period * duty else c.base


def pat_harlequin(s, u, x, y, c, w=3.0):
    return c.cols[(int(s / w) + (1 if u > 0 else 0)) % len(c.cols)]


def pat_cycle(s, u, x, y, c, w=3.0):
    return c.cols[int(s / w) % len(c.cols)]


def pat_hue(s, u, x, y, c, turns=1.0, sat=0.65, val=0.95, levels=12, h0=0.0):
    t = (h0 + s / c.L * turns) % 1.0
    return hsv(round(t * levels) / levels, sat, val)


def pat_barber(s, u, x, y, c, period=6, slope=2.5):
    return c.alt if ((s + u * slope) % period) < period / 2 else c.base


def pat_glowdots(s, u, x, y, c, p=0.12):
    n = noise(x, y, c.seed)
    return c.cols[0] if n < p else c.cols[1] if n < p * 1.9 else c.base


def pat_blotch(s, u, x, y, c, p=0.5, size=2):
    return c.alt if noise(int(s / size), int((u + 1) * 1.5), c.seed) < p else c.base


def pat_vein(s, u, x, y, c, period=5):
    return c.alt if abs(u) < 0.2 or ((s - abs(u) * 4) % period) < 1.2 and abs(u) < 0.9 else c.base


def pat_cracks(s, u, x, y, c, p=0.18):
    return c.alt if (int(s * 0.8 + u * 2.5) % 4 == 0 and noise(x, y, c.seed) < 0.75) or noise(x, y, c.seed) < 0.04 else c.base


def pat_net(s, u, x, y, c):
    """reticulated: diamond mesh"""
    return c.alt if (int(s / 2.2 + u * 1.6) + int(s / 2.2 - u * 1.6)) % 2 == 0 else c.base


def pat_vbars(s, u, x, y, c, period=5):
    """alternating light edge / dark belly-like banding with bright spine"""
    return c.cols[0] if abs(u) < 0.2 else (c.alt if (s % period) < period / 2 else c.base)


def pat_confetti(s, u, x, y, c, p=0.45):
    n = noise(x, y, c.seed)
    return c.cols[int(noise(y, x, c.seed + 5) * len(c.cols))] if n < p else c.base


PATS = {k[4:]: v for k, v in dict(globals()).items() if k.startswith("pat_")}


# ---------------------------------------------------------------- render
def disc_pixels(cx, cy, r):
    R = int(r) + 1
    for y in range(int(round(cy)) - R, int(round(cy)) + R + 1):
        for x in range(int(round(cx)) - R, int(round(cx)) + R + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                yield x, y


def smooth(a, b, t):
    t = max(0.0, min(1.0, (t - a) / (b - a)))
    return t * t * (3 - 2 * t)


def head_profile(shape, rb, s, hl, rh=None):
    if shape == "round":
        rh = rh or rb + 0.7
        if s < hl:
            return rh * (0.62 + 0.38 * min(1, s / 1.6))
        return rh + (rb * 0.85 - rh) * smooth(hl, hl + 2, s) + (rb * 0.15) * smooth(hl + 2, hl + 5, s)
    if shape in ("viper", "spade"):
        rh = rh or rb + (1.7 if shape == "viper" else 1.4)
        tip = rb * (0.5 if shape == "viper" else 0.7)
        if s < hl:
            f = min(1, s / (hl * 0.75))
            f = f if shape == "viper" else math.sin(math.pi / 2 * f)
            return tip + (rh - tip) * f
        return rh + (rb * 0.8 - rh) * smooth(hl, hl + 2, s) + rb * 0.2 * smooth(hl + 2, hl + 5, s)
    if shape == "long":
        rr = rb * 0.92
        return rr * (0.55 + 0.45 * min(1, s / 2)) if s < hl else rr + rb * 0.08 * smooth(hl, hl + 3, s)
    if shape == "flat":
        rh = rh or rb + 1.4
        if s < hl:
            return rh * (0.72 + 0.28 * min(1, s / 1.2))
        return rh + (rb * 0.8 - rh) * smooth(hl, hl + 1.5, s) + rb * 0.2 * smooth(hl + 1.5, hl + 4, s)
    raise ValueError(shape)


def render(g, path, spec, name_seed=0):
    """Draws the snake into grid g. Returns dict with mask info for accessories."""
    L = path[-1][2]
    rb = spec.get("rb", 3.0)
    shape = spec.get("head", "round")
    hl = spec.get("hl", {"round": 4, "viper": 5, "spade": 5, "long": 6, "flat": 4}[shape])
    tail = spec.get("tail", "taper")
    tf = spec.get("tf", 0.38)
    bul = spec.get("bulge", 0.0)
    hood = spec.get("hood", 0.0)
    hoodlen = spec.get("hoodlen", 11)
    frill = spec.get("frill", 0.0)

    def rfun(s):
        r = head_profile(shape, rb, s, hl, spec.get("rh"))
        r *= 1 + bul * math.sin(math.pi * min(1, s / L))
        if hood and hl + 1 < s < hl + 1 + hoodlen:
            r = max(r, rb + hood * math.sin(math.pi * (s - hl - 1) / hoodlen) ** 0.8)
        if frill and hl < s < hl + 6:
            r = max(r, rb + frill * math.sin(math.pi * (s - hl) / 6))
        s0 = L * (1 - tf)
        if tail == "rattle":
            e = L - 9
            if s > e - 5:
                r = min(r, rb - (rb - 1.5) * smooth(e - 5, e, s))
            if s > e:
                r = 1.7
        elif tail == "paddle":
            e = L - 8
            if s > s0 and s <= e:
                r = r - (r - rb * 0.55) * smooth(s0, e, s)
            elif s > e:
                r = max(0.5, 2.9 * math.sin(math.pi * (s - e) / 8) ** 0.6 + 0.2)
        elif tail == "none":
            pass
        elif s > s0:
            r = r * (1 - 0.84 * ((s - s0) / (L - s0)) ** 0.85)
        return max(0.55, r)

    owner = {}
    for idx in range(len(path) - 1, -1, -1):
        cx, cy, s, tx, ty = path[idx]
        r = rfun(s)
        for p in disc_pixels(cx, cy, r):
            owner[p] = idx
    hole = set()
    base, alt = spec["base"], spec.get("alt", spec["base"])
    c = C()
    c.base, c.alt, c.L, c.seed = base, alt, L, name_seed
    c.cols = spec.get("cols") or [alt, base]
    c.dark, c.light = shade(base, 0.6), shade(base, 1.3)
    pat = PATS[spec.get("pat", "solid")]
    pp = spec.get("pp", {})
    out = spec.get("outline") or shade(base, 0.33)
    headcol = spec.get("headcol") or (base if spec.get("headpat") is None else None)
    rim = spec.get("rim")  # lit-edge colour for legendary look
    clipped = 0
    for (x, y), idx in owner.items():
        cx, cy, s, tx, ty = path[idx]
        r = rfun(s)
        edge = False
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = owner.get((x + dx, y + dy))
            if q is None:
                edge = True
                break
            sq = path[q][2]
            if abs(sq - s) > 4 + r and s < sq:
                edge = True
                break
        u = ((x - cx) * -ty + (y - cy) * tx) / max(r, 0.5)
        if edge:
            col = out
        else:
            if s <= hl + 1.5 and headcol:
                col = headcol
            elif s <= hl + 1.5 and spec.get("headpat"):
                col = PATS[spec["headpat"]](s, u, x, y, c)
            elif tail == "rattle" and s > L - 9:
                col = spec.get("rattle_cols", [hx("e6d6a0"), hx("a88c50")])[int((s - (L - 9)) / 2) % 2]
            else:
                col = pat(s, u, x, y, c, **pp)
                if hood and spec.get("hoodcol") and r > rb + 0.4 and s > hl:
                    col = spec["hoodcol"]
                if frill and spec.get("frillcol") and r > rb + 0.4 and s > hl:
                    col = spec["frillcol"]
                if tail == "tuft" and s > L - 6:
                    col = spec.get("tuftcol", alt)
            sh = spec.get("shade", 1.0)
            col = shade(col, 1.16) if u < -0.55 else shade(col, 0.82) if u > 0.55 else col
            if rim and u < -0.7:
                col = lerp(col, rim, 0.55)
        if not setpx(g, x, y, col):
            clipped += 1
    return dict(owner=owner, rfun=rfun, L=L, hl=hl, rb=rb, clipped=clipped)


def at(path, s):
    i = min(len(path) - 1, max(0, int(round(s / 0.25))))
    return path[i]


def side(path, s, off):
    """pixel at arc length s, signed lateral offset off (left of travel positive)."""
    x, y, _, tx, ty = at(path, s)
    return x + -ty * off, y + tx * off


def finish(g, path, info, spec):
    """eyes, tongue, accessories."""
    rb, hl, rfun = info["rb"], info["hl"], info["rfun"]
    head = spec.get("head", "round")
    t0 = at(path, 0)
    fx, fy = -t0[3], -t0[4]  # forward direction
    se = hl * 0.55
    eye = spec.get("eye", YEL)
    off = max(1.0, rfun(se) * 0.62)
    if head == "long":
        off = max(1.0, rfun(se) * 0.55)
    for sgn in (-1, 1):
        ex, ey = side(path, se, sgn * off)
        setpx(g, ex, ey, eye)
        if spec.get("pupil", rb >= 3.0) and not spec.get("glow"):
            ix, iy = side(path, se, sgn * (off - 1.0))
            if (round(ix), round(iy)) != (round(ex), round(ey)):
                setpx(g, ix, iy, BLACK)
        if spec.get("glow"):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (int(round(ex)) + dx, int(round(ey)) + dy)
                if q in info["owner"]:
                    y_, x_ = q[1], q[0]
                    g[y_][x_] = lerp(g[y_][x_], eye, 0.55)
    tcol = spec.get("tongue", RED)
    if tcol:
        tip = rfun(0) * 0.8
        px, py = t0[0] + fx * (tip + 0.8), t0[1] + fy * (tip + 0.8)
        setpx(g, px, py, tcol)
        nx, ny = -fy, fx
        setpx(g, px + fx * 1.0 + nx * 0.9, py + fy * 1.0 + ny * 0.9, tcol)
        setpx(g, px + fx * 1.0 - nx * 0.9, py + fy * 1.0 - ny * 0.9, tcol)
    acc = spec.get("acc", [])
    cols = spec.get("acccols", {})
    for a in acc:
        ACC[a](g, path, info, spec, cols.get(a, spec.get("accol", spec.get("alt", spec["base"]))))


def acc_horns(g, path, info, spec, col):
    hl = info["hl"]
    t0 = at(path, 0)
    fx, fy = -t0[3], -t0[4]
    for sgn in (-1, 1):
        r = info["rfun"](hl * 0.45)
        bx, by = side(path, hl * 0.45, sgn * (r + 0.3))
        setpx(g, bx, by, col)
        nx, ny = -fy * sgn * -1, fx * sgn * -1
        px, py = side(path, hl * 0.45, sgn * (r + 1.3))
        setpx(g, px + fx * 0.9, py + fy * 0.9, col)
        setpx(g, px + fx * 1.9, py + fy * 1.9, col)


def acc_antlers(g, path, info, spec, col):
    hl = info["hl"]
    t0 = at(path, 0)
    fx, fy = -t0[3], -t0[4]
    for sgn in (-1, 1):
        r = info["rfun"](hl * 0.5)
        for k, (o, f) in enumerate([(0.2, 0), (1.0, 0.6), (1.7, 1.4), (2.4, 2.2), (1.3, 2.4), (3.0, 1.5), (3.4, 3.0)]):
            px, py = side(path, hl * 0.5, sgn * (r + o))
            setpx(g, px + fx * f, py + fy * f, col)


def acc_whiskers(g, path, info, spec, col):
    t0 = at(path, 0)
    fx, fy = -t0[3], -t0[4]
    for sgn in (-1, 1):
        px, py = side(path, 0.8, sgn * (info["rfun"](0.8) + 0.6))
        ox, oy = side(path, 0.8, sgn * 1.0)
        ox, oy = px - ox, py - oy
        for k in range(1, 6):
            setpx(g, px + fx * k * 0.8 + ox * k * 0.5, py + fy * k * 0.8 + oy * k * 0.5, col)


def acc_spikes(g, path, info, spec, col, s0=None, s1=None, step=3.0, size=1):
    hl, L = info["hl"], info["L"]
    s = hl + 3 if s0 is None else s0
    s1 = L * 0.7 if s1 is None else s1
    while s < s1:
        r = info["rfun"](s)
        for sgn in (-1, 1):
            for k in range(size):
                bx, by = side(path, s - k * 0.6, sgn * (r + 0.9 + k))
                setpx(g, bx, by, col)
        s += step


def acc_bigspikes(g, path, info, spec, col):
    acc_spikes(g, path, info, spec, col, step=3.4, size=2)


def acc_fins(g, path, info, spec, col):
    hl, L = info["hl"], info["L"]
    s = hl + 4
    while s < L * 0.8:
        r = info["rfun"](s)
        for sgn in (-1, 1):
            for k, (o, b) in enumerate([(0.9, 0), (1.9, 0.8), (2.6, 1.6)]):
                bx, by = side(path, s + b, sgn * (r + o))
                setpx(g, bx, by, col if k < 2 else shade(col, 0.8))
        s += 5.0


def acc_crest(g, path, info, spec, col):
    """bright dorsal line / mohawk of dots down the spine"""
    hl, L = info["hl"], info["L"]
    s = hl + 1.5
    while s < L * 0.75:
        x, y, *_ = at(path, s)
        setpx(g, x, y, col)
        s += 1.5
        if int(s) % 4 == 0:
            s += 1


def acc_mane(g, path, info, spec, col):
    hl = info["hl"]
    for sgn in (-1, 1):
        for k in range(6):
            s = hl + 0.5 + k * 1.6
            r = info["rfun"](s)
            px, py = side(path, s, sgn * (r + 0.8))
            setpx(g, px, py, col)
            px, py = side(path, s + 0.8, sgn * (r + 1.7))
            setpx(g, px, py, shade(col, 0.8))


def acc_wings(g, path, info, spec, col):
    hl = info["hl"]
    for sgn in (-1, 1):
        for k in range(7):
            s = hl + 3 + k * 0.7
            r = info["rfun"](s)
            ln = 5 - abs(k - 2) * 0.9
            for j in range(int(ln)):
                px, py = side(path, s + j * 0.8, sgn * (r + 1.0 + j * 0.9 + k * 0.2))
                setpx(g, px, py, col if (j + k) % 2 else shade(col, 0.82))


def acc_halo(g, path, info, spec, col):
    t0 = at(path, 0)
    fx, fy = -t0[3], -t0[4]
    cx, cy = t0[0] + fx * 3.5, t0[1] + fy * 3.5
    for a in range(0, 360, 36):
        setpx(g, cx + 3.3 * math.cos(math.radians(a)), cy + 3.3 * math.sin(math.radians(a)), col)


def acc_crown(g, path, info, spec, col):
    t0 = at(path, 0)
    fx, fy = -t0[3], -t0[4]
    for sgn in (-1, 0, 1):
        px, py = side(path, 1.5, sgn * 1.6)
        setpx(g, px + fx * 0.5, py + fy * 0.5, col)
        setpx(g, px + fx * 1.5 * (2 if sgn == 0 else 1), py + fy * 1.5 * (2 if sgn == 0 else 1), col)


def acc_dorsal_spots(g, path, info, spec, col):
    hl, L = info["hl"], info["L"]
    s = hl + 3
    while s < L * 0.8:
        x, y, *_ = at(path, s)
        setpx(g, x, y, col)
        s += 2.6


ACC = {k[4:]: v for k, v in dict(globals()).items() if k.startswith("acc_")}


# ---------------------------------------------------------------- scenery
def deco(g, kind, seed, path=None):
    rnd = lambda i: noise(i, seed, 77)
    n = 0
    pts = []
    for i in range(80):
        x, y = 3 + int(rnd(i * 2) * 28), 3 + int(rnd(i * 2 + 1) * 34)
        if 2 <= x <= 30 and 2 <= y <= 37 and not in_corner(x, y):
            pts.append((x, y))
    pts = pts[:30]
    if kind == "leaves":
        for x, y in pts[:7]:
            setpx(g, x, y, (70, 150, 60)); setpx(g, x + 1, y + 1, (110, 190, 70))
    elif kind == "bubbles":
        for x, y in pts[:9]:
            setpx(g, x, y, (170, 220, 245))
            if x % 2: setpx(g, x + 1, y - 1, (120, 180, 230))
    elif kind == "waves":
        for k, y in enumerate((35, 37)):
            for x in range(3, 31):
                if (x // 3 + k) % 2 == 0:
                    setpx(g, x, y, (120, 170, 230) if k == 0 else (96, 130, 200))
    elif kind == "embers":
        for x, y in pts[:10]:
            setpx(g, x, y, (255, 140, 30) if (x + y) % 2 else (255, 220, 80))
    elif kind == "snow":
        for x, y in pts[:12]:
            setpx(g, x, y, (235, 245, 255))
    elif kind == "wisps":
        for x, y in pts[:8]:
            setpx(g, x, y, (190, 170, 235)); setpx(g, x, y - 1, (150, 120, 200))
    elif kind == "stars":
        for x, y in pts[:6]:
            setpx(g, x, y, (255, 240, 130))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                setpx(g, x + dx, y + dy, (200, 180, 90))
    elif kind == "confetti":
        cc = [(255, 90, 120), (90, 200, 255), (255, 230, 80), (140, 255, 140), (220, 130, 255)]
        for i, (x, y) in enumerate(pts[:14]):
            setpx(g, x, y, cc[i % 5])
    elif kind == "rocks":
        for x, y in [(4, 33), (27, 35), (28, 30), (5, 26)][:4]:
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                setpx(g, x + dx, y + dy, (120, 112, 124) if dx + dy else (150, 142, 150))
    elif kind == "sand":
        for x, y in pts[:12]:
            setpx(g, x, y, (200, 170, 120)); setpx(g, x + 1, y, (170, 140, 100))
    elif kind == "branch":
        for x in range(10, 31):
            setpx(g, x, 4, (96, 64, 38)); setpx(g, x, 5, (70, 46, 28))
        for x in (14, 20, 26):
            setpx(g, x, 3, (90, 170, 70)); setpx(g, x + 1, 2, (120, 200, 80))
    elif kind == "spores":
        for x, y in pts[:9]:
            setpx(g, x, y, (150, 220, 80))
    elif kind == "petals":
        for x, y in pts[:8]:
            setpx(g, x, y, (250, 170, 200)); setpx(g, x + 1, y, (230, 130, 170))
