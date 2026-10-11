"""Draws the long level-select snake. Usage: python3 tools/draw_levels.py assets/backgrounds/LevelSnake.png
The path is mirrored by centre_x() in Render.lua, which places the level nodes along it."""
import sys
import numpy as np
from PIL import Image

W, H, SCALE, R = 192, 540, 10, 15
LIGHT, MID, DARK = (195, 91, 224), (143, 67, 163), (116, 51, 141)
GREEN, SHADE, TAN, TAN2, BLACK = (106, 190, 48), (94, 163, 28), (240, 208, 135), (189, 151, 66), (0, 0, 0)
HEAD_Y = 480

def centre_x(y):
    u = (y + 10) / (HEAD_Y + 10)
    env = np.clip((1 - u) / 0.1, 0, 1)
    return 96 + 52 * np.sin(2 * np.pi * 3 * u) * env

ys = np.linspace(-10, HEAD_Y, 4000)
path = np.stack([centre_x(ys), ys], 1)
tangent = np.gradient(path, axis=0)
tangent /= np.linalg.norm(tangent, axis=1, keepdims=True)
arc = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])

img = np.zeros((H, W, 3), np.uint8)
bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16
for y in range(H):
    pts = np.stack([np.arange(W), np.full(W, y)], 1)
    d = np.linalg.norm(pts[:, None, :] - path[None], axis=2)
    i, dist = d.argmin(1), d.min(1)
    for x in range(W):
        n, k = dist[x], i[x]
        side = tangent[k][0] * (y - path[k][1]) - tangent[k][1] * (x - path[k][0])
        if n > R:  # background: light near the snake, dithered out to dark
            t = (n - R - 4) / 70
            img[y, x] = LIGHT if t < bayer[y % 4, x % 4] - 0.5 else (MID if t < 0.5 + bayer[y % 4, x % 4] else DARK)
        elif n > R - 1:
            img[y, x] = BLACK
        elif side > R - 6:  # belly band with alternating stripes
            img[y, x] = TAN if int(arc[k] // 3) % 2 else TAN2
        elif side < -(R - 3):
            img[y, x] = SHADE
        else:
            img[y, x] = GREEN

# Head at the bottom: wider blob, eyes, fangs and a forked tongue pointing down
hx = int(round(centre_x(HEAD_Y)))
for y in range(H):
    for x in range(W):
        e = ((x - hx) / 21) ** 2 + ((y - (HEAD_Y + 8)) / 22) ** 2
        if y > HEAD_Y - 6 and e <= 1:
            img[y, x] = GREEN if e <= 0.86 else BLACK
for dx in (-9, 9):
    img[HEAD_Y + 2:HEAD_Y + 6, hx + dx - 1:hx + dx + 2] = (255, 255, 255)
    img[HEAD_Y + 3:HEAD_Y + 6, hx + dx:hx + dx + 1] = BLACK
for dx in (-6, 6):
    img[HEAD_Y + 22:HEAD_Y + 27, hx + dx - 1:hx + dx + 1] = (255, 255, 255)
img[HEAD_Y + 29:HEAD_Y + 40, hx - 1:hx + 1] = (214, 25, 25)
for k in range(5):
    img[HEAD_Y + 40 + k, hx - 2 - k] = (214, 25, 25)
    img[HEAD_Y + 40 + k, hx + 1 + k] = (214, 25, 25)

Image.fromarray(img).resize((W * SCALE, H * SCALE), Image.NEAREST).save(sys.argv[1])
