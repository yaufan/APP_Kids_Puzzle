"""The 48 jigsaw pictures (design/content.py): a scene painted on a wooden board (faint grain shows
through the paint) with its actor in its box. Writes app/assets/art/backs/<id>.svg (the scene alone,
under the actor when the finished picture comes alive) and app/assets/art/pictures/<id>.svg (the
scene with the actor, which the app cuts into pieces). 400 x 300 each.
"""
import math
import sys

sys.dont_write_bytecode = True

import kit  # noqa: E402
from kit import INK, WHITE, Ctx, Shape, arc, circle, ellipse, path, poly, rect, rrect, smooth  # noqa: E402

import actors  # noqa: E402

sys.path.insert(0, str(kit.ROOT / "design"))
import content  # noqa: E402

W, H = 400, 300
BACKS = kit.ART / "backs"
PICS = kit.ART / "pictures"


def sky(c, top="#8FCBEB", bottom="#DDF1FA", y1=H):
    c.fill(rect(0, 0, W, y1), c.linear(0, 0, 0, y1, [(0, top, 1), (1, bottom, 1)]))


def sun(c, x, y, r=22):
    for k in range(10):
        a = math.radians(k * 36)
        c.stroke(path([(x + math.cos(a) * r * 1.25, y + math.sin(a) * r * 1.25), (x + math.cos(a) * r * 1.6, y + math.sin(a) * r * 1.6)]), "#F5C443", 3)
    c.paint(circle(x, y, r), "#F7CF4F")
    c.face(x, y + 2, r * .5)


def cloud(c, x, y, w, key):
    c.paint(kit.puffs(x, y, w, w * .45, n=4, key=key), WHITE, edge=1)


def hills(c, y, col, amp=24, key="h", n=4):
    r = kit.rnd("hills", key)
    pts = [(-20, H + 10), (-20, y)]
    for i in range(n + 1):
        pts.append((W * i / n, y - amp * r.uniform(.2, 1)))
    pts += [(W + 20, y), (W + 20, H + 10)]
    c.paint(smooth(pts, .6), col, edge=1)


def ground(c, y, col):
    c.fill(rect(0, y, W, H - y), c.linear(0, y, 0, H, [(0, kit.lt(col, .08), 1), (1, kit.dk(col, .08), 1)]))


def tree(c, x, y, s=1.0, col="#5FA04A", fruit=None):
    c.paint(rrect(x - 5 * s, y - 10 * s, 10 * s, 40 * s, 4 * s), "#8A5A33")
    c.paint(kit.puffs(x, y - 22 * s, 60 * s, 46 * s, n=3, key=f"tree{x}{y}"), col)
    if fruit:
        for dx, dy in [(-14, -22), (8, -30), (16, -14), (-4, -10)]:
            c.flat(circle(x + dx * s, y + dy * s, 3.6 * s), fruit)


def flowers(c, y0, y1, key, n=10):
    r = kit.rnd("flowers", key)
    for _ in range(n):
        x, y = r.uniform(10, W - 10), r.uniform(y0, y1)
        col = r.choice(["#F28B8B", "#F7CF4F", WHITE, "#B7A6E6"])
        for k in range(5):
            a = math.radians(k * 72)
            c.flat(circle(x + math.cos(a) * 3, y + math.sin(a) * 3, 2.4), col)
        c.flat(circle(x, y, 1.6), "#E8A93A")


def grain(c, key):
    """The wood showing faintly through the paint."""
    c.grain(rect(0, 0, W, H), "#C9A06A", key=key, op=.09, gap=22, width=1.4)


def buildings(c, base, key, night=False):
    r = kit.rnd("city", key)
    x = -10
    while x < W:
        w, h = r.uniform(34, 60), r.uniform(50, 120)
        col = r.choice(["#9FB8D0", "#B9C7D6", "#C9B8A8", "#A8C4B8"]) if not night else r.choice(["#3E4A72", "#46507E", "#3A4466"])
        c.paint(rrect(x, base - h, w, h + 4, 3), col, edge=1)
        for wy in range(int(base - h + 10), int(base - 8), 16):
            for wx in range(int(x + 7), int(x + w - 8), 12):
                c.flat(rect(wx, wy, 6, 8), "#FFE7A0" if night and r.random() < .6 else ("#E8F1F8" if not night else "#5A6490"), remember=False)
        x += w + r.uniform(2, 8)


