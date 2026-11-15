"""The shapes of 拼拼樂工坊's geometric puzzles, checked with shapely and written as JSON for the app:

- 七巧板 (app/assets/tangram.json): 24 silhouettes (小小 6, 中 8, 大 10). Each is made from the
  traditional pieces placed edge to edge, so every one can be solved by construction; the check makes
  sure each piece really is that piece (side lengths), that no two overlap and that the set is right.
- 照著拼 (app/assets/blocks.json): 12 pattern-block cards. Blocks on the triangle grid also get every
  other way of filling the same outline (two trapezoids for a hexagon, …) for 大, which only asks for
  the outline to be filled.
- 台灣大拼圖 (app/assets/taiwan.json): Taiwan's coast cut into 48 pieces of about the same size
  (Lloyd-relaxed Voronoi cells, north to south).

    python3 design/puzzles.py              # write the three files (and check them)
    python3 design/puzzles.py preview OUT  # OUT_tangram.png, OUT_blocks.png, OUT_taiwan.png to look at

Units: in the tangram, a small triangle's short side is 1 (so a large triangle's is 2, the square's
side 1, the parallelogram's sides 1 and √2). In the pattern blocks, every side is 1. y grows downwards
(screen coordinates). Deterministic.
"""
import json
import math
import pathlib
import random
import sys

from shapely.geometry import MultiPoint, Point, Polygon
from shapely.ops import unary_union, voronoi_diagram

ROOT = pathlib.Path(__file__).resolve().parents[1]
ASSETS = ROOT / "app" / "assets"
R2 = math.sqrt(2)
EPS = 1e-6

# ================================================================ tangram
# The pieces with their first vertex at 0,0. A small triangle's short side is 1.
TAN = {
    "L": [(0, 0), (2, 0), (0, 2)],
    "M": [(0, 0), (2, 0), (1, 1)],
    "S": [(0, 0), (1, 0), (0, 1)],
    "Q": [(0, 0), (1, 0), (1, 1), (0, 1)],
    "P": [(0, 0), (1, 0), (2, 1), (1, 1)],
}
# How far a piece turns before it looks the same again.
SYMMETRY = {"L": 360, "M": 360, "S": 360, "Q": 90, "P": 180}
AREA = {"L": 2, "M": 1, "S": .5, "Q": 1, "P": 1}
FULL_SET = ["L", "L", "M", "S", "S", "Q", "P"]
TAN_ZH = {"L": "大三角形", "M": "中三角形", "S": "小三角形", "Q": "正方形", "P": "平行四邊形"}
r = R2
h = R2 / 2


def C(kind, pts):
    """A piece drawn in the traditional square's units (its small triangle's long side is 2)."""
    return (kind, [(x / R2, y / R2) for x, y in pts])


def V(kind, pts):
    return (kind, list(pts))


def _xf(pts, rot, flip, x, y):
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)
    out = []
    for px, py in pts:
        if flip:
            px = -px
        out.append((x + px * ca - py * sa, y + px * sa + py * ca))
    return out


def centroid(pts):
    c = Polygon(pts).centroid
    return c.x, c.y


def _same(a, b):
    if len(a) != len(b):
        return False
    for k in range(len(a)):
        if all(abs(a[(i + k) % len(a)][0] - b[i][0]) < 1e-3 and abs(a[(i + k) % len(a)][1] - b[i][1]) < 1e-3 for i in range(len(b))):
            return True
    return False


def orient(kind, pts):
    """(angle, flip): the piece centred on its centroid, mirrored if flip, then turned angle degrees
    clockwise (on screen), is pts. Triangles and the square never need the mirror."""
    cx, cy = centroid(pts)
    ccx, ccy = centroid(TAN[kind])
    base = [(px - ccx, py - ccy) for px, py in TAN[kind]]
    target = [(px - cx, py - cy) for px, py in pts]
    for flip in ((False, True) if kind == "P" else (False,)):
        for k in range(8):
            got = _xf(base, k * 45, flip, 0, 0)
            if _same(got, target) or _same(got[::-1], target):
                return k * 45 % SYMMETRY[kind], flip
    raise SystemExit(f"{kind} is not a {TAN_ZH[kind]}: {pts}")


