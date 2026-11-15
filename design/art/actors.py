"""Every thing that comes alive in a finished picture (design/content.py's actors), painted wood:
fruit with little faces, Taiwan's animals (the helpers' drawings), night-market snacks, the MRT and
the garbage truck, the temple fair, the city. Each is drawn on its own canvas (its own width and
height; the app fits it into its box in the picture).

Writes app/assets/art/actors/<id>.svg, and for the ones on an inset board (形狀洞洞) the wooden
cut-out piece with its knob, app/assets/art/inset/<id>.svg, and its hole, inset/<id>_hole.svg.
"""
import math
import sys

sys.dont_write_bytecode = True

import kit  # noqa: E402
from kit import (BLUE, BROWN, CREAM, GOLD, GREEN, GREY, INK, LEAF, LIME, NAVY, ORANGE, PINK, PURPLE, RED, SKY,  # noqa: E402
                 STEEL, TAN, TEAL, WHITE, YELLOW, Ctx, Shape, arc, circle, ellipse, path, poly, rrect, smooth, star)

sys.path.insert(0, str(kit.ROOT / "design"))
import content  # noqa: E402
import helpers  # noqa: E402

OUT = kit.ART / "actors"
INSET = kit.ART / "inset"


def half_disc(cx, cy, r):
    """The lower half of a circle (a watermelon slice, a bowl)."""
    return arc(cx, cy, r, 0, 180) + Shape([("Z",)])


def wheel(c, x, y, r):
    c.paint(circle(x, y, r), "#3A3A44")
    c.flat(circle(x, y, r * .45), GREY)
    c.flat(circle(x, y, r * .15), INK)


def window_row(c, x, y, w, h, n, gap, col="#CDEBFA"):
    for i in range(n):
        c.paint(rrect(x + i * (w + gap), y, w, h, h * .25), col, edge=1)
        c.flat(rrect(x + i * (w + gap) + 2, y + 2, w * .35, h * .3, 1.5), WHITE, op=.6, remember=False)


# ================================================================ fruit
def watermelon():
    c = Ctx(100, 80)
    c.paint(half_disc(50, 22, 44), "#3E8E3A")
    c.flat(half_disc(50, 22, 38), "#E9F2D2")
    c.paint(half_disc(50, 22, 34), "#EC5A5A", edge=0)
    for x, y in [(30, 34), (42, 44), (58, 44), (70, 34), (50, 32), (36, 52), (64, 52)]:
        c.flat(ellipse(x, y, 1.8, 2.8), INK)
    c.face(50, 30, 14)
    return c


def pineapple():
    c = Ctx(80, 110)
    for a, h in [(-30, 30), (-12, 38), (0, 42), (12, 38), (30, 30)]:
        leaf = smooth([(40, 44), (40 + math.sin(math.radians(a)) * h - 5, 44 - math.cos(math.radians(a)) * h), (40 + math.sin(math.radians(a)) * h + 4, 44 - math.cos(math.radians(a)) * h + 2)], .4)
        c.paint(leaf, LEAF if abs(a) > 20 else GREEN)
    body = ellipse(40, 74, 30, 34)
    c.paint(body, "#F2B33A")
    c.begin_clip(body)
    for k in range(-8, 9):
        c.stroke(path([(k * 9 - 10, 30), (k * 9 + 70, 120)]), "#C9822A", 1.6)
        c.stroke(path([(k * 9 + 90, 30), (k * 9 + 10, 120)]), "#C9822A", 1.6)
    c.end()
    c.face(40, 72, 14)
    return c


def banana():
    c = Ctx(120, 70)
    b = smooth([(8, 22), (30, 48), (64, 56), (98, 44), (114, 20), (108, 18), (92, 36), (62, 42), (32, 36), (14, 16)], .6)
    c.paint(b, "#F5D04A")
    c.stroke(path([(22, 30), (44, 42), (64, 46), (88, 40), (104, 28)]), "#D8A92E", 1.4)
    c.paint(rrect(4, 14, 9, 8, 3), "#7A5A2E")
    c.flat(circle(113, 19, 2.5), "#5A3A1E")
    c.face(64, 40, 12)
    return c


def mango():
    c = Ctx(100, 100)
    m = smooth([(30, 30), (60, 18), (86, 38), (84, 72), (56, 92), (24, 80), (14, 54)], .8)
    c.paint(m, "#F5B03A")
    c.flat(ellipse(70, 40, 16, 14), "#EF6A4A", op=.45, remember=False)
    c.stroke(path([(56, 18), (60, 8)]), "#6A4A2A", 3)
    c.paint(smooth([(60, 10), (76, 2), (86, 8), (72, 14)], .6), GREEN)
    c.face(50, 56, 15)
    return c


