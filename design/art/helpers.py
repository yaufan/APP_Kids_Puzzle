"""The six workshop helpers (docs/design.md 「畫面和玩法」), painted wooden toys seen from the front,
each in three poses: idle, cheer (arms up, mouth open) and sleep (its own way: 甲甲 curls into a ball,
石石 curls up with its tail over its nose, 熊熊 lies hugging a honey pot, 藍藍 tucks its head under
a wing on a branch, 花花 folds its legs, 猴猴 hugs its knees). Writes app/assets/art/helpers/.

The same drawings (idle) are the animals of the 動物盒 pictures and the 動物嵌板 (actors.py).
"""
import sys

sys.dont_write_bytecode = True

import kit  # noqa: E402
from kit import INK, WHITE, Ctx, arc, circle, ellipse, path, poly, rrect, smooth  # noqa: E402

OUT = kit.ART / "helpers"
NAMES = ["pangolin", "leopardCat", "bear", "magpie", "deer", "macaque"]
POSES = ["idle", "cheer", "sleep"]


def happy_eyes(c, cx, cy, gap, r):
    for x in (cx - gap / 2, cx + gap / 2):
        c.stroke(arc(x, cy + r * .4, r * 1.1, 200, 340), INK, r * .75)


def face(c, cx, cy, gap, pose, r=None, mouth=None, nose=None):
    """Eyes (closed when sleeping, smiling when cheering), cheeks and a mouth."""
    r = r or gap * .17
    if pose == "sleep":
        for x in (cx - gap / 2, cx + gap / 2):
            c.stroke(arc(x, cy - r * .4, r * 1.1, 20, 160), INK, r * .7)
    elif pose == "cheer":
        happy_eyes(c, cx, cy, gap, r)
    else:
        c.eyes(cx, cy, gap, r)
    c.cheeks(cx, cy + gap * .45, gap * 1.45, gap * .17, op=.5)
    if nose:
        c.flat(ellipse(cx, cy + gap * .35, gap * .14, gap * .1), nose)
    my = cy + gap * (.62 if nose else .45)
    if pose == "cheer":
        c.flat(kit.Shape([("M", cx - gap * .26, my), ("C", cx - gap * .2, my + gap * .45, cx + gap * .2, my + gap * .45, cx + gap * .26, my), ("Z",)]), kit.MOUTH)
    elif pose != "sleep":
        c.stroke(arc(cx, my - gap * .15, gap * .2, 30, 150), mouth or INK, max(1.2, gap * .07))


def arms_up(c, col, x1, x2, y, w=7, length=16):
    for x, d in ((x1, -1), (x2, 1)):
        c.stroke(path([(x, y), (x + d * length * .55, y - length)]), kit.edge_of(col), w + 2.4, remember=True)
        c.stroke(path([(x, y), (x + d * length * .55, y - length)]), col, w)


def arms_down(c, col, x1, x2, y, w=7, length=13):
    for x, d in ((x1, -1), (x2, 1)):
        c.stroke(path([(x, y), (x + d * 4, y + length)]), kit.edge_of(col), w + 2.4, remember=True)
        c.stroke(path([(x, y), (x + d * 4, y + length)]), col, w)


def zzz(c, x, y):
    for i, s in enumerate((5, 4, 3)):
        xx, yy = x + i * 6, y - i * 7
        c.stroke(path([(xx, yy), (xx + s, yy), (xx, yy + s), (xx + s, yy + s)]), "#8C7AB8", 1.6)


# ================================================================ 甲甲 the pangolin
PANGO = "#C99862"
PANGO_DK = "#9C6B3E"


def scales(c, cx, cy, w, h, rows=4, col=PANGO_DK):
    """Rows of rounded scales, like little puzzle pieces (inside an ellipse)."""
    body = ellipse(cx, cy, w / 2, h / 2)
    c.begin_clip(body)
    for r in range(rows + 1):
        y = cy - h / 2 + h * r / rows
        n = 5 + r % 2
        for i in range(n + 1):
            x = cx - w / 2 + w * (i + (.5 if r % 2 else 0)) / n
            c.paint(ellipse(x, y, w / n * .55, h / rows * .62), kit.mix(PANGO, col, .25 + .1 * (r % 2)), edge=.8, shade=False)
    c.end()


