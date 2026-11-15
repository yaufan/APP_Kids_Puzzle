import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

/// 小小 (2½ to 3), 中 (3 to 4), 大 (4 to 5): docs/design.md 「三個難度」.
enum Level {
  small('小小', '2 歲半～3 歲'),
  middle('中', '3～4 歲'),
  big('大', '4～5 歲');

  const Level(this.zh, this.ages);

  final String zh;
  final String ages;
}

/// The four toy boxes on the workshop's shelf.
enum Mode {
  shapes('形狀洞洞', '/shapes'),
  jigsaw('拼圖', '/jigsaw'),
  tangram('七巧板', '/tangram'),
  blocks('照著拼', '/blocks');

  const Mode(this.zh, this.path);

  final String zh;
  final String path;
}

/// The workshop helper the child picked (docs/design.md 「畫面和玩法」): its own look, its own
/// little sound, its own voice pitch, its own way of sleeping and its own way of saying things.
enum Helper {
  pangolin('甲甲', '穿山甲', 'sniff', 1.15, '嗅嗅～', '甲甲捲成一顆球，睡著了'),
  leopardCat('石石', '石虎', 'mew', 1.3, '喵～', '石石捲成一圈，尾巴蓋住鼻子，睡著了'),
  bear('熊熊', '台灣黑熊', 'grunt', .95, '嗯～', '熊熊抱著蜂蜜罐，睡著了'),
  magpie('藍藍', '台灣藍鵲', 'chirp', 1.4, '啾啾！', '藍藍把頭埋進翅膀，睡著了'),
  deer('花花', '梅花鹿', 'bleat', 1.2, '呦～', '花花把腳折起來，睡著了'),
  macaque('猴猴', '台灣獼猴', 'ooh', 1.25, '嗚嗚！', '猴猴抱著膝蓋，睡著了');

  const Helper(this.zh, this.animal, this.sound, this.pitch, this.call, this.sleeps);

  /// The name the child hears.
  final String zh;
  final String animal;

  /// Its little sound (a file in assets/sounds/).
  final String sound;

  /// The voice's pitch for it.
  final double pitch;

  /// What it says first when it is happy.
  final String call;

  /// The rest screen: how it sleeps.
  final String sleeps;
}

/// A jigsaw box and its eight pictures.
class PicBox {
  PicBox(this.id, this.zh, this.color, this.music, this.free, this.pictures);

  final String id;
  final String zh;
  final Color color;
  final String music;
  final bool free;
  final List<Picture> pictures;
}

/// One picture of a jigsaw box (design/content.py).
class Picture {
  Picture(this.id, this.zh, this.box, this.actor, this.actorBox, this.anim, this.sound, this.line, this.index);

  final String id;
  final String zh;
  final String box;
  final String actor;

  /// Where the actor is in the 400 × 300 picture.
  final Rect actorBox;
  final String anim;
  final String sound;
  final String line;

  /// 0 to 47: its place in the boxes, and so its piece of the Taiwan puzzle.
  final int index;

  static const size = Size(400, 300);
}

class InsetItem {
  InsetItem(this.actor, this.zh, this.at, this.size, this.line);

  final String actor;
  final String zh;
  final Offset at;
  final double size;
  final String line;
}

class InsetBoard {
  InsetBoard(this.id, this.zh, this.color, this.items);

  final String id;
  final String zh;
  final Color color;
  final List<InsetItem> items;

  static const size = Size(400, 300);
}

/// A piece of a geometric puzzle in its place: kind, middle, turn (degrees), mirrored, corners.
class ShapeSlot {
  ShapeSlot(this.kind, this.at, this.angle, this.flip, this.points, this.cells);

  final String kind;
  final Offset at;
  final double angle;
  final bool flip;
  final List<Offset> points;

  /// The bits of the outline it covers (照著拼; one each for the tangram).
  final List<String> cells;

  Path get path => Path()..addPolygon(points, true);
}

/// A tangram piece or a pattern block as it comes out of the box (centred on 0,0).
class ShapeKind {
  ShapeKind(this.id, this.zh, this.symmetry, this.points);

  final String id;
  final String zh;
  final int symmetry;
  final List<Offset> points;

  Size get size {
    var x0 = 0.0, y0 = 0.0, x1 = 0.0, y1 = 0.0;
    for (final p in points) {
      if (p.dx < x0) x0 = p.dx;
      if (p.dy < y0) y0 = p.dy;
      if (p.dx > x1) x1 = p.dx;
      if (p.dy > y1) y1 = p.dy;
    }
    return Size(x1 - x0, y1 - y0);
  }

  double get radius => points.fold(0.0, (m, p) => p.distance > m ? p.distance : m);
}

class TanFigure {
  TanFigure(this.id, this.zh, this.level, this.anim, this.size, this.lines, this.slots, this.eye, this.eyes);

  final String id;
  final String zh;
  final Level level;
  final String anim;
  final Size size;

  /// Whether the lines between the pieces are drawn in the shadow.
  final bool lines;
  final List<ShapeSlot> slots;
  final Offset? eye;
  final int eyes;
}

class BlockCard {
  BlockCard(this.id, this.zh, this.size, this.slots, this.extra);

  final String id;
  final String zh;
  final Size size;

  /// The blocks of the card's picture.
  final List<ShapeSlot> slots;

  /// 大: other blocks that fit the outline (two trapezoids for a hexagon…).
  final List<ShapeSlot> extra;

  Set<String> get cells => {for (final s in slots) ...s.cells};
}