def lychee():
    c = Ctx(100, 100)
    c.stroke(path([(50, 10), (50, 26), (30, 42)]), "#6A4A2A", 2.6)
    c.stroke(path([(50, 26), (72, 44)]), "#6A4A2A", 2.6)
    c.stroke(path([(50, 26), (52, 58)]), "#6A4A2A", 2.6)
    c.paint(smooth([(50, 12), (70, 4), (82, 12), (66, 18)], .6), GREEN)
    for x, y, r in [(30, 56, 17), (72, 56, 17), (52, 74, 19)]:
        c.paint(circle(x, y, r), "#D8444E")
        for k in range(9):
            a = k * 40
            c.flat(circle(x + math.cos(math.radians(a)) * r * .55, y + math.sin(math.radians(a)) * r * .55, 1.6), "#A82E3A", remember=False)
    c.face(52, 74, 11)
    return c


def sugar_apple():
    c = Ctx(100, 100)
    body = smooth([(50, 14), (80, 30), (88, 60), (70, 88), (50, 92), (30, 88), (12, 60), (20, 30)], .8)
    c.paint(body, "#9CC46A")
    c.begin_clip(body)
    for row in range(8):
        for col in range(8):
            x, y = 8 + col * 12 + (6 if row % 2 else 0), 14 + row * 11
            c.paint(ellipse(x, y, 6.5, 5.5), "#B4D47E", edge=.8, shade=False)
    c.end()
    c.stroke(path([(50, 14), (50, 6)]), "#6A4A2A", 3)
    c.face(50, 58, 15)
    return c


def wax_apple():
    c = Ctx(90, 100)
    b = smooth([(30, 16), (60, 16), (72, 50), (84, 86), (45, 94), (6, 86), (18, 50)], .7)
    c.paint(b, "#D9404E")
    c.flat(ellipse(32, 40, 6, 14), WHITE, op=.3, remember=False)
    c.paint(ellipse(45, 18, 15, 5), "#B5303E")
    c.stroke(path([(45, 16), (45, 6)]), "#6A4A2A", 2.6)
    c.face(45, 64, 14)
    return c


def orange():
    c = Ctx(100, 100)
    c.paint(circle(50, 54, 40), "#F59A2E")
    for k in range(14):
        a = k * 51
        c.flat(circle(50 + math.cos(math.radians(a)) * (12 + k * 1.8), 54 + math.sin(math.radians(a)) * (12 + k * 1.8), 1.2), "#D97A1E", remember=False)
    c.paint(smooth([(52, 16), (70, 6), (80, 12), (64, 20)], .6), GREEN)
    c.face(50, 56, 18)
    return c


def mango_ice():
    c = Ctx(100, 100)
    c.paint(smooth([(14, 46), (50, 18), (86, 46)], .9) + Shape([("Z",)]), "#FBF6EE")      # shaved ice
    c.paint(half_disc(50, 52, 38), "#7FC4E8")                                          # the bowl
    c.paint(rrect(12, 46, 76, 8, 4), "#A6D8F2")
    for x, y in [(36, 34), (50, 28), (64, 34), (43, 42), (58, 42), (50, 38)]:
        c.paint(rrect(x - 6, y - 6, 12, 12, 3), "#F5A83A")
    c.stroke(path([(28, 40), (40, 46), (52, 40), (66, 46), (74, 40)]), "#FFF0C8", 2.6)
    c.paint(rrect(70, 10, 6, 34, 3).rotate(30, 73, 27), "#D9D9E0")
    c.face(50, 70, 14)
    return c


# ================================================================ animals (the helpers, and two of the sea)
def animal(name):
    def draw():
        c = helpers.draw(name)
        if name == "bear":                       # with a mango
            c.paint(smooth([(70, 66), (82, 60), (88, 72), (78, 82)], .8), "#F5B03A")
        return c
    return draw


def turtle():
    c = Ctx(130, 90)
    for x, y in [(30, 70), (92, 70), (34, 26), (88, 26)]:
        c.paint(ellipse(x, y, 13, 7).rotate(30 if x < 60 else -30, x, y), "#7FB86A")
    c.paint(ellipse(116, 48, 14, 11), "#7FB86A")
    c.eyes(116, 45, 9, 2.2)
    c.smile(118, 51, 5)
    shell = ellipse(62, 48, 44, 30)
    c.paint(shell, "#4E8F3A")
    c.begin_clip(shell)
    for x, y in [(62, 48), (40, 36), (84, 36), (40, 60), (84, 60), (62, 24), (62, 72)]:
        c.paint(poly([(x - 9, y - 6), (x, y - 11), (x + 9, y - 6), (x + 9, y + 6), (x, y + 11), (x - 9, y + 6)]), "#6FAE4E", edge=1)
    c.end()
    return c