# ---- a little tiling solver for the seven-piece figures: a silhouette drawn on the grid (sides
# along the grid or at 45 degrees), filled with the pieces in the "legs along the grid" family.
def _quarters(poly):
    x0, y0, x1, y1 = poly.bounds
    cs = set()
    for i in range(math.floor(x0), math.ceil(x1)):
        for j in range(math.floor(y0), math.ceil(y1)):
            for q, (cx, cy) in enumerate([(i + .5, j + .2), (i + .8, j + .5), (i + .5, j + .8), (i + .2, j + .5)]):
                if poly.contains(Point(cx, cy)):
                    cs.add((j, i, q))
    return cs


def _shapes(kind):
    out = []
    for flip in (False, True):
        for k in range(4):
            q = _xf(TAN[kind], k * 90, flip, 0, 0)
            q = [(round(x), round(y)) for x, y in q]
            mx, my = min(p[0] for p in q), min(p[1] for p in q)
            q = [(x - mx, y - my) for x, y in q]
            c = frozenset(_quarters(Polygon(q)))
            if all(c != s[1] for s in out):
                out.append((q, c))
    return out


def solve(target, pieces):
    """Pieces (a list of kinds) that tile the target polygon exactly, or SystemExit."""
    want = _quarters(Polygon(target))
    if abs(len(want) / 4 - sum(AREA[k] for k in pieces)) > 1e-6:
        raise SystemExit(f"silhouette area {len(want) / 4} is not the pieces' {sum(AREA[k] for k in pieces)}")
    shapes = {k: _shapes(k) for k in set(pieces)}
    left, placed, free = list(pieces), [], set(want)

    def rec():
        if not free:
            return True
        c = min(free)
        for k in sorted(set(left)):
            left.remove(k)
            for pts, cs in shapes[k]:
                for rr in sorted(cs):
                    if rr[2] != c[2]:
                        continue
                    dj, di = c[0] - rr[0], c[1] - rr[1]
                    moved = {(a + dj, b_ + di, q) for a, b_, q in cs}
                    if moved <= free:
                        free.difference_update(moved)
                        placed.append((k, [(x + di, y + dj) for x, y in pts]))
                        if rec():
                            return True
                        placed.pop()
                        free.update(moved)
            left.append(k)
        return False

    if not rec():
        raise SystemExit(f"no way to fill {target} with {pieces}")
    return placed


def S7(target):
    return solve(target, FULL_SET)


