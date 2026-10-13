"""Draws the campaign opponents' portraits (the friends use their own photos). Usage: python3 tools/draw_opponents.py assets/opponents
Reuses the figure helpers from draw_charmers.py; every portrait is 71x87 art pixels scaled 5x."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import draw_charmers as dc
from draw_charmers import person, snake, WHITE, BLACK

def c(r, g, b):
    return (r, g, b, 255)

def garden_keeper(d):  # straw hat, green apron, a garter snake in the watering can
    person(d, c(225, 180, 140), c(190, 145, 110), c(80, 140, 70), c(50, 100, 45))
    d.ellipse([8, 14, 62, 30], fill=c(230, 200, 110))
    d.ellipse([20, 4, 50, 24], fill=c(240, 215, 130))
    d.rectangle([20, 16, 50, 19], fill=c(180, 60, 50))
    d.rectangle([29, 49, 41, 50], fill=c(150, 60, 60))
    snake(d, [(60, 86), (62, 76), (56, 68), (60, 58)], head_dir=-1)

def pond_skulker(d):  # reed hat, teal cloak, glowing pale eyes
    person(d, c(150, 190, 170), c(115, 155, 135), c(40, 110, 120), c(20, 70, 85), eye=c(255, 240, 120))
    d.polygon([(35, 0), (66, 26), (4, 26)], fill=c(170, 150, 80))
    d.rectangle([4, 24, 66, 28], fill=c(120, 100, 50))
    d.polygon([(10, 56), (35, 66), (60, 56), (60, 70), (10, 70)], fill=c(40, 110, 120))
    snake(d, [(8, 84), (6, 74), (12, 66), (10, 56)], body=c(90, 180, 200), belly=c(50, 120, 150), head_dir=1)

def venom_rookie(d):  # red bandana, wide grin, purple scarf
    person(d, c(235, 195, 160), c(200, 160, 125), c(90, 60, 150), c(60, 35, 110))
    d.rectangle([17, 18, 53, 28], fill=c(200, 40, 50))
    d.polygon([(52, 22), (66, 16), (64, 30)], fill=c(200, 40, 50))
    d.rectangle([20, 24, 22, 34], fill=c(90, 55, 30))
    d.rectangle([48, 24, 50, 34], fill=c(90, 55, 30))
    d.rectangle([28, 48, 42, 50], fill=WHITE)
    d.rectangle([12, 58, 58, 64], fill=c(150, 90, 200))
    snake(d, [(60, 84), (66, 74), (60, 66), (64, 54)], body=c(180, 90, 220), belly=c(120, 50, 160), head_dir=-1)

def dune_wanderer(d):  # sand wraps over the face, sun-beaten eyes
    person(d, c(180, 125, 85), c(145, 95, 65), c(220, 190, 130), c(180, 145, 85), eye=c(60, 40, 20))
    d.polygon([(35, 4), (60, 30), (62, 64), (8, 64), (10, 30)], fill=c(235, 215, 165))
    d.ellipse([22, 28, 48, 46], fill=c(180, 125, 85))
    d.rectangle([24, 35, 29, 37], fill=BLACK)
    d.rectangle([41, 35, 46, 37], fill=BLACK)
    d.rectangle([24, 46, 46, 64], fill=c(235, 215, 165))
    d.rectangle([10, 52, 60, 55], fill=c(190, 150, 90))
    snake(d, [(4, 82), (10, 72), (6, 62), (12, 52)], body=c(210, 170, 90), belly=c(160, 120, 60), head_dir=1)

def crypt_warden(d):  # bone-grey hood, skull mask, lantern
    person(d, c(215, 215, 200), c(175, 175, 165), c(60, 60, 80), c(35, 35, 55), eye=c(120, 255, 180))
    d.polygon([(35, 2), (64, 36), (62, 64), (8, 64), (6, 36)], fill=c(55, 55, 75))
    d.ellipse([20, 20, 50, 54], fill=c(225, 225, 210))
    d.rectangle([25, 33, 31, 40], fill=c(20, 20, 30))
    d.rectangle([39, 33, 45, 40], fill=c(20, 20, 30))
    d.point([(28, 36), (42, 36)], fill=c(120, 255, 180))
    d.polygon([(33, 42), (37, 42), (35, 46)], fill=c(20, 20, 30))
    for x in range(26, 46, 4):
        d.rectangle([x, 49, x + 1, 53], fill=c(20, 20, 30))
    d.rectangle([52, 66, 62, 80], fill=c(250, 210, 90))
    snake(d, [(6, 84), (8, 74), (4, 66), (8, 56)], body=c(170, 200, 180), belly=c(110, 140, 125), head_dir=1)

def reed_stalker(d):  # feathered hunter's hat, brown cloak, camouflage paint
    person(d, c(200, 150, 105), c(165, 115, 80), c(100, 80, 45), c(65, 50, 25))
    d.ellipse([14, 12, 56, 30], fill=c(80, 100, 50))
    d.rectangle([20, 4, 50, 18], fill=c(80, 100, 50))
    d.polygon([(46, 8), (66, -2), (62, 14)], fill=c(220, 70, 60))
    for x in (22, 28, 41, 47):
        d.rectangle([x, 40, x + 2, 41], fill=c(60, 90, 40))
    d.rectangle([30, 49, 40, 50], fill=c(140, 60, 60))
    d.line([(8, 54), (8, 86)], fill=c(120, 85, 45), width=3)
    snake(d, [(60, 86), (64, 74), (58, 66), (62, 56)], body=c(130, 170, 60), belly=c(90, 125, 40), head_dir=-1)

def fang_brawler(d):  # mohawk, scar, fang necklace
    person(d, c(205, 150, 110), c(170, 115, 80), c(40, 40, 50), c(20, 20, 30))
    d.polygon([(30, 18), (35, -2), (40, 18)], fill=c(220, 60, 50))
    d.rectangle([30, 8, 40, 22], fill=c(220, 60, 50))
    d.line([(24, 26), (30, 42)], fill=c(230, 90, 90), width=1)
    d.rectangle([26, 36, 29, 37], fill=BLACK)
    d.rectangle([41, 36, 44, 37], fill=BLACK)
    d.rectangle([22, 28, 30, 29], fill=BLACK)
    d.rectangle([40, 28, 48, 29], fill=BLACK)
    d.rectangle([29, 49, 41, 50], fill=c(110, 40, 40))
    for x in (24, 30, 36, 42, 48):
        d.polygon([(x - 2, 62), (x + 2, 62), (x, 70)], fill=WHITE)
    snake(d, [(62, 86), (66, 76), (60, 68), (64, 58)], body=c(210, 60, 60), belly=c(150, 30, 40), head_dir=-1)

def bog_hermit(d):  # mossy hood, long grey beard, lantern eyes
    person(d, c(190, 175, 145), c(155, 140, 115), c(70, 85, 50), c(40, 55, 30), eye=c(250, 220, 90))
    d.polygon([(35, 2), (62, 34), (60, 62), (10, 62), (8, 34)], fill=c(75, 95, 50))
    d.ellipse([20, 22, 50, 54], fill=c(190, 175, 145))
    d.rectangle([26, 35, 29, 37], fill=c(250, 220, 90))
    d.rectangle([41, 35, 44, 37], fill=c(250, 220, 90))
    d.polygon([(22, 46), (48, 46), (44, 78), (35, 84), (26, 78)], fill=c(170, 170, 160))
    for x in (14, 24, 46, 56):
        d.rectangle([x, 10 + (x % 7), x + 3, 14 + (x % 7)], fill=c(110, 150, 60))
    snake(d, [(4, 86), (10, 76), (4, 68), (10, 60)], body=c(110, 160, 60), belly=c(70, 110, 40), head_dir=1)

def constrictor(d):  # heavy, bald, snake wrapped around the shoulders
    person(d, c(170, 115, 85), c(135, 85, 60), c(140, 90, 50), c(100, 60, 30))
    d.ellipse([17, 12, 53, 40], fill=c(170, 115, 85))
    d.rectangle([22, 28, 30, 30], fill=BLACK)
    d.rectangle([40, 28, 48, 30], fill=BLACK)
    d.rectangle([26, 36, 29, 37], fill=BLACK)
    d.rectangle([41, 36, 44, 37], fill=BLACK)
    d.rectangle([28, 50, 42, 52], fill=c(120, 50, 40))
    snake(d, [(0, 76), (10, 66), (24, 68), (35, 64), (48, 68), (60, 64), (68, 70)], body=c(60, 150, 80), belly=c(35, 105, 55), head_dir=-1)
    snake(d, [(0, 86), (14, 78), (30, 82), (46, 78), (60, 82)], body=c(80, 170, 100), belly=c(40, 115, 60), head_dir=-1)

def mist_witch(d):  # pointed hat, silver braid, violet fog
    person(d, c(225, 205, 220), c(190, 170, 190), c(70, 50, 120), c(40, 25, 85), eye=c(160, 100, 255))
    d.polygon([(35, -4), (52, 28), (18, 28)], fill=c(55, 40, 100))
    d.ellipse([10, 22, 60, 34], fill=c(55, 40, 100))
    d.rectangle([22, 28, 48, 30], fill=c(190, 150, 255))
    d.rectangle([14, 26, 19, 64], fill=c(225, 225, 240))
    d.rectangle([51, 26, 56, 64], fill=c(225, 225, 240))
    d.rectangle([31, 49, 39, 50], fill=c(150, 70, 110))
    for (x, y) in ((8, 80), (60, 78), (30, 84)):
        d.ellipse([x, y, x + 8, y + 4], fill=c(170, 140, 230))
    snake(d, [(62, 86), (66, 76), (58, 68), (64, 56)], body=c(190, 150, 255), belly=c(130, 90, 200), head_dir=-1)

def ember_queen(d):  # flame crown, red hair, ember eyes
    person(d, c(240, 190, 160), c(205, 150, 120), c(170, 40, 30), c(110, 20, 20), eye=c(255, 150, 30))
    d.rectangle([14, 20, 56, 30], fill=c(210, 60, 30))
    d.rectangle([12, 26, 19, 64], fill=c(210, 60, 30))
    d.rectangle([51, 26, 58, 64], fill=c(210, 60, 30))
    d.ellipse([19, 24, 51, 58], fill=c(240, 190, 160))
    d.rectangle([26, 36, 29, 37], fill=c(255, 150, 30))
    d.rectangle([41, 36, 44, 37], fill=c(255, 150, 30))
    d.rectangle([31, 49, 39, 50], fill=c(190, 40, 50))
    for x, h in ((20, 8), (28, 2), (35, 10), (42, 2), (50, 8)):
        d.polygon([(x - 4, 22), (x, h), (x + 4, 22)], fill=c(255, 190, 40))
    snake(d, [(8, 86), (6, 76), (12, 68), (10, 56)], body=c(240, 120, 30), belly=c(190, 70, 20), head_dir=1)

def canyon_duelist(d):  # wide hat, red neckerchief, eyepatch, thin moustache
    person(d, c(190, 130, 90), c(155, 100, 65), c(170, 110, 60), c(120, 75, 35))
    d.ellipse([6, 14, 64, 30], fill=c(120, 80, 45))
    d.rectangle([21, 4, 49, 20], fill=c(135, 90, 50))
    d.rectangle([21, 14, 49, 16], fill=c(60, 40, 25))
    d.rectangle([24, 33, 31, 40], fill=c(20, 15, 15))
    d.rectangle([41, 36, 44, 37], fill=BLACK)
    d.line([(20, 30), (31, 40)], fill=c(20, 15, 15), width=1)
    d.rectangle([26, 46, 44, 47], fill=c(50, 30, 20))
    d.polygon([(18, 58), (52, 58), (35, 76)], fill=c(200, 40, 40))
    snake(d, [(62, 86), (66, 76), (60, 68), (64, 58)], body=c(190, 150, 80), belly=c(140, 100, 50), head_dir=-1)

def golden_heir(d):  # jewelled crown, gold collar, haughty look
    person(d, c(235, 200, 165), c(200, 160, 125), c(40, 60, 130), c(250, 200, 60))
    d.rectangle([20, 10, 50, 22], fill=c(250, 200, 60))
    for x in (22, 30, 38, 46):
        d.polygon([(x - 3, 11), (x, 0), (x + 3, 11)], fill=c(250, 200, 60))
    d.rectangle([33, 14, 37, 18], fill=c(210, 40, 70))
    d.rectangle([14, 22, 20, 44], fill=c(80, 55, 35))
    d.rectangle([50, 22, 56, 44], fill=c(80, 55, 35))
    d.rectangle([22, 29, 30, 30], fill=c(80, 55, 35))
    d.rectangle([40, 29, 48, 30], fill=c(80, 55, 35))
    d.rectangle([12, 58, 58, 64], fill=c(250, 200, 60))
    snake(d, [(60, 86), (64, 76), (58, 68), (62, 58)], body=c(250, 200, 60), belly=c(200, 140, 30), head_dir=-1)

def viper_king(d):  # horned black crown, scaled cloak, serpent eyes
    person(d, c(170, 200, 120), c(130, 165, 85), c(30, 90, 50), c(15, 55, 30), eye=c(250, 220, 40))
    d.polygon([(14, 20), (20, 0), (26, 18)], fill=c(30, 30, 40))
    d.polygon([(56, 20), (50, 0), (44, 18)], fill=c(30, 30, 40))
    d.rectangle([18, 14, 52, 24], fill=c(30, 30, 40))
    d.rectangle([32, 15, 38, 21], fill=c(210, 40, 70))
    d.rectangle([25, 33, 31, 39], fill=c(20, 20, 20))
    d.rectangle([39, 33, 45, 39], fill=c(20, 20, 20))
    d.rectangle([28, 33, 28, 39], fill=c(250, 220, 40))
    d.rectangle([42, 33, 42, 39], fill=c(250, 220, 40))
    d.rectangle([29, 49, 41, 50], fill=c(30, 60, 30))
    d.point([(33, 52), (37, 52)], fill=WHITE)
    snake(d, [(2, 86), (6, 76), (4, 66), (10, 58)], body=c(60, 170, 80), belly=c(30, 110, 50), head_dir=1)
    snake(d, [(66, 86), (64, 76), (66, 66), (60, 58)], body=c(60, 170, 80), belly=c(30, 110, 50), head_dir=-1)


def tide_priestess(d):  # shell crown, sea-green hair, pearl necklace
    person(d, c(200, 225, 220), c(160, 190, 185), c(30, 110, 150), c(15, 70, 110), eye=c(40, 160, 200))
    d.rectangle([14, 20, 56, 30], fill=c(60, 180, 170))
    d.rectangle([12, 26, 19, 66], fill=c(60, 180, 170))
    d.rectangle([51, 26, 58, 66], fill=c(60, 180, 170))
    d.ellipse([19, 24, 51, 58], fill=c(200, 225, 220))
    for x in (22, 29, 36, 43, 49):
        d.polygon([(x - 4, 22), (x, 6 + (x % 5)), (x + 4, 22)], fill=c(250, 225, 210))
    d.rectangle([26, 36, 29, 37], fill=c(40, 160, 200))
    d.rectangle([41, 36, 44, 37], fill=c(40, 160, 200))
    d.rectangle([31, 49, 39, 50], fill=c(190, 90, 110))
    for x in range(18, 54, 6):
        d.ellipse([x, 62, x + 4, 66], fill=c(250, 245, 235))
    snake(d, [(60, 86), (64, 76), (58, 68), (62, 56)], body=c(60, 190, 200), belly=c(30, 130, 150), head_dir=-1)

def cinder_monk(d):  # shaved head, ash markings, ember beads
    person(d, c(190, 140, 100), c(155, 105, 70), c(200, 100, 30), c(130, 50, 15))
    d.ellipse([17, 12, 53, 40], fill=c(190, 140, 100))
    d.rectangle([30, 14, 40, 24], fill=c(80, 80, 85))
    d.line([(35, 14), (35, 34)], fill=c(80, 80, 85), width=1)
    d.rectangle([22, 28, 30, 29], fill=BLACK)
    d.rectangle([40, 28, 48, 29], fill=BLACK)
    d.rectangle([26, 36, 29, 37], fill=c(255, 150, 40))
    d.rectangle([41, 36, 44, 37], fill=c(255, 150, 40))
    d.rectangle([30, 49, 40, 50], fill=c(110, 50, 40))
    for x in range(16, 56, 6):
        d.ellipse([x, 64, x + 4, 68], fill=c(255, 120, 40))
    snake(d, [(6, 84), (8, 74), (4, 66), (10, 56)], body=c(240, 130, 40), belly=c(180, 70, 20), head_dir=1)

def night_stalker(d):  # black hood, silver mask, glowing violet eyes
    person(d, c(60, 55, 80), c(40, 35, 60), c(35, 30, 55), c(20, 15, 35), eye=c(190, 120, 255))
    d.polygon([(35, 2), (64, 34), (62, 66), (8, 66), (6, 34)], fill=c(35, 30, 55))
    d.ellipse([20, 22, 50, 56], fill=c(30, 26, 48))
    d.rectangle([22, 32, 48, 42], fill=c(200, 205, 220))
    d.rectangle([25, 35, 31, 38], fill=c(190, 120, 255))
    d.rectangle([39, 35, 45, 38], fill=c(190, 120, 255))
    d.rectangle([22, 46, 48, 56], fill=c(35, 30, 55))
    snake(d, [(60, 86), (66, 76), (60, 68), (64, 56)], body=c(130, 70, 200), belly=c(80, 40, 140), head_dir=-1)
    snake(d, [(8, 86), (4, 76), (10, 68), (6, 58)], body=c(80, 40, 140), belly=c(50, 25, 100), head_dir=1)

def emerald_emperor(d):  # jade crown, long green robes, golden collar
    person(d, c(205, 190, 140), c(170, 155, 105), c(20, 120, 70), c(250, 200, 60), eye=c(20, 120, 70))
    d.rectangle([18, 12, 52, 24], fill=c(60, 200, 120))
    for x in (22, 30, 38, 46):
        d.polygon([(x - 3, 13), (x, 2), (x + 3, 13)], fill=c(60, 200, 120))
    d.rectangle([33, 15, 37, 20], fill=c(250, 220, 90))
    d.rectangle([22, 28, 30, 29], fill=c(60, 50, 30))
    d.rectangle([40, 28, 48, 29], fill=c(60, 50, 30))
    d.polygon([(26, 46), (35, 44), (44, 46), (40, 56), (35, 60), (30, 56)], fill=c(70, 60, 40))
    d.rectangle([12, 58, 58, 64], fill=c(250, 200, 60))
    snake(d, [(2, 86), (6, 76), (4, 66), (10, 58)], body=c(60, 200, 120), belly=c(30, 140, 80), head_dir=1)
    snake(d, [(66, 86), (64, 76), (66, 66), (60, 58)], body=c(250, 200, 60), belly=c(190, 140, 30), head_dir=-1)

FIGURES = {f.__name__: f for f in (tide_priestess, cinder_monk, night_stalker, emerald_emperor, garden_keeper, pond_skulker, venom_rookie, dune_wanderer, crypt_warden, reed_stalker, fang_brawler,
                                   bog_hermit, constrictor, mist_witch, ember_queen, canyon_duelist, golden_heir, viper_king)}
BACKDROPS = {
    "tide_priestess": ((150, 225, 230), (30, 80, 130)), "cinder_monk": ((255, 190, 110), (140, 60, 30)),
    "night_stalker": ((110, 90, 160), (25, 15, 50)), "emerald_emperor": ((140, 230, 170), (20, 90, 60)),
    "garden_keeper": ((190, 230, 140), (90, 150, 80)), "pond_skulker": ((140, 210, 220), (40, 90, 120)),
    "venom_rookie": ((210, 150, 240), (100, 60, 150)), "dune_wanderer": ((250, 220, 150), (200, 150, 80)),
    "crypt_warden": ((140, 150, 180), (40, 40, 70)), "reed_stalker": ((170, 200, 120), (80, 100, 60)),
    "fang_brawler": ((250, 150, 130), (130, 40, 50)), "bog_hermit": ((150, 180, 110), (50, 70, 45)),
    "constrictor": ((230, 190, 130), (140, 90, 60)), "mist_witch": ((200, 170, 250), (70, 50, 130)),
    "ember_queen": ((255, 190, 90), (170, 50, 30)), "canyon_duelist": ((240, 170, 110), (160, 80, 50)),
    "golden_heir": ((255, 230, 140), (190, 140, 50)), "viper_king": ((120, 210, 140), (20, 60, 40)),
}

if __name__ == "__main__":
    folder = sys.argv[1] if len(sys.argv) > 1 else "assets/opponents"
    dc.FIGURES.update(FIGURES)
    dc.BACKDROPS.update(BACKDROPS)
    for name in FIGURES:
        dc.render(name, folder)