def salmon():
    c = Ctx(140, 70)
    c.paint(poly([(16, 35), (2, 18), (2, 52)]), "#C98A8A")
    body = smooth([(14, 35), (50, 14), (100, 14), (134, 34), (100, 56), (50, 56)], .7)
    c.paint(body, "#D8A0A0")
    c.flat(smooth([(30, 38), (70, 50), (120, 40), (100, 54), (50, 54)], .7), "#F2D6D0", op=.8, remember=False)
    for x in range(36, 110, 14):
        c.flat(ellipse(x, 24 + (x % 3) * 3, 5, 3), "#9A6A8A", op=.7, remember=False)
    c.flat(ellipse(70, 34, 30, 3), "#E86F8A", op=.5, remember=False)
    c.eyes(118, 30, 1, 3)
    c.smile(126, 38, 5)
    return c


# ================================================================ night market
def bubble_tea():
    c = Ctx(80, 120)
    c.paint(rrect(46, 2, 8, 40, 4).rotate(12, 50, 22), "#E86F8A")
    cup = poly([(12, 30), (68, 30), (60, 114), (20, 114)])
    c.paint(cup, "#F2E2C8")
    c.begin_clip(cup)
    c.flat(rrect(0, 40, 80, 80, 0), "#C99A6E", remember=False)
    for x, y in [(26, 104), (38, 106), (50, 104), (32, 96), (46, 96), (56, 98), (24, 90)]:
        c.flat(circle(x, y, 4.6), "#3A2A20", remember=False)
        c.flat(circle(x - 1.4, y - 1.4, 1.2), WHITE, op=.6, remember=False)
    c.end()
    c.paint(rrect(8, 24, 64, 9, 4), "#FFFDF8")
    c.face(40, 62, 14)
    return c


def egg_cake():
    c = Ctx(120, 80)
    for i, x in enumerate((24, 60, 96)):
        y = 44 + (6 if i == 1 else 0)
        c.paint(ellipse(x, y, 19, 22), "#F2B54A")
        c.flat(ellipse(x, y - 8, 10, 6), "#F9D27A", op=.8, remember=False)
        c.face(x, y + 2, 10)
    return c


def corn():
    c = Ctx(100, 120)
    c.stroke(path([(50, 92), (50, 118)]), "#C9A06A", 5)
    for d in (-1, 1):
        c.paint(smooth([(50, 90), (50 + d * 26, 60), (50 + d * 22, 98)], .5), "#8CC05A")
    cob = ellipse(50, 52, 20, 42)
    c.paint(cob, "#F2C23A")
    c.begin_clip(cob)
    for row in range(12):
        for col in range(5):
            c.paint(ellipse(34 + col * 8 + (4 if row % 2 else 0), 14 + row * 7, 3.6, 3.2), "#F5D25A", edge=.6, shade=False)
    for y in (34, 52, 70):
        c.stroke(path([(28, y), (72, y + 6)]), "#8A4A1E", 3.2, op=.7)
    c.end()
    c.face(50, 54, 12)
    return c


def tanghulu():
    c = Ctx(60, 130)
    c.stroke(path([(30, 8), (30, 126)]), "#D9B47A", 3.6, remember=True)
    for i, y in enumerate((20, 40, 60, 80, 100)):
        c.paint(circle(30, y, 13), "#D9303E", shine=True)
    c.face(30, 62, 9)
    return c


def cotton_candy():
    c = Ctx(110, 130)
    c.stroke(path([(55, 70), (55, 126)]), "#E8D6B8", 4, remember=True)
    cloud = kit.puffs(55, 50, 74, 64, n=5, key="cotton")
    c.paint(cloud, "#F7A8C8")
    c.flat(circle(40, 34, 8), WHITE, op=.35, remember=False)
    c.face(55, 50, 14)
    return c


def ring_toss():
    c = Ctx(120, 110)
    c.paint(rrect(4, 84, 112, 22, 6), "#C98A4E")
    for x, col in [(24, "#6FAE4E"), (60, "#3F95D1"), (96, "#E86F6F")]:
        c.paint(rrect(x - 8, 46, 16, 40, 5), col)
        c.paint(rrect(x - 4, 34, 8, 14, 2), col)
    c.stroke(ellipse(60, 66, 18, 7), "#F2C94C", 4.5, remember=True)
    c.face(60, 72, 7)
    return c


def pinball():
    c = Ctx(90, 130)
    board = rrect(8, 6, 74, 118, 14)
    c.paint(board, "#3F95D1")
    c.flat(rrect(14, 12, 62, 106, 10), "#D9EEF8")
    for row in range(5):
        for col in range(4):
            c.flat(circle(24 + col * 14 + (7 if row % 2 else 0), 30 + row * 16, 2.4), "#E8A93A")
    c.paint(circle(52, 44, 6), "#C9CDD6", shine=True)
    c.paint(rrect(20, 104, 50, 8, 4), "#E86F6F")
    return c