# (id, name, how it moves when done, pieces, where its eye is or None)
TANGRAMS = {
    # ---- 小小: 2 to 3 pieces, the lines drawn, every piece already the right way round.
    "small": [
        ("house", "房子", "hop", [V("M", [(0, 1), (2, 1), (1, 0)]), V("L", [(0, 1), (2, 1), (0, 3)]), V("L", [(2, 1), (2, 3), (0, 3)])], None),
        ("sailboat", "帆船", "sway", [V("L", [(0, 2), (2 * r, 2), (r, 2 + r)]), V("M", [(r, 2 - r), (r, 2), (2 * r, 2)]),
                                     V("S", [(r, 1), (r, 2), (r - 1, 2)])], None),
        ("fish", "魚", "swim", [V("L", [(r, 0), (r, 2 * r), (0, r)]), V("L", [(r, 0), (2 * r, r), (r, 2 * r)]),
                               V("M", [(0, r), (-1, r - 1), (-1, r + 1)])], (2.0, 1.15)),
        ("tree", "大樹", "sway", [V("L", [(0, 2), (2, 0), (2, 2)]), V("L", [(2, 0), (4, 2), (2, 2)]),
                                 V("Q", [(1.5, 2), (2.5, 2), (2.5, 3), (1.5, 3)])], None),
        ("lantern", "天燈", "fly", [V("Q", [(.5, 0), (1.5, 0), (1.5, 1), (.5, 1)]), V("S", [(.5, 0), (-.5, 0), (.5, 1)]),
                                   V("S", [(1.5, 0), (2.5, 0), (1.5, 1)])], None),
        ("mountain", "山", "pulse", [V("L", [(0, r), (r, 0), (2 * r, r)]), V("L", [(2 * r, r), (3 * r, 0), (4 * r, r)]),
                                    V("S", [(1.5 * r, .5 * r), (2.5 * r, .5 * r), (2 * r, r)])], None),
    ],
    # ---- 中: 4 to 5 pieces, the lines drawn, pieces turn themselves upright near their place.
    "middle": [
        ("cat", "小貓", "hop", [V("Q", [(0, -h), (h, 0), (0, h), (-h, 0)]), V("S", [(0, -h), (-h, 0), (-h, -2 * h)]),
                                V("S", [(0, -h), (h, 0), (h, -2 * h)]), V("L", [(0, h), (r, h + r), (-r, h + r)]),
                                V("P", [(r, h + r), (r + 1, h + r), (r + 2, h + r - 1), (r + 1, h + r - 1)])], (0, 0)),
        ("rabbit", "兔子", "hop", [V("Q", [(0, 0), (1, 0), (1, 1), (0, 1)]), V("P", [(0, 0), (1, -1), (1, -2), (0, -1)]),
                                  V("S", [(1, 0), (1, -1), (2, -1)]), V("L", [(0, 1), (2, 1), (0, 3)]),
                                  V("M", [(2, 1), (2 + r, 1), (2, 1 + r)])], (.6, .45)),
        ("bird", "小鳥", "fly", [V("Q", [(0, 0), (1, 0), (1, 1), (0, 1)]), V("S", [(0, 0), (-1, 0), (0, 1)]),
                                 V("L", [(1, 0), (3, 0), (1, 2)]), V("M", [(1, 0), (3, 0), (2, -1)]),
                                 V("P", [(3, 0), (4, 0), (5, -1), (4, -1)])], (.55, .4)),
        ("turtle", "烏龜", "drive", [V("L", [(0, 2), (2, 0), (2, 2)]), V("L", [(2, 0), (4, 2), (2, 2)]),
                                    V("Q", [(4, 1), (5, 1), (5, 2), (4, 2)]), V("S", [(.5, 2), (1.5, 2), (.5, 3)]),
                                    V("S", [(2.5, 2), (3.5, 2), (3.5, 3)])], (4.6, 1.4)),
        ("snail", "蝸牛", "drive", [C("L", [(0, 0), (4, 0), (2, 2)]), C("L", [(0, 0), (4, 0), (2, -2)]),
                                   C("P", [(2, 2), (4, 2), (5, 3), (3, 3)]), C("M", [(4, 2), (6, 2), (4, 0)]),
                                   C("S", [(4, 0), (6, 0), (5, -1)])], (4.55 / R2, 1.2 / R2)),
        ("duck", "鴨子", "swim", [C("L", [(0, 2), (4, 2), (2, 4)]), C("Q", [(3, 0), (4, 1), (3, 2), (2, 1)]),
                                 C("S", [(4, 0), (4, 2), (5, 1)]), C("S", [(0, 2), (-1, 1), (0, 0)])], (3.1 / R2, .9 / R2)),
        ("butterfly", "蝴蝶", "fly", [C("L", [(0, 1), (-2, -1), (-2, 3)]), C("L", [(0, 1), (2, -1), (2, 3)]),
                                     C("S", [(0, 1), (-1, 2), (0, 3)]), C("S", [(0, 1), (1, 2), (0, 3)])], None),
        ("heart", "愛心", "pulse", solve([(0, 1), (1, 0), (2, 1), (3, 0), (4, 1), (2, 3)], ["L", "L", "M", "S", "S"]), None),
    ],
    # ---- 大: all seven pieces; the first five with lines, the rest only the shadow; tap to turn.
    "big": [
        ("house7", "房子", "hop", S7([(1, 0), (3, 2), (2, 2), (2, 4), (0, 4), (0, 2), (-1, 2)]), None),
        ("boat7", "船", "sway", S7([(2, 0), (4, 2), (5, 2), (4, 3), (1, 3), (0, 2)]), None),
        ("cat7", "貓", "hop", S7([(0, 0), (1, 1), (3, 1), (4, 0), (4, 2), (3, 3), (1, 3), (0, 2)]), (2, 1.9)),
        ("rocket7", "火箭", "fly", S7([(1, 0), (2, 1), (2, 3), (3, 4), (-1, 4), (0, 3), (0, 1)]), None),
        ("mrt7", "捷運", "drive", S7([(0, 0), (3, 0), (5, 2), (0, 2)]), None),
        ("giraffe7", "長頸鹿", "nod", S7([(1, 0), (2, 0), (2, 3), (4, 3), (4, 5), (3, 5), (3, 4), (2, 4), (2, 5), (1, 5)]), (1.5, .55)),
        ("dog7", "狗", "hop", S7([(1, 0), (2, 0), (2, 1), (4, 1), (5, 0), (5, 1), (4, 2), (4, 3), (3, 3), (3, 2), (2, 2), (2, 3),
                                  (1, 3), (1, 2), (0, 1)]), (1.1, .75)),
        ("bear7", "熊", "nod", S7([(0, 0), (1, 0), (1, 1), (2, 1), (2, 0), (3, 0), (3, 3), (0, 3)]), (1.5, 1.8)),
        ("teapot7", "茶壺", "wiggle", S7([(2, 0), (3, 1), (4, 1), (4, 2), (3, 3), (1, 3), (0, 2), (0, 1), (1, 1)]), None),
        ("roof7", "廟的屋頂", "pulse", S7([(1, 0), (3, 0), (4, 1), (5, 1), (4, 2), (0, 2), (-1, 1), (0, 1)]), None),
    ],
}


