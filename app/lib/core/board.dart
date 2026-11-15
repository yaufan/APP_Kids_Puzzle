import 'dart:math' as math;
import 'dart:ui';

import 'content.dart';

/// How pieces turn (docs/design.md 「轉動和翻面」): not at all (小小, every piece already the
/// right way round), by themselves when let go near their place (中), or a tap turns them 45
/// degrees and the parallelogram has a flip button (大).
enum Turning { none, auto, tap }

/// How strongly a place pulls a piece in (parent mode).
enum Magnet {
  strong('強', 1.3),
  normal('中', 1),
  weak('弱', .75);

  const Magnet(this.zh, this.factor);

  final String zh;
  final double factor;
}

/// A place on a board where a piece of [kind] goes.
class Slot {
  Slot({required this.id, required this.kind, required this.at, this.angle = 0, this.flip = false, this.symmetry = 360, this.chiral = false, List<String>? cells, this.outline})
      : cells = cells == null || cells.isEmpty ? [id] : cells;

  final String id;
  final String kind;

  /// Its middle, in the board's units.
  final Offset at;

  /// The turn (degrees, clockwise) and mirroring a piece needs there.
  final double angle;
  final bool flip;

  /// How far the piece turns before it looks the same again.
  final int symmetry;

  /// Whether mirroring the piece makes a different shape (the parallelogram).
  final bool chiral;

  /// The bits of the picture it fills; two places that share one cannot both be filled.
  final List<String> cells;

  /// Its outline in the board's units (for the glow and the hint), if known.
  final Path? outline;
}

/// A piece in play.
class Piece {
  Piece({required this.id, required this.kind, required this.size, this.angle = 0, this.flip = false});

  final String id;
  final String kind;

  /// Its box in the board's units (as drawn, before turning).
  final Size size;
  double angle;
  bool flip;

  double get reach => math.max(size.width, size.height);
}

/// Where a piece was let go: the place it goes (and whether it is turned the right way).
class Fit {
  const Fit(this.slot, {this.turnedRight = true});

  final Slot slot;
  final bool turnedRight;
}

/// The pieces in their places: what is filled and whether the whole board is done. Pure logic, no
/// widgets (test/rules_test.dart plays it).
class Board {
  Board(this.slots, {Set<String>? need}) : need = need ?? {for (final s in slots) ...s.cells};

  final List<Slot> slots;

  /// The cells that have to be filled for the board to be done.
  final Set<String> need;
  final covered = <String>{};

  /// Piece id → the place it is in.
  final placed = <String, Slot>{};

  bool isFree(Slot s) => s.cells.every((c) => !covered.contains(c));

  bool get done => need.every(covered.contains);

  int get left => need.where((c) => !covered.contains(c)).length;

  /// The nearest free place for [p] within [radius] of [at] (the nearest wins when two are in
  /// reach, so two places never fight over a piece). With [checkTurn], the fit says whether the
  /// piece is turned (and mirrored) the right way for it; of two places of the same shape in
  /// reach (the tangram's two big triangles), the one the piece is already turned right for wins.
  Fit? fit(Piece p, Offset at, double radius, {bool checkTurn = false}) {
    Slot? best, turned;
    var bestD = double.infinity, turnedD = double.infinity;
    for (final s in slots) {
      if (s.kind != p.kind || !isFree(s)) continue;
      final d = (s.at - at).distance;
      if (d > radius) continue;
      if (d < bestD) {
        best = s;
        bestD = d;
      }
      if (checkTurn && d < turnedD && sameTurn(p.angle, p.flip, s)) {
        turned = s;
        turnedD = d;
      }
    }
    if (turned != null) return Fit(turned);
    if (best == null) return null;
    return Fit(best, turnedRight: !checkTurn);
  }

  /// Whether a piece at [angle] (mirrored if [flip]) looks like the one [s] needs (within 10°).
  static bool sameTurn(double angle, bool flip, Slot s) {
    if (s.chiral && flip != s.flip) return false;
    final d = ((angle - s.angle) % s.symmetry + s.symmetry) % s.symmetry;
    return d < 10 || d > s.symmetry - 10;
  }

  /// [angle] moved by whole turns of the symmetry so it is as close as possible to [from] (so a
  /// piece turning itself upright takes the short way round).
  static double nearestTurn(double angle, double from, int symmetry) {
    var a = angle;
    while (a - from > symmetry / 2) {
      a -= symmetry;
    }
    while (from - a > symmetry / 2) {
      a += symmetry;
    }
    return a;
  }

