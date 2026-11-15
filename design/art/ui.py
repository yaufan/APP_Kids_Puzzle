"""The workshop's own pictures: the four toy boxes on the shelf (形狀洞洞、拼圖、七巧板、照著拼), the
wooden floor, and the rest screen's window with the moon, a star and the helper's cushion. Writes
app/assets/art/ui/.
"""
import math
import sys

sys.dont_write_bytecode = True

import kit  # noqa: E402
from kit import WHITE, Ctx, Shape, circle, ellipse, poly, rect, rrect, star  # noqa: E402

OUT = kit.ART / "ui"


def jigsaw_piece(x, y, s, tabs=(1, 1, -1, -1)):
    """A jigsaw piece s across at x, y (top left of its square), knobs out (+1) or in (-1) on the
    top, right, bottom and left sides."""
    pts = []
    corners = [(x, y), (x + s, y), (x + s, y + s), (x, y + s)]
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        dx, dy = (b[0] - a[0]) / s, (b[1] - a[1]) / s
        nx, ny = dy, -dx                          # outward normal for a clockwise square
        t = tabs[i]
        for u, v in [(0, 0), (.36, 0), (.32, .14), (.3, .26), (.38, .34), (.5, .36), (.62, .34), (.7, .26), (.68, .14), (.64, 0)]:
            pts.append((a[0] + dx * u * s + nx * v * s * t, a[1] + dy * u * s + ny * v * s * t))
    return kit.smooth(pts, .25)


def mode_shapes():
    c = Ctx(160, 120)
    box = rrect(20, 50, 120, 64, 8)
    c.slab(box, "#E8463E", key="sbox")
    for x, sh in [(44, circle(44, 70, 10)), (80, rect(70, 60, 20, 20)), (116, poly([(116, 58), (128, 80), (104, 80)]))]:
        c.hole(sh, board="#E8463E")
    c.slab(star(62, 30, 16, 7), "#F2994A", depth=3, key="s1")
    c.slab(circle(104, 32, 13), "#3F95D1", depth=3, key="s2")
    c.slab(kit.heart(130, 22, 18), "#EB7FA6", depth=3, key="s3")
    return c


def mode_jigsaw():
    c = Ctx(160, 120)
    c.slab(jigsaw_piece(26, 30, 50, (1, -1, 1, -1)), "#F2C94C", key="j1")
    c.slab(jigsaw_piece(84, 16, 48, (-1, 1, -1, 1)), "#2FA6A0", key="j2")
    c.slab(jigsaw_piece(78, 66, 44, (1, 1, -1, -1)), "#E8463E", key="j3")
    return c


def mode_tangram():
    c = Ctx(160, 120)
    s = 100 / 2.83
    o = (30, 10)

    def P(*pts):
        return poly([(o[0] + x * s, o[1] + y * s) for x, y in pts])
    pieces = [(P((0, 0), (2.83, 0), (1.41, 1.41)), "#E8463E"), (P((0, 0), (1.41, 1.41), (0, 2.83)), "#3F95D1"),
              (P((2.83, 0), (2.83, 1.41), (2.12, .71)), "#6FAE4E"), (P((2.12, .71), (2.83, 1.41), (2.12, 2.12), (1.41, 1.41)), "#F2C94C"),
              (P((2.83, 1.41), (2.83, 2.83), (1.41, 2.83)), "#F2994A"), (P((0, 2.83), (.71, 2.12), (2.12, 2.12), (1.41, 2.83)), "#2FA6A0"),
              (P((.71, 2.12), (1.41, 1.41), (2.12, 2.12)), "#7B6CC8")]
    for i, (sh, col) in enumerate(pieces):
        c.slab(sh, col, depth=3, key=f"t{i}", grain=False, bevel=1.4)
    return c


def mode_blocks():
    c = Ctx(160, 120)
    h3 = math.sqrt(3) / 2
    s = 30
    cx, cy = 80, 62
    hexa = poly([(cx + s * math.cos(math.radians(a)), cy + s * math.sin(math.radians(a))) for a in range(0, 360, 60)])
    c.slab(hexa, "#F2C94C", depth=3, key="h")
    for k in range(6):
        a0, a1 = math.radians(k * 60), math.radians(k * 60 + 60)
        p0 = (cx + s * math.cos(a0), cy + s * math.sin(a0))
        p1 = (cx + s * math.cos(a1), cy + s * math.sin(a1))
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
        d = (mid[0] - cx, mid[1] - cy)
        ln = math.hypot(*d)
        tip = (mid[0] + d[0] / ln * s * h3, mid[1] + d[1] / ln * s * h3)
        if k % 2 == 0:
            c.slab(poly([p0, p1, tip]), "#6FAE4E", depth=3, key=f"b{k}", grain=False, bevel=1.4)
    return c


def floor():
    c = Ctx(400, 90)
    for i, x in enumerate(range(0, 400, 80)):
        b = rect(x, 0, 80, 90)
        c.fill(b, c.linear(0, 0, 0, 90, [(0, kit.mix("#D9AE78", "#C99A62", (i % 2) * .6), 1), (1, "#B9864E", 1)]))
        c.grain(b, "#C99A62", key=f"floor{i}", op=.2, gap=14)
        c.stroke(kit.path([(x, 0), (x, 90)]), "#8A5A33", 1.6, op=.6)
    c.stroke(kit.path([(0, 1), (400, 1)]), "#8A5A33", 2.4, op=.5)
    return c


def window():
    c = Ctx(160, 160)
    c.slab(rrect(6, 6, 148, 148, 14), "#C49A6A", key="win")
    c.fill(rrect(20, 20, 120, 120, 6), c.linear(0, 20, 0, 140, [(0, "#1E2246", 1), (1, "#3E3A6A", 1)]))
    moon = Shape(circle(98, 66, 22).cmds)
    c.flat(moon, "#FFE9A8")
    c.flat(circle(110, 58, 19), "#2A2C56")
    for x, y, r in [(46, 46, 4), (60, 100, 3), (120, 112, 3.5), (40, 120, 2.6)]:
        c.sparkle(x, y, r * 1.4, "#FFF1B0")
    c.paint(rect(76, 20, 8, 120), "#C49A6A", edge=0)
    c.paint(rect(20, 76, 120, 8), "#C49A6A", edge=0)
    return c


def star_icon():
    c = Ctx(40, 40)
    c.sparkle(20, 20, 18, "#FFF1B0")
    return c


def cushion():
    c = Ctx(200, 60)
    c.paint(ellipse(100, 34, 94, 22), "#D96A8A")
    c.flat(ellipse(100, 28, 80, 13), "#EB8FA8", op=.8)
    for x in (16, 184):
        c.paint(circle(x, 34, 6), "#F2C94C")
    return c


def build():
    files = {"mode_shapes": mode_shapes, "mode_jigsaw": mode_jigsaw, "mode_tangram": mode_tangram, "mode_blocks": mode_blocks,
             "floor": floor, "window": window, "star": star_icon, "cushion": cushion}
    for name, f in files.items():
        kit.write_svg(OUT / f"{name}.svg", f().svg())
    print(f"ui: {len(files)} files")


if __name__ == "__main__":
    build()