# Figures seen from the front get two eyes, the others one (seen from the side).
FRONT_FACES = {"cat", "cat7", "bear7"}


def tan_check(level, fid, pieces, need):
    polys = [Polygon(p) for _, p in pieces]
    for (kind, pts), poly in zip(pieces, polys):
        if not poly.is_valid or abs(poly.area - AREA[kind]) > 1e-3:
            raise SystemExit(f"tangram {fid}: a broken {kind} (area {poly.area:.3f})")
        orient(kind, pts)
    for i in range(len(polys)):
        for j in range(i + 1, len(polys)):
            if polys[i].intersection(polys[j]).area > 1e-4:
                raise SystemExit(f"tangram {fid}: pieces {i} ({pieces[i][0]}) and {j} ({pieces[j][0]}) overlap")
    kinds = sorted(k for k, _ in pieces)
    if level == "big" and kinds != sorted(FULL_SET):
        raise SystemExit(f"tangram {fid}: a 大 figure uses all seven pieces, not {kinds}")
    for k in set(kinds):
        if kinds.count(k) > FULL_SET.count(k):
            raise SystemExit(f"tangram {fid}: more {TAN_ZH[k]} than a set has")
    if not need[0] <= len(pieces) <= need[1]:
        raise SystemExit(f"tangram {fid}: {len(pieces)} pieces, a {level} figure has {need}")
    for i, p in enumerate(polys):
        if not any(p.distance(q) < 1e-4 for j, q in enumerate(polys) if j != i):
            raise SystemExit(f"tangram {fid}: piece {i} floats on its own")


def tangram_json():
    out = []
    need = {"small": (2, 3), "middle": (4, 5), "big": (7, 7)}
    for level in ("small", "middle", "big"):
        for i, (fid, zh, anim, pieces, eye) in enumerate(TANGRAMS[level]):
            tan_check(level, fid, pieces, need[level])
            xs = [x for _, p in pieces for x, _ in p]
            ys = [y for _, p in pieces for _, y in p]
            x0, y0 = min(xs), min(ys)
            slots = []
            for kind, pts in pieces:
                cx, cy = centroid(pts)
                ang, flip = orient(kind, pts)
                slots.append({"kind": kind, "x": round(cx - x0, 4), "y": round(cy - y0, 4), "angle": ang, "flip": flip,
                              "points": [[round(x - x0, 4), round(y - y0, 4)] for x, y in pts]})
            item = {"id": fid, "zh": zh, "level": level, "anim": anim, "w": round(max(xs) - x0, 4), "h": round(max(ys) - y0, 4),
                    "lines": level != "big" or i < 5, "slots": slots}
            if eye:
                item["eye"] = [round(eye[0] - x0, 4), round(eye[1] - y0, 4)]
                item["eyes"] = 2 if fid in FRONT_FACES else 1
            out.append(item)
    pieces = {}
    for k, pts in TAN.items():
        cx, cy = centroid(pts)
        pieces[k] = {"zh": TAN_ZH[k], "symmetry": SYMMETRY[k], "points": [[round(x - cx, 4), round(y - cy, 4)] for x, y in pts]}
    return {"pieces": pieces, "figures": out}


# ================================================================ pattern blocks
H3 = math.sqrt(3) / 2


