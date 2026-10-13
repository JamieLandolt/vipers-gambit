"""Generates the extra Viper's Gambit snake cards (86 regular + 5 legendary) and tools/new_cards.tsv.

Usage: python3 tools/draw_more_cards.py [out_dir [sheet_dir]]
out_dir defaults to assets/Snake_Cards. Contact sheets (numbered, 20 cards each) go to sheet_dir if given.
Does not touch the original 43 cards (their names are never produced here).
"""
import math
import os
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont

from draw_cards import S, W, H, CARDS, load, save, clear_art, draw_stats
from snake_engine import POSES, catmull, transform, render, finish, deco, hx

PI = math.pi
POSE = {
    "S1": ("wave", dict(amp=5, cycles=1.5)),
    "S2": ("wave", dict(amp=9, cycles=1.0)),
    "S3": ("wave", dict(amp=3.5, cycles=3)),
    "S4": ("wave", dict(amp=8, cycles=2.0)),
    "S5": ("wave", dict(amp=6, cycles=2.5, phase=PI)),
    "S6": ("wave", dict(amp=4.5, cycles=1, cx=18, phase=PI)),
    "coilA": ("coil", dict(cy=26)),
    "coilB": ("coil", dict(cx=14, cy=26, R0=8, turns=2.0, a0=PI, d=-1, head=(14, 5))),
    "coilC": ("coil", dict(cx=15, cy=25, R0=8.5, turns=2.0, head=(18, 5))),
    "spiral": ("spiral", dict(cy=23)),
    "spiral2": ("spiral", dict(cy=23, R0=10, turns=1.6, a0=0, d=-1)),
    "zig4": ("zig", dict(xl=10, xr=22)),
    "zig6": ("zig", dict(n=6, xl=12, xr=22)),
    "arch": ("arch", dict(base=32)),
    "arch2": ("arch", dict(R=8, H_=23, cx=17, base=32)),
    "arc": ("arc", dict()),
    "loop": ("loop", dict(b=8, a=3.8, cx=17, y0=4)),
    "loop2": ("loop", dict(b=6, a=2.5, loops=2, cx=17, y0=6)),
    "fig8": ("fig8", dict(B=13)),
    "hwave": ("hwave", dict()),
    "hwave2": ("hwave", dict(amp=8, cycles=1.0, cy=21)),
    "diag": ("line", dict(x0=26, y0=5, x1=6, y1=35, amp=3, cycles=1.5)),
    "drape": ("pts", dict(pts=[(13, 34), (13, 22), (14, 12), (18, 7), (22, 11), (22, 22), (20, 32)])),
    "S7": ("wave", dict(amp=7, cycles=1.25, cx=19, y0=4, y1=35, phase=PI)),
    "S8": ("wave", dict(amp=3, cycles=2, y0=5, y1=36)),
    "S9": ("wave", dict(amp=9, cycles=0.75, cx=18, y0=5, y1=36)),
    "S10": ("wave", dict(amp=5, cycles=2, cx=15, phase=PI, y0=12, y1=36)),
    "hwave3": ("hwave", dict(amp=3, cycles=3, cy=14, x0=5, x1=29)),
    "hwave4": ("hwave", dict(amp=5, cycles=2, cy=26, x0=4, x1=29)),
    "hwave5": ("hwave", dict(amp=7, cycles=1.5, cy=20, x0=6, x1=28, phase=PI)),
    "zig3": ("zig", dict(n=3, xl=8, xr=25)),
    "zig5": ("zig", dict(n=5, xl=11, xr=21)),
    "zig7": ("zig", dict(n=7, xl=13, xr=20, y0=5, y1=36)),
    "ushape": ("pts", dict(pts=[(11, 12), (10, 28), (14, 33), (21, 31), (23, 24), (21, 10)])),
    "N": ("pts", dict(pts=[(11, 12), (11, 32), (21, 12), (21, 33)])),
    "question": ("pts", dict(pts=[(11, 12), (14, 6), (21, 7), (24, 13), (20, 20), (16, 26), (16, 36)])),
    "loop3": ("loop", dict(b=7, a=2.9, cx=17, y0=4)),
    "diag2": ("line", dict(x0=27, y0=12, x1=5, y1=35, amp=2, cycles=1)),
    "diag3": ("line", dict(x0=22, y0=4, x1=11, y1=36, amp=6, cycles=2)),
    "hook2": ("pts", dict(pts=[(14, 11), (14, 27), (10, 32), (18, 34), (24, 28)])),
    "Zs": ("pts", dict(pts=[(24, 6), (12, 12), (24, 20), (10, 28), (20, 36)])),
    "hook": ("pts", dict(pts=[(16, 5), (16, 24), (18, 30), (24, 31), (26, 26)])),
    "wideS": ("pts", dict(pts=[(24, 6), (10, 14), (22, 22), (10, 30), (18, 36)])),
}