def pangolin(c, pose):
    if pose == "sleep":
        c.paint(ellipse(50, 66, 34, 28), PANGO)
        scales(c, 50, 64, 66, 54, rows=4)
        c.paint(ellipse(28, 76, 12, 10), "#E8C9A0")            # the snout tucked in
        face(c, 27, 74, 8, "sleep", nose="#A0623E")
        c.paint(smooth([(70, 84), (84, 74), (86, 58), (80, 52), (76, 62), (68, 76)]), PANGO_DK)   # the tail around
        zzz(c, 74, 30)
        return
    if pose == "cheer":
        arms_up(c, PANGO_DK, 32, 68, 62, 8)
    c.paint(ellipse(50, 70, 26, 24), PANGO)                  # body
    scales(c, 50, 70, 50, 46, rows=3)
    c.paint(smooth([(70, 82), (86, 86), (92, 74), (86, 70), (78, 76)]), PANGO_DK)  # tail
    if pose != "cheer":
        arms_down(c, PANGO_DK, 30, 70, 64, 7)
    c.paint(ellipse(38, 93, 9, 5), PANGO_DK)
    c.paint(ellipse(62, 93, 9, 5), PANGO_DK)
    c.paint(ellipse(50, 36, 24, 21), PANGO)                  # head
    c.paint(kit.Shape([("M", 28, 34), ("C", 30, 12, 70, 12, 72, 34), ("C", 60, 26, 40, 26, 28, 34), ("Z",)]), PANGO_DK, edge=1)  # scale cap
    for x in (36, 50, 64):
        c.stroke(arc(x, 26, 7, 200, 340), kit.mix(PANGO_DK, INK, .3), 1.2)
    c.paint(ellipse(50, 46, 12, 9), "#E8C9A0")               # snout
    face(c, 50, 38, 16, pose, nose="#A0623E")


# ================================================================ 石石 the leopard cat
CAT = "#C9A77C"
CAT_DK = "#7A5A3A"


def cat_head(c, cx, cy, pose, s=1.0):
    for d in (-1, 1):
        ear = poly([(cx + d * 22 * s, cy - 2 * s), (cx + d * 20 * s, cy - 24 * s), (cx + d * 6 * s, cy - 14 * s)])
        c.paint(ear, CAT)
        c.flat(poly([(cx + d * 18 * s, cy - 6 * s), (cx + d * 18 * s, cy - 18 * s), (cx + d * 10 * s, cy - 13 * s)]), "#E8A9A0")
    c.paint(ellipse(cx, cy, 24 * s, 20 * s), CAT)
    for d in (-1, 1):                                      # the white lines on the forehead
        c.stroke(path([(cx + d * 4 * s, cy - 18 * s), (cx + d * 5 * s, cy - 8 * s)]), WHITE, 2.4 * s)
        c.stroke(path([(cx + d * 9 * s, cy - 17 * s), (cx + d * 10 * s, cy - 9 * s)]), CAT_DK, 1.8 * s)
    c.flat(ellipse(cx, cy + 8 * s, 12 * s, 8 * s), "#F4E6D2")
    face(c, cx, cy + 1 * s, 17 * s, pose, nose="#C46E6E")
    for d in (-1, 1):
        for k in (-1, 1):
            c.stroke(path([(cx + d * 12 * s, cy + (9 + k * 2) * s), (cx + d * 24 * s, cy + (8 + k * 4) * s)]), WHITE, .9, op=.9)


def spots(c, pts, r=2.6, col=CAT_DK):
    for x, y in pts:
        c.flat(ellipse(x, y, r, r * .8), col, op=.85)