  void place(Piece p, Slot s) {
    covered.addAll(s.cells);
    placed[p.id] = s;
    p.flip = s.flip;
    p.angle = nearestTurn(s.angle, p.angle, s.symmetry);
  }

  /// A free place for [p] (the hint): the nearest to [near] if given.
  Slot? home(Piece p, {Offset? near}) {
    Slot? best;
    var bestD = double.infinity;
    for (final s in slots) {
      if (s.kind != p.kind || !isFree(s)) continue;
      final d = near == null ? 0.0 : (s.at - near).distance;
      if (best == null || d < bestD) {
        best = s;
        bestD = d;
      }
    }
    return best;
  }
}

/// The tray under the board (docs/design.md 「塊從哪裡來」): six pieces at a time, the next one
/// coming into the place of the one put on the board; or, for the pattern blocks, one stack per
/// kind of block with how many are left.
class Tray {
  Tray(List<Piece> order, {this.size = 6, this.stacks = false}) : _queue = [...order] {
    if (stacks) {
      for (final p in _queue) {
        if (!_kinds.contains(p.kind)) _kinds.add(p.kind);
      }
    } else {
      cells = List<Piece?>.filled(size, null);
      for (var i = 0; i < size && _queue.isNotEmpty; i++) {
        cells[i] = _queue.removeAt(0);
      }
    }
  }

  final int size;
  final bool stacks;
  final List<Piece> _queue;
  final _kinds = <String>[];
  final _used = <String>{};
  late List<Piece?> cells;

  /// The pieces a child can pick up, with their place in the tray.
  List<(int, Piece)> get shown {
    if (!stacks) return [for (var i = 0; i < cells.length; i++) if (cells[i] != null) (i, cells[i]!)];
    final out = <(int, Piece)>[];
    for (var i = 0; i < _kinds.length; i++) {
      final p = _queue.where((p) => p.kind == _kinds[i] && !_used.contains(p.id)).firstOrNull;
      if (p != null) out.add((i, p));
    }
    return out;
  }

  /// How many places the tray shows.
  int get places => stacks ? _kinds.length : size;

  /// How many of [kind] are still in its stack.
  int count(String kind) => _queue.where((p) => p.kind == kind && !_used.contains(p.id)).length;

  /// The pieces not put on the board yet (shown or waiting).
  int get waiting => stacks ? _queue.where((p) => !_used.contains(p.id)).length : _queue.length + cells.whereType<Piece>().length;

  /// [p] went onto the board: the next piece comes into its place.
  void take(Piece p) {
    if (stacks) {
      _used.add(p.id);
      return;
    }
    final i = cells.indexWhere((c) => c?.id == p.id);
    if (i < 0) return;
    cells[i] = _queue.isEmpty ? null : _queue.removeAt(0);
  }
}

/// The finger rules (docs/design.md 「點和拖分得開」): a touch that hardly moved and was short is a
/// tap; anything else is a drag.
abstract final class Touch {
  static const tapMove = 10.0;
  static const tapTime = Duration(milliseconds: 250);

  static bool isTap(Offset moved, Duration held) => moved.distance < tapMove && held < tapTime;

  /// Nothing goes nearer than this to the screen's edges (the phone's back gesture).
  static const edge = 24.0;

  /// [p] kept inside [area] less the edge.
  static Offset clamp(Offset p, Size area) => Offset(
        p.dx.clamp(edge, math.max(edge, area.width - edge)),
        p.dy.clamp(edge, math.max(edge, area.height - edge)),
      );

  /// How near (in screen points) a piece of [pieceSize] points must be let go to be pulled in:
  /// 小小 about a whole piece (at least 70), 中 half, 大 a third (at least 28).
  static double magnet(Level l, Magnet m, double pieceSize) {
    final r = switch (l) {
      Level.small => math.max(70.0, pieceSize),
      Level.middle => math.max(44.0, pieceSize * .5),
      Level.big => math.max(28.0, pieceSize * .34),
    };
    return r * m.factor;
  }

  /// Small pieces float a little above the finger so it does not hide them.
  static double lift(double pieceSize) => pieceSize < 80 ? 34 : 0;
}