ROSTER = []


def add(name, typ, tier, cost, style, border, lore, base, alt, pat, pose, **kw):
    ROSTER.append(dict(name=name, typ=typ, tier=tier, cost=cost, style=style, border=border, lore=lore,
                       base=hx(base), alt=hx(alt), pat=pat, pose=pose, **kw))


def cols(*cs):
    return [hx(c) for c in cs]


# ------------------------------------------------------------------ LAND
add("Dust_Adder", "Land", 1, 1, "bal", "Basic", "Dusty and quick, it vanishes into the dry ground.", "b8a07a", "8a6f4a", "stripe", "S1", mir=True, rb=2.5, deco="sand", pp=dict(w=0.22))
add("Rock_Snake", "Land", 1, 2, "tank", "Basic", "It sleeps among boulders so long that moss mistakes it for stone.", "8a8580", "6a6560", "scales", "S2", head="flat", deco="rocks")
add("Hog_Nosed_Snake", "Land", 1, 2, "bal", "Basic", "When cornered it rolls over and plays dead, badly.", "c9a46a", "7a4f2a", "spots", "hook", head="flat", rb=3.2, pp=dict(p=0.4, size=2.5))
add("Scrub_Racer", "Land", 1, 1, "glass", "Basic", "Too fast for anything in the scrub to catch.", "8a8a3a", "d8d27a", "stripes2", "diag", rb=2.3)
add("Clay_Snake", "Land", 1, 2, "bal", "Fire", "Baked red by the sun, it hardens at the first sign of a fight.", "b5603a", "e2a070", "bands", "zig4", pp=dict(period=5))
add("Rust_Viper", "Land", 1, 2, "glass", "Fire", "Its scales flake like old iron, and its bite is just as hard.", "a24a2a", "d9822e", "speckle", "S4", mir=True, head="viper", acc=["horns"], accol=hx("e8c890"), pp=dict(p=0.3))
add("Dune_Viper", "Land", 2, 3, "glass", "Basic", "It drifts sideways over the dunes, leaving only wavy tracks.", "e0c88a", "a67c3c", "diamonds", "diag2", head="viper", acc=["horns"], accol=hx("fff0c0"), deco="sand", pp=dict(period=8))
add("Mesa_Adder", "Land", 2, 3, "bal", "Fire", "Banded like the red cliffs it hides in.", "d2693a", "f2d7a0", "bands", "zig6", head="spade", pp=dict(period=5, duty=0.4))
add("Bull_Snake", "Land", 2, 4, "tank", "Basic", "Hisses like a rattler and hits like a bull.", "e3c36a", "7a4a22", "saddles", "coilA", rb=3.2)
add("Prairie_Rattler", "Land", 2, 3, "atk", "Venom", "Hear the rattle and you are already in range.", "b49a62", "6b5230", "diamonds", "hook2", head="viper", tail="rattle", pp=dict(period=6))
add("Stone_Constrictor", "Land", 2, 4, "tank", "Basic", "It squeezes until the pebbles in its path turn to sand.", "7d8590", "adb4bc", "net", "arch", rb=3.4, bulge=0.1, head="flat", deco="rocks")
add("Iron_Snake", "Land", 2, 3, "tank", "Basic", "Forged by a thousand rainy seasons in the old mine.", "60697a", "9fb0c8", "speckle", "loop", head="spade", acc=["spikes"], accol=hx("c8d4e4"), pp=dict(p=0.25))
add("Sandstorm_Asp", "Land", 3, 4, "atk", "Gold", "Wears the desert wind like a golden hood.", "e6b84a", "fff0b0", "grad", "coilB", hood=2.2, hoodcol=hx("f4d878"), pp=dict(stops=cols("c8842a", "e6b84a", "f4d878", "fff0b0")), deco="sand")
add("Tiger_Snake", "Land", 3, 5, "atk", "Fire", "Stripes like a tiger and a temper to match.", "e08a28", "2a2018", "bands", "S7", flip=True, head="spade", rb=3.5, pp=dict(period=4))
add("Bushmaster", "Land", 3, 6, "bal", "Basic", "The largest viper in the dry forest, and the most patient.", "a8643a", "3e2418", "diamonds", "S8", rb=3.4, head="spade", acc=["spikes"], accol=hx("3e2418"), pp=dict(period=7))
add("Basalt_Serpent", "Land", 3, 5, "tank", "Fire", "Cracks glow orange where the lava still sleeps beneath its scales.", "2a2228", "ff6a1e", "cracks", "Zs", rb=3.2, head="flat", eye=hx("ff9a3a"), deco="embers")
add("Obsidian_Wyrm", "Land", 4, 6, "glass", "Fire", "Black glass scales, red veins, and a hunger that never cools.", "1a1a24", "c8283c", "chevron", "coilC", rb=3.3, head="viper", acc=["horns", "spikes"], accol=hx("c8283c"), acccols=dict(horns=hx("e8e0f0")), eye=hx("ff5a3a"), pp=dict(period=6))
add("Colossus_Python", "Land", 4, 6, "tank", "Basic", "It has swallowed three explorers and still looks for more.", "9a7648", "3e2c1a", "net", "spiral", rb=3.6, head="flat")