def leopardCat(c, pose):
    if pose == "sleep":
        c.paint(ellipse(50, 72, 36, 20), CAT)
        spots(c, [(32, 66), (44, 62), (58, 63), (70, 68), (38, 78), (64, 78)])
        c.paint(smooth([(14, 80), (30, 90), (60, 92), (80, 84), (74, 80), (56, 86), (30, 84)]), CAT_DK)  # tail
        cat_head(c, 34, 66, "sleep", .72)
        c.paint(smooth([(18, 74), (34, 80), (52, 78), (50, 74), (34, 76)]), CAT_DK)   # the tail over the nose
        zzz(c, 70, 34)
        return
    if pose == "cheer":
        arms_up(c, CAT, 34, 66, 62, 7)
    c.paint(smooth([(66, 84), (84, 80), (90, 62), (86, 58), (80, 72), (66, 78)]), CAT)   # tail
    for i, (x, y) in enumerate([(88, 64), (84, 74)]):
        c.flat(ellipse(x, y, 2.6, 2), CAT_DK)
    c.paint(ellipse(50, 72, 21, 22), CAT)
    spots(c, [(40, 64), (58, 66), (46, 78), (60, 80), (36, 76)])
    c.flat(ellipse(50, 74, 10, 14), "#F4E6D2", op=.9)
    if pose != "cheer":
        arms_down(c, CAT, 33, 67, 64, 7)
    c.paint(ellipse(40, 94, 8, 4.5), CAT)
    c.paint(ellipse(60, 94, 8, 4.5), CAT)
    cat_head(c, 50, 38, pose)


# ================================================================ 熊熊 the Formosan black bear
BEAR = "#3E3432"
MUZ = "#D8B48A"


def bear_head(c, cx, cy, pose, s=1.0):
    for d in (-1, 1):
        c.paint(circle(cx + d * 18 * s, cy - 15 * s, 8 * s), BEAR)
        c.flat(circle(cx + d * 18 * s, cy - 15 * s, 4 * s), "#6A5652")
    c.paint(ellipse(cx, cy, 25 * s, 21 * s), BEAR)
    c.paint(ellipse(cx, cy + 7 * s, 12 * s, 9 * s), MUZ, edge=1)
    c.flat(ellipse(cx, cy + 3 * s, 4.5 * s, 3.2 * s), INK)
    eyes_y = cy - 4 * s
    if pose == "sleep":
        for x in (cx - 9 * s, cx + 9 * s):
            c.stroke(arc(x, eyes_y - 1, 3.4 * s, 20, 160), WHITE, 1.6 * s)
    elif pose == "cheer":
        for x in (cx - 9 * s, cx + 9 * s):
            c.stroke(arc(x, eyes_y + 1.5, 3.6 * s, 200, 340), WHITE, 1.8 * s)
    else:
        for x in (cx - 9 * s, cx + 9 * s):
            c.flat(circle(x, eyes_y, 3.4 * s), WHITE)
            c.flat(circle(x, eyes_y, 2.2 * s), INK)
            c.flat(circle(x - .8 * s, eyes_y - .8 * s, .8 * s), WHITE)
    if pose == "cheer":
        c.flat(kit.Shape([("M", cx - 5 * s, cy + 9 * s), ("C", cx - 4 * s, cy + 16 * s, cx + 4 * s, cy + 16 * s, cx + 5 * s, cy + 9 * s), ("Z",)]), kit.MOUTH)
    elif pose != "sleep":
        c.stroke(arc(cx, cy + 6 * s, 4 * s, 40, 140), INK, 1.4 * s)
    c.cheeks(cx, cy + 4 * s, 30 * s, 3.4 * s, op=.45)


def bear_v(c, cx, cy, s=1.0):
    c.flat(poly([(cx - 12 * s, cy - 6 * s), (cx, cy + 6 * s), (cx + 12 * s, cy - 6 * s), (cx + 8 * s, cy - 6 * s), (cx, cy + 1 * s), (cx - 8 * s, cy - 6 * s)]), "#F4EBDD")


def bear(c, pose):
    if pose == "sleep":
        c.paint(ellipse(58, 78, 38, 17), BEAR)
        bear_head(c, 28, 68, "sleep", .78)
        c.paint(rrect(40, 70, 20, 20, 6), "#E8A93A")          # the honey pot in its arms
        c.paint(rrect(38, 66, 24, 7, 3), "#C9852C")
        c.flat(ellipse(50, 80, 5, 3), "#C9852C", op=.6)
        c.paint(ellipse(42, 88, 8, 5), BEAR)                  # paws around the pot
        c.paint(ellipse(60, 88, 8, 5), BEAR)
        zzz(c, 72, 40)
        return
    if pose == "cheer":
        arms_up(c, BEAR, 31, 69, 62, 9)
    c.paint(ellipse(50, 72, 24, 23), BEAR)
    bear_v(c, 50, 64)
    c.flat(ellipse(50, 80, 12, 11), "#5C4D4A", op=.8)
    if pose != "cheer":
        arms_down(c, BEAR, 30, 70, 62, 9)
    c.paint(ellipse(39, 94, 9, 5), BEAR)
    c.paint(ellipse(61, 94, 9, 5), BEAR)
    bear_head(c, 50, 36, pose)