def bapu():
    c = Ctx(150, 120)
    c.stroke(path([(56, 54), (56, 18)]), STEEL, 3)
    c.paint(Shape([("M", 20, 24), ("C", 30, 2, 82, 2, 92, 24), ("Z",)]), "#E86F8A")      # umbrella
    for x in (34, 56, 78):
        c.stroke(arc(x, 24, 11, 0, 180), WHITE, 1.4)
    c.paint(rrect(16, 52, 84, 44, 10), "#FFFDF8")
    c.paint(rrect(16, 52, 84, 12, 6), "#7FC4E8")
    c.paint(circle(58, 76, 12), "#F7C8D8")                     # a scoop on the side
    c.paint(poly([(48, 84), (68, 84), (58, 104)]), "#E8B06A")
    c.paint(rrect(100, 70, 34, 10, 4), STEEL)
    c.paint(smooth([(126, 66), (146, 58), (146, 76)], .3), "#F2C94C")    # the horn: 叭噗
    wheel(c, 32, 102, 12)
    wheel(c, 84, 102, 12)
    wheel(c, 130, 102, 10)
    return c


# ================================================================ rides
def mrt():
    c = Ctx(220, 90)
    c.paint(rrect(4, 10, 196, 64, 16, rtr=34), "#F4F6F8")
    c.paint(rrect(4, 50, 196, 10, 0, rtr=0), "#3F7FD1")
    window_row(c, 18, 22, 26, 20, 5, 10)
    c.paint(rrect(176, 22, 18, 26, 6), "#2A3A5A")
    c.eyes(186, 36, 1, 2.6)
    for x in (40, 160):
        wheel(c, x, 78, 9)
    return c


def hsr():
    c = Ctx(220, 80)
    body = smooth([(4, 20), (130, 14), (190, 26), (216, 52), (190, 62), (4, 62)], .5)
    c.paint(body, "#F8F8F6")
    c.flat(rrect(4, 44, 200, 6, 3), "#E8792E", remember=False)
    window_row(c, 16, 26, 18, 12, 6, 8)
    c.paint(smooth([(176, 30), (202, 42), (180, 44)], .5), "#2A3A5A")
    c.eyes(190, 40, 1, 2.4)
    for x in (40, 150):
        wheel(c, x, 68, 8)
    return c


def train():
    c = Ctx(220, 100)
    c.paint(rrect(4, 22, 110, 56, 10), "#F2C94C")
    window_row(c, 14, 32, 22, 18, 4, 4)
    c.paint(rrect(118, 14, 98, 64, 12, rtr=26), "#3F6FC4")
    c.paint(rrect(118, 54, 98, 10, 0), "#F2994A")
    c.paint(rrect(176, 24, 30, 22, 6), "#CDEBFA", edge=1)
    c.eyes(191, 35, 12, 2.6)
    c.smile(191, 44, 6)
    c.paint(rrect(130, 2, 14, 14, 3), "#3A3A44")
    for x in (24, 92, 140, 196):
        wheel(c, x, 86, 10)
    return c


def bus():
    c = Ctx(190, 110)
    c.paint(rrect(4, 12, 180, 76, 14), "#3FA06A")
    c.paint(rrect(4, 62, 180, 10, 0), "#FFFDF8")
    window_row(c, 14, 24, 26, 26, 4, 8)
    c.paint(rrect(150, 22, 28, 36, 6), "#CDEBFA", edge=1)
    c.paint(rrect(168, 72, 14, 8, 3), "#F2C94C")
    c.eyes(164, 40, 10, 2.6)
    for x in (40, 146):
        wheel(c, x, 92, 13)
    return c


def garbage():
    c = Ctx(190, 120)
    c.paint(rrect(4, 20, 124, 72, 12), "#F2C94C")
    for x in range(16, 120, 18):
        c.stroke(path([(x, 30), (x, 82)]), "#D8A92E", 2.4)
    c.paint(rrect(126, 36, 58, 56, 12, rtr=22), "#F2F2EE")
    c.paint(rrect(148, 44, 28, 22, 6), "#CDEBFA", edge=1)
    c.eyes(162, 55, 10, 2.4)
    for x, y in [(20, 8), (34, 2), (48, 10)]:                  # the music it plays
        c.stroke(path([(x, y + 10), (x, y)]), "#7B6CC8", 2.2)
        c.flat(ellipse(x - 2.5, y + 10, 3.4, 2.6), "#7B6CC8")
    for x in (40, 150):
        wheel(c, x, 98, 14)
    return c