def L(a, b):
    """Grid point a·(1, 0) + b·(½, √3/2), y downwards."""
    return (a + b * .5, -b * H3)


def G(kind, *pts):
    """A block on the triangle grid, by its corners' grid points."""
    return (kind, [L(a, b) for a, b in pts])


def XY(kind, *pts):
    return (kind, list(pts))


def hexa(a, b):
    return G("hex", (a + 1, b), (a, b + 1), (a - 1, b + 1), (a - 1, b), (a, b - 1), (a + 1, b - 1))


def up(a, b):
    """The triangle standing on side (a, b)-(a+1, b)."""
    return G("tri", (a, b), (a + 1, b), (a, b + 1))


def tri3(p, q, s):
    return G("tri", p, q, s)


def square(x, y):
    return XY("square", (x, y), (x + 1, y), (x + 1, y + 1), (x, y + 1))


def ray(px, py, deg):
    """A thin rhombus with its sharp corner at px, py pointing deg degrees (0 = right, y down)."""
    c15 = math.cos(math.radians(15))

    def d(a, s=1.0):
        return (px + s * math.cos(math.radians(a)), py + s * math.sin(math.radians(a)))
    return ("thin", [(px, py), d(deg - 15), d(deg, 2 * c15), d(deg + 15)])


def _hex_corners(a, b):
    return [L(a + 1, b), L(a, b + 1), L(a - 1, b + 1), L(a - 1, b), L(a, b - 1), L(a + 1, b - 1)]


CARDS = [
    ("flower", "小花", [hexa(0, 0), tri3((0, 1), (-1, 1), (-1, 2)), tri3((1, 0), (0, 1), (1, 1)), tri3((-1, 1), (-1, 0), (-2, 1)),
                        tri3((1, 0), (1, -1), (2, -1)), tri3((-1, 0), (0, -1), (-1, -1)),
                        square(-.5, H3)]),
    ("sun", "太陽", [hexa(0, 0)] + [ray(x, y, math.degrees(math.atan2(y - 0.0, x - 0.0))) for x, y in _hex_corners(0, 0)]),
    ("butterfly", "蝴蝶", [G("rhomb", (0, 1), (1, 0), (1, -1), (0, 0)), hexa(1, 1), hexa(-1, 1),
                           tri3((0, 0), (1, -1), (0, -1)), tri3((1, 0), (1, -1), (2, -1))]),
    ("turtle", "烏龜", [hexa(0, 0), G("rhomb", (1, 0), (2, 0), (1, 1), (0, 1)), tri3((1, 0), (1, -1), (2, -1)),
                        tri3((-1, 0), (0, -1), (-1, -1)), tri3((-1, 1), (-1, 0), (-2, 1))]),
    ("fish", "小魚", [hexa(0, 0), tri3((-1, 1), (-1, 0), (-2, 1)), tri3((-1, 0), (0, -1), (-1, -1)), tri3((0, 1), (-1, 1), (-1, 2))]),
    ("pineapple", "鳳梨", [hexa(0, 0), hexa(-1, 2), tri3((-2, 3), (-1, 3), (-2, 4)), tri3((0, 2), (-1, 3), (0, 3)),
                           tri3((-2, 3), (-2, 2), (-3, 3))]),
    ("skylantern", "天燈", [square(0, 0), square(1, 0), XY("trap", (0, 0), (2, 0), (1.5, -H3), (.5, -H3)),
                            XY("tri", (.5, 1), (1.5, 1), (1, 1 + H3))]),
    ("taipei101", "台北 101", [square(0, 0), square(0, -1), square(0, -2), XY("trap", (-.5, -2), (1.5, -2), (1, -2 - H3), (0, -2 - H3)),
                              XY("tri", (0, -2 - H3), (1, -2 - H3), (.5, -2 - 2 * H3))]),
    ("train", "火車", [square(0, 0), square(1, 0), square(2, 0), square(2, -1), XY("trap", (0, 0), (2, 0), (1.5, -H3), (.5, -H3)),
                       XY("rhomb", (3, 1), (3, 0), (3 + H3, .5), (3 + H3, 1.5)) if False else XY("tri", (3, 0), (3, 1), (3 + H3, .5))]),
    ("snail", "蝸牛", [hexa(0, 0), G("trap", (0, -2), (2, -2), (1, -1), (0, -1)), G("rhomb", (2, -2), (3, -2), (2, -1), (1, -1)),
                       tri3((2, -1), (3, -1), (3, -2)), tri3((2, -1), (3, -1), (2, 0))]),
    ("robot", "機器人", [square(0, 0), square(1, 0), square(0, 1), square(1, 1), square(.5, -1),
                         XY("tri", (0, 0), (0, 1), (-H3, .5)), XY("tri", (2, 0), (2, 1), (2 + H3, .5))]),
    ("temple", "廟", [square(0, 0), square(1, 0), square(2, 0), XY("trap", (-.5, 0), (1.5, 0), (1, -H3), (0, -H3)),
                      XY("trap", (1.5, 0), (3.5, 0), (3, -H3), (2, -H3)), XY("tri", (1, -H3), (2, -H3), (1.5, 0)),
                      XY("trap", (.5, -H3), (2.5, -H3), (2, -2 * H3), (1, -2 * H3))]),
]
BLK_ZH = {"hex": "黃色六角形", "trap": "紅色梯形", "rhomb": "藍色菱形", "tri": "綠色三角形", "square": "橘色正方形", "thin": "細細的菱形"}
BLK_AREA = {"hex": 6 * H3 / 2, "trap": 3 * H3 / 2, "rhomb": H3, "tri": H3 / 2, "square": 1, "thin": .5}
LATTICE_KINDS = ("hex", "trap", "rhomb", "tri")
# The block shapes, centred, in their first position (for the tray).
BLK = {
    "hex": [L(1, 0), L(0, 1), L(-1, 1), L(-1, 0), L(0, -1), L(1, -1)],
    "trap": [L(0, 0), L(2, 0), L(1, 1), L(0, 1)],
    "rhomb": [L(0, 0), L(1, 0), L(1, 1), L(0, 1)],
    "tri": [L(0, 0), L(1, 0), L(0, 1)],
    "square": [(0, 0), (1, 0), (1, 1), (0, 1)],
    "thin": ray(0, 0, 0)[1],
}
BLK_SYM = {"hex": 60, "trap": 360, "rhomb": 180, "tri": 120, "square": 90, "thin": 180}


