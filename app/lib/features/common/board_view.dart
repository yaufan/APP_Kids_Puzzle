import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/wood.dart';
import '../../core/board.dart';
import '../../core/content.dart';
import '../../core/providers.dart';

/// Draws a piece at [scale] screen points per board unit, unturned: a box of `piece.size * scale`.
typedef PieceBuilder = Widget Function(Piece piece, double scale, bool lifted);

/// Draws what is under the pieces (the frame, the holes, the shadow) in a box of
/// `boardSize * scale`.
typedef BackBuilder = Widget Function(BuildContext context, double scale);

/// The play area of every puzzle (docs/design.md 「手指的規則」): the board on top, the tray under
/// it. Raw pointer events: a piece follows the finger the moment it is touched; only the first
/// finger counts; a cancelled touch puts the piece back. A piece let go near a place it fits is
/// pulled in ("咻—咔"); anywhere else it floats back to its spot in the tray. A short tap picks a
/// piece and a tap on its place sends it there (for children who cannot drag yet); with
/// [Turning.tap] a tap turns the piece instead.
class PuzzleBoard extends ConsumerStatefulWidget {
  const PuzzleBoard({
    super.key,
    required this.board,
    required this.pieces,
    required this.boardSize,
    required this.back,
    required this.pieceView,
    this.turning = Turning.none,
    this.stacks = false,
    this.placeSound = 'snap',
    this.onPlaced,
    this.onDone,
    this.onMiss,
    this.onWrongTurn,
    this.onHelpTurn,
    this.hintAfter,
    this.hint,
    this.trayColor = Wood.mid,
    this.countDots = false,
  });

  final Board board;

  /// The pieces, in the order the tray gives them.
  final List<Piece> pieces;
  final Size boardSize;
  final BackBuilder back;
  final PieceBuilder pieceView;
  final Turning turning;

  /// The tray holds one stack per kind (照著拼) instead of six pieces at a time.
  final bool stacks;
  final String placeSound;
  final void Function(Piece piece, Slot slot)? onPlaced;
  final VoidCallback? onDone;
  final void Function(Piece piece)? onMiss;
  final void Function(Piece piece, Slot slot)? onWrongTurn;
  final void Function(Piece piece)? onHelpTurn;

  /// A place lights up after this long without a piece put down (null: never).
  final Duration? hintAfter;

  /// Bumped by the screen to light up a place now (the helper's paw).
  final ValueNotifier<int>? hint;
  final Color trayColor;

  /// Show how many are left in each stack as dots.
  final bool countDots;

  @override
  ConsumerState<PuzzleBoard> createState() => PuzzleBoardState();
}

class PuzzleBoardState extends ConsumerState<PuzzleBoard> {
  late final Tray _tray = Tray(widget.pieces, stacks: widget.stacks, size: math.max(1, math.min(6, widget.pieces.length)), placed: widget.board.placed.keys.toSet());
  final _anim = <String, Duration>{};
  final _hops = <String, int>{};
  final _misses = <String, int>{};
  final _wrongTurns = <String, int>{};
  final _glow = <String>{};
  Slot? _near;
  (Slot, Piece)? _ghost;
  Timer? _ghostTimer, _hintTimer, _doneTimer;

  int? _pointer;
  Piece? _held;
  Offset _heldAt = Offset.zero;
  Offset _downAt = Offset.zero;
  DateTime _downTime = DateTime(0);
  Piece? _selected;
  AppLifecycleListener? _life;
  _Layout? _layout;
  var _over = false;

  @override
  void initState() {
    super.initState();
    _restartHint();
    widget.hint?.addListener(_showHint);
    // The app went away mid-drag: the piece goes back, and the finger is forgotten (its lift may
    // never come), so the next touch can pick a piece.
    _life = AppLifecycleListener(onHide: () {
      _pointer = null;
      _cancelHold();
    });
  }

  @override
  void dispose() {
    widget.hint?.removeListener(_showHint);
    _ghostTimer?.cancel();
    _hintTimer?.cancel();
    _doneTimer?.cancel();
    _life?.dispose();
    super.dispose();
  }

  Board get board => widget.board;

  /// The pieces still in the tray (tests and the screens look at them).
  List<Piece> get trayPieces => [for (final (_, p) in _tray.shown) p];

  /// The places lit up now (tests).
  Set<String> get glowing => {..._glow};

  void _sfx(String s) => ref.read(soundsProvider).play(s);

  // ---------------------------------------------------------------- for tests and the demo video
  Offset _global(Offset local) => (context.findRenderObject()! as RenderBox).localToGlobal(local);