def bike():
    c = Ctx(150, 100)
    for x in (34, 116):
        c.stroke(circle(x, 66, 26), "#3A3A44", 5, remember=True)
        c.stroke(circle(x, 66, 4), STEEL, 3, remember=True)
    frame = [(34, 66), (66, 66), (98, 34), (54, 34), (34, 66)]
    c.stroke(path(frame), "#E86F6F", 5, remember=True)
    c.stroke(path([(66, 66), (52, 26)]), "#E86F6F", 5, remember=True)
    c.stroke(path([(98, 34), (116, 66)]), "#E86F6F", 5, remember=True)
    c.stroke(path([(98, 34), (96, 18), (108, 16)]), "#3A3A44", 4, remember=True)
    c.paint(rrect(42, 20, 22, 7, 3), "#3A3A44")
    c.paint(circle(108, 14, 4), "#F2C94C")                     # the bell
    return c


def boat():
    c = Ctx(150, 110)
    c.stroke(path([(72, 64), (72, 10)]), "#8A5A33", 3.4, remember=True)
    for i, col in enumerate(["#D9534A", "#F2C94C", "#3F95D1", "#6FAE4E"]):
        c.paint(poly([(72 + i * 0, 10 + i * 12), (98, 14 + i * 12), (72, 20 + i * 12)]), col, edge=1)
    c.paint(rrect(48, 46, 46, 24, 4), "#FFFDF8")
    c.paint(rrect(54, 52, 12, 10, 2), "#CDEBFA", edge=1)
    hull = poly([(6, 66), (144, 66), (124, 100), (24, 100)])
    c.paint(hull, "#3F7FD1")
    c.flat(rrect(14, 74, 124, 6, 3), WHITE, op=.9, remember=False)
    c.eyes(118, 84, 1, 3)
    return c


def alishan():
    c = Ctx(200, 100)
    c.paint(rrect(4, 26, 90, 50, 8), "#C9433E")
    window_row(c, 12, 36, 20, 16, 3, 8, col="#FDE7C8")
    c.paint(rrect(96, 20, 96, 56, 10, rtr=20), "#B5372F")
    c.paint(rrect(150, 30, 30, 20, 6), "#FDE7C8", edge=1)
    c.paint(rrect(110, 4, 16, 18, 3), "#3A3A44")
    c.eyes(165, 40, 12, 2.4)
    c.smile(165, 48, 6)
    for x in (26, 72, 120, 172):
        wheel(c, x, 84, 10)
    return c


# ================================================================ temple fair
def lion():
    c = Ctx(130, 120)
    c.paint(smooth([(10, 70), (20, 30), (64, 8), (110, 30), (120, 70), (100, 100), (30, 100)], .8), "#E8463E")
    c.flat(smooth([(16, 72), (24, 34), (64, 16), (104, 34), (112, 72)], .8), "#F2C94C", op=.9, remember=False)
    c.paint(smooth([(30, 56), (64, 40), (98, 56), (90, 88), (38, 88)], .8), "#F2994A")
    for x in (46, 82):
        c.paint(circle(x, 54, 11), WHITE)
        c.flat(circle(x, 56, 6), INK)
        c.flat(circle(x - 2, 53, 2), WHITE)
    c.paint(ellipse(64, 70, 12, 8), "#E8463E")
    c.paint(Shape([("M", 40, 82), ("C", 50, 100, 78, 100, 88, 82), ("Z",)]), "#B8434F")
    for x in (52, 62, 72):
        c.flat(rrect(x, 82, 7, 6, 2), WHITE)
    c.paint(ellipse(64, 16, 9, 12), "#6FAE4E")                # the horn
    for k in range(7):                                        # fur trim
        c.paint(circle(20 + k * 15, 104, 7), WHITE, edge=1)
    return c


def dragon():
    c = Ctx(270, 120)
    pts = [(30 + i * 30, 60 + 24 * math.sin(i * 1.2)) for i in range(7)]
    for i, (x, y) in enumerate(pts):
        c.stroke(path([(x, y + 6), (x, y + 30)]), "#8A5A33", 3, remember=True)     # the poles
    for i, (x, y) in reversed(list(enumerate(pts))):
        c.paint(circle(x, y, 18), "#F2C94C" if i % 2 else "#E8463E")
        c.flat(ellipse(x, y + 4, 12, 7), "#6FAE4E", op=.8, remember=False)
    hx, hy = pts[-1]
    c.paint(smooth([(hx, hy - 20), (hx + 34, hy - 10), (hx + 40, hy + 8), (hx + 6, hy + 18)], .7), "#E8463E")
    c.paint(circle(hx + 14, hy - 6, 6), WHITE)
    c.flat(circle(hx + 15, hy - 5, 3.4), INK)
    c.stroke(path([(hx + 4, hy - 18), (hx - 6, hy - 34)]), "#F2C94C", 3)
    c.stroke(path([(hx + 36, hy + 4), (hx + 46, hy + 14), (hx + 40, hy + 26)]), "#F2C94C", 2.4)
    return c