class TaiwanMap {
  TaiwanMap(this.size, this.outline, this.pieces);

  final Size size;
  final List<Offset> outline;
  final List<List<Offset>> pieces;
}

/// Everything in the boxes: assets/content.json (design/content.py), tangram.json, blocks.json and
/// taiwan.json (design/puzzles.py).
class Library {
  Library({required this.boxes, required this.insets, required this.tanKinds, required this.tangrams, required this.blockKinds, required this.cards, required this.taiwan});

  final List<PicBox> boxes;
  final List<InsetBoard> insets;
  final Map<String, ShapeKind> tanKinds;
  final List<TanFigure> tangrams;
  final Map<String, ShapeKind> blockKinds;
  final List<BlockCard> cards;
  final TaiwanMap taiwan;

  late final List<Picture> pictures = [for (final b in boxes) ...b.pictures];
  late final Map<String, Picture> picture = {for (final p in pictures) p.id: p};
  late final Map<String, PicBox> box = {for (final b in boxes) b.id: b};

  PicBox boxOf(Picture p) => box[p.box]!;

  List<TanFigure> tangramsAt(Level l) => [for (final t in tangrams) if (t.level == l) t];

  /// The Taiwan puzzle's piece for picture [index] (spread over the island, not box by box).
  static int taiwanPiece(int index) => index * 29 % 48;

  static Future<Library> load() async {
    Future<Map<String, dynamic>> read(String name) async => jsonDecode(await rootBundle.loadString('assets/$name.json')) as Map<String, dynamic>;
    return parse(await read('content'), await read('tangram'), await read('blocks'), await read('taiwan'));
  }

  static Offset _pt(dynamic p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
  static List<Offset> _pts(dynamic l) => [for (final p in l as List) _pt(p)];
  static Color _color(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

  static ShapeSlot _slot(Map<String, dynamic> s) => ShapeSlot(
        s['kind'] as String,
        Offset((s['x'] as num).toDouble(), (s['y'] as num).toDouble()),
        (s['angle'] as num? ?? 0).toDouble(),
        s['flip'] == true,
        _pts(s['points']),
        [for (final c in (s['cells'] as List?) ?? const []) c as String],
      );

  static Map<String, ShapeKind> _kinds(Map<String, dynamic> m) => {
        for (final e in m.entries)
          e.key: ShapeKind(e.key, (e.value as Map)['zh'] as String, ((e.value as Map)['symmetry'] as num).toInt(), _pts((e.value as Map)['points'])),
      };

  static Library parse(Map<String, dynamic> content, Map<String, dynamic> tangram, Map<String, dynamic> blocks, Map<String, dynamic> taiwan) {
    var index = 0;
    final boxes = [
      for (final b in content['boxes'] as List)
        () {
          final m = b as Map<String, dynamic>;
          final id = m['id'] as String;
          return PicBox(id, m['zh'] as String, _color(m['color'] as String), m['music'] as String, m['free'] == true, [
            for (final p in m['pictures'] as List)
              () {
                final q = p as Map<String, dynamic>;
                final r = [for (final v in q['box'] as List) (v as num).toDouble()];
                return Picture(q['id'] as String, q['zh'] as String, id, q['actor'] as String, Rect.fromLTWH(r[0], r[1], r[2], r[3]), q['anim'] as String, q['sound'] as String,
                    q['line'] as String, index++);
              }(),
          ]);
        }(),
    ];
    final insets = [
      for (final b in content['insets'] as List)
        () {
          final m = b as Map<String, dynamic>;
          return InsetBoard(m['id'] as String, m['zh'] as String, _color(m['color'] as String), [
            for (final i in m['items'] as List)
              () {
                final q = i as Map<String, dynamic>;
                return InsetItem(q['actor'] as String, q['zh'] as String, Offset((q['x'] as num).toDouble(), (q['y'] as num).toDouble()), (q['size'] as num).toDouble(), q['line'] as String);
              }(),
          ]);
        }(),
    ];
    final tangrams = [
      for (final f in tangram['figures'] as List)
        () {
          final m = f as Map<String, dynamic>;
          final eye = m['eye'];
          return TanFigure(m['id'] as String, m['zh'] as String, Level.values.byName(m['level'] as String), m['anim'] as String,
              Size((m['w'] as num).toDouble(), (m['h'] as num).toDouble()), m['lines'] == true, [for (final s in m['slots'] as List) _slot(s as Map<String, dynamic>)],
              eye == null ? null : _pt(eye), (m['eyes'] as num? ?? 1).toInt());
        }(),
    ];
    final cards = [
      for (final c in blocks['cards'] as List)
        () {
          final m = c as Map<String, dynamic>;
          return BlockCard(m['id'] as String, m['zh'] as String, Size((m['w'] as num).toDouble(), (m['h'] as num).toDouble()),
              [for (final s in m['slots'] as List) _slot(s as Map<String, dynamic>)], [for (final s in m['extra'] as List) _slot(s as Map<String, dynamic>)]);
        }(),
    ];
    return Library(
      boxes: boxes,
      insets: insets,
      tanKinds: _kinds(tangram['pieces'] as Map<String, dynamic>),
      tangrams: tangrams,
      blockKinds: _kinds(blocks['kinds'] as Map<String, dynamic>),
      cards: cards,
      taiwan: TaiwanMap(Size((taiwan['w'] as num).toDouble(), (taiwan['h'] as num).toDouble()), _pts(taiwan['outline']), [for (final p in taiwan['pieces'] as List) _pts(p)]),
    );
  }
}