  /// Screen points per board unit.
  double get scale => _layout!.scale;

  /// Where [p] is drawn now (its middle), on the screen.
  Offset pieceAt(Piece p) => _global(_where(p, _layout!).$1);

  /// Where a finger has to let [p] go for it to land on [s] (small pieces float above the finger).
  Offset fingerFor(Piece p, Slot s) {
    final l = _layout!;
    return _global(l.board.topLeft + s.at * l.scale + Offset(0, Touch.lift(p.reach * l.scale)));
  }

  /// The flip button next to [p] in the tray.
  Offset? flipAt(Piece p) {
    final cell = _cellOf(p);
    return cell == null ? null : _global(_flipButton(cell, _layout!).center);
  }

  // ---------------------------------------------------------------- hints
  void _restartHint() {
    _hintTimer?.cancel();
    final d = widget.hintAfter;
    if (d == null || _over) return;
    _hintTimer = Timer(d, _showHint);
  }

  void _showHint() {
    if (!mounted || _over) return;
    // The picked piece's place, or the first piece in the tray that still has one (照著拼 at 大:
    // a stack can have blocks left that fit nowhere any more, while the next stack's do).
    Piece? p;
    Slot? s;
    for (final q in [?_selected, for (final (_, q) in _tray.shown) q]) {
      s = board.home(q);
      if (s != null) {
        p = q;
        break;
      }
    }
    final piece = p, place = s;
    if (piece == null || place == null) return;
    setState(() {
      _glow
        ..clear()
        ..add(place.id);
      _hops[piece.id] = (_hops[piece.id] ?? 0) + 1;
    });
  }

  // ---------------------------------------------------------------- geometry
  double _magnet(Piece p, _Layout l) {
    final s = ref.read(gameProvider).settings;
    return Touch.magnet(s.level, s.magnet, p.reach * l.scale) / l.scale;
  }

  Offset _toBoard(Offset screen, _Layout l) => (screen - l.board.topLeft) / l.scale;

  /// Where [p] is drawn now (its middle) and how big.
  (Offset, double) _where(Piece p, _Layout l) {
    final placed = board.placed[p.id];
    if (placed != null) return (l.board.topLeft + placed.at * l.scale, 1);
    if (identical(p, _held)) return (_heldAt, 1.04);
    final cell = _cellOf(p);
    if (cell == null) return (l.board.center, 0);
    return (l.cells[cell].center, l.trayScale(p));
  }

  int? _cellOf(Piece p) {
    for (final (i, q) in _tray.shown) {
      if (q.id == p.id) return i;
    }
    return null;
  }

  Rect _flipButton(int cell, _Layout l) {
    final c = l.cells[cell];
    return Rect.fromCenter(center: c.bottomRight - const Offset(24, 24), width: 48, height: 48);
  }

  Piece? _pieceAt(Offset at, _Layout l) {
    Piece? best;
    var bestD = double.infinity;
    for (final (i, p) in _tray.shown) {
      final c = l.cells[i];
      if (!c.inflate(4).contains(at)) continue;
      final d = (c.center - at).distance;
      if (d < bestD) {
        best = p;
        bestD = d;
      }
    }
    return best;
  }

  // ---------------------------------------------------------------- fingers
  void _down(PointerDownEvent e) {
    // Only the finger holding a piece counts: a second finger or a palm never takes it away. A
    // finger or palm that touched first but holds nothing (resting on the board) does not stop
    // the next finger from picking a piece; the newest such touch is the one followed.
    if (_held != null || _over) return;
    final l = _layout;
    if (l == null) return;
    _pointer = e.pointer;
    _downAt = e.localPosition;
    _downTime = DateTime.now();
    final p = _pieceAt(e.localPosition, l);
    if (p == null) return;
    if (widget.turning == Turning.tap && p.kind == 'P') {
      final cell = _cellOf(p);
      if (cell != null && _flipButton(cell, l).contains(e.localPosition)) return;
    }
    _sfx('pick');
    setState(() {
      _held = p;
      _anim[p.id] = Duration.zero;
      _heldAt = Touch.clamp(e.localPosition - Offset(0, Touch.lift(p.reach * l.scale)), l.size);
    });
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    final p = _held, l = _layout;
    if (p == null || l == null) return;
    final at = Touch.clamp(e.localPosition - Offset(0, Touch.lift(p.reach * l.scale)), l.size);
    final fit = board.fit(p, _toBoard(at, l), _magnet(p, l));
    final near = fit?.slot;
    if (near != null && near.id != _near?.id) _sfx('near');
    setState(() {
      _heldAt = at;
      _near = near;
    });
  }