def lantern():
    c = Ctx(100, 130)
    c.stroke(path([(50, 2), (50, 18)]), "#8A5A33", 3)
    c.paint(rrect(34, 14, 32, 10, 4), GOLD)
    body = ellipse(50, 60, 40, 36)
    c.paint(body, "#E8463E")
    c.begin_clip(body)
    for x in (30, 50, 70):
        c.stroke(ellipse(50, 60, abs(x - 50) + 4, 36), "#B5302E", 1.6)
    c.end()
    c.paint(rrect(34, 94, 32, 9, 4), GOLD)
    for x in (42, 50, 58):
        c.stroke(path([(x, 104), (x, 126)]), GOLD, 2.6, remember=True)
    c.face(50, 60, 16)
    return c


def puppet():
    c = Ctx(100, 130)
    c.paint(smooth([(20, 128), (24, 70), (50, 58), (76, 70), (80, 128)], .5), "#3F6FC4")
    c.flat(poly([(50, 64), (40, 128), (60, 128)]), "#F2C94C", op=.9)
    for d in (-1, 1):
        c.paint(ellipse(50 + d * 30, 82, 9, 7), "#F3C9A0")
    c.paint(circle(50, 40, 22), "#F7D7B8")
    c.paint(Shape([("M", 26, 32), ("C", 30, 6, 70, 6, 74, 32), ("Z",)]), "#2A2A3A")       # the hair
    c.paint(rrect(30, 4, 40, 14, 6), "#E8463E")                                         # the hat
    c.paint(circle(50, 4, 5), GOLD)
    c.face(50, 42, 14)
    return c


def sky_lantern():
    c = Ctx(100, 130)
    body = poly([(16, 8), (84, 8), (74, 104), (26, 104)])
    c.paint(body, "#FFF0C8")
    c.flat(rrect(30, 34, 40, 34, 6), "#E8463E", op=.85)
    c.flat(rrect(42, 40, 16, 22, 3), "#FFF0C8", op=.9, remember=False)
    c.flat(poly([(26, 104), (74, 104), (68, 112), (32, 112)]), "#E8B06A")
    c.paint(smooth([(50, 108), (58, 120), (50, 130), (42, 120)], .7), "#F2994A")
    c.flat(smooth([(50, 114), (54, 121), (50, 126), (46, 121)], .7), "#FFE27A")
    return c


def drum():
    c = Ctx(120, 120)
    for x in (24, 96):
        c.stroke(path([(x, 70), (x - 8 if x < 60 else x + 8, 116)]), "#8A5A33", 5, remember=True)
    c.paint(rrect(14, 30, 92, 64, 20), "#D9433E")
    c.paint(ellipse(60, 32, 46, 14), "#F5E6C8")
    for x in range(22, 104, 10):
        c.flat(circle(x, 46, 2), GOLD)
    c.face(60, 66, 18)
    for d in (-1, 1):
        c.stroke(path([(60 + d * 10, 26), (60 + d * 30, 4)]), "#8A5A33", 4, remember=True)
        c.paint(circle(60 + d * 30, 4, 4.5), "#E8463E")
    return c


def top():
    c = Ctx(100, 120)
    c.stroke(path([(50, 4), (50, 26)]), "#8A5A33", 5, remember=True)
    body = smooth([(14, 46), (50, 24), (86, 46), (50, 112)], .55)
    c.paint(body, "#F2994A")
    c.begin_clip(body)
    for y, col in [(46, "#E8463E"), (58, "#F2C94C"), (70, "#3F95D1")]:
        c.flat(rrect(0, y, 100, 7, 0), col, remember=False)
    c.end()
    c.face(50, 44, 14)
    return c


def bench():
    c = Ctx(150, 90)
    c.paint(rrect(10, 34, 130, 14, 6), "#B98245")
    c.paint(rrect(10, 14, 130, 12, 6), "#C99255")
    for x in (24, 122):
        c.paint(rrect(x - 4, 26, 8, 60, 3), "#8A5A33")
    c.paint(smooth([(60, 34), (64, 18), (82, 16), (86, 34)], .6), "#3F95D1")              # a teapot
    c.paint(circle(73, 14, 4), "#3F95D1")
    c.paint(rrect(96, 26, 10, 9, 3), WHITE)
    return c


# ================================================================ city and sea
def taipei101():
    c = Ctx(80, 220)
    c.stroke(path([(40, 2), (40, 24)]), STEEL, 3, remember=True)
    for i in range(8):
        y = 24 + i * 20
        c.paint(poly([(24, y), (56, y), (60, y + 20), (20, y + 20)]), "#6FB8A8")
        c.flat(rrect(30, y + 6, 20, 8, 2), "#CDEBFA", op=.8, remember=False)
    c.paint(poly([(16, 184), (64, 184), (72, 218), (8, 218)]), "#5A9E90")
    c.face(40, 200, 10)
    return c


