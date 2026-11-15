import 'dart:math' as math;
import 'dart:ui';

import 'content.dart';

/// The shapes of the shape box (docs/design.md 「形狀盒」), each with its colour, drawn in a box one
/// unit across centred on 0,0.
enum ToyShape {
  circle('圓形', '圓圓的', Color(0xFFE2574C)),
  square('正方形', '方方的', Color(0xFF3F95D1)),
  triangle('三角形', '尖尖的', Color(0xFFF2C94C)),
  star('星星', '有五個角的', Color(0xFFF2994A)),
  heart('愛心', '紅紅的', Color(0xFFEB7FA6)),
  moon('月亮', '彎彎的', Color(0xFF9B7FD4)),
  rectangle('長方形', '長長的', Color(0xFF2FA6A0)),
  oval('橢圓形', '扁扁的', Color(0xFF6FAE4E)),
  trapezoid('梯形', '像小山的', Color(0xFFB9784A));

  const ToyShape(this.zh, this.look, this.color);

  final String zh;
  final String look;
  final Color color;

  /// The shape's outline, [size] across, centred on 0,0.
  Path path(double size) {
    final s = size / 2;
    switch (this) {
      case circle:
        return Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: s * .86));
      case square:
        return Path()..addRect(Rect.fromCenter(center: Offset.zero, width: s * 1.5, height: s * 1.5));
      case rectangle:
        return Path()..addRect(Rect.fromCenter(center: Offset.zero, width: s * 1.9, height: s * 1.05));
      case oval:
        return Path()..addOval(Rect.fromCenter(center: Offset.zero, width: s * 1.95, height: s * 1.2));
      case triangle:
        return Path()..addPolygon([Offset(0, -s * .9), Offset(s * .95, s * .72), Offset(-s * .95, s * .72)], true);
      case trapezoid:
        return Path()..addPolygon([Offset(-s * .5, -s * .55), Offset(s * .5, -s * .55), Offset(s * .98, s * .6), Offset(-s * .98, s * .6)], true);
      case star:
        return Path()
          ..addPolygon([
            for (var i = 0; i < 10; i++)
              Offset(math.cos(-math.pi / 2 + i * math.pi / 5) * (i.isEven ? s * .98 : s * .45), math.sin(-math.pi / 2 + i * math.pi / 5) * (i.isEven ? s * .98 : s * .45) + s * .06),
          ], true);
      case heart:
        final w = s * 1.9, h = s * 1.75;
        final x0 = 0.0, y0 = -h * .28;
        return Path()
          ..moveTo(x0, y0)
          ..cubicTo(x0 + w * .1, y0 - h * .32, x0 + w * .5, y0 - h * .3, x0 + w * .5, y0 + h * .06)
          ..cubicTo(x0 + w * .5, y0 + h * .4, x0 + w * .15, y0 + h * .56, x0, y0 + h * .78)
          ..cubicTo(x0 - w * .15, y0 + h * .56, x0 - w * .5, y0 + h * .4, x0 - w * .5, y0 + h * .06)
          ..cubicTo(x0 - w * .5, y0 - h * .3, x0 - w * .1, y0 - h * .32, x0, y0)
          ..close();
      case moon:
        final outer = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: s * .92));
        final inner = Path()..addOval(Rect.fromCircle(center: Offset(s * .5, -s * .28), radius: s * .78));
        return Path.combine(PathOperation.difference, outer, inner);
    }
  }
}

/// The shape box's rounds: 小小 adds one hole a round, 1 to 6; 中 and 大 put look-alikes side by
/// side (正方形 and 長方形, 圓形 and 橢圓形, 三角形 and 梯形).
abstract final class ShapeRounds {
  static const small = [
    [ToyShape.circle],
    [ToyShape.circle, ToyShape.square],
    [ToyShape.circle, ToyShape.square, ToyShape.triangle],
    [ToyShape.circle, ToyShape.square, ToyShape.triangle, ToyShape.star],
    [ToyShape.circle, ToyShape.square, ToyShape.triangle, ToyShape.star, ToyShape.heart],
    [ToyShape.circle, ToyShape.square, ToyShape.triangle, ToyShape.star, ToyShape.heart, ToyShape.moon],
  ];

  static const alike = [
    [ToyShape.square, ToyShape.rectangle],
    [ToyShape.circle, ToyShape.oval],
    [ToyShape.triangle, ToyShape.trapezoid],
    [ToyShape.circle, ToyShape.oval, ToyShape.square, ToyShape.rectangle],
    [ToyShape.triangle, ToyShape.trapezoid, ToyShape.star, ToyShape.heart],
    [ToyShape.square, ToyShape.rectangle, ToyShape.circle, ToyShape.oval, ToyShape.triangle, ToyShape.trapezoid],
  ];

  static List<List<ToyShape>> of(Level l) => l == Level.small ? small : alike;

  static const lid = Size(400, 300);

  /// Where the holes of a round with [n] shapes go on the 400 × 300 lid, and how big they are.
  static (List<Offset>, double) holes(int n) {
    final cols = n <= 3 ? n : (n == 4 ? 2 : 3);
    final rows = (n + cols - 1) ~/ cols;
    final size = math.min(lid.width / cols, lid.height / rows) * .7;
    final out = <Offset>[];
    for (var i = 0; i < n; i++) {
      final r = i ~/ cols, c = i % cols;
      final inRow = r == rows - 1 ? n - r * cols : cols;
      final w = lid.width / inRow;
      out.add(Offset(w * (c + .5), lid.height / rows * (r + .5)));
    }
    return (out, math.min(size, 150));
  }
}