# ================================================================ 藍藍 the Taiwan blue magpie
MAG = "#2E6FC4"
MAG_HEAD = "#2A2A3A"


def magpie(c, pose):
    if pose == "sleep":
        c.paint(rrect(4, 78, 92, 7, 3.5), "#8A5A33")          # the branch
        c.paint(smooth([(56, 70), (80, 66), (96, 56), (98, 62), (82, 74), (60, 78)]), MAG)  # tail
        c.paint(ellipse(44, 62, 22, 17), MAG)
        c.paint(smooth([(30, 54), (46, 46), (62, 52), (58, 66), (40, 68)]), "#4A86D6")   # the wing over the head
        c.flat(ellipse(30, 58, 8, 7), MAG_HEAD)
        c.stroke(path([(38, 78), (40, 84)]), "#D8453A", 2.4)
        zzz(c, 66, 30)
        return
    # tail: long, with white tips
    c.paint(smooth([(58, 70), (74, 84), (94, 96), (98, 90), (78, 78), (62, 64)]), MAG)
    c.flat(ellipse(95, 93, 4, 3), WHITE)
    if pose == "cheer":
        for d in (-1, 1):
            c.paint(smooth([(50 + d * 14, 62), (50 + d * 34, 40), (50 + d * 30, 56), (50 + d * 22, 70)]), "#4A86D6")
    c.paint(ellipse(50, 66, 20, 22), MAG)
    c.flat(ellipse(50, 72, 11, 14), "#CFE0F5", op=.9)
    if pose != "cheer":
        for d in (-1, 1):
            c.paint(smooth([(50 + d * 14, 58), (50 + d * 24, 70), (50 + d * 18, 84), (50 + d * 12, 74)]), "#4A86D6")
    for x in (44, 56):
        c.stroke(path([(x, 86), (x, 94)]), "#D8453A", 2.4)
        c.stroke(path([(x - 3, 95), (x + 3, 95)]), "#D8453A", 2.2)
    c.paint(circle(50, 36, 20), MAG_HEAD)
    for x in (43, 57):                                       # bright eyes ringed white
        c.flat(circle(x, 34, 4.2), WHITE)
    if pose == "cheer":
        for x in (43, 57):
            c.stroke(arc(x, 36, 3, 200, 340), INK, 1.8)
    else:
        for x in (43, 57):
            c.flat(circle(x, 34, 2.6), INK)
            c.flat(circle(x - .8, 33.2, .8), WHITE)
    c.paint(poly([(46, 42), (54, 42), (50, 50 if pose != "cheer" else 47)]), "#E2453A", edge=.8)
    if pose == "cheer":
        c.paint(poly([(46.5, 48), (53.5, 48), (50, 53)]), "#E2453A", edge=.8)
    c.cheeks(50, 42, 26, 3, op=.4)


# ================================================================ 花花 the sika deer
DEER = "#D59A5A"
DEER_LT = "#F3DDBF"


def deer_spots(c, pts):
    for x, y in pts:
        c.flat(circle(x, y, 2.3), WHITE, op=.95)


def deer_head(c, cx, cy, pose, s=1.0):
    for d in (-1, 1):
        ear = ellipse(cx + d * 22 * s, cy - 8 * s, 10 * s, 5 * s).rotate(d * -28, cx + d * 22 * s, cy - 8 * s)
        c.paint(ear, DEER)
        c.flat(ellipse(cx + d * 22 * s, cy - 8 * s, 6 * s, 2.6 * s).rotate(d * -28, cx + d * 22 * s, cy - 8 * s), "#F2B9A8")
        c.stroke(path([(cx + d * 8 * s, cy - 15 * s), (cx + d * 11 * s, cy - 24 * s)]), "#8A5A33", 2.6 * s)
    c.paint(ellipse(cx, cy, 18 * s, 19 * s), DEER)
    c.flat(ellipse(cx, cy + 9 * s, 10 * s, 8 * s), DEER_LT)
    face(c, cx, cy - 1 * s, 15 * s, pose, nose=INK)