  void _up(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    final l = _layout;
    if (l == null) return;
    final p = _held;
    final tap = Touch.isTap(e.localPosition - _downAt, DateTime.now().difference(_downTime));
    if (p != null) {
      _held = null;
      _near = null;
      if (tap) {
        _back(p, quick: true);
        _tapPiece(p);
      } else {
        _drop(p, _heldAt, l);
      }
      return;
    }
    if (!tap) return;
    // A tap on the flip button, or on the board with a piece picked.
    if (widget.turning == Turning.tap) {
      for (final (i, q) in _tray.shown) {
        if (q.kind == 'P' && _flipButton(i, l).contains(e.localPosition)) {
          _sfx('flip');
          setState(() {
            q.flip = !q.flip;
            _anim[q.id] = const Duration(milliseconds: 250);
          });
          return;
        }
      }
    }
    final sel = _selected;
    if (sel == null || !l.board.inflate(24).contains(e.localPosition)) return;
    setState(() => _selected = null);
    final fit = board.fit(sel, _toBoard(e.localPosition, l), _magnet(sel, l) * 1.6);
    if (fit != null) {
      _place(sel, fit.slot, l);
    } else {
      _miss(sel);
    }
  }

  void _cancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _cancelHold();
  }

  /// The app went away, or the touch was taken over: the piece goes back to the tray (no miss).
  void _cancelHold() {
    final p = _held;
    if (p == null || !mounted) return;
    setState(() {
      _held = null;
      _near = null;
    });
    _back(p);
  }

  void _tapPiece(Piece p) {
    if (widget.turning == Turning.tap) {
      _sfx('turn');
      setState(() {
        p.angle += 45;
        _anim[p.id] = const Duration(milliseconds: 220);
      });
      return;
    }
    setState(() {
      _selected = identical(_selected, p) ? null : p;
      _hops[p.id] = (_hops[p.id] ?? 0) + 1;
    });
  }

  void _back(Piece p, {bool quick = false}) {
    setState(() => _anim[p.id] = Duration(milliseconds: quick ? 160 : 400));
  }

  void _drop(Piece p, Offset at, _Layout l) {
    final fit = board.fit(p, _toBoard(at, l), _magnet(p, l), checkTurn: widget.turning == Turning.tap);
    if (fit == null) {
      _miss(p);
      return;
    }
    if (!fit.turnedRight) {
      _sfx('back');
      _back(p);
      final n = _wrongTurns[p.id] = (_wrongTurns[p.id] ?? 0) + 1;
      _ghostTimer?.cancel();
      setState(() => _ghost = (fit.slot, p));
      _ghostTimer = Timer(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _ghost = null);
      });
      if (n >= 2) {
        // The helper turns it the right way.
        setState(() {
          p.angle = Board.nearestTurn(fit.slot.angle, p.angle, fit.slot.symmetry);
          p.flip = fit.slot.flip;
          _anim[p.id] = const Duration(milliseconds: 500);
        });
        _wrongTurns[p.id] = 0;
        widget.onHelpTurn?.call(p);
      } else {
        widget.onWrongTurn?.call(p, fit.slot);
      }
      return;
    }
    _place(p, fit.slot, l);
  }

  void _miss(Piece p) {
    _sfx('back');
    _back(p);
    final n = _misses[p.id] = (_misses[p.id] ?? 0) + 1;
    if (n >= 3) {
      final s = board.home(p);
      if (s != null) setState(() => _glow.add(s.id));
    }
    widget.onMiss?.call(p);
  }

  void _place(Piece p, Slot s, _Layout l) {
    _sfx(widget.placeSound);
    setState(() {
      board.place(p, s);
      _tray.take(p);
      _anim[p.id] = const Duration(milliseconds: 220);
      _glow.remove(s.id);
      _glow.removeWhere((id) => !board.isFree(board.slots.firstWhere((x) => x.id == id)));
      if (identical(_selected, p)) _selected = null;
      _misses.remove(p.id);
      _hops[p.id] = (_hops[p.id] ?? 0) + 1;
    });
    widget.onPlaced?.call(p, s);
    _restartHint();
    if (board.done && !_over) {
      _over = true;
      _hintTimer?.cancel();
      _doneTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted) widget.onDone?.call();
      });
    }
  }

  // ---------------------------------------------------------------- drawing
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final l = _layout = _Layout(Size(box.maxWidth, box.maxHeight), widget.boardSize, _tray.places, widget.pieces);
        final back = Positioned.fromRect(rect: l.board, child: widget.back(context, l.scale));
        final glow = Positioned.fromRect(
          rect: l.board,
          child: IgnorePointer(child: CustomPaint(painter: _GlowPainter(board, {..._glow, ?_near?.id}, l.scale, _ghost?.$1))),
        );
        final placed = <Widget>[], tray = <Widget>[];
        final heldId = _held?.id;
        Widget? held;
        for (final p in widget.pieces) {
          final inBoard = board.placed.containsKey(p.id);
          final cell = _cellOf(p);
          if (!inBoard && cell == null && p.id != heldId) continue;
          final (at, s) = _where(p, l);
          final w = p.size.width * l.scale, h = p.size.height * l.scale;
          final lifted = p.id == heldId;
          final child = AnimatedPositioned(
            key: ValueKey('piece-${p.id}'),
            duration: _anim[p.id] ?? Duration.zero,
            curve: Curves.easeOutCubic,
            left: at.dx - w / 2,
            top: at.dy - h / 2,
            width: w,
            height: h,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: s,
                duration: lifted ? const Duration(milliseconds: 90) : (_anim[p.id] ?? Duration.zero),
                child: _Hopper(
                  trigger: _hops[p.id] ?? 0,
                  selected: identical(_selected, p),
                  child: AnimatedRotation(
                    turns: p.angle / 360,
                    duration: _anim[p.id] ?? Duration.zero,
                    child: Transform.flip(flipX: p.flip, child: widget.pieceView(p, l.scale, lifted)),
                  ),
                ),
              ),
            ),
          );
          if (lifted) {
            held = child;
          } else if (inBoard) {
            placed.add(child);
          } else {
            tray.add(child);
          }
        }
        final trayBack = Positioned.fromRect(rect: l.tray, child: IgnorePointer(child: CustomPaint(painter: _TrayPainter(widget.trayColor))));
        final extras = <Widget>[
          if (widget.turning == Turning.tap)
            for (final (i, p) in _tray.shown)
              if (p.kind == 'P' && p.id != heldId)
                Positioned.fromRect(
                  rect: _flipButton(i, l).deflate(4),
                  child: IgnorePointer(
                    child: Semantics(
                      label: '翻過來',
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Wood.blue, width: 2.5)),
                        child: const Icon(Icons.flip_rounded, color: Wood.blue, size: 24),
                      ),
                    ),
                  ),
                ),
          if (widget.turning == Turning.tap)
            for (final (i, p) in _tray.shown)
              if (p.id != heldId)
                Positioned(
                  left: l.cells[i].left + 4,
                  top: l.cells[i].top + 4,
                  child: const IgnorePointer(child: Icon(Icons.rotate_right_rounded, color: Wood.deep, size: 22)),
                ),
          if (widget.countDots)
            for (final (i, p) in _tray.shown)
              Positioned(
                left: l.cells[i].left,
                width: l.cells[i].width,
                bottom: l.size.height - l.cells[i].bottom - 2,
                child: IgnorePointer(child: _Dots(_tray.count(p.kind))),
              ),
        ];
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: Stack(clipBehavior: Clip.none, children: [back, trayBack, ...placed, glow, ...tray, ...extras, ?held]),
        );
      });
}

