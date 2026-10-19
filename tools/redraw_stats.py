"""Redraws the cost, attack, defense and rarity bars on the ORIGINAL purple 33x48 cards so the numbers match the real stats.
Usage: luajit tools/dump_stats.lua > stats.json; python3 tools/redraw_stats.py SRC_DIR stats.json OUT_DIR
Then run tools/recolour_cards.py on OUT_DIR (see that file). The printed numbers must match CardData.lua, which scales
health and floors attack at run time."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import draw_cards

src, stats_file, out = sys.argv[1:4]
stats = {k.lower(): v for k, v in json.load(open(stats_file)).items()}
draw_cards.CARDS = src.rstrip("/") + "/"
os.makedirs(out, exist_ok=True)
for f in sorted(os.listdir(src)):
    if f.endswith(".png") and f[:-4].lower() in stats:
        cost, attack, defense, rarity, kind = stats[f[:-4].lower()]
        if kind != "snake":
            continue
        grid = draw_cards.load(f)
        if rarity == 5:  # legendaries keep their own rarity marks; only the numbers change
            draw_cards.fill(grid, 3, 2, 5, 6)
            draw_cards.fill(grid, 3, 41, 7, 45)
            draw_cards.fill(grid, 26, 41, 30, 45)
        else:
            draw_cards.draw_stats(grid, cost, attack, defense, rarity)
        draw_cards.save(grid, os.path.join(out, f))