def lanterns_string(c, y, n=7, sag=16):
    pts = [(W * i / 16, y + sag * math.sin(math.pi * i / 16)) for i in range(17)]
    c.stroke(path(pts), "#5A4632", 1.6)
    for i in range(1, n + 1):
        x = W * i / (n + 1)
        yy = y + sag * math.sin(math.pi * x / W) + 4
        col = ["#E8463E", "#F2994A", "#F2C94C"][i % 3]
        c.paint(ellipse(x, yy + 9, 9, 11), col, edge=1)
        c.flat(rrect(x - 4, yy - 3, 8, 3, 1), "#E8A93A")


def stalls(c, base, key):
    r = kit.rnd("stalls", key)
    for i, x in enumerate(range(-20, W, 105)):
        col = ["#E8463E", "#3F95D1", "#F2994A", "#6FAE4E"][i % 4]
        c.paint(rrect(x, base - 70, 100, 76, 4), "#6A4A3A", edge=1)
        c.flat(rect(x + 6, base - 52, 88, 46), "#FFE2A8", op=.85)
        aw = Shape([("M", x - 4, base - 70), ("L", x + 104, base - 70), ("L", x + 100, base - 88), ("L", x, base - 88), ("Z",)])
        c.paint(aw, col, edge=1)
        for k in range(0, 100, 20):
            c.flat(rect(x + k, base - 88, 10, 18), WHITE, op=.6)
        if r.random() < .7:
            c.flat(circle(x + 30, base - 30, 6), "#F2C94C", remember=False)


def stars(c, key, n=24, y1=150):
    r = kit.rnd("stars", key)
    for _ in range(n):
        c.sparkle(r.uniform(5, W - 5), r.uniform(5, y1), r.uniform(2.5, 5), "#FFF1B0")


def waves(c, y, col, n=8, amp=5):
    for k in range(3):
        yy = y + k * 14
        pts = [(x, yy + amp * math.sin(x / 26 + k)) for x in range(0, W + 1, 10)]
        c.stroke(path(pts), col, 2.4, op=.6)


def temple_wall(c, base):
    c.paint(rect(0, base - 130, W, 130), "#C9433E", edge=0)
    for x in (60, 200, 340):
        c.paint(rrect(x - 30, base - 100, 60, 100, 6), "#8A2E2A", edge=1)
        c.flat(circle(x + 18, base - 50, 3), "#E8A93A")
    for x in (10, 130, 270, 390):
        c.paint(rrect(x - 7, base - 130, 14, 130, 3), "#A8342F", edge=1)
    roof = Shape([("M", -30, base - 124), ("C", 60, base - 140, 340, base - 140, 430, base - 124), ("L", 420, base - 150),
                  ("C", 330, base - 170, 70, base - 170, -20, base - 150), ("Z",)])
    c.paint(roof, "#3F8A6A")
    for x, d in ((-6, -1), (406, 1)):
        c.paint(smooth([(x, base - 150), (x + d * 18, base - 186), (x + d * 6, base - 158)], .5), "#3F8A6A")
    c.paint(rrect(150, base - 196, 100, 30, 8), "#E8A93A", edge=1)


def tiles(c, y):
    ground(c, y, "#D8C2A0")
    for k in range(1, 6):
        c.stroke(path([(0, y + k * (H - y) / 6), (W, y + k * (H - y) / 6)]), "#B9A07E", 1.2, op=.6)