class _Layout {
  _Layout(this.size, this.boardSize, int places, List<Piece> pieces) {
    final trayH = (size.height * .3).clamp(140.0, 330.0);
    final cols = places <= 3 ? places : (places == 4 ? 4 : 3);
    final rows = places <= 4 ? 1 : 2;
    tray = Rect.fromLTWH(12, size.height - trayH, size.width - 24, trayH - 8);
    final cw = (tray.width - 12) / math.max(cols, 1), ch = (tray.height - 12) / rows;
    cells = [
      for (var i = 0; i < math.max(places, 1); i++)
        Rect.fromLTWH(tray.left + 6 + cw * (i % cols), tray.top + 6 + ch * (i ~/ cols), cw, ch),
    ];
    final area = Rect.fromLTWH(Touch.edge, 8, size.width - 2 * Touch.edge, size.height - trayH - 16);
    scale = math.min(area.width / boardSize.width, area.height / boardSize.height);
    final bw = boardSize.width * scale, bh = boardSize.height * scale;
    board = Rect.fromLTWH(area.left + (area.width - bw) / 2, area.top + (area.height - bh) / 2, bw, bh);
    for (final p in pieces) {
      _reach = math.max(_reach, p.reach);
    }
  }

  final Size size;
  final Size boardSize;
  late final Rect tray;
  late final List<Rect> cells;
  late final double scale;
  late final Rect board;
  var _reach = 0.0;

