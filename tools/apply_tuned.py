"""Writes the decks and venom printed by `MODE=tune luajit tools/sim.lua` (piped in on stdin) into Opponents.lua."""
import re, sys
rows = {}
for line in sys.stdin:
    m = re.match(r'(\d+)\t.*?\tvenom (\d+)\t.*?\t(\{ .* \})\s*$', line)
    if m:
        rows[int(m.group(1))] = (int(m.group(2)), m.group(3))
lines = open("Opponents.lua").read().split("\n")
level = 0
for i, l in enumerate(lines):
    m = re.match(r'(\t\{ "[^"]+", "[^"]+", "[^"]+", "\w+", )(\d+)(, )\{ .* \} \},$', l)
    if m:
        level += 1
        if level in rows:
            lines[i] = m.group(1) + str(rows[level][0]) + m.group(3) + rows[level][1] + " },"
open("Opponents.lua", "w").write("\n".join(lines))