def fireworks():
    c = Ctx(220, 150)
    for cx, cy, r, col in [(60, 60, 44, "#F2C94C"), (150, 48, 38, "#EB7FA6"), (110, 104, 30, "#7FD0F0")]:
        for k in range(12):
            a = math.radians(k * 30)
            c.stroke(path([(cx + math.cos(a) * r * .3, cy + math.sin(a) * r * .3), (cx + math.cos(a) * r, cy + math.sin(a) * r)]), col, 3.2, remember=True)
            c.flat(circle(cx + math.cos(a) * r, cy + math.sin(a) * r, 3.2), col)
        c.flat(circle(cx, cy, 4), WHITE)
    return c


def ferris():
    c = Ctx(120, 140)
    for x in (40, 80):
        c.stroke(path([(60, 60), (x - 20 if x < 60 else x + 20, 136)]), STEEL, 5, remember=True)
    c.stroke(circle(60, 60, 48), "#E86F8A", 4, remember=True)
    for k in range(8):
        a = math.radians(k * 45)
        c.stroke(path([(60, 60), (60 + math.cos(a) * 48, 60 + math.sin(a) * 48)]), "#F2C3D0", 2)
    for k, col in enumerate(["#F2C94C", "#3F95D1", "#6FAE4E", "#E86F6F", "#7B6CC8", "#F2994A", "#2FA6A0", "#EB7FA6"]):
        a = math.radians(k * 45)
        x, y = 60 + math.cos(a) * 48, 60 + math.sin(a) * 48
        c.paint(rrect(x - 8, y - 4, 16, 14, 5), col)
    c.paint(circle(60, 60, 8), GOLD)
    return c


def lake_boat():
    c = Ctx(140, 80)
    c.stroke(path([(70, 44), (70, 6)]), "#8A5A33", 3, remember=True)
    c.paint(poly([(72, 8), (104, 40), (72, 40)]), "#FFFDF8")
    hull = Shape([("M", 10, 44), ("L", 130, 44), ("C", 120, 76, 20, 76, 10, 44), ("Z",)])
    c.paint(hull, "#C98A4E")
    c.flat(rrect(18, 48, 104, 5, 2.5), "#E3B987", remember=False)
    c.eyes(108, 56, 1, 2.6)
    return c


def lighthouse():
    c = Ctx(80, 200)
    c.paint(poly([(26, 12), (54, 12), (60, 26), (20, 26)]), "#D9433E")
    c.paint(rrect(26, 26, 28, 20, 4), "#FFF0A8")
    c.flat(circle(40, 36, 6), "#FFE27A")
    body = poly([(22, 46), (58, 46), (68, 186), (12, 186)])
    c.paint(body, "#FFFDF8")
    c.begin_clip(body)
    for y in (76, 130):
        c.flat(rrect(0, y, 80, 22, 0), "#D9433E", remember=False)
    c.end()
    c.paint(rrect(32, 156, 16, 30, 6), "#7A522B")
    c.paint(rrect(4, 184, 72, 14, 6), "#9AA0A6")
    c.face(40, 112, 12)
    return c


def crab():
    c = Ctx(120, 90)
    for d in (-1, 1):
        for k in range(3):
            c.stroke(path([(60 + d * 20, 58 + k * 6), (60 + d * (40 + k * 4), 70 + k * 7)]), "#C9433E", 4, remember=True)
        c.stroke(path([(60 + d * 22, 44), (60 + d * 38, 28)]), "#C9433E", 5, remember=True)
        c.paint(smooth([(60 + d * 36, 32), (60 + d * 52, 14), (60 + d * 50, 34), (60 + d * 40, 38)], .6), "#E8503E")
    for x in (50, 70):
        c.stroke(path([(x, 40), (x, 26)]), "#C9433E", 3, remember=True)
        c.paint(circle(x, 24, 5), WHITE)
        c.flat(circle(x, 25, 2.8), INK)
    c.paint(ellipse(60, 54, 28, 20), "#E8503E")
    c.smile(60, 58, 9)
    c.cheeks(60, 56, 30, 3)
    return c


def shell():
    c = Ctx(100, 90)
    body = smooth([(50, 84), (12, 46), (24, 14), (50, 6), (76, 14), (88, 46)], .7)
    c.paint(body, "#F7E6D6")
    c.begin_clip(body)
    for a in range(-60, 61, 20):
        x2 = 50 + math.sin(math.radians(a)) * 80
        c.stroke(path([(50, 86), (x2, 86 - math.cos(math.radians(a)) * 80)]), "#E8B8A0", 3)
    c.end()
    c.paint(rrect(38, 78, 24, 10, 4), "#E8B8A0")
    c.face(50, 44, 14)
    return c


def starfish():
    c = Ctx(100, 100)
    s = star(50, 54, 46, 20)
    c.paint(s, "#F2994A")
    for i in range(5):
        a = math.radians(-90 + i * 72)
        for k in (12, 22, 32):
            c.flat(circle(50 + math.cos(a) * k, 54 + math.sin(a) * k, 1.8), "#FFE2B0", remember=False)
    c.face(50, 54, 12)
    return c