  /// How much smaller a piece is in the tray (all pieces by the same amount, so sizes compare).
  double trayScale(Piece p) {
    if (cells.isEmpty) return 1;
    // A piece's box has room to turn in; the piece itself is smaller, so it may fill the cell.
    final cell = cells.first.shortestSide;
    return math.min(1.0, cell / (_reach * scale * .9));
  }
}

class _Hopper extends StatefulWidget {
  const _Hopper({required this.trigger, required this.selected, required this.child});

  final int trigger;
  final bool selected;
  final Widget child;

  @override
  State<_Hopper> createState() => _HopperState();
}

class _HopperState extends State<_Hopper> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void didUpdateWidget(_Hopper old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final up = math.sin(_c.value * math.pi) * 16;
          return Transform.translate(
            offset: Offset(0, -up - (widget.selected ? 8 : 0)),
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: widget.selected ? [BoxShadow(color: Wood.glow.withValues(alpha: .9), blurRadius: 14, spreadRadius: 2)] : null,
                shape: BoxShape.circle,
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      );
}

class _GlowPainter extends CustomPainter {
  _GlowPainter(this.board, this.ids, this.scale, this.ghost);

  final Board board;
  final Set<String> ids;
  final double scale;
  final Slot? ghost;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    for (final s in board.slots) {
      if (!ids.contains(s.id)) continue;
      final path = s.outline ?? (Path()..addOval(Rect.fromCircle(center: s.at, radius: 30)));
      canvas.drawPath(path, Paint()..color = Wood.glow.withValues(alpha: .45));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 / scale
        ..color = const Color(0xFFFFC93C));
    }
    final g = ghost;
    if (g != null) {
      final path = g.outline ?? (Path()..addOval(Rect.fromCircle(center: g.at, radius: 30)));
      canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .45));
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 / scale
        ..color = Colors.white);
      // A curved arrow: turn it this way.
      final b = path.getBounds();
      final r = b.shortestSide * .55 + 6 / scale;
      final arc = Path()..addArc(Rect.fromCircle(center: b.center, radius: r), -math.pi * .9, math.pi * .7);
      final arrow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 / scale
        ..strokeCap = StrokeCap.round
        ..color = Wood.orange;
      canvas.drawPath(arc, arrow);
      final end = b.center + Offset(math.cos(-math.pi * .2), math.sin(-math.pi * .2)) * r;
      canvas.drawLine(end, end + Offset(-10, -2) / scale, arrow);
      canvas.drawLine(end, end + Offset(-2, -11) / scale, arrow);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlowPainter old) => true;
}

class _TrayPainter extends CustomPainter {
  _TrayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    WoodPaint.board(canvas, Offset.zero & size, color: color, radius: 26, seed: 11, depth: 5);
    final inner = RRect.fromRectAndRadius((Offset.zero & size).deflate(8), const Radius.circular(20));
    canvas.drawRRect(inner, Paint()..color = Wood.deep.withValues(alpha: .1));
  }

  @override
  bool shouldRepaint(_TrayPainter old) => old.color != color;
}

class _Dots extends StatelessWidget {
  const _Dots(this.n);

  final int n;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '還有 $n 個',
        // Smaller rather than cut off in a narrow tray (six dots and "…" for a big stack).
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < math.min(n, 6); i++)
                Container(width: 9, height: 9, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: Wood.ink.withValues(alpha: .55), shape: BoxShape.circle)),
              if (n > 6) const Text('…', style: TextStyle(fontSize: 12, color: Wood.ink)),
            ]),
          ),
        ),
      );
}

/// A tangram piece or pattern block, as a wooden shape in its colour. The box is a square around
/// the piece's centre (its centroid), so it turns about the right point: use [shapeBox] for its size.
Widget shapePiece(ShapeKind kind, Color color, double scale, bool lifted, {int seed = 0}) {
  final r = kind.radius;
  final path = polygonPath(kind.points, scale: scale, offset: Offset(r * scale, r * scale));
  return SizedBox.square(
    dimension: 2 * r * scale,
    child: WoodShape(path: path, color: color, lifted: lifted, seed: seed, depth: math.max(2.0, math.min(5.0, r * scale * .09))),
  );
}

/// The box [shapePiece] draws [kind] in (board units).
Size shapeBox(ShapeKind kind) => Size.square(2 * kind.radius);
