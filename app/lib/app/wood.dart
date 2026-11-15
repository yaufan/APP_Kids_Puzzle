import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The painted-wood look (docs/art.md 「彩繪木頭」), drawn by Flutter for every shape that is not a
/// picture: a piece is a matt painted slab of wood with a thickness under it, a few fine grain
/// lines, and rounded edges (a light line along the top-left inside, a dark one along the
/// bottom-right); a hole is cut into the board, darker, with its own shadow inside.
abstract final class WoodPaint {
  /// A slab in [color] shaped like [path]; [lifted] when it is in a finger (deeper, with a soft
  /// shadow). [seed] moves the grain about so pieces differ.
  static void piece(Canvas canvas, Path path, Color color, {bool lifted = false, int seed = 0, double depth = 4, bool grain = true}) {
    final b = path.getBounds();
    final d = lifted ? depth * 1.6 : depth;
    if (lifted) {
      canvas.drawPath(path.shift(Offset(d * .8, d * 2)), Paint()
        ..color = Wood.ink.withValues(alpha: .22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    } else {
      canvas.drawPath(path.shift(Offset(d * .3, d * .9)), Paint()..color = Wood.ink.withValues(alpha: .14));
    }
    // The thickness: the same shape, darker, a little lower.
    final side = Color.lerp(color, Wood.deep, .5)!;
    for (var i = d; i > 0; i -= 1.5) {
      canvas.drawPath(path.shift(Offset(0, i)), Paint()..color = side);
    }
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, .18)!, color, Color.lerp(color, Wood.deep, .1)!],
      ).createShader(b));
    if (grain) WoodPaint.grain(canvas, path, color, seed: seed);
    bevel(canvas, path, width: math.min(3.0, math.max(1.2, b.shortestSide * .05)));
  }

  /// Fine wavy grain lines inside [path].
  static void grain(Canvas canvas, Path path, Color color, {int seed = 0, double alpha = .16}) {
    final b = path.getBounds();
    if (b.isEmpty) return;
    final r = math.Random(seed);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(.8, b.shortestSide * .012)
      ..color = Color.lerp(color, Wood.deep, .7)!.withValues(alpha: alpha);
    canvas.save();
    canvas.clipPath(path);
    final gap = math.max(6.0, b.height / 6);
    for (var y = b.top + gap * (.3 + r.nextDouble() * .5); y < b.bottom; y += gap * (.8 + r.nextDouble() * .5)) {
      final line = Path()..moveTo(b.left - 4, y);
      final amp = gap * (.15 + r.nextDouble() * .25), waves = 1 + r.nextInt(2), ph = r.nextDouble() * math.pi * 2;
      for (var x = 0.0; x <= 1.0; x += .1) {
        line.lineTo(b.left - 4 + (b.width + 8) * x, y + amp * math.sin(ph + x * math.pi * 2 * waves));
      }
      canvas.drawPath(line, p);
    }
    canvas.restore();
  }

  /// The rounded edge: light along the top left, dark along the bottom right, inside [path].
  static void bevel(Canvas canvas, Path path, {double width = 2.4}) {
    canvas.save();
    canvas.clipPath(path);
    canvas.drawPath(path.shift(Offset(width * .7, width * .7)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = Colors.white.withValues(alpha: .45));
    canvas.drawPath(path.shift(Offset(-width * .7, -width * .7)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = Wood.deep.withValues(alpha: .35));
    canvas.restore();
  }

  /// A hole shaped like [path] cut into a board of [board] colour.
  static void hole(Canvas canvas, Path path, {Color board = Wood.mid}) {
    final b = path.getBounds();
    canvas.drawPath(path, Paint()..color = Color.lerp(board, Wood.deep, .55)!);
    canvas.save();
    canvas.clipPath(path);
    // The shadow of the board's edge falls into the hole from the top left.
    canvas.drawPath(path.shift(Offset(b.shortestSide * .08 + 2, b.shortestSide * .08 + 2)), Paint()..color = Color.lerp(board, Wood.deep, .35)!);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Wood.deep.withValues(alpha: .4));
    canvas.restore();
    // The cut edge catches the light along the bottom right.
    canvas.save();
    canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(b.inflate(6)), path));
    canvas.drawPath(path.shift(const Offset(1.2, 1.2)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: .5));
    canvas.restore();
  }

  /// A wooden board (a tray, a lid, a frame) filling [rect].
  static void board(Canvas canvas, Rect rect, {Color color = Wood.light, double radius = 22, int seed = 3, double depth = 5}) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    piece(canvas, path, color, seed: seed, depth: depth);
  }
}

/// Paints one wooden shape (a tangram piece, a pattern block, a shape-box shape) filling its box.
class WoodShape extends StatelessWidget {
  const WoodShape({super.key, required this.path, required this.color, this.lifted = false, this.seed = 0, this.depth = 4});

  /// The outline, in the widget's own box.
  final Path path;
  final Color color;
  final bool lifted;
  final int seed;
  final double depth;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _ShapePainter(path, color, lifted, seed, depth));
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.path, this.color, this.lifted, this.seed, this.depth);

  final Path path;
  final Color color;
  final bool lifted;
  final int seed;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) => WoodPaint.piece(canvas, path, color, lifted: lifted, seed: seed, depth: depth);

  @override
  bool shouldRepaint(_ShapePainter old) => old.path != path || old.color != color || old.lifted != lifted;
}

/// A wooden board as a background widget.
class WoodBoard extends StatelessWidget {
  const WoodBoard({super.key, this.color = Wood.light, this.radius = 22, this.child, this.seed = 3});

  final Color color;
  final double radius;
  final Widget? child;
  final int seed;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _BoardPainter(color, radius, seed), child: child);
}

class _BoardPainter extends CustomPainter {
  _BoardPainter(this.color, this.radius, this.seed);

  final Color color;
  final double radius;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) => WoodPaint.board(canvas, Offset.zero & Size(size.width, size.height - 5), color: color, radius: radius, seed: seed);

  @override
  bool shouldRepaint(_BoardPainter old) => old.color != color || old.radius != radius;
}

/// [points] (in some units) as a path scaled by [scale] and moved by [offset].
Path polygonPath(List<Offset> points, {double scale = 1, Offset offset = Offset.zero}) => Path()..addPolygon([for (final p in points) p * scale + offset], true);