# ---------------------------------------------------------------- scenes
def s_table(c, k):
    c.fill(rect(0, 0, W, 190), "#FBEFD8")
    for x in range(0, W, 40):
        c.flat(rect(x, 0, 20, 190), "#F6E2C2", op=.6, remember=False)
    c.paint(rrect(250 if k % 2 else 30, 30, 110, 80, 8), "#BFE3F2", edge=2)     # a window
    c.stroke(path([(305 if k % 2 else 85, 30), (305 if k % 2 else 85, 110)]), "#C49A6A", 3)
    cloth = rect(0, 180, W, 120)
    c.fill(cloth, "#F4F1EC")
    c.begin_clip(cloth)
    col = ["#E8828A", "#7FB2E0", "#8CC37A"][k % 3]
    for x in range(0, W, 30):
        c.flat(rect(x, 180, 15, 120), col, op=.35)
    for y in range(180, H, 30):
        c.flat(rect(0, y, W, 15), col, op=.35)
    c.end()
    c.paint(ellipse(200, 250, 120, 26), WHITE, edge=1.4)


def s_orchard(c, k):
    sky(c)
    sun(c, 340 if k % 2 else 60, 52)
    cloud(c, 150, 46, 90, f"o{k}")
    hills(c, 170, "#9ACB6E", key=f"o{k}")
    for i, x in enumerate((40, 360, 110, 300)):
        tree(c, x, 196 - (i % 2) * 10, .9, fruit=["#F2994A", "#E8463E", "#F7CF4F"][k % 3])
    ground(c, 220, "#8CC36A")
    flowers(c, 230, 295, f"o{k}")


def s_meadow(c, k):
    sky(c, "#9AD3F0", "#E8F6FB")
    cloud(c, 90, 50, 80, f"m{k}")
    cloud(c, 300, 70, 70, f"m{k}b")
    hills(c, 150, "#B9DA82", amp=30, key=f"m{k}")
    hills(c, 190, "#94C66C", amp=20, key=f"m{k}b")
    ground(c, 235, "#82BC5E")
    flowers(c, 200, 290, f"m{k}", 14)


def s_forest(c, k):
    sky(c, "#A8D8EE", "#E2F3F9")
    hills(c, 140, "#8FB8A0", amp=40, key=f"f{k}", n=3)
    for i, x in enumerate(range(-10, W + 40, 70)):
        tree(c, x, 190 + (i % 2) * 14, 1.1, col=["#4E8F3A", "#5FA04A", "#3E7F3A"][i % 3])
    ground(c, 228, "#7DB65A")
    flowers(c, 240, 295, f"f{k}", 8)


def s_sea(c, k):
    sky(c, "#4FB3D9", "#1F6FA0")
    r = kit.rnd("sea", k)
    for _ in range(12):
        c.stroke(circle(r.uniform(10, W - 10), r.uniform(10, 220), r.uniform(3, 7)), WHITE, 1.6, op=.6)
    ground(c, 250, "#E8D3A0")
    for x in (30, 80, 330, 370):
        c.paint(smooth([(x, 255), (x - 8, 220), (x + 4, 190), (x - 4, 160), (x + 8, 170), (x + 10, 210), (x + 8, 255)], .6), "#3FA06A")


def s_river(c, k):
    s_meadow(c, k)
    c.fill(rect(0, 150, W, 110), c.linear(0, 150, 0, 260, [(0, "#7FC4E8", 1), (1, "#4E9FD0", 1)]))
    waves(c, 175, WHITE)
    for x in (30, 100, 300, 380):
        c.paint(ellipse(x, 262, 26, 10), "#A4A8AE")


def s_branch(c, k):
    s_forest(c, k)
    c.paint(rrect(-20, 52, 440, 22, 11), "#8A5A33")
    for x in range(10, W, 50):
        c.paint(ellipse(x, 48, 18, 9).rotate(-20, x, 48), "#5FA04A")


def s_night(c, k):
    sky(c, "#26284E", "#5B4B7A", 200)
    c.paint(circle(330 if k % 2 else 70, 50, 20), "#FFF1B0")
    stars(c, f"n{k}")
    lanterns_string(c, 70)
    stalls(c, 240, f"n{k}")
    ground(c, 236, "#7A6A5A")