# ------------------------------------------------------------------ WATER
add("Pond_Snake", "Water", 1, 1, "bal", "Basic", "Always found where the lilies are thickest.", "4a8a7a", "bfe0c8", "stripe", "hwave", pp=dict(w=0.2))
add("Reed_Snake", "Water", 1, 1, "bal", "Basic", "Thin as a reed and just as hard to spot.", "8a9a4a", "e0dc7a", "stripes2", "S3", flip=True, rb=2.3, head="long", deco="bubbles")
add("Brook_Snake", "Water", 1, 2, "def", "Basic", "It follows the stream wherever the water takes it.", "6a8aa8", "d8ecf4", "spots", "arc", pp=dict(p=0.3))
add("Eel_Snake", "Water", 1, 2, "bal", "Basic", "Half eel, half snake, all slippery.", "2e5a66", "6ab0b8", "grad", "hwave3", mir=True, rb=2.6, tail="paddle", acc=["fins"], accol=hx("4aa0b0"))
add("Ripple_Snake", "Water", 1, 1, "bal", "Frost", "Each ring on its skin is a ripple that never fades.", "5aa0d8", "dcf0ff", "rings", "hwave2", pp=dict(period=4, th=1.6))
add("Moray_Viper", "Water", 2, 3, "atk", "Basic", "Its jaws snap from the reef before the fish even sees it.", "8a7a3a", "d8c46a", "blotch", "S4", flip=True, rb=3.4, head="flat", rh=5.0, deco="bubbles")
add("Cottonmouth", "Water", 2, 3, "atk", "Venom", "It gapes pale and wide before it strikes.", "4a4a3a", "a8a070", "bands", "zig3", flip=True, head="spade", pp=dict(period=5, duty=0.45), eye=hx("ffe070"))
add("Reef_Adder", "Water", 2, 3, "bal", "Basic", "A flash of orange and blue on the coral.", "ff7a3a", "2a8ad8", "harlequin", "S5", acc=["fins"], accol=hx("ffc080"), cols=cols("ff7a3a", "2a8ad8", "f4f0e0"), pp=dict(w=2.5))
add("Tide_Snake", "Water", 2, 2, "def", "Frost", "It rises and falls with the moon.", "2a68b8", "a8d8f8", "grad", "hwave4", pp=dict(stops=cols("2a68b8", "5aa8e0", "a8d8f8", "ffffff")), deco="waves")
add("Kelp_Snake", "Water", 2, 2, "bal", "Basic", "It wears the forest of the sea on its back.", "5a7a2a", "a8883a", "vein", "S6", frill=2.0, frillcol=hx("6a9a30"), deco="bubbles")
add("Lagoon_Python", "Water", 2, 4, "tank", "Basic", "Warm shallows, golden spots, and a long, lazy squeeze.", "3ab8b0", "ffd84a", "spots", "ushape", rb=3.3, pp=dict(p=0.35, size=2.4))
add("Tempest_Serpent", "Water", 3, 5, "atk", "Basic", "Lightning follows wherever it swims.", "5a6a8a", "ffe04a", "zigzag", "wideS", head="viper", acc=["fins"], accol=hx("9ab0d0"), tail="paddle", deco="bubbles")
add("Abyssal_Eel", "Water", 3, 5, "bal", "Shadow", "Lured by its glowing lights, few ever surface again.", "14233e", "2ab8ff", "glowdots", "S9", mir=True, head="flat", glow=True, eye=hx("5ae8ff"), acc=["fins"], accol=hx("2a6aa8"), tail="paddle", cols=cols("3ad0ff", "1e3560"))
add("Pearl_Serpent", "Water", 3, 4, "def", "Gold", "Its scales shimmer like the inside of a shell.", "e8d8e8", "9ac0d8", "grad", "arch2", pp=dict(stops=cols("f6e8f0", "c8d8f0", "f0c8e0", "fff6ff")), acc=["spikes"], accol=hx("ffffff"))
add("Siren_Snake", "Water", 3, 4, "bal", "Rainbow", "Its song sounds like someone you miss.", "d85a9a", "3ab8c8", "chevron", "S1", flip=True, frill=2.6, frillcol=hx("3ab8c8"), acc=["whiskers"], accol=hx("ffc0e0"))
add("Glacier_Adder", "Water", 3, 5, "atk", "Frost", "Frozen in a glacier for a thousand years, and angry about it.", "a8d8f0", "ffffff", "saddles", "Zs", mir=True, head="viper", acc=["horns", "crest"], accol=hx("ffffff"), deco="snow")
add("Maelstrom_Serpent", "Water", 4, 6, "bal", "Frost", "It coils into a whirlpool and drags ships to the deep.", "1f4f9f", "d0f0ff", "barber", "spiral2", mir=True, rb=3.2, head="spade", acc=["fins"], accol=hx("6ab4f0"), pp=dict(period=6))
add("Coral_Dragon", "Water", 4, 5, "atk", "Fire", "Reef kings once crowned it a dragon, and it never argued.", "f07a6a", "ffd0a0", "net", "S7", head="spade", acc=["whiskers", "mane", "horns"], accol=hx("ffe8c0"), acccols=dict(mane=hx("ffa070")), deco="bubbles")
add("Storm_Leviathan", "Water", 4, 6, "tank", "Frost", "When it breaches, the sky turns to follow.", "2a3a6a", "7ab0f0", "zigzag", "arch", mir=True, rb=3.8, head="viper", acc=["bigspikes"], accol=hx("7ab0f0"), tail="paddle", deco="waves")