def _cells_of(poly):
    """The unit triangles of the grid inside poly (keys are their centres, rounded)."""
    x0, y0, x1, y1 = poly.bounds
    cells = set()
    inner = poly.buffer(-1e-3)
    for b in range(math.floor(-y1 / H3) - 2, math.ceil(-y0 / H3) + 2):
        for a in range(math.floor(x0 - b * .5) - 2, math.ceil(x1 - b * .5) + 2):
            p0, p1, p2, p3 = L(a, b), L(a + 1, b), L(a, b + 1), L(a + 1, b + 1)
            for tri in ((p0, p1, p2), (p1, p3, p2)):
                cx, cy = sum(p[0] for p in tri) / 3, sum(p[1] for p in tri) / 3
                if inner.contains(Point(cx, cy)):
                    cells.add(f"{cx:.3f},{cy:.3f}")
    return cells


def _on_grid(kind, poly):
    return kind in LATTICE_KINDS and abs(len(_cells_of(poly)) * (H3 / 2) - poly.area) < 1e-3


def _turn(pts, deg):
    a = math.radians(deg)
    ca, sa = math.cos(a), math.sin(a)
    return [(x * ca - y * sa, x * sa + y * ca) for x, y in pts]


def _centred(pts):
    c = Polygon(pts).centroid
    return [(x - c.x, y - c.y) for x, y in pts]


def block_angle(kind, pts):
    """The turn (degrees, clockwise on screen) that takes the block as it comes out of the box onto
    pts, both centred."""
    c = Polygon(pts).centroid
    target = [(x - c.x, y - c.y) for x, y in pts]
    base = _centred(BLK[kind])
    for k in range(24):
        got = _turn(base, k * 15)
        if _same(got, target) or _same(got[::-1], target):
            return (k * 15) % BLK_SYM[kind]
    raise SystemExit(f"{kind} does not match {pts}")