def s_track(c, k):
    sky(c, "#9AD3F0", "#E8F6FB")
    cloud(c, 300, 50, 80, f"t{k}")
    buildings(c, 210, f"t{k}")
    c.paint(rrect(-10, 204, 420, 18, 2), "#C8CDD4")
    for x in (60, 200, 340):
        c.paint(rrect(x - 10, 222, 20, 60, 2), "#B4BAC2")
    ground(c, 270, "#8CC36A")


def s_rail(c, k):
    sky(c)
    sun(c, 340, 50, 18)
    hills(c, 170, "#A8D27A", key=f"r{k}")
    ground(c, 200, "#94C66C")
    c.paint(rect(0, 226, W, 12), "#9A8A7A")
    for x in range(0, W, 18):
        c.flat(rect(x, 236, 10, 6), "#7A5A3A")
    c.paint(rect(0, 222, W, 4), "#6F7C8C")


def s_road(c, k):
    sky(c)
    cloud(c, 100, 44, 80, f"rd{k}")
    for i, x in enumerate((10, 120, 250, 330)):
        col = ["#F2C9A0", "#C9DDF0", "#F7E0A8", "#D9C2E8"][(i + k) % 4]
        c.paint(rrect(x, 90 + (i % 2) * 20, 90, 120, 4), col)
        c.paint(poly([(x - 6, 92 + (i % 2) * 20), (x + 96, 92 + (i % 2) * 20), (x + 45, 60 + (i % 2) * 20)]), "#C9643E")
        c.flat(rect(x + 30, 130 + (i % 2) * 20, 24, 26), "#BFE3F2")
    c.fill(rect(0, 200, W, 100), "#7A7E86")
    for x in range(10, W, 60):
        c.flat(rect(x, 268, 34, 5), WHITE)
    c.paint(rect(0, 196, W, 8), "#C8CDD4")
    c.stroke(path([(360, 200), (360, 140)]), "#6F7C8C", 3)
    c.paint(circle(360, 136, 10), "#3F95D1")


def s_harbor(c, k):
    sky(c, "#9AD3F0", "#E8F6FB", 170)
    cloud(c, 90, 60, 80, f"h{k}")
    sun(c, 330, 56, 20)
    hills(c, 150, "#8FB8A0", amp=20, key=f"h{k}")
    c.fill(rect(0, 160, W, 140), c.linear(0, 160, 0, H, [(0, "#6FBEE8", 1), (1, "#2F86C0", 1)]))
    waves(c, 200, WHITE)
    waves(c, 250, WHITE)


def s_mountain_rail(c, k):
    sky(c, "#A8D8EE", "#E2F3F9")
    c.paint(poly([(-40, 230), (90, 60), (220, 230)]), "#7FA88E")
    c.paint(poly([(140, 230), (290, 40), (440, 230)]), "#6F9A80")
    c.flat(poly([(266, 70), (290, 40), (314, 70), (302, 66), (290, 76), (278, 66)]), WHITE)
    for x in range(-10, W, 46):
        tree(c, x, 230, .7, col="#3E7F3A")
    ground(c, 238, "#7DB65A")
    c.paint(rect(0, 246, W, 6), "#6F7C8C")


def s_temple(c, k):
    sky(c, "#9AD3F0", "#E8F6FB", 120)
    temple_wall(c, 210)
    tiles(c, 210)
    lanterns_string(c, 24, 5, 10)


def s_lantern_night(c, k):
    sky(c, "#26284E", "#5B4B7A")
    stars(c, f"ln{k}", 30, 200)
    c.paint(circle(70, 60, 22), "#FFF1B0")
    hills(c, 250, "#3A3F6A", amp=30, key=f"ln{k}")
    r = kit.rnd("lanterns", k)
    for _ in range(6):
        x, y = r.uniform(20, 380), r.uniform(60, 200)
        c.paint(poly([(x - 6, y - 8), (x + 6, y - 8), (x + 4, y + 8), (x - 4, y + 8)]), "#FFD58A", edge=1)