# ------------------------------------------------------------------ TREE
add("Leaf_Snake", "Tree", 1, 1, "bal", "Basic", "Hangs among the leaves and fools the wind.", "5cc040", "2e8a2a", "vein", "S1", deco="leaves")
add("Twig_Snake", "Tree", 1, 1, "bal", "Basic", "Not a branch, whatever the birds think.", "8a6a44", "5a4026", "bands", "zig7", mir=True, rb=2.2, head="long", pp=dict(period=3, duty=0.3))
add("Moss_Snake", "Tree", 1, 2, "def", "Basic", "Slow, damp and fuzzy with green.", "4a6a38", "8aaa4a", "blotch", "S3", rb=3.0, head="flat", deco="spores", pp=dict(p=0.45))
add("Bark_Snake", "Tree", 1, 2, "bal", "Basic", "Rough scales, rougher manners.", "6a5038", "3e2e20", "scales", "diag", mir=True, flip=True, rb=2.8, head="flat")
add("Fern_Snake", "Tree", 1, 1, "bal", "Basic", "Unfurls at dawn like a young fern.", "7acc6a", "d8f0a0", "chevron", "arc", mir=True)
add("Orchid_Snake", "Tree", 1, 2, "glass", "Venom", "Beautiful, and every bit as poisonous as it looks.", "9a4aa8", "f0a0d8", "spots", "question", deco="petals", pp=dict(p=0.3))
add("Emerald_Boa", "Tree", 2, 4, "def", "Gold", "A green jewel wound around a branch.", "1fa860", "e8fff0", "zigzag", "coilA", mir=True, rb=3.2)
add("Jungle_Racer", "Tree", 2, 2, "atk", "Venom", "It races the monkeys and wins.", "245a2a", "f0e040", "spots", "diag3", rb=2.4, head="long", pp=dict(p=0.3))
add("Canopy_Viper", "Tree", 2, 3, "bal", "Venom", "Its red tail flickers like a flower to lure the unwary.", "70d048", "e83a3a", "stripe", "S5", mir=True, head="viper", tail="tuft", acc=["crest"], accol=hx("f0e060"))
add("Bamboo_Pit_Viper", "Tree", 2, 3, "atk", "Venom", "Sits so still that bamboo grows around it.", "b8d048", "5a7a1a", "rings", "drape", head="spade", deco="branch", pp=dict(period=5))
add("Liana_Snake", "Tree", 2, 2, "bal", "Basic", "A vine that learned to bite.", "3a8a3a", "a8e06a", "vein", "spiral2", rb=2.4, deco="leaves")
add("Chameleon_Snake", "Tree", 2, 3, "bal", "Rainbow", "Its colours change with its mood, mostly angry.", "5ac8a0", "e8a83a", "blotch", "Zs", flip=True, pp=dict(p=0.5))
add("Mossback_Python", "Tree", 3, 5, "tank", "Basic", "Entire ferns grow on its back, and it lets them.", "5a6a2a", "8aa04a", "blotch", "coilC", mir=True, rb=3.8, bulge=0.12, head="flat", deco="leaves")
add("Thornback_Viper", "Tree", 3, 4, "atk", "Venom", "Every inch of its spine is a warning.", "4a7a3a", "c8a060", "chevron", "zig5", flip=True, head="viper", acc=["bigspikes"], accol=hx("e8d8a0"))
add("Blossom_Boa", "Tree", 3, 5, "def", "Basic", "Spring follows it everywhere, in pink.", "3a8a4a", "ff8ab8", "spots", "fig8", acc=["crown"], accol=hx("ffd0e0"), deco="petals", pp=dict(p=0.35))
add("Amber_Tree_Viper", "Tree", 3, 4, "atk", "Gold", "Golden eyes, golden scales, a golden branch to hang from.", "d89a2a", "7a4a1a", "diamonds", "drape", mir=True, head="spade", deco="branch")
add("Venom_Vine", "Tree", 3, 4, "glass", "Venom", "Its purple bands drip with poison.", "6ac82a", "a02ad0", "stripes2", "loop3", rb=2.4, head="viper", tongue=hx("a02ad0"), deco="spores")
add("Elderwood_Wyrm", "Tree", 4, 6, "bal", "Basic", "Older than the forest, and the forest is very old.", "6a4a2a", "4a8a3a", "net", "coilB", rb=3.5, head="flat", acc=["antlers", "mane"], accol=hx("a8783a"), acccols=dict(mane=hx("4a9a3a")), deco="leaves")
add("Canopy_King", "Tree", 4, 5, "bal", "Gold", "All the branches bow when it passes.", "2a8a4a", "f0c83a", "chevron", "S2", flip=True, head="spade", acc=["crown", "wings"], accol=hx("f0c83a"), acccols=dict(wings=hx("5ac86a")), deco="leaves")