def deer(c, pose):
    if pose == "sleep":
        c.paint(ellipse(56, 78, 34, 15), DEER)
        deer_spots(c, [(44, 72), (56, 70), (68, 72), (50, 80), (64, 80)])
        for x in (34, 74):
            c.paint(ellipse(x, 90, 9, 4), "#B97E44")         # folded legs
        deer_head(c, 30, 64, "sleep", .8)
        zzz(c, 72, 36)
        return
    if pose == "cheer":
        arms_up(c, DEER, 36, 64, 62, 6)
    c.paint(ellipse(50, 70, 18, 20), DEER)
    c.flat(ellipse(50, 74, 9, 13), DEER_LT)
    deer_spots(c, [(38, 64), (62, 64), (36, 76), (64, 76), (42, 84), (58, 84)])
    for x in (41, 59):
        c.paint(rrect(x - 3.5, 82, 7, 14, 3), DEER)
        c.flat(rrect(x - 3.5, 92, 7, 4, 2), "#5A3A26")
    if pose != "cheer":
        arms_down(c, DEER, 36, 64, 62, 6, 12)
    deer_head(c, 50, 36, pose)


# ================================================================ 猴猴 the Formosan macaque
MAC = "#9C8670"
MAC_FACE = "#F0C3A8"


def mac_head(c, cx, cy, pose, s=1.0):
    for d in (-1, 1):
        c.paint(circle(cx + d * 22 * s, cy + 2 * s, 6 * s), MAC)
        c.flat(circle(cx + d * 22 * s, cy + 2 * s, 3.4 * s), MAC_FACE)
    c.paint(ellipse(cx, cy, 22 * s, 20 * s), MAC)
    c.paint(smooth([(cx - 15 * s, cy - 2 * s), (cx - 8 * s, cy - 10 * s), (cx, cy - 6 * s), (cx + 8 * s, cy - 10 * s), (cx + 15 * s, cy - 2 * s),
                    (cx + 12 * s, cy + 12 * s), (cx, cy + 17 * s), (cx - 12 * s, cy + 12 * s)], .7), MAC_FACE, edge=1)
    face(c, cx, cy + 1 * s, 13 * s, pose, nose="#B77A66")


def macaque(c, pose):
    if pose == "sleep":
        c.paint(smooth([(70, 88), (88, 82), (90, 66), (84, 64), (82, 76), (68, 82)]), MAC)   # tail
        c.paint(ellipse(50, 72, 25, 22), MAC)
        c.paint(ellipse(50, 80, 18, 12), "#B29C86")             # knees
        c.paint(ellipse(36, 76, 8, 6), MAC)                     # arms around them
        c.paint(ellipse(64, 76, 8, 6), MAC)
        mac_head(c, 50, 48, "sleep", .85)
        zzz(c, 74, 26)
        return
    c.paint(smooth([(64, 84), (84, 86), (92, 70), (86, 66), (82, 78), (66, 78)]), MAC)   # tail
    if pose == "cheer":
        arms_up(c, MAC, 33, 67, 62, 7, 18)
    c.paint(ellipse(50, 72, 20, 22), MAC)
    c.flat(ellipse(50, 74, 11, 14), "#C8B09A")
    if pose != "cheer":
        arms_down(c, MAC, 32, 68, 62, 7, 15)
    c.paint(ellipse(40, 94, 8, 4.5), MAC)
    c.paint(ellipse(60, 94, 8, 4.5), MAC)
    mac_head(c, 50, 38, pose)


DRAW = {"pangolin": pangolin, "leopardCat": leopardCat, "bear": bear, "magpie": magpie, "deer": deer, "macaque": macaque}


def draw(name, pose="idle"):
    c = Ctx(100, 100)
    DRAW[name](c, pose)
    return c


def build():
    n = 0
    for name in NAMES:
        for pose in POSES:
            kit.write_svg(OUT / f"{name}_{pose}.svg", draw(name, pose).svg(), (100, 100))
            n += 1
    print(f"helpers: {n} files")


if __name__ == "__main__":
    build()