def block_placements(kind, region):
    """Every way to put grid block `kind` (any turn) on the grid inside the cells `region`."""
    out, seen = [], set()
    pts = [tuple(float(v) for v in c.split(",")) for c in region]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    base = BLK[kind]
    for b in range(math.floor(-max(ys) / H3) - 4, math.ceil(-min(ys) / H3) + 4):
        for a in range(math.floor(min(xs) - b * .5) - 4, math.ceil(max(xs) - b * .5) + 4):
            ox, oy = L(a, b)
            for rot in range(0, 360, 60):
                q = [(ox + x, oy + y) for x, y in _turn(base, rot)]
                c = _cells_of(Polygon(q))
                key = tuple(sorted(c))
                if c and c <= region and key not in seen and abs(len(c) * H3 / 2 - BLK_AREA[kind]) < 1e-3:
                    seen.add(key)
                    out.append((q, c))
    return out


def blocks_json():
    cards = []
    for cid, zh, blocks in CARDS:
        polys = [Polygon(p) for _, p in blocks]
        for i, ((kind, _), poly) in enumerate(zip(blocks, polys)):
            if not poly.is_valid or abs(poly.area - BLK_AREA[kind]) > 1e-3:
                raise SystemExit(f"blocks {cid}: block {i} is not a {BLK_ZH[kind]} (area {poly.area:.3f})")
            for j in range(i + 1, len(polys)):
                if poly.intersection(polys[j]).area > 1e-4:
                    raise SystemExit(f"blocks {cid}: blocks {i} ({kind}) and {j} ({blocks[j][0]}) overlap")
        if not 4 <= len(blocks) <= 9:
            raise SystemExit(f"blocks {cid}: {len(blocks)} blocks")
        for i, p in enumerate(polys):
            if not any(p.distance(q) < 1e-4 for j, q in enumerate(polys) if j != i):
                raise SystemExit(f"blocks {cid}: block {i} floats on its own")
        xs = [x for _, p in blocks for x, _ in p]
        ys = [y for _, p in blocks for _, y in p]
        x0, y0 = min(xs), min(ys)

        def rel(pts):
            return [[round(x - x0, 4), round(y - y0, 4)] for x, y in pts]

        slots, grid = [], set()
        for i, ((kind, pts), poly) in enumerate(zip(blocks, polys)):
            if _on_grid(kind, poly):
                cells = sorted(_cells_of(poly))
                grid |= set(cells)
            else:
                cells = [f"slot{i}"]
            c = poly.centroid
            slots.append({"kind": kind, "x": round(c.x - x0, 4), "y": round(c.y - y0, 4), "angle": block_angle(kind, pts),
                          "points": rel(pts), "cells": cells})
        extra = []
        if grid:
            for kind in LATTICE_KINDS:
                for pts, cells in block_placements(kind, grid):
                    c = Polygon(pts).centroid
                    item = {"kind": kind, "x": round(c.x - x0, 4), "y": round(c.y - y0, 4), "angle": block_angle(kind, pts),
                            "points": rel(pts), "cells": sorted(cells)}
                    if not any(s["kind"] == kind and s["cells"] == item["cells"] for s in slots):
                        extra.append(item)
        cards.append({"id": cid, "zh": zh, "w": round(max(xs) - x0, 4), "h": round(max(ys) - y0, 4), "slots": slots, "extra": extra})
    kinds = {}
    for k, pts in BLK.items():
        c = Polygon(pts).centroid
        kinds[k] = {"zh": BLK_ZH[k], "symmetry": BLK_SYM[k], "points": [[round(x - c.x, 4), round(y - c.y, 4)] for x, y in pts]}
    return {"kinds": kinds, "cards": cards}


# ================================================================ Taiwan
COAST = [
    (121.54, 25.30), (121.74, 25.16), (121.95, 25.04), (121.85, 24.80), (121.86, 24.56), (121.66, 24.10),
    (121.55, 23.70), (121.42, 23.30), (121.22, 22.90), (120.98, 22.50), (120.86, 21.92), (120.70, 21.96),
    (120.60, 22.36), (120.30, 22.56), (120.12, 22.96), (120.12, 23.40), (120.28, 23.90), (120.48, 24.25),
    (120.86, 24.70), (121.02, 25.02), (121.38, 25.18),
]
TW_PIECES = 48