# ------------------------------------------------------------------ SPIRIT
add("Wisp_Snake", "Spirit", 1, 1, "bal", "Frost", "A glimmer on the marsh that follows you home.", "9ad0f0", "e8f8ff", "grad", "S8", flip=True, rb=2.4, glow=True, eye=hx("ffffff"), deco="wisps")
add("Gloom_Snake", "Spirit", 1, 2, "def", "Shadow", "It brings the dark to every room.", "4a4258", "6a5e80", "speckle", "S3", mir=True, pp=dict(p=0.2), deco="wisps")
add("Ash_Snake", "Spirit", 1, 1, "bal", "Shadow", "What remains after the fire has forgotten.", "8a8a90", "c8c8d0", "speckle", "zig7", flip=True, pp=dict(p=0.35), deco="snow")
add("Mist_Snake", "Spirit", 1, 1, "def", "Frost", "Hard to hit when it is mostly fog.", "d0d8e0", "ffffff", "grad", "hwave", eye=hx("5a6a8a"), pp=dict(stops=cols("c0c8d8", "e0e8f0", "ffffff")))
add("Wraith_Adder", "Spirit", 2, 3, "atk", "Shadow", "Its glowing eyes are the last thing most things see.", "4a2a7a", "b080ff", "chevron", "S9", head="viper", glow=True, eye=hx("ff60ff"), acc=["horns"], accol=hx("b080ff"), deco="wisps")
add("Bone_Viper", "Spirit", 2, 3, "atk", "Shadow", "A viper that forgot to stop after dying.", "e8e0c8", "a89c78", "bands", "zig6", flip=True, head="viper", eye=hx("000000"), pp=dict(period=3, duty=0.4))
add("Phantom_Racer", "Spirit", 2, 2, "atk", "Frost", "You only see it after it has passed through you.", "78d8d0", "d0fff8", "barber", "diag2", mir=True, flip=True, rb=2.3, glow=True, eye=hx("ffffff"))
add("Dusk_Snake", "Spirit", 2, 3, "bal", "Shadow", "Born where the sunset meets the first star.", "d8602a", "4a2a78", "grad", "arc", flip=True, pp=dict(stops=cols("e8802a", "c85a5a", "7a3a98", "3a2a68")))
add("Cursed_Snake", "Spirit", 2, 3, "atk", "Venom", "Bound in rags and bitter to the last.", "2a4a30", "c8c8a0", "bands", "N", flip=True, head="viper", eye=hx("ff3030"), pp=dict(period=4, duty=0.25))
add("Grave_Snake", "Spirit", 2, 2, "def", "Shadow", "It guards the old stones, and the old stones guard it.", "5a5a48", "8aa06a", "blotch", "hook", mir=True, deco="wisps")
add("Banshee_Serpent", "Spirit", 3, 4, "def", "Frost", "Its wail turns warriors to statues.", "f0e0f0", "c8a0e8", "stripe", "S6", frill=2.4, frillcol=hx("d8b8ff"), acc=["halo"], accol=hx("ffffff"), glow=True, eye=hx("ff80c0"), deco="wisps")
add("Lich_Snake", "Spirit", 3, 5, "bal", "Venom", "A dead king's mind in a living green body.", "2a7a78", "b0ff7a", "glowdots", "question", mir=True, head="flat", glow=True, eye=hx("b0ff7a"), acc=["crown"], accol=hx("d8ff80"), cols=cols("b0ff7a", "3ad0a0"))
add("Soul_Eater", "Spirit", 3, 5, "atk", "Shadow", "Every soul it swallows adds one more spark.", "5a2a8a", "ffe84a", "glowdots", "loop", mir=True, head="spade", acc=["spikes"], accol=hx("e0a0ff"), cols=cols("ffe84a", "e0a0ff"))
add("Nightmare_Adder", "Spirit", 3, 4, "glass", "Shadow", "Coils in the corner of every bad dream.", "10101c", "3a6aff", "cracks", "N", head="viper", acc=["mane"], accol=hx("3a6aff"), glow=True, eye=hx("5a8aff"), deco="wisps")
add("Plague_Wraith", "Spirit", 3, 3, "bal", "Venom", "A sickly green mist wearing a snake's shape.", "6a7a3a", "c8e06a", "blotch", "S1", mir=True, flip=True, acc=["mane"], accol=hx("a0c850"), glow=True, eye=hx("e0ff60"), deco="spores")
add("Reaper_Serpent", "Spirit", 4, 6, "glass", "Shadow", "It does not strike. It simply arrives.", "1c1824", "d8d0e8", "bands", "zig3", rb=3.2, head="viper", glow=True, eye=hx("ff2a2a"), acc=["horns", "bigspikes"], accol=hx("d8d0e8"), pp=dict(period=6, duty=0.15))
add("Void_Wyrm", "Spirit", 4, 6, "bal", "Shadow", "A hole in the night in the shape of a snake.", "0a0a1e", "ffffff", "speckle", "coilB", mir=True, rb=3.4, glow=True, eye=hx("c080ff"), acc=["wings"], accol=hx("3a2a7a"), pp=dict(p=0.09), deco="stars")
add("Phantom_King", "Spirit", 4, 5, "def", "Frost", "Rules a court of the quietly dead.", "88d8e8", "f8ffff", "grad", "S10", mir=True, hood=2.0, hoodcol=hx("c0eef8"), glow=True, eye=hx("40c0ff"), acc=["crown", "wings"], accol=hx("ffe880"), acccols=dict(wings=hx("c8f0ff")), pp=dict(stops=cols("88d8e8", "c8f0f8", "ffffff")), deco="wisps")

