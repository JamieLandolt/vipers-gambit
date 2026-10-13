"""Turns tools/new_cards.tsv into NewCards.lua (stats, type, border and lore for the added snakes).
Usage: python3 tools/import_cards.py   (run from the project root)"""
import csv
import os

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
rows = list(csv.DictReader(open(os.path.join(root, "tools", "new_cards.tsv")), delimiter="\t"))

out = ["-- Generated from tools/new_cards.tsv by tools/import_cards.py", "return {"]
for r in rows:
    assert os.path.exists(os.path.join(root, "assets", "Snake_Cards", r["name"] + ".png")), r["name"]
    lore = r["lore"].replace("\\", "\\\\").replace('"', '\\"')
    out.append(
        '\t{ name = "%s", cost = %s, attack = %s, defense = %s, rarity = %s, type = "%s", border = "%s", lore = "%s" },'
        % (r["name"], r["cost"], r["attack"], r["defense"], r["rarity"], r["type"], r["border"], lore)
    )
out.append("}")
open(os.path.join(root, "NewCards.lua"), "w").write("\n".join(out) + "\n")
print(len(rows), "cards written to NewCards.lua")
