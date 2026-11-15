"""Design-stage sketches for 「拼拼樂工坊」 (working name; puzzles for ages 2-5).

    python3 make_mockups.py          # writes docs/mockups/*.png (needs Node.js + Playwright's Chromium)
    python3 make_mockups.py 3        # only one page: 0 = style page, 1..8 = a screen, c = contact sheet

Every picture is drawn here as SVG by code: no outside pictures, no emoji. Words use the font
jf open 粉圓 2.1 from a sibling app's checkout. render.js turns each page into a PNG with Playwright's
Chromium at 390x844, device scale 2.

    0_畫風選擇.png     the same jigsaw table in three styles: A 彩繪木頭風 (recommended), B 彩色玻璃風,
                       C 摺紙風. Screens 1-8 are drawn in A.
    1_工坊.png         home: the 台灣大拼圖 that grows, four toy boxes, 甲甲 the pangolin
    2_形狀洞洞.png     an inset board of Taiwan fruit for 2-year-olds (outline shown, no rotation)
    3_拼圖.png         a 9-piece knobbed jigsaw of a Formosan black bear, a faint picture as a guide
    4_七巧板.png       tangram cat (big level): tap to turn, a flip button on the parallelogram
    5_照著拼.png       pattern blocks: copy the flower from the card
    6_動起來.png       a finished MRT picture comes alive, one more piece joins the Taiwan puzzle
    7_休息.png         time is up: 甲甲 rolls into a ball and sleeps
    8_家長模式.png     parents' settings and progress
    contact_sheet.png  screens 1-8 small, with titles

All three styles use only what flutter_svg can draw (no filter, mask, pattern, style, text, image):
  wood    flat matte paint with a soft top-to-bottom gradient, wood-grain lines (thin wavy strokes clipped
          to the piece), a light and a dark outline shifted by 2 px and clipped to the piece (a rounded,
          sanded edge), and a darker copy shifted down as the piece's thickness.
  glass   a diagonal gradient from light to the colour, a white streak clipped to the piece, and a thick
          grey "lead" outline; backgrounds are split into cells by more lead lines.
  origami a flat colour folded into facets: triangles from a fold point to the corners, clipped to the
          piece, alternately lighter and darker, with thin white creases and a crisp offset shadow.
"""
import hashlib
import math
import pathlib
import subprocess
import sys
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
FONT = None
for _c in ("app_kids_bopomofo", "app_kids_feelings", "app_kids_goodnight", "app_kids_live_circ", "app_kids_falsecharge", "app_kids_maze"):
    _p = pathlib.Path("/home/user") / _c / "app" / "assets" / "fonts" / "jf-openhuninn-2.1.ttf"
    if _p.exists():
        FONT = _p
        break
if FONT is None:
    sys.exit("font jf-openhuninn-2.1.ttf not found in a sibling app's checkout")
SCRATCH = pathlib.Path("/dev/shm") if pathlib.Path("/dev/shm").is_dir() else pathlib.Path(tempfile.gettempdir())
W, H = 390, 844

# ---------------------------------------------------------------- colours (painted wood)
INK = "#4A3426"
SOFT = "#9B806A"
WALL = "#F6EAD6"
BENCH = "#E3BC8B"
BENCH2 = "#D4A673"
SIDE = "#B9844F"
RED = "#E2604F"
ORA = "#F09A45"
YEL = "#F4C94A"
GRN = "#7DBB5B"
LEAF = "#5FA457"
TEAL = "#4BB2A6"
BLUE = "#5B9AD8"
NAVY = "#3F5D8C"
PURP = "#9D83D0"
PINK = "#EE97B0"
CREAM = "#FFF7E8"
WHITE = "#FFFDF8"
SKY = "#BFE2F5"
GRASS = "#A9D98A"
BEAR = "#3A3230"
TAN = "#DDB487"
PANG = "#C9935B"
PANG2 = "#E6BE8A"
CHEEK = "#FF9EA8"
DARK = "#2E2420"
STYLE = "wood"   # "wood" (A, recommended), "glass" (B), "origami" (C)


# ---------------------------------------------------------------- defs registry and small maths
class Defs:
    def __init__(self):
        self.d = {}

    def add(self, key, svg):
        self.d.setdefault(key, svg)
        return key

    def svg(self):
        return "<defs>" + "".join(self.d.values()) + "</defs>"


D = Defs()


def _h(*parts):
    return hashlib.md5("|".join(map(str, parts)).encode()).hexdigest()[:10]


def _rand(seed, i):
    return int(hashlib.md5(f"{seed}|{i}".encode()).hexdigest()[:6], 16) / 0xFFFFFF


def _rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mixc(a, b, t):
    ra, rb = _rgb(a), _rgb(b)
    return "#%02X%02X%02X" % tuple(round(ra[i] + (rb[i] - ra[i]) * t) for i in range(3))


def darker(c, t=.25):
    return mixc(c, "#24170E", t)


def lighter(c, t=.35):
    return mixc(c, "#FFFFFF", t)