# ------------------------------------------------------------------ RAINBOW
add("Candy_Snake", "Rainbow", 1, 1, "bal", "Rainbow", "Sweet to look at, sticky to fight.", "ff7aa8", "ffffff", "barber", "S8", mir=True, rb=2.6, pp=dict(period=5))
add("Confetti_Snake", "Rainbow", 1, 1, "bal", "Rainbow", "Every day is a party where it lives.", "f4eef8", "ff5a8a", "confetti", "zig4", mir=True, cols=cols("ff5a8a", "5ac8ff", "ffe050", "7aff7a", "d880ff"), deco="confetti")
add("Jelly_Snake", "Rainbow", 1, 2, "def", "Rainbow", "Wobbles, shines and is surprisingly hard to bite.", "ff90d8", "8af0ff", "spots", "arc", mir=True, flip=True, rb=3.2, pp=dict(p=0.4))
add("Prism_Adder", "Rainbow", 2, 3, "atk", "Rainbow", "Split the light and you will find it in the middle.", "ff6a6a", "6a6aff", "hue", "diag3", mir=True, head="viper", pp=dict(turns=1.5))
add("Carnival_Snake", "Rainbow", 2, 3, "bal", "Rainbow", "The best show in town, and it wants an audience.", "e83a3a", "f4e03a", "harlequin", "zig6", flip=True, head="spade", cols=cols("e83a3a", "f4e03a", "2a8ae8", "3ac85a"))
add("Opal_Snake", "Rainbow", 2, 2, "def", "Rainbow", "Milky and bright, with a fire inside.", "ffd0e8", "c8e0ff", "grad", "hook", mir=True, pp=dict(stops=cols("ffd0e8", "c8e0ff", "d8ffe8", "fff0c8")))
add("Parrot_Snake", "Rainbow", 2, 4, "atk", "Rainbow", "Squawks, preens and bites with a hooked grin.", "3ac83a", "e83a3a", "cycle", "arch", mir=True, tail="tuft", acc=["crest"], accol=hx("f0d83a"), cols=cols("3ac83a", "e83a3a", "3a6ae8", "f0d83a"), pp=dict(w=3.5))
add("Aurora_Serpent", "Rainbow", 3, 5, "bal", "Rainbow", "Wears the northern lights like a cape.", "2a9a6a", "c05ad8", "grad", "N", mir=True, acc=["wings"], accol=hx("7af0c8"), pp=dict(stops=cols("2a9a6a", "3ad0a0", "6a7af0", "c05ad8")), deco="stars")
add("Kaleido_Viper", "Rainbow", 3, 4, "glass", "Rainbow", "Turn it just a little and it becomes someone else.", "e83a8a", "3ae8c8", "harlequin", "ushape", mir=True, head="viper", acc=["horns"], accol=hx("fff0a0"), cols=cols("e83a8a", "3ae8c8", "f0e03a", "8a3ae8"), pp=dict(w=2.5))
add("Sunset_Boa", "Rainbow", 3, 5, "def", "Fire", "Every evening the sky borrows its colours.", "ffe85a", "4a2a78", "grad", "hwave5", rb=3.6, head="flat", pp=dict(stops=cols("ffe85a", "ff9a3a", "e8503a", "a83a8a", "4a2a78")))
add("Chromatic_Wyrm", "Rainbow", 4, 6, "bal", "Rainbow", "A dragon in every colour, flawless in none.", "ff6a6a", "6a6aff", "hue", "wideS", flip=True, rb=3.4, head="viper", acc=["horns"], accol=hx("ffffff"), pp=dict(turns=2.0, sat=0.75))
add("Spectrum_Basilisk", "Rainbow", 4, 5, "glass", "Rainbow", "One glance and the rainbow rules you.", "ff4a4a", "4a4aff", "cycle", "fig8", flip=True, rb=3.0, head="spade", glow=True, eye=hx("ffffff"), acc=["crown", "mane"], accol=hx("ffe880"), acccols=dict(mane=hx("ffffff")), cols=cols("ff4a4a", "ff9a3a", "ffe84a", "4ae85a", "4ab8ff", "8a5aff"), pp=dict(w=2.5))