def rainbow_bridge():
    c = Ctx(300, 130)
    for i, col in enumerate(["#E86F6F", "#F2994A", "#F2C94C", "#6FAE4E", "#3F95D1", "#7B6CC8"]):
        r = 140 - i * 9
        c.stroke(arc(150, 140, r, 200, 340), col, 9, remember=True)
    c.paint(rrect(4, 92, 292, 12, 5), "#B98245")
    for x in range(20, 290, 30):
        c.stroke(path([(x, 92), (x, 72)]), "#8A5A33", 2.6)
    c.stroke(path([(6, 74), (294, 74)]), "#8A5A33", 2.6)
    return c


def slide():
    c = Ctx(140, 130)
    c.stroke(path([(34, 128), (34, 30)]), "#3F95D1", 6, remember=True)
    c.stroke(path([(60, 128), (60, 30)]), "#3F95D1", 6, remember=True)
    for y in (50, 70, 90, 110):
        c.stroke(path([(34, y), (60, y)]), "#3F95D1", 4)
    c.paint(rrect(26, 22, 42, 12, 4), "#F2C94C")
    c.paint(Shape([("M", 60, 26), ("C", 90, 30, 104, 110, 136, 118), ("L", 136, 128), ("C", 98, 122, 84, 46, 60, 40), ("Z",)]), "#E8463E")
    return c


ACTORS = {
    "watermelon": watermelon, "pineapple": pineapple, "banana": banana, "mango": mango, "lychee": lychee,
    "sugar_apple": sugar_apple, "wax_apple": wax_apple, "orange": orange, "mango_ice": mango_ice,
    "bear": animal("bear"), "leopard_cat": animal("leopardCat"), "magpie": animal("magpie"), "deer": animal("deer"),
    "pangolin": animal("pangolin"), "macaque": animal("macaque"), "turtle": turtle, "salmon": salmon,
    "bubble_tea": bubble_tea, "egg_cake": egg_cake, "corn": corn, "tanghulu": tanghulu, "cotton_candy": cotton_candy,
    "ring_toss": ring_toss, "pinball": pinball, "bapu": bapu,
    "mrt": mrt, "hsr": hsr, "train": train, "bus": bus, "garbage": garbage, "bike": bike, "boat": boat, "alishan": alishan,
    "lion": lion, "dragon": dragon, "lantern": lantern, "puppet": puppet, "sky_lantern": sky_lantern, "drum": drum,
    "top": top, "bench": bench,
    "taipei101": taipei101, "fireworks": fireworks, "ferris": ferris, "lake_boat": lake_boat, "lighthouse": lighthouse,
    "crab": crab, "shell": shell, "starfish": starfish, "rainbow_bridge": rainbow_bridge, "slide": slide,
}


def inset_piece(name):
    """The wooden cut-out for the inset board: the drawing on a slab shaped like it, with a knob;
    and the hole it fits. Both on the same square canvas (the app draws them in the same box)."""
    c0 = ACTORS[name]()
    sil = c0.silhouette(grow=3)
    size = max(c0.w, c0.h) + 16
    dx, dy = (size - c0.w) / 2, (size - c0.h) / 2
    outline = kit.from_geom(sil).move(dx, dy)
    piece = Ctx(size, size)
    piece.slab(outline, kit.WOOD, depth=max(3, size * .035), grain=False, key=name, bevel=0)
    piece.begin(f"translate({kit.n(dx)} {kit.n(dy)})")
    piece.body.extend(c0.body)
    piece.defs.update(c0.defs)
    piece.end()
    piece.bevel(outline, max(1.6, size * .014))
    x0, y0, x1, y1 = sil.bounds
    cx, cy = (x0 + x1) / 2 + dx, (y0 + y1) / 2 + dy
    piece.knob(cx, cy - (y1 - y0) * .05, max(4, size * .045))
    hole = Ctx(size, size)
    hole.hole(outline, key=name)
    return piece, hole


def build():
    n = 0
    for name in content.actors():
        c = ACTORS[name]()
        kit.write_svg(OUT / f"{name}.svg", c.svg())
        n += 1
    insets = {a for _, _, _, items in content.INSETS for a, _, _ in items}
    for name in sorted(insets):
        piece, hole = inset_piece(name)
        kit.write_svg(INSET / f"{name}.svg", piece.svg())
        kit.write_svg(INSET / f"{name}_hole.svg", hole.svg())
        n += 2
    missing = set(content.actors()) - set(ACTORS)
    if missing:
        raise SystemExit(f"actors not drawn: {sorted(missing)}")
    print(f"actors: {n} files")


if __name__ == "__main__":
    build()
