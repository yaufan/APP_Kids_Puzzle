"""What is in 拼拼樂工坊's boxes: the six jigsaw boxes with their 48 pictures, and the six inset boards
of 形狀洞洞. The pictures are drawn by design/art/pictures.py from these; the app reads the names,
lines, sounds and moves from app/assets/content.json, which this writes.

    python3 design/content.py      # writes app/assets/content.json

A picture is a scene (its background) with one actor (the thing that comes alive when the picture is
done) in a box of the 400 x 300 picture. `anim` is how the actor moves (hop, drive, fly, sway, spin,
wiggle, pulse, swim, nod), `sound` the sound it makes (design/sounds/make_sounds.py), `line` what
the helper says: always with a word about where things are (上面、下面、旁邊、中間、左邊、右邊).
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "app" / "assets" / "content.json"

# id, name, colour, music, in the free version
BOXES = [
    ("fruit", "水果盒", "#F2994A", "fruit", True),
    ("animals", "動物盒", "#6FAE4E", "animals", True),
    ("night", "夜市盒", "#7B6CC8", "night", False),
    ("ride", "捷運和車車盒", "#3F95D1", "ride", False),
    ("temple", "廟會盒", "#D9534A", "temple", False),
    ("city", "城市盒", "#2FA6A0", "city", False),
]

# box: [(picture id, name, scene, actor, (x, y, w, h), anim, sound, line)]
PICTURES = {
    "fruit": [
        ("mango_ice", "芒果冰", "table", "mango_ice", (125, 70, 160, 160), "wiggle", "munch", "芒果冰冰涼涼，芒果在最上面！"),
        ("pineapple", "鳳梨", "orchard", "pineapple", (140, 50, 130, 190), "hop", "boing", "鳳梨的葉子在頭上！"),
        ("watermelon", "西瓜", "orchard", "watermelon", (115, 95, 170, 140), "pulse", "pop", "西瓜裂開，籽跳出來囉！"),
        ("banana", "香蕉", "table", "banana", (110, 85, 180, 140), "sway", "boing", "彎彎的香蕉，在盤子上面！"),
        ("lychee", "荔枝", "orchard", "lychee", (130, 60, 150, 170), "hop", "pop", "一串荔枝，掛在樹枝下面！"),
        ("sugar_apple", "釋迦", "table", "sugar_apple", (130, 70, 150, 160), "wiggle", "munch", "釋迦凸凸的，像一顆顆小拼圖！"),
        ("wax_apple", "蓮霧", "orchard", "wax_apple", (135, 70, 140, 160), "hop", "ding", "紅紅的蓮霧，像小鈴鐺掛在上面！"),
        ("orange", "柳丁", "meadow", "orange", (60, 120, 130, 130), "drive", "boing", "圓圓的柳丁，滾到右邊囉！"),
    ],
    "animals": [
        ("bear", "台灣黑熊", "forest", "bear", (110, 70, 180, 190), "nod", "munch", "黑熊坐在樹下，大口吃芒果！"),
        ("leopard_cat", "石虎", "meadow", "leopard_cat", (110, 90, 180, 160), "hop", "mew", "石虎躲在草叢後面！"),
        ("magpie", "台灣藍鵲", "forest", "magpie", (90, 60, 220, 150), "fly", "chirp", "藍鵲飛到天空上面囉！"),
        ("deer", "梅花鹿", "meadow", "deer", (110, 60, 180, 190), "hop", "bleat", "梅花鹿跳過小草地！"),
        ("pangolin", "穿山甲", "forest", "pangolin", (70, 120, 170, 130), "drive", "sniff", "穿山甲捲成一顆球，滾到旁邊！"),
        ("turtle", "綠蠵龜", "sea", "turtle", (90, 80, 200, 150), "swim", "waves", "綠蠵龜在海裡游，游到右邊！"),
        ("salmon", "櫻花鉤吻鮭", "river", "salmon", (100, 110, 200, 110), "swim", "splash", "鮭魚在溪水裡游來游去！"),
        ("macaque", "台灣獼猴", "branch", "macaque", (140, 70, 140, 180), "sway", "ooh", "獼猴抓著樹枝，盪來盪去！"),
    ],
    "night": [
        ("bubble_tea", "珍珠奶茶", "night", "bubble_tea", (140, 50, 120, 200), "wiggle", "pop", "珍珠在杯子下面！"),
        ("egg_cake", "雞蛋糕", "night", "egg_cake", (110, 90, 180, 150), "hop", "munch", "雞蛋糕排排站，一個在一個旁邊！"),
        ("corn", "烤玉米", "night", "corn", (120, 70, 160, 180), "wiggle", "sizzle", "烤玉米在烤架上面！"),
        ("tanghulu", "糖葫蘆", "night", "tanghulu", (150, 40, 100, 220), "sway", "pop", "糖葫蘆一顆一顆往上串！"),
        ("cotton_candy", "棉花糖", "night", "cotton_candy", (125, 40, 150, 210), "pulse", "sparkle", "好大一朵棉花糖，在棍子上面！"),
        ("ring_toss", "套圈圈", "night", "ring_toss", (105, 70, 190, 180), "spin", "ding", "圈圈套到瓶子上面囉！"),
        ("pinball", "彈珠台", "night", "pinball", (120, 45, 160, 210), "hop", "ding", "彈珠從上面滾到下面！"),
        ("bapu", "叭噗冰淇淋車", "night", "bapu", (60, 90, 190, 160), "drive", "bapu", "叭噗！冰淇淋車開到右邊囉！"),
    ],
    "ride": [
        ("mrt", "捷運", "track", "mrt", (30, 95, 250, 110), "drive", "mrt", "叮咚！捷運從左邊開到右邊囉！"),
        ("hsr", "高鐵", "track", "hsr", (30, 100, 250, 100), "drive", "whoosh", "高鐵咻一下，開得好快！"),
        ("train", "火車", "rail", "train", (40, 100, 240, 120), "drive", "toot", "火車在鐵軌上面開！"),
        ("bus", "公車", "road", "bus", (50, 95, 220, 140), "drive", "bell", "公車停在站牌旁邊！"),
        ("garbage", "垃圾車", "road", "garbage", (50, 90, 220, 145), "drive", "garbage", "垃圾車來了，音樂響囉！"),
        ("bike", "腳踏車", "road", "bike", (70, 100, 180, 140), "drive", "bell", "腳踏車叮叮，騎到右邊！"),
        ("boat", "漁船", "harbor", "boat", (90, 90, 210, 150), "swim", "waves", "漁船在海上面搖呀搖！"),
        ("alishan", "阿里山小火車", "mountain_rail", "alishan", (40, 110, 220, 120), "drive", "toot", "小火車爬上山，經過大樹旁邊！"),
    ],
    "temple": [
        ("lion", "舞獅", "temple", "lion", (100, 70, 200, 180), "nod", "cymbal", "舞獅搖搖頭，眨眨眼睛！"),
        ("dragon", "舞龍", "temple", "dragon", (40, 70, 260, 160), "swim", "drum", "舞龍彎彎的，從左邊游到右邊！"),
        ("lantern", "元宵花燈", "lantern_night", "lantern", (135, 40, 130, 200), "sway", "ding", "花燈掛在上面，亮晶晶！"),
        ("puppet", "布袋戲", "temple", "puppet", (130, 50, 140, 200), "hop", "drum", "布袋戲偶從台子上面跳出來！"),
        ("sky_lantern", "天燈", "lantern_night", "sky_lantern", (140, 100, 120, 150), "fly", "wind", "天燈慢慢飛到天上面！"),
        ("drum", "大鼓", "temple", "drum", (115, 70, 170, 170), "pulse", "drum", "咚咚咚，大鼓在中間！"),
        ("top", "陀螺", "temple", "top", (140, 80, 120, 160), "spin", "spin", "陀螺轉呀轉，轉一圈又一圈！"),
        ("big_tree", "廟口的大樹下", "temple_tree", "bench", (140, 165, 140, 90), "sway", "chirp", "大樹下面好涼快，坐在椅子上！"),
    ],
    "city": [
        ("taipei101", "台北 101", "city", "taipei101", (150, 15, 100, 270), "pulse", "ding", "101 好高好高，站在最中間！"),
        ("fireworks", "新年煙火", "city_night", "fireworks", (90, 15, 220, 150), "pulse", "fireworks", "煙火在 101 上面開花！"),
        ("ferris", "摩天輪", "park", "ferris", (110, 30, 180, 220), "spin", "chime", "摩天輪轉一圈，好高喔！"),
        ("sun_moon", "日月潭", "lake", "lake_boat", (120, 140, 160, 90), "swim", "waves", "小船在日月潭上面！"),
        ("lighthouse", "燈塔", "harbor", "lighthouse", (150, 30, 100, 230), "pulse", "waves", "燈塔站在海邊，亮亮的！"),
        ("beach", "海邊", "beach", "crab", (130, 150, 140, 110), "drive", "waves", "螃蟹在沙灘上面走到旁邊！"),
        ("rainbow_bridge", "彩虹橋", "river_city", "rainbow_bridge", (40, 80, 320, 150), "pulse", "bell", "彩虹橋彎彎的，跨在河上面！"),
        ("slide", "公園溜滑梯", "park", "slide", (100, 60, 200, 200), "hop", "boing", "從溜滑梯上面滑下來！"),
    ],
}

# The inset boards of 形狀洞洞: id, name, colour, [(actor, name, how it looks)].
INSETS = [
    ("fruit", "水果嵌板", "#F2994A", [("watermelon", "西瓜", "紅紅的"), ("pineapple", "鳳梨", "黃黃的"), ("banana", "香蕉", "彎彎的"),
                                    ("mango", "芒果", "黃黃的"), ("lychee", "荔枝", "紅紅的"), ("sugar_apple", "釋迦", "綠綠的")]),
    ("animals", "動物嵌板", "#6FAE4E", [("bear", "黑熊", "黑黑的"), ("leopard_cat", "石虎", "有花紋的"), ("magpie", "藍鵲", "藍藍的"),
                                       ("deer", "梅花鹿", "有白點點的"), ("pangolin", "穿山甲", "有鱗片的"), ("turtle", "海龜", "綠綠的")]),
    ("ride", "車車嵌板", "#3F95D1", [("mrt", "捷運", "長長的"), ("bus", "公車", "大大的"), ("garbage", "垃圾車", "會唱歌的"),
                                    ("bike", "腳踏車", "有兩個輪子的"), ("train", "火車", "嘟嘟叫的")]),
    ("night", "夜市嵌板", "#7B6CC8", [("bubble_tea", "珍珠奶茶", "甜甜的"), ("egg_cake", "雞蛋糕", "香香的"), ("corn", "烤玉米", "黃黃的"),
                                     ("tanghulu", "糖葫蘆", "紅紅的"), ("cotton_candy", "棉花糖", "軟軟的")]),
    ("temple", "廟會嵌板", "#D9534A", [("lion", "舞獅", "會眨眼的"), ("lantern", "花燈", "亮亮的"), ("puppet", "布袋戲偶", "會跳的"),
                                      ("drum", "大鼓", "咚咚響的"), ("top", "陀螺", "會轉的")]),
    ("sea", "海邊嵌板", "#2FA6A0", [("crab", "螃蟹", "紅紅的"), ("shell", "貝殼", "白白的"), ("boat", "漁船", "搖搖的"),
                                   ("lighthouse", "燈塔", "高高的"), ("starfish", "海星", "五個角的")]),
]

# Where the holes go on a 400 x 300 board (the middle of each, and the size of its box).
INSET_SPOTS = {
    6: [(75, 82), (200, 82), (325, 82), (75, 220), (200, 220), (325, 220)],
    5: [(75, 82), (200, 82), (325, 82), (137, 220), (263, 220)],
}
INSET_SIZE = 112
SPOT_WORDS = {
    6: ["左上角", "上面中間", "右上角", "左下角", "下面中間", "右下角"],
    5: ["左上角", "上面中間", "右上角", "下面左邊", "下面右邊"],
}


def actors():
    """Every actor the art has to draw (pictures and insets)."""
    names = {p[3] for ps in PICTURES.values() for p in ps}
    names |= {a for _, _, _, items in INSETS for a, _, _ in items}
    return sorted(names)


def data():
    boxes = []
    for bid, zh, col, music, free in BOXES:
        pics = []
        for pid, pzh, scene, actor, (x, y, w, h), anim, sound, line in PICTURES[bid]:
            assert 0 <= x and x + w <= 400 and 0 <= y and y + h <= 300, pid
            pics.append({"id": pid, "zh": pzh, "actor": actor, "box": [x, y, w, h], "anim": anim, "sound": sound, "line": line})
        assert len(pics) == 8, bid
        boxes.append({"id": bid, "zh": zh, "color": col, "music": music, "free": free, "pictures": pics})
    ids = [p["id"] for b in boxes for p in b["pictures"]]
    assert len(ids) == len(set(ids)) == 48
    insets = []
    for bid, zh, col, items in INSETS:
        spots = INSET_SPOTS[len(items)]
        words = SPOT_WORDS[len(items)]
        insets.append({"id": bid, "zh": zh, "color": col, "items": [
            {"actor": a, "zh": izh, "x": spots[i][0], "y": spots[i][1], "size": INSET_SIZE, "line": f"{look}{izh}，放在{words[i]}！"}
            for i, (a, izh, look) in enumerate(items)]})
    return {"boxes": boxes, "insets": insets}


if __name__ == "__main__":
    d = data()
    OUT.write_text(json.dumps(d, ensure_ascii=False, indent=1) + "\n")
    print(f"{OUT.relative_to(ROOT)}: {len(d['boxes'])} boxes, 48 pictures, {len(d['insets'])} inset boards, {len(actors())} actors to draw")