# ------------------------------------------------------------------ stats / build
def stats_for(spec, i):
    cost, tier = spec["cost"], spec["tier"]
    f = 4.0 + 0.45 * (tier - 1) + ((i * 37) % 5 - 2) * 0.12
    total = max(3, round(cost * f))
    share = dict(bal=0.5, glass=0.72, tank=0.3, atk=0.6, def_=0.4)[spec["style"].replace("def", "def_")] + ((i * 13) % 5 - 2) * 0.02
    atk = max(1, round(total * share))
    dfn = max(1, total - atk)
    atk, dfn = min(atk, 19), min(dfn, 19)  # two digits starting with 2 would collide with the corner frame
    return atk, dfn


def build_regular(spec):
    seed = zlib.crc32(spec["name"].encode()) & 0xFFFF
    kind, kw = POSE[spec["pose"]]
    pts0 = POSES[kind](**kw) if kind != "pts" else kw["pts"]
    want = (spec.get("flip", False), spec.get("mir", False))
    best = None
    for flip, mir in [want] + [c for c in ((False, False), (True, False), (False, True), (True, True)) if c != want]:
        g = load("Snake.png")
        clear_art(g)
        if spec.get("deco"):
            deco(g, spec["deco"], seed)
        path = catmull(transform(pts0, flip, mir))
        info = render(g, path, spec, seed)
        if best is None or info["clipped"] < best[1]:
            best = (g, info["clipped"], path, info)
        if info["clipped"] == 0:
            break
        if (flip, mir) != want and best[1] == 0:
            break
    g, clipped, path, info = best
    finish(g, path, info, spec)
    draw_stats(g, spec["cost"], spec["atk"], spec["def"], spec["tier"])
    return g, clipped