def taiwan_json():
    pts = [((lon - 120.0) * 100 * math.cos(math.radians(23.7)), (25.4 - lat) * 111) for lon, lat in COAST]
    island = Polygon(pts).buffer(3, join_style=1).buffer(-3, join_style=1)
    r = random.Random(48)
    x0, y0, x1, y1 = island.bounds
    seeds = []
    while len(seeds) < TW_PIECES:
        p = Point(r.uniform(x0, x1), r.uniform(y0, y1))
        if island.contains(p):
            seeds.append((p.x, p.y))
    cells = []
    for _ in range(40):
        vor = voronoi_diagram(MultiPoint(seeds), envelope=island.buffer(50))
        cells = []
        for s in seeds:
            cell = next(g for g in vor.geoms if g.contains(Point(s)))
            cells.append(cell.intersection(island))
        seeds = [(c.centroid.x, c.centroid.y) for c in cells]
    cells.sort(key=lambda c: (round(c.centroid.y / 18), c.centroid.x))
    s = 1 / max(x1 - x0, y1 - y0)
    out = []
    for c in cells:
        if c.geom_type != "Polygon":
            c = max(c.geoms, key=lambda g: g.area)
        c = c.simplify(.4)
        out.append([[round((x - x0) * s, 4), round((y - y0) * s, 4)] for x, y in list(c.exterior.coords)[:-1]])
    outline = [[round((x - x0) * s, 4), round((y - y0) * s, 4)] for x, y in list(island.simplify(.3).exterior.coords)[:-1]]
    return {"w": round((x1 - x0) * s, 4), "h": round((y1 - y0) * s, 4), "outline": outline, "pieces": out}


# ================================================================ main
def write_all():
    data = {"tangram": tangram_json(), "blocks": blocks_json(), "taiwan": taiwan_json()}
    for name, d in data.items():
        (ASSETS / f"{name}.json").write_text(json.dumps(d, ensure_ascii=False, separators=(",", ":")) + "\n")
    t, b, w = data["tangram"], data["blocks"], data["taiwan"]
    print(f"tangram: {len(t['figures'])} figures; blocks: {len(b['cards'])} cards "
          f"({sum(len(c['extra']) for c in b['cards'])} other ways for 大); taiwan: {len(w['pieces'])} pieces")
    return data


def preview(out):
    from PIL import Image, ImageDraw, ImageFont
    data = {"tangram": tangram_json(), "blocks": blocks_json(), "taiwan": taiwan_json()}
    font = ImageFont.truetype(str(ASSETS / "fonts" / "jf-openhuninn-2.1.ttf"), 22)
    colours = {"L": "#E2574C", "M": "#F7A440", "S": "#8BBF5A", "Q": "#F2C94C", "P": "#4FA3D9",
               "hex": "#F2C94C", "trap": "#E2574C", "rhomb": "#4FA3D9", "tri": "#8BBF5A", "square": "#F7A440", "thin": "#E8D2A6"}

    def sheet(items, name):
        cols, cell = 6, 240
        rows = (len(items) + cols - 1) // cols
        img = Image.new("RGB", (cols * cell, rows * cell), "#F5ECDD")
        d = ImageDraw.Draw(img)
        for i, (title, w, h, polys) in enumerate(items):
            ox, oy = (i % cols) * cell, (i // cols) * cell
            s = (cell - 60) / max(w, h, 1)
            for kind, pts in polys:
                d.polygon([(ox + 20 + x * s, oy + 40 + y * s) for x, y in pts], fill=colours.get(kind, "#B98B5A"), outline="#4A3426")
            d.text((ox + 10, oy + 6), title, fill="#4A3426", font=font)
        img.save(f"{out}_{name}.png")
        print(f"{out}_{name}.png")

    sheet([(f"{f['zh']} {f['level']}", f["w"], f["h"], [(s["kind"], s["points"]) for s in f["slots"]]) for f in data["tangram"]["figures"]], "tangram")
    sheet([(f"{c['zh']} +{len(c['extra'])}", c["w"], c["h"], [(s["kind"], s["points"]) for s in c["slots"]]) for c in data["blocks"]["cards"]], "blocks")
    tw = data["taiwan"]
    sheet([("台灣", tw["w"], tw["h"], [(["L", "M", "S", "Q", "P"][i % 5], p) for i, p in enumerate(tw["pieces"])])], "taiwan")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "preview":
        preview(sys.argv[2])
    else:
        write_all()
