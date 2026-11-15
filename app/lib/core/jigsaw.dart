import 'dart:math' as math;
import 'dart:ui';

import 'content.dart';

/// How a picture is cut (docs/design.md 「塊數的梯子」): straight cuts into 2, 3, 4 or 6, or real
/// jigsaw pieces with knobs, 4 to 24. The same picture can be cut every way.
enum Cut {
  r2(2, 1, false),
  r3(3, 1, false),
  r4(2, 2, false),
  r6(3, 2, false),
  t4(2, 2, true),
  t6(3, 2, true),
  t9(3, 3, true),
  t12(4, 3, true),
  t16(4, 4, true),
  t20(5, 4, true),
  t24(6, 4, true);

  const Cut(this.cols, this.rows, this.tabs);

  final int cols;
  final int rows;
  final bool tabs;

  int get count => cols * rows;

  /// The ladder at each level: a child starts at the first and may always pick a smaller one.
  static List<Cut> ladder(Level l) => switch (l) {
        Level.small => const [r2, r3, r4],
        Level.middle => const [r4, r6, t4, t6, t9, t12],
        Level.big => const [t9, t12, t16, t20, t24],
      };

  /// Pictures done at one size before the next size is offered.
  static const toNext = 3;
}

/// Where a piece sits in its picture (the tray gives corners and edges first for 12 or more).
enum Part { corner, edge, middle }

/// One piece of a cut picture: its cell, the outline (in the piece's own box, which is the cell
/// with room for knobs all round) and where it is in the picture.
class JigsawPiece {
  JigsawPiece(this.col, this.row, this.cell, this.margin, this.outline, this.part);

  final int col;
  final int row;

  /// The cell in the 400 × 300 picture.
  final Rect cell;

  /// Room for knobs around the cell.
  final double margin;

  /// The outline in the piece's own box (0,0 is the cell's top left minus the margin).
  final List<Offset> outline;
  final Part part;

  String get id => '$col-$row';

  Size get size => Size(cell.width + 2 * margin, cell.height + 2 * margin);

  Offset get center => cell.center;

  /// The picture's top left in the piece's own box.
  Offset get pictureAt => Offset(margin - cell.left, margin - cell.top);

  Path get path => Path()..addPolygon(outline, true);
}

/// Cuts a picture: every edge between two pieces gets a knob that sticks out of one and into the
/// other, its side and size from a fixed seed (the picture's id), so a picture is always cut the
/// same way.
class Jigsaw {
  Jigsaw(this.pictureId, this.cut, {this.size = Picture.size}) {
    final w = size.width / cut.cols, h = size.height / cut.rows;
    _tab = math.min(w, h) * .2;
    final r = math.Random(_seed('$pictureId/${cut.name}'));
    // _h[r][c]: the edge under row r, column c; _v[r][c]: the edge right of column c, row r.
    _h = [for (var y = 0; y < cut.rows - 1; y++) [for (var x = 0; x < cut.cols; x++) _Knob.random(r)]];
    _v = [for (var y = 0; y < cut.rows; y++) [for (var x = 0; x < cut.cols - 1; x++) _Knob.random(r)]];
    pieces = [
      for (var y = 0; y < cut.rows; y++)
        for (var x = 0; x < cut.cols; x++) _piece(x, y, w, h),
    ];
  }

  final String pictureId;
  final Cut cut;

  /// The picture's size.
  final Size size;
  late final double _tab;
  late final List<List<_Knob>> _h, _v;
  late final List<JigsawPiece> pieces;

  static int _seed(String s) {
    var h = 17;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h;
  }

  /// Room around a cell for the knobs.
  double get margin => cut.tabs ? _tab * 1.25 : 0;

  JigsawPiece _piece(int x, int y, double w, double h) {
    final cell = Rect.fromLTWH(x * w, y * h, w, h);
    final m = margin;
    final o = Offset(m - cell.left, m - cell.top);
    final tl = cell.topLeft, tr = cell.topRight, br = cell.bottomRight, bl = cell.bottomLeft;
    final pts = <Offset>[
      ..._edge(tl, tr, y == 0 || !cut.tabs ? null : _h[y - 1][x], vertical: false),
      ..._edge(tr, br, x == cut.cols - 1 || !cut.tabs ? null : _v[y][x], vertical: true).skip(1),
      ..._edge(bl, br, y == cut.rows - 1 || !cut.tabs ? null : _h[y][x], vertical: false).toList().reversed.skip(1),
      ..._edge(tl, bl, x == 0 || !cut.tabs ? null : _v[y][x - 1], vertical: true).toList().reversed.skip(1),
    ];
    pts.removeLast();
    final onX = x == 0 || x == cut.cols - 1, onY = y == 0 || y == cut.rows - 1;
    return JigsawPiece(x, y, cell, m, [for (final p in pts) p + o], onX && onY ? Part.corner : (onX || onY ? Part.edge : Part.middle));
  }

  /// The points along an edge from [a] to [b] (left to right, or top to bottom), with [k]'s knob
  /// bulging down (or right) when its side is +1.
  List<Offset> _edge(Offset a, Offset b, _Knob? k, {required bool vertical}) {
    if (k == null) return [a, b];
    final len = (b - a).distance;
    final dir = (b - a) / len;
    final normal = vertical ? const Offset(1, 0) : const Offset(0, 1);
    final s = _tab * k.size;
    final mid = len * (.5 + k.shift);
    Offset at(double u, double v) => a + dir * u + normal * (v * k.side);
    final out = <Offset>[at(0, 0), at(mid - .5 * s, 0), at(mid - .4 * s, .14 * s)];
    const steps = 18;
    final c = Offset(mid, .64 * s), rad = .44 * s;
    final a0 = math.atan2(.3 * s - .64 * s, -.32 * s), a1 = math.atan2(.3 * s - .64 * s, .32 * s);
    // From the left side of the knob over its top (v largest) to the right side.
    final start = a0 < 0 ? a0 + 2 * math.pi : a0;
    final end = a1;
    for (var i = 0; i <= steps; i++) {
      final t = start + (end - start) * i / steps;
      out.add(at(c.dx + rad * math.cos(t), c.dy + rad * math.sin(t)));
    }
    out.addAll([at(mid + .4 * s, .14 * s), at(mid + .5 * s, 0), at(len, 0)]);
    return out;
  }

  /// The tray's order: corners, then edges, then the middle (each shuffled) when [edgesFirst]; all
  /// shuffled otherwise.
  List<JigsawPiece> order(math.Random r, {required bool edgesFirst}) {
    if (!edgesFirst) return [...pieces]..shuffle(r);
    return [
      for (final part in Part.values) ...[for (final p in pieces) if (p.part == part) p]..shuffle(r),
    ];
  }
}

class _Knob {
  _Knob(this.side, this.size, this.shift);

  factory _Knob.random(math.Random r) => _Knob(r.nextBool() ? 1 : -1, .9 + r.nextDouble() * .2, (r.nextDouble() - .5) * .1);

  final double side;
  final double size;
  final double shift;
}