def s_temple_tree(c, k):
    s_temple(c, k)
    c.paint(rrect(34, 100, 40, 120, 10), "#8A5A33")
    c.paint(kit.puffs(70, 70, 220, 120, n=5, key="banyan"), "#4E8F3A")
    for x in (20, 50, 90):
        c.stroke(path([(x, 110), (x + 4, 200)]), "#8A5A33", 2, op=.7)


def s_city(c, k):
    sky(c, "#9AD3F0", "#E8F6FB")
    cloud(c, 80, 60, 90, f"c{k}")
    cloud(c, 320, 40, 70, f"c{k}b")
    buildings(c, 260, f"c{k}")
    ground(c, 256, "#8CC36A")


def s_city_night(c, k):
    sky(c, "#1E2246", "#3E3A6A")
    stars(c, f"cn{k}", 18, 120)
    c.begin("translate(170 120) scale(.5)")
    t = actors.taipei101()
    c.body.extend(t.body)
    c.defs.update(t.defs)
    c.end()
    buildings(c, 300, f"cn{k}", night=True)


def s_park(c, k):
    s_meadow(c, k)
    tree(c, 50, 200, 1.2)
    tree(c, 360, 190, 1.1)


def s_lake(c, k):
    sky(c, "#A8D8EE", "#E2F3F9")
    c.paint(poly([(-40, 170), (80, 70), (200, 170)]), "#6F9A80")
    c.paint(poly([(150, 170), (290, 60), (440, 170)]), "#5F8A70")
    c.fill(rect(0, 160, W, 140), c.linear(0, 160, 0, H, [(0, "#5FB0C8", 1), (1, "#2F7FA0", 1)]))
    c.paint(ellipse(320, 168, 34, 8), "#4E8F3A")          # the little island
    waves(c, 200, WHITE)


def s_beach(c, k):
    s_harbor(c, k)
    c.paint(smooth([(-20, 300), (-20, 200), (120, 186), (300, 196), (420, 182), (420, 300)], .6), "#F2DDA8")
    r = kit.rnd("beach", k)
    for _ in range(5):
        c.flat(circle(r.uniform(20, 380), r.uniform(220, 290), 4), "#F7E6D6")


def s_river_city(c, k):
    s_city(c, k)
    c.fill(rect(0, 200, W, 100), c.linear(0, 200, 0, H, [(0, "#6FBEE8", 1), (1, "#2F86C0", 1)]))
    waves(c, 240, WHITE)


SCENES = {
    "table": s_table, "orchard": s_orchard, "meadow": s_meadow, "forest": s_forest, "sea": s_sea, "river": s_river,
    "branch": s_branch, "night": s_night, "track": s_track, "rail": s_rail, "road": s_road, "harbor": s_harbor,
    "mountain_rail": s_mountain_rail, "temple": s_temple, "lantern_night": s_lantern_night, "temple_tree": s_temple_tree,
    "city": s_city, "city_night": s_city_night, "park": s_park, "lake": s_lake, "beach": s_beach, "river_city": s_river_city,
}


def place(c, actor, box):
    """The actor fitted into box (keeping its shape, centred, as the app's BoxFit.contain does)."""
    a = actors.ACTORS[actor]()
    x, y, w, h = box
    s = min(w / a.w, h / a.h)
    ox, oy = x + (w - a.w * s) / 2, y + (h - a.h * s) / 2
    c.begin(f"translate({kit.n(ox)} {kit.n(oy)}) scale({s:.4f})")
    c.body.extend(a.body)
    c.defs.update(a.defs)
    c.end()


def build():
    n = 0
    for box in content.BOXES:
        for k, (pid, _, scene, actor, rect_, *_rest) in enumerate(content.PICTURES[box[0]]):
            back = Ctx(W, H)
            SCENES[scene](back, k)
            grain(back, pid)
            kit.write_svg(BACKS / f"{pid}.svg", back.svg(), (W, H))
            pic = Ctx(W, H)
            SCENES[scene](pic, k)
            place(pic, actor, rect_)
            grain(pic, pid)
            kit.write_svg(PICS / f"{pid}.svg", pic.svg(), (W, H))
            n += 2
    print(f"pictures: {n} files")


if __name__ == "__main__":
    build()