def lg(stops, x1=0, y1=0, x2=0, y2=1):
    k = "lg" + _h(stops, x1, y1, x2, y2)
    D.add(k, f'<linearGradient id="{k}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">' + "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops) + "</linearGradient>")
    return f"url(#{k})"


def rg(stops):
    k = "rg" + _h(stops)
    D.add(k, f'<radialGradient id="{k}">' + "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops) + "</radialGradient>")
    return f"url(#{k})"


# ---------------------------------------------------------------- shapes: a path string with its bounding box
class Sh:
    def __init__(self, d, b):
        self.d, self.b = d, b

    def __add__(self, o):
        return Sh(self.d + " " + o.d, (min(self.b[0], o.b[0]), min(self.b[1], o.b[1]), max(self.b[2], o.b[2]), max(self.b[3], o.b[3])))


def rr(x, y, w, h, r=6):
    r = min(r, w / 2, h / 2)
    d = (f"M{x + r:.1f},{y:.1f} h{w - 2 * r:.1f} a{r},{r} 0 0 1 {r},{r} v{h - 2 * r:.1f} a{r},{r} 0 0 1 {-r},{r} "
         f"h{-(w - 2 * r):.1f} a{r},{r} 0 0 1 {-r},{-r} v{-(h - 2 * r):.1f} a{r},{r} 0 0 1 {r},{-r}Z")
    return Sh(d, (x, y, x + w, y + h))


def circ(cx, cy, r):
    return Sh(f"M{cx - r:.1f},{cy:.1f} a{r},{r} 0 1 0 {2 * r},0 a{r},{r} 0 1 0 {-2 * r},0Z", (cx - r, cy - r, cx + r, cy + r))


def ell(cx, cy, rx, ry):
    return Sh(f"M{cx - rx:.1f},{cy:.1f} a{rx},{ry} 0 1 0 {2 * rx},0 a{rx},{ry} 0 1 0 {-2 * rx},0Z", (cx - rx, cy - ry, cx + rx, cy + ry))


def poly(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return Sh("M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + "Z", (min(xs), min(ys), max(xs), max(ys)))


def smooth(pts, closed=True):
    n = len(pts)
    out = [f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"]
    for i in (range(n) if closed else range(n - 1)):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        if not closed:
            p0, p3 = pts[max(i - 1, 0)], pts[min(i + 2, n - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        out.append(f"C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}")
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return Sh(" ".join(out) + ("Z" if closed else ""), (min(xs), min(ys), max(xs), max(ys)))


def star(cx, cy, R, r=None, n=5):
    r = r or R * .5
    pts = []
    for i in range(2 * n):
        a = math.radians(-90 + i * 180 / n)
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad * math.cos(a), cy + rad * math.sin(a)))
    return poly(pts)


def heart(cx, cy, s):
    d = (f"M{cx},{cy + s} C{cx - s * 1.6},{cy - s * .2} {cx - s * .9},{cy - s * 1.2} {cx},{cy - s * .4} "
         f"C{cx + s * .9},{cy - s * 1.2} {cx + s * 1.6},{cy - s * .2} {cx},{cy + s}Z")
    return Sh(d, (cx - s * 1.3, cy - s * 1.1, cx + s * 1.3, cy + s))


def _clip(sh):
    k = "cp" + _h(sh.d)
    D.add(k, f'<clipPath id="{k}"><path d="{sh.d}"/></clipPath>')
    return k


def stroke(d, col, w, op=1.0, dash=None, cap="round"):
    da = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="{cap}" stroke-linejoin="round" opacity="{op}"{da}/>'


def place(x, y, s, fn, *a, rot=0.0, **kw):
    t = f"translate({x:.1f} {y:.1f})" + (f" rotate({rot})" if rot else "") + (f" scale({s})" if s != 1 else "")
    return f'<g transform="{t}">{fn(*a, **kw)}</g>'


# ---------------------------------------------------------------- the three ways to draw a piece
def grain(sh, col, seed="g", n=None, op=.32):
    x0, y0, x1, y1 = sh.b
    w, h = x1 - x0, y1 - y0
    n = n or max(2, int(h / 9))
    o = []
    for i in range(n):
        y = y0 + (i + .5) * h / n + (_rand(seed, i) - .5) * 4
        a = 1.2 + _rand(seed, i + 50) * 2.2
        pts = " ".join(f"L{x0 + w * t / 8:.1f},{y + a * math.sin(t * 1.3 + i):.1f}" for t in range(1, 9))
        o.append(f'<path d="M{x0:.1f},{y:.1f} {pts}" fill="none" stroke="{darker(col, .22)}" stroke-width=".8" opacity="{op}"/>')
    return "".join(o)


def facets(sh, seed="f", strength=1.0):
    x0, y0, x1, y1 = sh.b
    w, h = x1 - x0, y1 - y0
    cx, cy = x0 + w * (.38 + _rand(seed, 1) * .24), y0 + h * (.35 + _rand(seed, 2) * .3)
    ring = [(x0, y0), (x0 + w * .5, y0 - 1), (x1, y0), (x1 + 1, y0 + h * .5), (x1, y1), (x0 + w * .5, y1 + 1), (x0, y1), (x0 - 1, y0 + h * .5)]
    o = []
    for i in range(8):
        a, b = ring[i], ring[(i + 1) % 8]
        fill = "#FFFFFF" if i % 2 == 0 else "#000000"
        op = (.18 if i < 4 else .07) if i % 2 == 0 else (.05 if i < 4 else .13)
        o.append(f'<path d="M{cx:.1f},{cy:.1f} L{a[0]:.1f},{a[1]:.1f} L{b[0]:.1f},{b[1]:.1f}Z" fill="{fill}" opacity="{op * strength:.3f}"/>')
    for i in (0, 2, 5):
        a = ring[i]
        o.append(f'<path d="M{cx:.1f},{cy:.1f} L{a[0]:.1f},{a[1]:.1f}" stroke="#FFFFFF" stroke-width=".7" opacity="{.45 * strength:.2f}"/>')
    return "".join(o)


def piece(sh, col, thick=4, shade=1, seed=None, extra=""):
    """A physical piece you can pick up (a toy piece, a button, the board)."""
    seed = seed or _h(sh.d)
    k = _clip(sh)
    o = []
    if STYLE == "wood":
        if shade:
            o.append(f'<path d="{sh.d}" fill="#3B2412" opacity=".16" transform="translate(2 {thick + 3})"{extra}/>')
        if thick:
            o.append(f'<path d="{sh.d}" fill="{darker(col, .28)}" transform="translate(0 {thick})"{extra}/>')
        o.append(f'<path d="{sh.d}" fill="{lg([(0, lighter(col, .1)), (1, darker(col, .06))])}"{extra}/>')
        o.append(f'<g clip-path="url(#{k})"{extra}>{grain(sh, col, seed)}'
                 f'<path d="{sh.d}" fill="none" stroke="#FFFFFF" stroke-width="4" opacity=".35" transform="translate(2 2)"/>'
                 f'<path d="{sh.d}" fill="none" stroke="#3B2412" stroke-width="4" opacity=".16" transform="translate(-2 -2)"/></g>')
        o.append(f'<path d="{sh.d}" fill="none" stroke="{darker(col, .45)}" stroke-width="1" opacity=".55"{extra}/>')
    elif STYLE == "glass":
        x0, y0, x1, y1 = sh.b
        if shade:
            o.append(f'<path d="{sh.d}" fill="#1D2233" opacity=".14" transform="translate(1.5 {2 + shade * 1.5})"{extra}/>')
        o.append(f'<path d="{sh.d}" fill="{lg([(0, lighter(col, .5)), (.55, lighter(col, .1)), (1, col)], 0, 0, 1, 1)}"{extra}/>')
        w, h = x1 - x0, y1 - y0
        o.append(f'<g clip-path="url(#{k})"{extra}><path d="M{x0 + w * .15:.1f},{y1:.1f} L{x0 + w * .45:.1f},{y0:.1f} L{x0 + w * .6:.1f},{y0:.1f} L{x0 + w * .3:.1f},{y1:.1f}Z" fill="#FFFFFF" opacity=".32"/>'
                 f'<circle cx="{x0 + w * .78:.1f}" cy="{y0 + h * .3:.1f}" r="{min(w, h) * .05:.1f}" fill="#FFFFFF" opacity=".5"/></g>')
        o.append(f'<path d="{sh.d}" fill="none" stroke="#3E4352" stroke-width="3.2" stroke-linejoin="round"{extra}/>'
                 f'<path d="{sh.d}" fill="none" stroke="#9AA0B2" stroke-width=".8" stroke-linejoin="round" opacity=".7"{extra}/>')
    else:  # origami
        if shade:
            o.append(f'<path d="{sh.d}" fill="#2B2030" opacity=".16" transform="translate(2.5 {2.5 + shade})"{extra}/>')
        o.append(f'<path d="{sh.d}" fill="{col}"{extra}/>')
        o.append(f'<g clip-path="url(#{k})"{extra}>{facets(sh, seed)}</g>')
    return "".join(o)


def paint(sh, col, seed=None, extra=""):
    """Something painted on a piece (part of a puzzle picture): no thickness, no shadow."""
    seed = seed or _h(sh.d)
    k = _clip(sh)
    if STYLE == "wood":
        return (f'<path d="{sh.d}" fill="{lg([(0, lighter(col, .08)), (1, darker(col, .05))])}"{extra}/>'
                f'<path d="{sh.d}" fill="none" stroke="{darker(col, .4)}" stroke-width="1.3" opacity=".7" stroke-linejoin="round"{extra}/>')
    if STYLE == "glass":
        x0, y0, x1, y1 = sh.b
        w = x1 - x0
        return (f'<path d="{sh.d}" fill="{lg([(0, lighter(col, .45)), (1, col)], 0, 0, 1, 1)}"{extra}/>'
                f'<g clip-path="url(#{k})"{extra}><path d="M{x0 + w * .2:.1f},{y1:.1f} L{x0 + w * .5:.1f},{y0:.1f} L{x0 + w * .58:.1f},{y0:.1f} L{x0 + w * .28:.1f},{y1:.1f}Z" fill="#FFFFFF" opacity=".25"/></g>'
                f'<path d="{sh.d}" fill="none" stroke="#3E4352" stroke-width="2.4" stroke-linejoin="round"{extra}/>')
    return f'<path d="{sh.d}" fill="{col}"{extra}/><g clip-path="url(#{k})"{extra}>{facets(sh, seed, .8)}</g>'


def flat(sh, col, op=1.0):
    return f'<path d="{sh.d}" fill="{col}" opacity="{op}"/>'


def recess(sh, col=BENCH2):
    """A hole cut into the board: where a piece goes."""
    k = _clip(sh)
    if STYLE == "wood":
        return (f'<path d="{sh.d}" fill="{darker(col, .2)}"/>'
                f'<g clip-path="url(#{k})"><path d="{sh.d}" fill="none" stroke="#3B2412" stroke-width="7" opacity=".28" transform="translate(2.5 3)"/>{grain(sh, darker(col, .2), "r" + _h(sh.d), op=.25)}</g>')
    if STYLE == "glass":
        return f'<path d="{sh.d}" fill="#E9EEF5"/>' + stroke(sh.d, "#9AA0B2", 2, 1, "5 4")
    return f'<path d="{sh.d}" fill="{darker(col, .18)}"/><g clip-path="url(#{k})"><path d="{sh.d}" fill="none" stroke="#000" stroke-width="5" opacity=".1" transform="translate(2 2)"/></g>'


# ---------------------------------------------------------------- words
def tx(x, y, s, size=16, color=INK, anchor="middle", extra=""):
    return f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" fill="{color}" text-anchor="{anchor}" font-family="Huninn, sans-serif" {extra}>{s}</text>'


def txo(x, y, s, size, color, ol="#FFFFFF", ow=6, anchor="middle"):
    return tx(x, y, s, size, color, anchor, f'stroke="{ol}" stroke-width="{ow}" stroke-linejoin="round" paint-order="stroke"')


# ---------------------------------------------------------------- faces and characters
def eye(cx, cy, r, col=DARK):
    return (f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{col}"/>'
            f'<circle cx="{cx - r * .3:.1f}" cy="{cy - r * .35:.1f}" r="{r * .38:.1f}" fill="#FFFFFF"/>')


def happy_eye(cx, cy, r, col=DARK):
    return stroke(f"M{cx - r:.1f},{cy + r * .3:.1f} q{r},{-r * 1.3:.1f} {2 * r:.1f},0", col, max(1.6, r * .5))


def shut_eye(cx, cy, r, col=DARK):
    return stroke(f"M{cx - r:.1f},{cy - r * .2:.1f} q{r},{r * 1.1:.1f} {2 * r:.1f},0", col, max(1.6, r * .45))


def cheek(cx, cy, r):
    return f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{r:.1f}" ry="{r * .65:.1f}" fill="{CHEEK}" opacity=".7"/>'


def smile(cx, cy, w, col=DARK, open_=False):
    if open_:
        return f'<path d="M{cx - w:.1f},{cy:.1f} q{w},{w * 1.4:.1f} {2 * w:.1f},0Z" fill="#B5433F"/>' + stroke(f"M{cx - w:.1f},{cy:.1f} h{2 * w:.1f}", col, 1.4)
    return stroke(f"M{cx - w:.1f},{cy:.1f} q{w},{w * .9:.1f} {2 * w:.1f},0", col, 1.8)


def pangolin(mood="smile", wave=False):
    """甲甲 the Formosan pangolin, about 130 x 100, facing right. Its scales are little puzzle pieces."""
    o = []
    o.append(piece(smooth([(30, 64), (6, 74), (-6, 90), (6, 92), (26, 84), (40, 78)]), PANG, 3))  # tail
    body = ell(58, 60, 40, 30)
    o.append(piece(body, PANG2, 4))
    k = _clip(body)
    sc = []
    for r_, (yy, n) in enumerate(((36, 5), (48, 6), (60, 6))):
        for i in range(n):
            x = 24 + i * 13 + (6 if r_ % 2 else 0)
            sc.append(paint(Sh(f"M{x - 8:.1f},{yy:.1f} q8,-10 16,0 q-2,10 -8,12 q-6,-2 -8,-12Z", (x - 8, yy - 6, x + 8, yy + 12)),
                            [PANG, darker(PANG, .08), lighter(PANG, .1)][(i + r_) % 3]))
    o.append(f'<g clip-path="url(#{k})">{"".join(sc)}</g>')
    o.append(paint(ell(62, 78, 30, 10), PANG2))
    for fx in (36, 74):
        o.append(piece(ell(fx, 88, 9, 6), darker(PANG, .15), 2))
    head = smooth([(84, 48), (100, 40), (118, 48), (128, 58), (118, 66), (100, 70), (86, 64)])
    o.append(piece(head, PANG2, 3))
    o.append(f'<circle cx="127" cy="58" r="3.4" fill="{DARK}"/>')
    if mood == "sleep":
        o.append(shut_eye(103, 52, 4.4))
    elif mood == "happy":
        o.append(happy_eye(103, 53, 4.4))
    else:
        o.append(eye(104, 52, 4.6))
    o.append(cheek(110, 62, 4.6))
    o.append(paint(ell(92, 44, 5, 4), darker(PANG2, .15)))
    if wave:
        o.append(piece(smooth([(72, 56), (74, 38), (78, 22), (88, 20), (90, 36), (84, 58)]), darker(PANG, .1), 3))
    return "".join(o)


def pangolin_ball():
    """甲甲 rolled up into a ball, asleep (about 100 x 90)."""
    o = [piece(circ(50, 50, 40), PANG2, 4)]
    k = _clip(circ(50, 50, 40))
    sc = []
    for r_ in range(6):
        for i in range(7):
            x = 12 + i * 13 + (6 if r_ % 2 else 0)
            yy = 14 + r_ * 12
            sc.append(paint(Sh(f"M{x - 8:.1f},{yy:.1f} q8,-10 16,0 q-2,10 -8,12 q-6,-2 -8,-12Z", (x - 8, yy - 6, x + 8, yy + 12)),
                            [PANG, darker(PANG, .08), lighter(PANG, .1)][(i + r_) % 3]))
    o.append(f'<g clip-path="url(#{k})">{"".join(sc)}</g>')
    o.append(piece(smooth([(36, 66), (52, 58), (70, 62), (74, 74), (58, 82), (40, 80)]), PANG2, 2))
    o.append(shut_eye(52, 69, 4) + shut_eye(64, 69, 4) + cheek(46, 75, 4) + cheek(70, 75, 4))
    o.append(piece(smooth([(14, 72), (6, 56), (14, 40), (20, 52), (22, 70)]), PANG, 2))
    return "".join(o)


def bear(mood="smile"):
    """A Formosan black bear holding a mango, about 100 x 112."""
    o = []
    for ex in (28, 72):
        o.append(paint(circ(ex, 18, 11), BEAR) + paint(circ(ex, 18, 5.5), "#6B5B55"))
    o.append(paint(ell(50, 80, 36, 30), BEAR))
    o.append(paint(Sh("M30,62 Q50,82 70,62 Q66,58 64,58 Q50,72 36,58 Q32,58 30,62Z", (30, 58, 70, 76)), CREAM))
    o.append(paint(circ(50, 38, 26), BEAR))
    o.append(paint(ell(50, 48, 12, 9), TAN))
    o.append(f'<ellipse cx="50" cy="43.5" rx="5" ry="3.4" fill="{DARK}"/>')
    o.append(smile(50, 50, 4, "#2A1E1A"))
    if mood == "happy":
        o.append(happy_eye(39, 34, 4, "#FFFFFF") + happy_eye(61, 34, 4, "#FFFFFF"))
    else:
        o.append(f'<circle cx="40" cy="33" r="4.6" fill="#FFFFFF"/><circle cx="60" cy="33" r="4.6" fill="#FFFFFF"/>'
                 f'<circle cx="40.6" cy="33.8" r="2.8" fill="{DARK}"/><circle cx="60.6" cy="33.8" r="2.8" fill="{DARK}"/>')
    o.append(cheek(31, 45, 4.5) + cheek(69, 45, 4.5))
    o.append(paint(smooth([(36, 84), (46, 76), (60, 76), (66, 86), (58, 96), (42, 96)]), ORA))
    o.append(paint(ell(50, 80, 5, 3), LEAF))
    for ax in (32, 68):
        o.append(paint(ell(ax, 88, 9, 8), BEAR))
    for fx in (32, 68):
        o.append(paint(ell(fx, 106, 13, 7), BEAR) + paint(ell(fx, 106, 6, 3.5), TAN))
    return "".join(o)


def cloud(x, y, s=1.0):
    return place(x, y, s, lambda: paint(circ(0, 10, 12) + circ(16, 2, 16) + circ(34, 10, 12) + rr(-10, 8, 54, 14, 7), WHITE))


def sun(x, y, r=20, mood="happy"):
    o = []
    for i in range(8):
        a = math.radians(i * 45 + 22)
        o.append(paint(poly([(x + (r + 4) * math.cos(a - .18), y + (r + 4) * math.sin(a - .18)), (x + (r + 13) * math.cos(a), y + (r + 13) * math.sin(a)),
                             (x + (r + 4) * math.cos(a + .18), y + (r + 4) * math.sin(a + .18))]), ORA))
    o.append(paint(circ(x, y, r), YEL))
    o.append(happy_eye(x - r * .33, y - 2, r * .14) + happy_eye(x + r * .33, y - 2, r * .14) + smile(x, y + r * .25, r * .2) + cheek(x - r * .55, y + r * .2, r * .15) + cheek(x + r * .55, y + r * .2, r * .15))
    return "".join(o)


def lead_lines(x, y, w, h, seed, n=4):
    """Stained glass only: the background split into cells by lead lines."""
    if STYLE != "glass":
        return ""
    o = []
    for i in range(n):
        if i % 2 == 0:
            ya, yb = y + h * _rand(seed, i), y + h * _rand(seed, i + 9)
            o.append(stroke(f"M{x:.1f},{ya:.1f} L{x + w:.1f},{yb:.1f}", "#3E4352", 2.2, .8))
        else:
            xa, xb = x + w * _rand(seed, i), x + w * _rand(seed, i + 9)
            o.append(stroke(f"M{xa:.1f},{y:.1f} L{xb:.1f},{y + h:.1f}", "#3E4352", 2.2, .8))
    return "".join(o)


def bear_picture(x, y, w, h):
    """The puzzle picture: a black bear with a mango on a hill, the sun and a cloud."""
    k = _clip(rr(x, y, w, h, 0))
    o = [f'<g clip-path="url(#{k})"><rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{lg([(0, lighter(SKY, .3)), (1, SKY)])}"/>']
    o.append(lead_lines(x, y, w, h * .6, "bp", 3))
    if STYLE == "origami":
        o.append(facets(rr(x, y, w, h * .7, 0), "sky", .6))
    o.append(sun(x + w * .8, y + h * .2, w * .08))
    o.append(cloud(x + w * .12, y + h * .12, w / 330))
    o.append(paint(ell(x + w * .2, y + h * 1.0, w * .55, h * .42), GRASS, "h1"))
    o.append(paint(ell(x + w * .95, y + h * 1.02, w * .5, h * .38), darker(GRASS, .1), "h2"))
    for i, fx in enumerate((.1, .22, .78, .9)):
        cx, cy = x + w * fx, y + h * (.86 + .05 * (i % 2))
        o.append(paint(circ(cx, cy, w * .022), [PINK, YEL, "#FFFFFF", PINK][i]) + f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{w * .008:.1f}" fill="{ORA}"/>')
    o.append(place(x + w * .5 - 55 * w / 330 * 1.2, y + h * .3, w / 330 * 1.2, bear))
    o.append("</g>")
    return "".join(o)


# ---------------------------------------------------------------- jigsaw pieces
KNOB = [(.36, 0), (.40, 0), (.43, .05), (.39, .11), (.34, .20), (.42, .26), (.50, .26), (.58, .26), (.66, .20), (.61, .11), (.57, .05), (.60, 0), (.64, 0)]


def _edge(p0, p1, s, size):
    L = math.dist(p0, p1)
    dx, dy = (p1[0] - p0[0]) / L, (p1[1] - p0[1]) / L
    nx, ny = dy, -dx

    def at(u, v):
        return (p0[0] + dx * u * L + nx * v * size * s, p0[1] + dy * u * L + ny * v * size * s)
    if s == 0:
        return f" L{p1[0]:.1f},{p1[1]:.1f}"
    p = [at(u, v) for u, v in KNOB]
    out = f" L{p[0][0]:.1f},{p[0][1]:.1f}"
    for i in range(1, 13, 3):
        out += f" C{p[i][0]:.1f},{p[i][1]:.1f} {p[i + 1][0]:.1f},{p[i + 1][1]:.1f} {p[i + 2][0]:.1f},{p[i + 2][1]:.1f}"
    return out + f" L{p1[0]:.1f},{p1[1]:.1f}"


def jig_tabs(rows, cols, seed):
    th = [[1 if _rand(seed + "h", r * 10 + c) > .5 else -1 for c in range(cols)] for r in range(rows - 1)]
    tv = [[1 if _rand(seed + "v", r * 10 + c) > .5 else -1 for c in range(cols - 1)] for r in range(rows)]
    return th, tv


def jig_path(x0, y0, cw, ch, r, c, rows, cols, tabs, knobs=True):
    th, tv = tabs
    tl, tr = (x0 + c * cw, y0 + r * ch), (x0 + (c + 1) * cw, y0 + r * ch)
    br, bl = (x0 + (c + 1) * cw, y0 + (r + 1) * ch), (x0 + c * cw, y0 + (r + 1) * ch)
    k = 1 if knobs else 0
    s_top = 0 if r == 0 else -th[r - 1][c] * k
    s_right = 0 if c == cols - 1 else tv[r][c] * k
    s_bot = 0 if r == rows - 1 else th[r][c] * k
    s_left = 0 if c == 0 else -tv[r][c - 1] * k
    size = min(cw, ch)
    d = f"M{tl[0]:.1f},{tl[1]:.1f}" + _edge(tl, tr, s_top, size) + _edge(tr, br, s_right, size) + _edge(br, bl, s_bot, size) + _edge(bl, tl, s_left, size) + "Z"
    pad = size * .28
    return Sh(d, (tl[0] - pad, tl[1] - pad, br[0] + pad, br[1] + pad))


def jig_piece(sh, picture, dx=0.0, dy=0.0, lifted=False, placed=False, s=1.0):
    """One jigsaw piece cut from `picture` (an SVG string drawn in board coordinates), drawn moved by dx,dy."""
    k = _clip(sh)
    x0, y0, x1, y1 = sh.b
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    tf = f"translate({dx:.1f} {dy:.1f})" + (f" translate({cx:.1f} {cy:.1f}) scale({s}) translate({-cx:.1f} {-cy:.1f})" if s != 1 else "")
    o = [f'<g transform="{tf}">']
    if placed:
        o.append(f'<g clip-path="url(#{k})">{picture}</g>')
        o.append(stroke(sh.d, "#3B2412" if STYLE != "glass" else "#3E4352", 1.1 if STYLE != "glass" else 2.4, .35 if STYLE != "glass" else .9))
        o.append("</g>")
        return "".join(o)
    th = 6 if lifted else 3.5
    if STYLE == "wood":
        o.append(f'<path d="{sh.d}" fill="#3B2412" opacity="{.22 if lifted else .16}" transform="translate({4 if lifted else 2} {th + (9 if lifted else 3)})"/>')
        o.append(f'<path d="{sh.d}" fill="{SIDE}" transform="translate(0 {th})"/>')
        o.append(f'<g clip-path="url(#{k})">{picture}<path d="{sh.d}" fill="none" stroke="#FFFFFF" stroke-width="4" opacity=".4" transform="translate(1.8 1.8)"/>'
                 f'<path d="{sh.d}" fill="none" stroke="#3B2412" stroke-width="4" opacity=".18" transform="translate(-1.8 -1.8)"/></g>')
        o.append(stroke(sh.d, "#5A3A20", 1, .5))
    elif STYLE == "glass":
        o.append(f'<path d="{sh.d}" fill="#1D2233" opacity=".16" transform="translate(3 {8 if lifted else 3})"/>')
        o.append(f'<g clip-path="url(#{k})">{picture}</g>')
        o.append(stroke(sh.d, "#3E4352", 3.4, 1) + stroke(sh.d, "#B5BACB", .8, .8))
    else:
        o.append(f'<path d="{sh.d}" fill="#2B2030" opacity=".18" transform="translate(3 {8 if lifted else 3})"/>')
        o.append(f'<g clip-path="url(#{k})">{picture}{facets(sh, _h(sh.d), .5)}</g>')
        o.append(stroke(sh.d, "#FFFFFF", 1.2, .8))
    o.append("</g>")
    return "".join(o)


def glow(sh, col=YEL):
    return stroke(sh.d, col, 9, .45) + stroke(sh.d, "#FFFFFF", 3, .9)


def sparkle(cx, cy, r, c=YEL, op=1.0):
    d = f"M{cx},{cy - r} Q{cx + r * .18},{cy - r * .18} {cx + r},{cy} Q{cx + r * .18},{cy + r * .18} {cx},{cy + r} Q{cx - r * .18},{cy + r * .18} {cx - r},{cy} Q{cx - r * .18},{cy - r * .18} {cx},{cy - r}Z"
    return f'<path d="{d}" fill="{c}" opacity="{op}"/>'


def finger(x, y, rot=-18.0, s=1.0):
    """A child's fingertip touching (x, y)."""
    return (f'<g transform="translate({x:.1f} {y:.1f}) rotate({rot}) scale({s})">'
            f'<circle cx="0" cy="0" r="17" fill="#FFFFFF" opacity=".35"/>'
            f'<path d="M-11,2 C-11,-10 11,-10 11,2 L13,70 L-13,70Z" fill="#F6C9A8" stroke="#C98E6B" stroke-width="1.6"/>'
            f'<path d="M-6,-1 C-6,-7 6,-7 6,-1 L6,6 L-6,6Z" fill="#FBE4D6" stroke="#D9A887" stroke-width="1"/></g>')


# ---------------------------------------------------------------- tangram
R2 = math.sqrt(2)
TAN_PIECES = {   # the classic set in a 4 x 4 square
    "big1": [(0, 0), (4, 0), (2, 2)], "big2": [(0, 0), (2, 2), (0, 4)], "mid": [(4, 2), (4, 4), (2, 4)],
    "sm1": [(4, 0), (4, 2), (3, 1)], "sm2": [(2, 2), (3, 3), (1, 3)], "sq": [(2, 2), (3, 1), (4, 2), (3, 3)],
    "par": [(0, 4), (1, 3), (3, 3), (2, 4)]}
TAN_COL = {"big1": RED, "big2": BLUE, "mid": YEL, "sm1": PURP, "sm2": TEAL, "sq": GRN, "par": ORA}
CAT = {  # a sitting cat built from all seven pieces (units; right angles checked by hand)
    "sq": [(2, 0), (3, 1), (2, 2), (1, 1)], "sm1": [(1, 1), (2, 0), (1, -1)], "sm2": [(3, 1), (2, 0), (3, -1)],
    "big1": [(2, 2), (0, 4), (2, 6)], "big2": [(2, 2), (4, 4), (2, 6)], "mid": [(2, 6), (4, 4), (4, 6)],
    "par": [(4, 6), (6, 6), (7, 5), (5, 5)]}


def tpoly(pts, ox, oy, u):
    return poly([(ox + px * u, oy + py * u) for px, py in pts])


def tan_shape(name, cx, cy, u, rot=0.0):
    """A tangram piece centred at (cx, cy), turned by rot degrees."""
    pts = TAN_PIECES[name]
    mx, my = sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
    a = math.radians(rot)
    out = []
    for px, py in pts:
        x, y = (px - mx) * u, (py - my) * u
        out.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return poly(out)


def rotate_badge(cx, cy, r=13):
    return (f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r}" fill="#FFFFFF" stroke="{darker(BENCH, .35)}" stroke-width="1.5"/>'
            + stroke(f"M{cx - r * .5:.1f},{cy + r * .2:.1f} A{r * .5:.1f},{r * .5:.1f} 0 1 1 {cx + r * .1:.1f},{cy + r * .5:.1f}", NAVY, 2.2)
            + f'<path d="M{cx - r * .78:.1f},{cy - r * .02:.1f} l{r * .3:.1f},{r * .42:.1f} l{r * .26:.1f},{-r * .38:.1f}Z" fill="{NAVY}"/>')


def flip_icon(cx, cy, s=1.0, col=NAVY):
    return (f'<path d="M{cx - 2 * s:.1f},{cy - 9 * s:.1f} L{cx - 2 * s:.1f},{cy + 9 * s:.1f} L{cx - 12 * s:.1f},{cy + 9 * s:.1f}Z" fill="{col}"/>'
            f'<path d="M{cx + 2 * s:.1f},{cy - 9 * s:.1f} L{cx + 2 * s:.1f},{cy + 9 * s:.1f} L{cx + 12 * s:.1f},{cy + 9 * s:.1f}Z" fill="none" stroke="{col}" stroke-width="1.6" stroke-dasharray="3 2"/>')


# ---------------------------------------------------------------- UI pieces
def board_bg(dim=False):
    o = [f'<rect width="{W}" height="{H}" fill="{lg([(0, lighter(WALL, .3)), (1, WALL)])}"/>']
    for i in range(7):     # pegboard dots on the workshop wall
        for j in range(4):
            o.append(f'<circle cx="{28 + i * 56}" cy="{20 + j * 22}" r="2" fill="{darker(WALL, .12)}"/>')
    return "".join(o)


def bench(y, h=None, col=BENCH):
    h = h or H - y
    return piece(rr(-6, y, W + 12, h + 10, 0), col, 0, 0, seed="bench" + str(y))


def wbtn(cx, cy, r, col, icon=""):
    return piece(circ(cx, cy, r), col, 4) + icon


def home_icon(cx, cy, s=1.0, col="#FFFFFF"):
    return (f'<path d="M{cx - 9 * s:.1f},{cy - 1 * s:.1f} L{cx:.1f},{cy - 9 * s:.1f} L{cx + 9 * s:.1f},{cy - 1 * s:.1f} L{cx + 6.5 * s:.1f},{cy - 1 * s:.1f} L{cx + 6.5 * s:.1f},{cy + 8 * s:.1f} '
            f'L{cx - 6.5 * s:.1f},{cy + 8 * s:.1f} L{cx - 6.5 * s:.1f},{cy - 1 * s:.1f}Z" fill="{col}"/>')


def paw_icon(cx, cy, s=1.0, col="#FFFFFF"):
    o = f'<ellipse cx="{cx:.1f}" cy="{cy + 3 * s:.1f}" rx="{6.5 * s:.1f}" ry="{5.5 * s:.1f}" fill="{col}"/>'
    for dx, dy in ((-7, -4), (-2.5, -8.5), (2.5, -8.5), (7, -4)):
        o += f'<circle cx="{cx + dx * s:.1f}" cy="{cy + dy * s:.1f}" r="{2.6 * s:.1f}" fill="{col}"/>'
    return o


def topbar(title, chip=None):
    o = [wbtn(36, 40, 22, TEAL, home_icon(36, 40))]
    o.append(piece(rr(80, 20, 230, 42, 14), CREAM, 4))
    o.append(tx(195, 48, title, 20, INK))
    o.append(wbtn(354, 40, 22, ORA, paw_icon(354, 41)))
    if chip:
        o.append(chip)
    return "".join(o)


def bubble(x, y, w, h, text, size=16, tail=None):
    o = [f'<rect x="{x}" y="{y + 3}" width="{w}" height="{h}" rx="16" fill="#3B2412" opacity=".1"/>',
         f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="16" fill="{WHITE}" stroke="{darker(WALL, .25)}" stroke-width="1.5"/>']
    if tail:
        tx_, ty_ = tail
        bx = min(max(tx_, x + 18), x + w - 18)
        by = y + h if ty_ > y + h else y
        o.append(f'<path d="M{bx - 9},{by} L{tx_},{ty_} L{bx + 9},{by}Z" fill="{WHITE}" stroke="{darker(WALL, .25)}" stroke-width="1.5"/>'
                 f'<rect x="{bx - 10}" y="{by - 2 if by > y else by + .5}" width="20" height="2.5" fill="{WHITE}"/>')
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        o.append(tx(x + w / 2, y + h / 2 + size * .36 + (i - (len(lines) - 1) / 2) * size * 1.35, ln, size, INK))
    return "".join(o)


def lock_chip(x=14, y=14):
    return (f'<rect x="{x}" y="{y}" width="34" height="30" rx="10" fill="#FFFFFF" opacity=".55"/>'
            f'<rect x="{x + 10}" y="{y + 13}" width="14" height="11" rx="2.5" fill="{SOFT}"/>'
            + stroke(f"M{x + 12.5},{y + 13} v-3 a4.5,4.5 0 0 1 9,0 v3", SOFT, 2))


def taiwan_shape(x, y, s=1.0):
    pts = [(58, 0), (70, 4), (80, 14), (84, 30), (80, 50), (76, 72), (74, 96), (70, 120), (64, 144), (58, 164), (52, 182), (46, 198),
           (40, 190), (34, 172), (24, 150), (14, 128), (10, 104), (12, 80), (20, 58), (32, 36), (44, 16)]
    return smooth([(x + px * s, y + py * s) for px, py in pts])


def taiwan_puzzle(x, y, s=1.0, filled=11):
    """The big Taiwan puzzle: the island cut into 4 x 7 knobbed pieces; finished pictures fill them in."""
    tw = taiwan_shape(x, y, s)
    k = _clip(tw)
    rows, cols = 7, 4
    cw, ch = 80 * s / cols, 202 * s / rows
    tabs = jig_tabs(rows, cols, "tw")
    order = [(r, c) for r in range(rows) for c in range(cols) if (c in (1, 2) or 1 <= r <= 4) and not (r == 6 and c != 1)]
    order.sort(key=lambda rc: _rand("twf", rc[0] * 7 + rc[1]))
    filled_set = set(order[:filled])
    cols_ = [RED, ORA, YEL, GRN, TEAL, BLUE, PURP, PINK]
    o = [f'<path d="{tw.d}" fill="#3B2412" opacity=".14" transform="translate(2 5)"/>', recess(tw, BENCH)]
    inner = []
    for r in range(rows):
        for c in range(cols):
            sh = jig_path(x + 8 * s, y - 1 * s, cw, ch, r, c, rows, cols, tabs)
            if (r, c) in filled_set:
                col = cols_[(r * 3 + c) % len(cols_)]
                inner.append(paint(sh, lighter(col, .1), seed=f"tw{r}{c}"))
            else:
                inner.append(stroke(sh.d, "#FFFFFF", 1, .35, "3 3"))
    o.append(f'<g clip-path="url(#{k})">{"".join(inner)}</g>')
    o.append(stroke(tw.d, darker(BENCH, .45), 1.6, .7))
    return "".join(o)


def page(body, bg=None, w=W, h=H):
    css = (f"@font-face {{ font-family: Huninn; src: url('file://{FONT}'); }}"
           f"* {{ margin: 0; padding: 0; }} body {{ width: {w}px; height: {h}px; overflow: hidden; background: {bg or WALL}; }}")
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{D.svg()}{body}</svg>'
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{svg}</body></html>'


def render(html, out, w, h, scale):
    with tempfile.TemporaryDirectory(dir=SCRATCH) as tmp:
        p = pathlib.Path(tmp) / "page.html"
        p.write_text(html)
        subprocess.run(["node", str(HERE / "render.js"), str(p), str(out), str(w), str(h), str(scale)], check=True)
    if pathlib.Path(out).stat().st_size > 400_000:
        from PIL import Image
        im = Image.open(out).convert("RGB")
        im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, kmeans=2, dither=Image.Dither.FLOYDSTEINBERG).save(out, optimize=True)


# ================================================================ SCREEN 1: the workshop (home)
def toybox(x, y, w, h, col, label, icon):
    o = [piece(rr(x, y, w, h, 18), col, 6)]
    o.append(piece(rr(x + 12, y + 12, w - 24, h - 58, 14), CREAM, 2, 0))
    o.append(icon)
    o.append(txo(x + w / 2, y + h - 18, label, 21, "#FFFFFF", darker(col, .45), 5))
    return "".join(o)


def screen_home():
    o = [board_bg(), lock_chip(14, 16)]
    o.append(piece(rr(70, 16, 250, 50, 16), YEL, 5))
    for nx in (84, 306):
        o.append(f'<circle cx="{nx}" cy="41" r="3.5" fill="{darker(YEL, .5)}"/>')
    o.append(txo(195, 50, "拼拼樂工坊", 26, INK, lighter(YEL, .6), 4))
    # the Taiwan puzzle
    o.append(piece(rr(16, 84, 358, 250, 22), BENCH, 5))
    o.append(taiwan_puzzle(40, 100, 1.08, 11))
    o.append(tx(260, 140, "台灣大拼圖", 22, INK))
    o.append(tx(260, 168, "拼好一張圖，", 14.5, SOFT) + tx(260, 188, "這裡就多一塊", 14.5, SOFT))
    for i in range(3):
        sh = jig_path(196 + i * 42, 212, 34, 34, 0, 1, 1, 3, ([], [[1, -1]]))
        o.append(paint(Sh(sh.d, sh.b), [RED, TEAL, YEL][i]))
    o.append(tx(260, 286, "11 / 48", 20, darker(GRN, .3)))
    o.append(tx(260, 312, "點一塊，看它動起來", 12.5, SOFT))
    # four toy boxes
    o.append(bench(356, 330))
    bw, bh = 168, 150
    # shape box icon
    ic1 = (piece(circ(98, 432, 18), RED, 3) + piece(rr(122, 414, 34, 34, 4), BLUE, 3) + piece(poly([(52, 450), (70, 414), (88, 450)]), YEL, 3)
           + piece(star(118, 472, 15), GRN, 2, 0) + piece(heart(72, 470, 10), PINK, 2, 0))
    sh1 = jig_path(232, 410, 38, 38, 0, 0, 1, 2, ([], [[1]]))
    sh2 = jig_path(232, 410, 38, 38, 0, 1, 1, 2, ([], [[1]]))
    ic2 = piece(sh1, ORA, 3) + piece(Sh(sh2.d, sh2.b), TEAL, 3, seed="i2") + f'<g transform="translate(0 4)">{piece(jig_path(256, 448, 34, 30, 0, 0, 1, 1, ([], [[]])), PURP, 3)}</g>'
    u = 13
    ic3 = "".join(piece(tpoly(TAN_PIECES[n], 72, 576, u), TAN_COL[n], 2, 0, seed=n) for n in TAN_PIECES)
    hx, hy, a = 290, 600, 15
    hexp = [(hx + a * math.cos(math.radians(60 * i)), hy + a * math.sin(math.radians(60 * i))) for i in range(6)]
    ic4 = piece(poly(hexp), YEL, 2, 0)
    for i in (3, 4, 5, 0, 1):
        p1, p2 = hexp[i], hexp[(i + 1) % 6]
        mx, my = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
        nx_, ny_ = (mx - hx) / math.hypot(mx - hx, my - hy), (my - hy) / math.hypot(mx - hx, my - hy)
        ic4 += piece(poly([p1, p2, (mx + nx_ * a * .87, my + ny_ * a * .87)]), GRN, 2, 0, seed=f"t{i}")
    ic4 += piece(rr(hx - a / 2, hy + a * .87, a, a, 1), ORA, 2, 0) + piece(rr(hx - a / 2, hy + a * .87 + a, a, a, 1), ORA, 2, 0, seed="s2")
    o.append(toybox(20, 380, bw, bh, RED, "形狀洞洞", ic1))
    o.append(toybox(202, 380, bw, bh, TEAL, "拼圖", ic2))
    o.append(toybox(20, 546, bw, bh, BLUE, "七巧板", ic3))
    o.append(toybox(202, 546, bw, bh, GRN, "照著拼", ic4))
    o.append(place(14, 722, 1.0, pangolin, "happy", True))
    o.append(bubble(166, 734, 206, 62, "今天想拼什麼呀？", 18, (146, 772)))
    return page("".join(o))


# ================================================================ SCREEN 2: shape holes (inset board, 小小)
def mango(cx, cy, s=1.0):
    return paint(smooth([(cx - 26 * s, cy + 4 * s), (cx - 14 * s, cy - 20 * s), (cx + 12 * s, cy - 22 * s), (cx + 28 * s, cy - 2 * s), (cx + 16 * s, cy + 20 * s), (cx - 12 * s, cy + 22 * s)]), ORA) \
        + paint(ell(cx + 8 * s, cy - 24 * s, 10 * s, 5 * s), LEAF)


def mango_sh(cx, cy, s=1.0):
    return smooth([(cx - 26 * s, cy + 4 * s), (cx - 14 * s, cy - 20 * s), (cx + 12 * s, cy - 22 * s), (cx + 28 * s, cy - 2 * s), (cx + 16 * s, cy + 20 * s), (cx - 12 * s, cy + 22 * s)])


FRUIT = {
    "西瓜": lambda cx, cy: Sh(f"M{cx - 50},{cy - 18} A50,50 0 0 0 {cx + 50},{cy - 18}Z", (cx - 50, cy - 18, cx + 50, cy + 32)),
    "鳳梨": lambda cx, cy: ell(cx, cy + 10, 30, 40) + poly([(cx - 20, cy - 26), (cx - 8, cy - 62), (cx, cy - 34), (cx + 8, cy - 64), (cx + 20, cy - 26)]),
    "香蕉": lambda cx, cy: Sh(f"M{cx - 52},{cy - 22} Q{cx - 30},{cy + 40} {cx + 48},{cy + 4} L{cx + 56},{cy - 6} Q{cx - 16},{cy + 16} {cx - 40},{cy - 30}Z", (cx - 56, cy - 30, cx + 56, cy + 30)),
    "芒果": lambda cx, cy: mango_sh(cx, cy, 1.6),
    "荔枝": lambda cx, cy: circ(cx, cy, 36),
}
FRUIT_COL = {"西瓜": RED, "鳳梨": YEL, "香蕉": "#F7DC5C", "芒果": ORA, "荔枝": "#D9475A"}


def fruit_piece(name, cx, cy, lifted=False, face=True):
    sh = FRUIT[name](cx, cy)
    o = []
    th = 7 if lifted else 4
    if name == "鳳梨":
        o.append(piece(poly([(cx - 20, cy - 26), (cx - 8, cy - 62), (cx, cy - 34), (cx + 8, cy - 64), (cx + 20, cy - 26)]), LEAF, th))
        o.append(piece(ell(cx, cy + 10, 30, 40), YEL, th, seed="pine"))
        k = _clip(ell(cx, cy + 10, 30, 40))
        lines = "".join(stroke(f"M{cx - 40 + i * 14},{cy - 30} l40,60", darker(YEL, .3), 1.4, .6) + stroke(f"M{cx + 40 - i * 14},{cy - 30} l-40,60", darker(YEL, .3), 1.4, .6) for i in range(6))
        o.append(f'<g clip-path="url(#{k})">{lines}</g>')
    elif name == "西瓜":
        o.append(piece(sh, GRN, th))
        o.append(paint(Sh(f"M{cx - 42},{cy - 18} A42,42 0 0 0 {cx + 42},{cy - 18}Z", (0, 0, 1, 1)), RED))
        for sx, sy in ((-20, -6), (0, 2), (20, -6), (-10, 12), (10, 12)):
            o.append(f'<ellipse cx="{cx + sx}" cy="{cy + sy}" rx="2.4" ry="3.6" fill="{DARK}"/>')
    else:
        o.append(piece(sh, FRUIT_COL[name], th))
        if name == "芒果":
            o.append(piece(ell(cx + 12, cy - 38, 14, 7), LEAF, 2, 0))
        if name == "荔枝":
            for i in range(10):
                a = i * 36
                o.append(f'<circle cx="{cx + 24 * math.cos(math.radians(a)):.1f}" cy="{cy + 24 * math.sin(math.radians(a)):.1f}" r="2.2" fill="{darker(FRUIT_COL[name], .25)}"/>')
    # the wooden knob to hold it by
    if face:
        fy = cy + (6 if name == "西瓜" else 4)
        o.append(happy_eye(cx - 9, fy - 4, 3.4) + happy_eye(cx + 9, fy - 4, 3.4) + smile(cx, fy + 4, 4) + cheek(cx - 15, fy + 3, 3.6) + cheek(cx + 15, fy + 3, 3.6))
    o.append(piece(circ(cx + (18 if name != "西瓜" else 30), cy - (14 if name != "西瓜" else 6), 7), BENCH, 3, seed="knob"))
    return "".join(o)


def screen_shapes():
    o = [board_bg(), topbar("水果嵌板")]
    o.append(piece(rr(14, 84, 362, 440, 26), BENCH, 7))
    spots = {"西瓜": (110, 170), "鳳梨": (285, 200), "香蕉": (110, 300), "芒果": (270, 350), "荔枝": (120, 440)}
    for n, (cx, cy) in spots.items():
        o.append(recess(FRUIT[n](cx, cy)))
    o.append(fruit_piece("西瓜", *spots["西瓜"]))
    o.append(fruit_piece("香蕉", *spots["香蕉"]))
    for i in range(3):
        o.append(sparkle(64 + i * 34, 252 + (i % 2) * 10, 6, YEL))
    # the mango is being pulled into place by the magnet
    o.append(glow(FRUIT["芒果"](*spots["芒果"])))
    o.append(fruit_piece("芒果", 292, 372, True))
    o.append(stroke("M300,392 q-10,-6 -20,-14", "#FFFFFF", 3, .9, "2 6"))
    o.append(finger(298, 384, -14))
    o.append(sparkle(236, 316, 8) + sparkle(318, 330, 6))
    # the tray
    o.append(bench(540))
    o.append(fruit_piece("鳳梨", 105, 640))
    o.append(fruit_piece("荔枝", 210, 650))
    o.append(place(250, 700, .82, pangolin, "happy"))
    o.append(bubble(196, 600, 180, 58, "黃黃的芒果，\n住這裡！", 16, (318, 716)))
    return page("".join(o))


# ================================================================ SCREEN 3: jigsaw (9 knobbed pieces)
def screen_jigsaw():
    o = [board_bg()]
    o.append(topbar("台灣黑熊"))
    bx, by, bs = 30, 96, 330
    o.append(piece(rr(bx - 16, by - 16, bs + 32, bs + 32, 22), BENCH, 7))
    o.append(f'<rect x="{bx}" y="{by}" width="{bs}" height="{bs}" rx="4" fill="{darker(BENCH2, .15)}"/>')
    pic = bear_picture(bx, by, bs, bs)
    o.append(f'<g opacity=".22">{pic}</g>')     # the faint picture: 中 shows it as a guide
    rows = cols = 3
    cw = bs / 3
    tabs = jig_tabs(rows, cols, "bear")
    sh = {(r, c): jig_path(bx, by, cw, cw, r, c, rows, cols, tabs) for r in range(3) for c in range(3)}
    for r in range(3):
        for c in range(3):
            o.append(stroke(sh[(r, c)].d, "#FFFFFF", 1.2, .55, "4 4"))
    placed = [(0, 0), (0, 1), (0, 2), (1, 0), (2, 0)]
    for rc in placed:
        o.append(jig_piece(sh[rc], pic, placed=True))
    o.append(glow(sh[(1, 1)]))
    o.append(sparkle(bx + 150, by + 120, 7) + sparkle(bx + 210, by + 176, 5))
    # lifted piece (1,1) near its spot
    o.append(jig_piece(sh[(1, 1)], pic, 16, 22, lifted=True, s=1.06))
    o.append(finger(bx + 182, by + 196, -12))
    # tray
    o.append(bench(486))
    tray = [((1, 2), 95 - (bx + 2.5 * cw), 560 - (by + 1.5 * cw)), ((2, 1), 205 - (bx + 1.5 * cw), 575 - (by + 2.5 * cw)), ((2, 2), 300 - (bx + 2.5 * cw), 560 - (by + 2.5 * cw))]
    for rc, dx, dy in tray:
        o.append(jig_piece(sh[rc], pic, dx, dy, s=.82))
    # little dots: how many pieces in this puzzle
    for i in range(9):
        col = GRN if i < 5 else "#FFFFFF"
        o.append(f'<circle cx="{123 + i * 18}" cy="672" r="6" fill="{col}" stroke="{darker(BENCH, .35)}" stroke-width="1.2"/>')
    o.append(place(18, 712, .86, pangolin, "smile"))
    o.append(bubble(150, 712, 220, 84, "黑熊的肚子，\n放中間！", 17, (130, 760)))
    return page("".join(o))


# ================================================================ SCREEN 4: tangram (big level)
def screen_tangram():
    o = [board_bg(), topbar("七巧板：小貓")]
    u, ox, oy = 38, 76, 150
    o.append(piece(rr(14, 84, 362, 380, 24), BENCH, 7))
    sil = "".join(tpoly(CAT[n], ox, oy, u).d + " " for n in CAT)
    o.append(f'<path d="{sil}" fill="{darker(BENCH2, .35)}" stroke="{darker(BENCH2, .35)}" stroke-width="2.5" stroke-linejoin="round"/>')
    o.append(f'<path d="{sil}" fill="none" stroke="#3B2412" stroke-width="4" opacity=".2" transform="translate(2 3)"/>')
    for n in ("sq", "sm1", "sm2", "big1", "big2"):
        o.append(piece(tpoly(CAT[n], ox, oy, u), TAN_COL[n], 3, 0, seed=n))
    o.append(happy_eye(ox + 1.7 * u, oy + 1.05 * u, 4) + happy_eye(ox + 2.3 * u, oy + 1.05 * u, 4) + cheek(ox + 1.45 * u, oy + 1.35 * u, 4) + cheek(ox + 2.55 * u, oy + 1.35 * u, 4))
    for i in range(3):
        o.append(sparkle(ox + 4.4 * u + i * 16, oy + 0.6 * u + (i % 2) * 14, 6))
    # the tray: the middle triangle (turned) and the parallelogram (needs a flip)
    o.append(bench(484))
    mid = tan_shape("mid", 112, 590, u * .9, 135)
    o.append(piece(mid, TAN_COL["mid"], 4, seed="mid"))
    o.append(rotate_badge(150, 548))
    par = tan_shape("par", 268, 584, u * .9, 0)
    par_pts = TAN_PIECES["par"]
    par = poly([(268 + (px - 1.5) * u * .9 * -1, 584 + (py - 3.5) * u * .9) for px, py in par_pts])   # mirrored: has to be flipped
    o.append(glow(par, "#FFFFFF"))
    o.append(piece(par, TAN_COL["par"], 4, seed="par"))
    o.append(rotate_badge(316, 556))
    o.append(piece(rr(236, 618, 66, 34, 17), CREAM, 3) + flip_icon(255, 635, .75) + tx(284, 641, "翻", 15, NAVY))
    # where they go (ghost hint after a while)
    o.append(f'<path d="{tpoly(CAT["mid"], ox, oy, u).d}" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-dasharray="5 4" opacity=".8"/>')
    o.append(f'<path d="{tpoly(CAT["par"], ox, oy, u).d}" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-dasharray="5 4" opacity=".8"/>')
    o.append(finger(122, 600, -10, .9))
    o.append(place(14, 700, .86, pangolin, "smile"))
    o.append(bubble(150, 690, 222, 108, "點一下，\n它會轉一轉。\n尾巴要翻過來喔！", 16, (130, 750)))
    return page("".join(o))


# ================================================================ SCREEN 5: copy the picture (pattern blocks)
def hexagon(cx, cy, a):
    return [(cx + a * math.cos(math.radians(60 * i)), cy + a * math.sin(math.radians(60 * i))) for i in range(6)]


def flower_parts(cx, cy, a):
    """Pattern-block flower: hexagon, five triangles, two squares (stem), two rhombi (leaves)."""
    hexp = hexagon(cx, cy, a)
    parts = [("hex", hexp, YEL)]
    for i in (3, 4, 5, 0, 1):
        p1, p2 = hexp[i], hexp[(i + 1) % 6]
        mx, my = (p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2
        d = math.hypot(mx - cx, my - cy)
        parts.append(("tri", [p1, p2, (mx + (mx - cx) / d * a * .866, my + (my - cy) / d * a * .866)], GRN))
    sy = cy + a * .866
    parts.append(("sq", [(cx - a / 2, sy), (cx + a / 2, sy), (cx + a / 2, sy + a), (cx - a / 2, sy + a)], ORA))
    parts.append(("sq", [(cx - a / 2, sy + a), (cx + a / 2, sy + a), (cx + a / 2, sy + 2 * a), (cx - a / 2, sy + 2 * a)], ORA))
    s60, c60 = a * .866, a * .5
    lx, ly = cx - a / 2, sy + 1.5 * a
    parts.append(("rh", [(lx, ly), (lx - c60, ly - s60), (lx - c60 - a, ly - s60), (lx - a, ly)], BLUE))
    rx_ = cx + a / 2
    parts.append(("rh", [(rx_, ly), (rx_ + c60, ly - s60), (rx_ + c60 + a, ly - s60), (rx_ + a, ly)], BLUE))
    return parts


def screen_copy():
    o = [board_bg(), topbar("照著拼：小花")]
    # the card to copy
    o.append(piece(rr(18, 84, 128, 158, 14), WHITE, 4))
    for kind, pts, col in flower_parts(82, 130, 17):
        o.append(paint(poly(pts), col, seed="m" + _h(pts)))
    o.append(tx(82, 232, "照著這張", 13, SOFT))
    # the board with the outline
    o.append(piece(rr(156, 84, 220, 380, 22), BENCH, 7))
    o.append(piece(rr(14, 256, 134, 208, 22), BENCH, 7))
    parts = flower_parts(266, 200, 40)
    allp = " ".join(poly(p).d for _, p, _ in parts)
    o.append(f'<path d="{allp}" fill="{darker(BENCH2, .3)}" stroke="{darker(BENCH2, .3)}" stroke-width="2" stroke-linejoin="round"/>')
    for _, p, _ in parts:
        o.append(stroke(poly(p).d, "#FFFFFF", 1.5, .6, "4 4"))
    for i, (kind, p, col) in enumerate(parts):
        if i in (0, 1, 2, 5, 6):
            o.append(piece(poly(p), col, 3, 0, seed=f"c{i}"))
    o.append(happy_eye(254, 196, 4) + happy_eye(278, 196, 4) + smile(266, 208, 5))
    o.append(glow(poly(parts[3][1])))
    o.append(sparkle(330, 150, 7) + sparkle(204, 132, 5))
    # tray of blocks, with how many are left
    o.append(bench(484))
    tray = [("綠三角", [(0, 26), (30, 26), (15, 0)], GRN, 2), ("藍菱形", [(0, 26), (15, 0), (45, 0), (30, 26)], BLUE, 2), ("黃六角", hexagon(15, 13, 15), YEL, 0)]
    tx0 = 56
    for name, pts, col, n in tray:
        if n:
            o.append(piece(poly([(tx0 + x * 1.3, 540 + y * 1.3) for x, y in pts]), col, 4, seed=name))
            o.append(tx(tx0 + 22, 606, f"還有 {n} 個", 13.5, INK))
        tx0 += 104
    o.append(piece(poly([(300 + x * 1.3, 540 + y * 1.3) for x, y in hexagon(15, 13, 15)]), YEL, 4, seed="hx2"))
    o.append(f'<rect x="282" y="526" width="72" height="66" rx="10" fill="{BENCH}" opacity=".6"/>' + tx(318, 606, "用好了", 13.5, SOFT))
    # a lifted triangle near its place
    o.append(piece(poly([(p[0] + 12, p[1] + 14) for p in parts[3][1]]), GRN, 7, seed="lift"))
    o.append(finger(parts[3][1][2][0] + 14, parts[3][1][2][1] + 34, -16, .9))
    # small left panel: free build hint
    o.append(tx(81, 292, "小提示", 15, INK))
    o.append(tx(81, 318, "兩個梯形", 13, SOFT) + tx(81, 338, "也可以拼成", 13, SOFT) + tx(81, 358, "一個六角形", 13, SOFT))
    tp = hexagon(81, 410, 26)
    o.append(paint(poly([tp[0], tp[1], tp[2], tp[3]]), RED, "tp1") + paint(poly([tp[3], tp[4], tp[5], tp[0]]), lighter(RED, .15), "tp2"))
    o.append(stroke(f"M{tp[0][0] + 4:.1f},{tp[0][1]:.1f} L{tp[3][0] - 4:.1f},{tp[3][1]:.1f}", "#FFFFFF", 2.5))
    o.append(place(14, 700, .86, pangolin, "smile"))
    o.append(bubble(150, 690, 222, 108, "看看小卡片，\n綠色三角形\n要放哪裡？", 16, (130, 750)))
    return page("".join(o))


# ================================================================ SCREEN 6: the picture comes alive
def mrt_picture(x, y, w, h):
    o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{lg([(0, "#9FD3F2"), (1, "#DDF1FB")])}"/>']
    o.append(lead_lines(x, y, w, h * .5, "mrt", 4))
    o.append(cloud(x + 30, y + 30, .9) + cloud(x + 200, y + 52, .7))
    # Taipei 101 in the back
    tx0, ty0 = x + w * .72, y + 26
    o.append(paint(poly([(tx0 - 4, ty0), (tx0 + 4, ty0), (tx0 + 3, ty0 + 30), (tx0 - 3, ty0 + 30)]), "#7FA9B8"))
    for i in range(7):
        yy = ty0 + 30 + i * 22
        o.append(paint(poly([(tx0 - 14, yy), (tx0 + 14, yy), (tx0 + 19, yy + 22), (tx0 - 19, yy + 22)]), ["#8CC0CF", "#9ACBD8"][i % 2], f"t{i}"))
    o.append(paint(rr(tx0 - 24, ty0 + 184, 48, 60, 3), "#86B7C6"))
    o.append(paint(rr(x - 4, y + h * .72, w + 8, h * .3, 0), GRASS, "g"))
    for i in range(5):
        o.append(paint(ell(x + 30 + i * 70, y + h * .74, 26, 16), LEAF, f"tr{i}"))
    # the elevated track
    o.append(paint(rr(x - 4, y + h * .62, w + 8, 16, 2), "#C9C2B6"))
    for px in (x + 50, x + 170, x + 290):
        o.append(paint(rr(px, y + h * .62 + 14, 16, h * .3, 2), "#BDB5A8", f"p{px}"))
    # the train with a face, doors open
    ty = y + h * .62 - 70
    o.append(paint(rr(x + 22, ty, 200, 66, 18), WHITE, "car"))
    o.append(paint(Sh(f"M{x + 222},{ty} q46,0 52,40 l0,26 l-52,0Z", (x + 222, ty, x + 274, ty + 66)), WHITE, "nose"))
    o.append(paint(rr(x + 22, ty + 42, 252, 10, 0), "#4E7FC4", "stripe"))
    for i in range(3):
        o.append(paint(rr(x + 36 + i * 46, ty + 12, 32, 22, 6), "#9ED0EE", f"w{i}"))
    o.append(paint(rr(x + 176, ty + 8, 14, 50, 3), "#5F6B7A", "door1") + paint(rr(x + 200, ty + 8, 14, 50, 3), "#5F6B7A", "door2"))
    o.append(paint(rr(x + 190, ty + 8, 10, 50, 0), "#FFE7A8", "light"))
    fx, fy = x + 252, ty + 30
    o.append(eye(fx - 6, fy - 4, 3.6) + eye(fx + 10, fy - 4, 3.6) + smile(fx + 2, fy + 6, 6, open_=True) + cheek(fx - 12, fy + 6, 4))
    for i in range(3):
        o.append(stroke(f"M{x + 2},{ty + 14 + i * 16} h{14 - i * 3}", "#FFFFFF", 3, .9))
    return "".join(o)


def screen_alive():
    o = [board_bg()]
    o.append(wbtn(36, 40, 22, TEAL, home_icon(36, 40)))
    bx, by, bw, bh = 24, 86, 342, 300
    o.append(piece(rr(bx - 12, by - 12, bw + 24, bh + 24, 22), BENCH, 7))
    k = _clip(rr(bx, by, bw, bh, 6))
    o.append(f'<g clip-path="url(#{k})">{mrt_picture(bx, by, bw, bh)}</g>')
    # confetti made of tiny puzzle pieces
    cols_ = [RED, YEL, TEAL, PINK, ORA, GRN, PURP]
    for i in range(16):
        cx_, cy_ = 20 + _rand("cf", i) * 350, 70 + _rand("cf", i + 40) * 120
        sh = jig_path(cx_, cy_, 13, 13, 0, 1, 1, 2, ([], [[1]]))
        o.append(f'<g transform="rotate({int(_rand("cf", i + 80) * 90)} {cx_ + 6} {cy_ + 6})">{paint(Sh(sh.d, sh.b), cols_[i % 7], seed=f"cf{i}")}</g>')
    o.append(bubble(34, 100, 168, 52, "叮咚！捷運來了！", 17, (250, 196)))
    # one more piece for the Taiwan puzzle
    o.append(bench(420))
    o.append(taiwan_puzzle(44, 446, .98, 12))
    o.append(tx(256, 476, "台灣大拼圖", 20, INK))
    o.append(txo(256, 516, "+1", 34, darker(GRN, .2), "#FFFFFF", 6))
    o.append(tx(256, 548, "12 / 48", 17, SOFT))
    fly = jig_path(150, 520, 30, 30, 0, 1, 1, 2, ([], [[1]]))
    o.append(paint(Sh(fly.d, fly.b), TEAL, "fly") + stroke("M186,560 q40,30 70,10", "#FFFFFF", 3, .9, "2 7"))
    o.append(sparkle(140, 516, 8) + sparkle(188, 512, 6))
    # three big round buttons: again, next, the Taiwan puzzle
    for cxb, col, icon, label in ((88, ORA, "again", "再拼一次"), (195, GRN, "next", "下一張"), (302, BLUE, "home", "回工坊")):
        ic = ""
        if icon == "again":
            ic = stroke(f"M{cxb - 12},{705} a13,13 0 1 0 5,-12", "#FFFFFF", 4.5) + f'<path d="M{cxb - 2},{684} l-10,10 l12,4Z" fill="#FFFFFF"/>'
        elif icon == "next":
            ic = f'<path d="M{cxb - 9},{690} L{cxb + 13},{704} L{cxb - 9},{718}Z" fill="#FFFFFF"/>'
        else:
            ic = home_icon(cxb, 705, 1.4)
        o.append(wbtn(cxb, 704, 38, col, ic))
        o.append(tx(cxb, 772, label, 15, INK))
    return page("".join(o))


# ================================================================ SCREEN 7: rest
def screen_rest():
    o = [board_bg()]
    o.append(f'<rect width="{W}" height="{H}" fill="#2C2440" opacity=".55"/>')
    # window with the moon
    o.append(piece(rr(120, 70, 150, 130, 16), BENCH, 5))
    o.append(f'<rect x="132" y="82" width="126" height="106" rx="8" fill="#2E3A6E"/>')
    o.append(f'<path d="M210,106 a24,24 0 1 0 22,32 a18,18 0 1 1 -22,-32Z" fill="#FFE9A6"/>')
    for sx, sy in ((150, 104), (168, 160), (240, 170), (150, 140)):
        o.append(sparkle(sx, sy, 4, "#FFE9A6"))
    o.append(stroke("M195,82 v106 M132,135 h126", BENCH, 5))
    o.append(bench(470, col=darker(BENCH, .25)))
    # the puzzle boxes, closed
    o.append(piece(rr(30, 420, 90, 60, 10), darker(RED, .25), 5) + piece(rr(270, 430, 90, 50, 10), darker(TEAL, .25), 5))
    o.append(piece(ell(195, 470, 90, 22), darker(PINK, .2), 4))
    o.append(place(145, 380, 1.0, pangolin_ball))
    o.append(tx(262, 392, "Z", 26, "#FFE9A6") + tx(282, 368, "z", 20, "#FFE9A6") + tx(298, 350, "z", 15, "#FFE9A6"))
    o.append(piece(rr(30, 540, 330, 190, 26), CREAM, 6))
    o.append(tx(195, 594, "換你去做了！", 30, INK))
    o.append(tx(195, 636, "甲甲捲成一顆球，睡覺囉。", 16, SOFT))
    o.append(tx(195, 664, "去拼一個真的拼圖，", 16, SOFT))
    o.append(tx(195, 690, "或把玩具收回盒子裡吧！", 16, SOFT))
    o.append(lock_chip(178, 760))
    o.append(tx(195, 812, "爸爸媽媽可以解開", 13, "#E8DCCB"))
    return page("".join(o))


# ================================================================ SCREEN 8: parents
def row(y, label, right, h=46):
    return (f'<rect x="16" y="{y}" width="358" height="{h}" rx="12" fill="#FFFFFF"/>'
            + tx(32, y + h / 2 + 5.5, label, 15, INK, "start") + right)


def seg(x, y, opts, sel, w=None):
    w = w or 52
    o = [f'<rect x="{x}" y="{y}" width="{w * len(opts)}" height="30" rx="15" fill="#F1E7D8"/>']
    for i, t in enumerate(opts):
        if i == sel:
            o.append(f'<rect x="{x + i * w + 2}" y="{y + 2}" width="{w - 4}" height="26" rx="13" fill="{TEAL}"/>')
        o.append(tx(x + i * w + w / 2, y + 20, t, 13.5, "#FFFFFF" if i == sel else INK))
    return "".join(o)


def toggle(x, y, on=True):
    return (f'<rect x="{x}" y="{y}" width="46" height="26" rx="13" fill="{GRN if on else "#D8CFC2"}"/>'
            f'<circle cx="{x + (33 if on else 13)}" cy="{y + 13}" r="10" fill="#FFFFFF"/>')


def screen_parents():
    o = [f'<rect width="{W}" height="{H}" fill="#F3ECE2"/>']
    o.append(tx(195, 46, "家長模式", 22, INK))
    o.append(tx(354, 46, "完成", 16, TEAL))
    y = 64
    o.append(row(y, "難度", seg(178, y + 8, ["小小", "中", "大"], 1, 64)))
    y += 49
    o.append(row(y, "每次玩多久", seg(166, y + 8, ["10", "15", "20", "30"], 1, 48)))
    y += 49
    o.append(tx(24, y + 22, "轉動和翻面", 14, SOFT, "start"))
    y += 30
    o.append(row(y, "七巧板", seg(186, y + 8, ["自己轉正", "點一下轉"], 0, 92)))
    y += 49
    o.append(row(y, "拼圖塊也要轉（4 歲半以上）", toggle(312, y + 10, False)))
    y += 49
    o.append(tx(24, y + 22, "幫忙", 14, SOFT, "start"))
    y += 30
    o.append(row(y, "拼圖底下淡淡的圖", toggle(312, y + 10, True)))
    y += 49
    o.append(row(y, "磁鐵", seg(206, y + 8, ["強", "中", "弱"], 1, 52)))
    y += 49
    o.append(row(y, "多久沒放好就提示", seg(206, y + 8, ["5秒", "10秒", "關"], 1, 52)))
    y += 54
    o.append(tx(24, y + 14, "進度（小朋友看不到）", 14, SOFT, "start"))
    y += 24
    o.append(f'<rect x="16" y="{y}" width="358" height="150" rx="12" fill="#FFFFFF"/>')
    o.append(taiwan_puzzle(30, y + 12, .62, 12))
    o.append(tx(102, y + 34, "拼好 12 張圖", 15, INK, "start"))
    o.append(tx(102, y + 58, "拼圖：現在 9 塊（有凸凸的）", 13, SOFT, "start"))
    o.append(tx(102, y + 80, "七巧板：拼好 5 個（有線的）", 13, SOFT, "start"))
    o.append(tx(102, y + 102, "形狀洞洞：全部會了", 13, SOFT, "start"))
    o.append(tx(102, y + 124, "今天玩了 11 分鐘", 13, SOFT, "start"))
    y += 158
    o.append(f'<rect x="16" y="{y}" width="358" height="76" rx="12" fill="#FFF6DF"/>')
    o.append(tx(32, y + 26, "一起玩的小提醒", 14.5, darker(ORA, .3), "start"))
    o.append(tx(32, y + 50, "多說「上面、旁邊、轉一轉、翻過來」，", 13, INK, "start"))
    o.append(tx(32, y + 68, "研究發現常聽到這些詞的小朋友，空間能力比較好。", 13, INK, "start"))
    y += 84
    o.append(row(y, "說出「上面、旁邊、轉一轉」", toggle(312, y + 10, True)))
    y += 49
    o.append(row(y, "玩法開關、聲音、完整版", tx(350, y + 29, "›", 20, SOFT)))
    return page("".join(o), "#F3ECE2")


# ================================================================ PAGE 0: THE SAME TABLE IN THREE STYLES
def style_scene(x, y, w=330, h=250):
    """A small jigsaw (3 x 2) of the bear: four pieces placed, one lifted near its spot, one waiting; 甲甲."""
    bgc = {"wood": BENCH, "glass": "#E6EEF6", "origami": "#F3E3D3"}[STYLE]
    o = [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{bgc}"/>']
    k = _clip(rr(x, y, w, h, 14))
    o.append(f'<g clip-path="url(#{k})">')
    if STYLE == "wood":
        o.append(grain(rr(x, y, w, h, 0), BENCH, "sceneg", 14, .4))
    elif STYLE == "glass":
        o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{lg([(0, "#FFFFFF"), (1, "#D5E3F1")], 0, 0, 1, 1)}"/>' + lead_lines(x, y, w, h, "scn", 4))
    else:
        o.append(facets(rr(x, y, w, h, 0), "scn", 1.2))
    bx, by, bw, bh = x + 16, y + 16, 210, 140
    o.append(piece(rr(bx - 8, by - 8, bw + 16, bh + 16, 10), {"wood": BENCH2, "glass": "#C9D6E6", "origami": "#E2C9B0"}[STYLE], 4))
    pic = bear_picture(bx, by, bw, bh * 1.0)
    o.append(f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" fill="{darker(BENCH2, .15) if STYLE == "wood" else "#B9C4D4" if STYLE == "glass" else "#D4B394"}"/>')
    o.append(f'<g opacity=".25">{pic}</g>')
    rows, cols = 2, 3
    cw, ch = bw / 3, bh / 2
    tabs = jig_tabs(rows, cols, "sty")
    sh = {(r, c): jig_path(bx, by, cw, ch, r, c, rows, cols, tabs) for r in range(2) for c in range(3)}
    for rc in ((0, 0), (0, 1), (0, 2), (1, 0)):
        o.append(jig_piece(sh[rc], pic, placed=True))
    o.append(glow(sh[(1, 1)]))
    o.append(jig_piece(sh[(1, 1)], pic, 14, 30, lifted=True, s=1.05))
    o.append(jig_piece(sh[(1, 2)], pic, 92, 66, s=.9))
    o.append(finger(bx + 120, by + 150, -14, .8))
    o.append(place(x + 236, y + 34, .66, pangolin, "happy", True))
    # a few loose shapes on the table
    o.append(piece(circ(x + 36, y + 206, 16), RED, 3) + piece(poly([(x + 62, y + 224), (x + 78, y + 192), (x + 94, y + 224)]), YEL, 3)
             + piece(tan_shape("par", x + 272, y + 120, 14, 0), TEAL, 3))
    o.append("</g>")
    return "".join(o)


def style_sheet():
    global STYLE
    ph = 1270
    o = [f'<rect width="{W}" height="{ph}" fill="#F7F2EA"/>']
    o.append(tx(195, 56, "畫風：選一個", 30, INK))
    o.append(tx(195, 88, "同一張拼圖桌，三種畫法；建議 A", 16, SOFT))
    bands = [("A 彩繪木頭風", "像真的木頭拼圖：上漆的木片，看得到木紋、", "圓圓的邊和厚度，洞是挖下去的。", "wood"),
             ("B 彩色玻璃風", "像教堂的彩色玻璃窗：一塊一塊亮亮的玻璃，", "中間是灰色的鉛條，光從後面透過來。", "glass"),
             ("C 摺紙風", "每樣東西都是色紙摺出來的：", "一面亮一面暗的摺痕，沒有框線。", "origami")]
    y = 112
    for title, d1, d2, st in bands:
        h = 360
        if st == "wood":
            o.append(f'<rect x="12" y="{y - 4}" width="366" height="{h + 8}" rx="28" fill="#5DB86A"/>')
            o.append(f'<rect x="16" y="{y}" width="358" height="{h}" rx="24" fill="#FFFFFF"/>')
            o.append(f'<rect x="276" y="{y - 14}" width="86" height="30" rx="15" fill="#5DB86A"/>' + tx(319, y + 7, "建議", 15, "#FFFFFF"))
        else:
            o.append(f'<rect x="16" y="{y + 4}" width="358" height="{h}" rx="24" fill="#E9DED3"/><rect x="16" y="{y}" width="358" height="{h}" rx="24" fill="#FFFFFF"/>')
        o.append(tx(34, y + 40, title, 22, INK, "start"))
        o.append(tx(34, y + 66, d1, 13.5, "#6E5C52", "start") + tx(34, y + 86, d2, 13.5, "#6E5C52", "start"))
        STYLE = st
        o.append(style_scene(30, y + 100, 330, 246))
        STYLE = "wood"
        y += h + 22
    return page("".join(o), "#F7F2EA", W, ph), ph


# ================================================================ CONTACT SHEET AND MAIN
def contact_sheet(names):
    cw_, ch_, gap, m = 232, 502, 24, 30
    per = 4
    rows = (len(names) + per - 1) // per
    w = per * cw_ + (per - 1) * gap + 2 * m
    rowh = ch_ + 64
    h = rows * rowh + 40
    items = []
    for i, n in enumerate(names):
        r, c = divmod(i, per)
        x = m + c * (cw_ + gap)
        y = 28 + r * rowh
        items.append(f'<div style="position:absolute;left:{x}px;top:{y}px;width:{cw_}px;text-align:center">'
                     f'<img src="file://{HERE / (n + ".png")}" style="width:{cw_}px;height:{ch_}px;border-radius:18px;box-shadow:0 6px 16px rgba(90,60,40,.2)">'
                     f'<div style="font:19px Huninn, sans-serif;color:{INK};margin-top:10px">{n.replace("_", " ")}</div></div>')
    css = f"@font-face {{ font-family: Huninn; src: url('file://{FONT}'); }} * {{ margin:0; padding:0 }} body {{ width:{w}px; height:{h}px; background:#F7F1E8; position:relative }}"
    return f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>{"".join(items)}</body></html>', w, h


SCREENS = {"1_工坊": screen_home, "2_形狀洞洞": screen_shapes, "3_拼圖": screen_jigsaw, "4_七巧板": screen_tangram,
           "5_照著拼": screen_copy, "6_動起來": screen_alive, "7_休息": screen_rest, "8_家長模式": screen_parents}


def main(only=None):
    global D
    if only in (None, "0"):
        D = Defs()
        html, ph = style_sheet()
        render(html, HERE / "0_畫風選擇.png", W, ph, 2)
        print("0_畫風選擇")
    for name, make in SCREENS.items():
        if only not in (None, name.split("_")[0]):
            continue
        D = Defs()
        render(make(), HERE / f"{name}.png", W, H, 2)
        print(name)
    if only in (None, "c"):
        html, w, h = contact_sheet(list(SCREENS))
        render(html, HERE / "contact_sheet.png", w, h, 1.25)
        print("contact_sheet")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