def all_specs():
    specs = []
    for i, s in enumerate(ROSTER):
        s = dict(s)
        s["atk"], s["def"] = stats_for(s, i)
        specs.append(s)
    try:
        from draw_legendary import LEGENDARY
    except ImportError:
        LEGENDARY = []
    return specs, LEGENDARY


def sheets(names, sheet_dir, out_dir, per=20):
    font = ImageFont.load_default(size=16)
    os.makedirs(sheet_dir, exist_ok=True)
    for n in range(0, len(names), per):
        chunk = names[n:n + per]
        sheet = Image.new("RGB", (W * S * 5, (H * S + 26) * 4), (30, 30, 30))
        d = ImageDraw.Draw(sheet)
        for k, name in enumerate(chunk):
            x, y = (k % 5) * W * S, (k // 5) * (H * S + 26)
            d.text((x + 6, y + 3), f"{n + k + 1} {name.replace('_', ' ')}", fill=(255, 255, 255), font=font)
            sheet.paste(Image.open(os.path.join(out_dir, name + ".png")), (x, y + 26))
        sheet.save(os.path.join(sheet_dir, f"new_sheet{n // per + 1}.png"))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else CARDS
    os.makedirs(out, exist_ok=True)
    specs, legends = all_specs()
    names, rows = [], []
    for s in specs:
        g, clipped = build_regular(s)
        save(g, os.path.join(out, s["name"] + ".png"))
        names.append(s["name"])
        rows.append((s["name"], s["cost"], s["atk"], s["def"], s["tier"], s["typ"], s["border"], s["lore"]))
        if clipped:
            print("clipped", s["name"], clipped)
    for L in legends:
        g = L["build"]()
        save(g, os.path.join(out, L["name"] + ".png"))
        names.append(L["name"])
        rows.append((L["name"], L["cost"], L["atk"], L["def"], 5, L["typ"], L["border"], L["lore"]))
    tsv = os.path.join(os.path.dirname(os.path.abspath(__file__)), "new_cards.tsv")
    with open(tsv, "w") as f:
        f.write("name\tcost\tattack\tdefense\trarity\ttype\tborder\tlore\n")
        for r in rows:
            f.write("\t".join(str(v) for v in r) + "\n")
    print(len(specs), "regular +", len(legends), "legendary cards written to", out)
    if len(sys.argv) > 2:
        sheets(names, sys.argv[2], out)


if __name__ == "__main__":
    main()
