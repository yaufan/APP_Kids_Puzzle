import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/content.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';

/// Whether the helper says where a piece went this time (docs/design.md 「甲甲說話」): 小小 every
/// time, 中 every other time, 大 only for corners and at the end.
bool talkNow(Level l, int placed, {bool special = false}) => switch (l) {
      Level.small => true,
      Level.middle => placed.isOdd || special,
      Level.big => special,
    };

/// How long before a place lights up by itself (小小 5 s, 中 and 大 10 s; off if the parent said
/// so).
Duration? hintAfter(WidgetRef ref) {
  final s = ref.read(gameProvider).settings;
  if (!s.hints) return null;
  return Duration(seconds: s.level == Level.small ? 5 : 10);
}

/// A puzzle's page: the top bar, the helper with what it said, the board (and tray), and the
/// finished panel on top when done. While a puzzle is being put together it counts as busy (the
/// play time lets it be finished).
class PlayPage extends ConsumerStatefulWidget {
  const PlayPage({super.key, required this.title, required this.music, required this.line, required this.child, this.cheer = 0, this.onHint, this.onHome, this.done, this.busy = true, this.above});

  final String title;
  final Music music;
  final String line;
  final int cheer;
  final Widget child;
  final VoidCallback? onHint;
  final VoidCallback? onHome;

  /// The finished panel (null while playing).
  final Widget? done;

  /// Whether the puzzle is still being put together.
  final bool busy;

  /// Something between the helper and the board (照著拼's card).
  final Widget? above;

  @override
  ConsumerState<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends ConsumerState<PlayPage> {
  late final Busy _busy = ref.read(busyProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _busy.set(widget.busy && widget.done == null);
    });
  }

  @override
  void didUpdateWidget(PlayPage old) {
    super.didUpdateWidget(old);
    final busy = widget.busy && widget.done == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _busy.set(busy);
    });
  }

  @override
  void dispose() {
    // Not while the tree is being torn down: just after (the next page sets its own after its first frame).
    final busy = _busy;
    Future(() => busy.set(false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WithMusic(
        music: widget.music,
        child: Scaffold(
          body: WallBg(
            floor: false,
            child: SafeArea(
              child: Stack(children: [
                Column(children: [
                  TopBar(title: widget.title, onHome: widget.onHome ?? () => context.go('/'), onHint: widget.done == null ? widget.onHint : null),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: HelperSays(text: widget.line, size: 64, cheer: widget.cheer, onTap: () => speak(ref, widget.line)),
                    ),
                  ),
                  ?widget.above,
                  Expanded(child: widget.child),
                ]),
                if (widget.done != null) Positioned.fill(child: widget.done!),
              ]),
            ),
          ),
        ),
      );
}

/// The finished panel: what came alive, a title, the helper cheering, confetti, three buttons.
class DonePanel extends StatefulWidget {
  const DonePanel({super.key, required this.title, required this.show, required this.buttons, this.extra});

  final String title;
  final Widget show;
  final Widget buttons;
  final Widget? extra;

  @override
  State<DonePanel> createState() => _DonePanelState();
}

class _DonePanelState extends State<DonePanel> {
  var _confetti = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _confetti++);
    });
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Wood.ink.withValues(alpha: .35),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Stack(alignment: Alignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: woodBox(Wood.paper, radius: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: widget.show),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const HelperView(size: 64, pose: 'cheer'),
                  const SizedBox(width: 8),
                  Flexible(child: Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Wood.ink, height: 1.35))),
                ]),
                if (widget.extra != null) ...[const SizedBox(height: 8), widget.extra!],
                const SizedBox(height: 14),
                widget.buttons,
              ]),
            ),
          ),
          Positioned.fill(child: Confetti(trigger: _confetti)),
        ]),
      );
}

/// A picture come alive (docs/design.md 「動起來」): its background, and its actor moving its own
/// way for four seconds (again on a tap).
class Alive extends StatefulWidget {
  const Alive({super.key, required this.picture, this.play = true, this.onTap});

  final Picture picture;
  final bool play;
  final VoidCallback? onTap;

  @override
  State<Alive> createState() => AliveState();
}

class AliveState extends State<Alive> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void initState() {
    super.initState();
    if (widget.play) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void replay() => _c.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final p = widget.picture;
    return AspectRatio(
      aspectRatio: Picture.size.width / Picture.size.height,
      child: LayoutBuilder(builder: (context, box) {
        final k = box.maxWidth / Picture.size.width;
        final r = Rect.fromLTWH(p.actorBox.left * k, p.actorBox.top * k, p.actorBox.width * k, p.actorBox.height * k);
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            Positioned.fill(child: Art('backs/${p.id}', fit: BoxFit.fill)),
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => _move(p.anim, _c.value, r, box.biggest, child!),
              child: Art('actors/${p.actor}', fit: BoxFit.fill),
            ),
          ]),
        );
      }),
    );
  }

  static Widget _move(String anim, double t, Rect r, Size size, Widget child) {
    final s = math.sin;
    var dx = 0.0, dy = 0.0, angle = 0.0, scale = 1.0;
    var pivot = Alignment.center;
    final fade = t <= 0 || t >= 1 ? 0.0 : 1.0;
    switch (anim) {
      case 'hop':
        dy = -s(t * math.pi * 3).abs() * r.height * .22 * fade;
      case 'drive':
        dx = s(t * math.pi) * size.width * .28;
      case 'fly':
        dy = -s(t * math.pi) * size.height * .3;
        dx = s(t * math.pi * 2) * r.width * .08;
      case 'sway':
        angle = s(t * math.pi * 4) * .14 * fade;
        pivot = Alignment.bottomCenter;
      case 'spin':
        angle = t * math.pi * 4;
      case 'wiggle':
        angle = s(t * math.pi * 10) * .09 * (1 - t);
        scale = 1 + .06 * s(t * math.pi);
      case 'pulse':
        scale = 1 + .14 * s(t * math.pi * 4).abs();
      case 'swim':
        dx = s(t * math.pi * 2) * size.width * .14;
        dy = s(t * math.pi * 6) * r.height * .06;
      case 'nod':
        angle = s(t * math.pi * 6) * .1 * fade;
        pivot = Alignment.bottomCenter;
    }
    return Positioned.fromRect(
      rect: r.shift(Offset(dx, dy)),
      child: Transform.rotate(angle: angle, alignment: pivot, child: Transform.scale(scale: scale, child: child)),
    );
  }
}

/// The Taiwan puzzle (docs/design.md 「台灣大拼圖」): 48 pieces, one for each picture, in its
/// box's colour once that picture was finished. A tap on a coloured piece shows its picture again.
class TaiwanView extends ConsumerWidget {
  const TaiwanView({super.key, this.onPiece, this.fresh});

  final void Function(Picture p)? onPiece;

  /// A piece just added (it glows).
  final String? fresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lib = ref.watch(libraryProvider);
    final done = ref.watch(gameProvider.select((g) => g.pictures));
    final map = lib.taiwan;
    final byPiece = {for (final p in lib.pictures) Library.taiwanPiece(p.index): p};
    return AspectRatio(
      aspectRatio: map.size.width / map.size.height,
      child: LayoutBuilder(builder: (context, box) {
        final k = box.maxWidth / map.size.width;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerUp: onPiece == null
              ? null
              : (e) {
                  final at = e.localPosition / k;
                  for (var i = 0; i < map.pieces.length; i++) {
                    final pic = byPiece[i];
                    if (pic != null && done.contains(pic.id) && (Path()..addPolygon(map.pieces[i], true)).contains(at)) {
                      onPiece!(pic);
                      return;
                    }
                  }
                },
          child: CustomPaint(
            size: box.biggest,
            painter: _TaiwanPainter(map, {for (final e in byPiece.entries) if (done.contains(e.value.id)) e.key: lib.boxOf(e.value).color}, k,
                fresh == null || lib.picture[fresh] == null ? null : Library.taiwanPiece(lib.picture[fresh]!.index)),
          ),
        );
      }),
    );
  }
}

class _TaiwanPainter extends CustomPainter {
  _TaiwanPainter(this.map, this.filled, this.k, this.fresh);

  final TaiwanMap map;
  final Map<int, Color> filled;
  final double k;
  final int? fresh;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(k);
    final outline = Path()..addPolygon(map.outline, true);
    canvas.drawPath(outline.shift(Offset(0, 2.5 / k)), Paint()..color = Wood.deep.withValues(alpha: .45));
    canvas.drawPath(outline, Paint()..color = const Color(0xFFE9D3B2));
    for (var i = 0; i < map.pieces.length; i++) {
      final path = Path()..addPolygon(map.pieces[i], true);
      final c = filled[i];
      if (c != null) {
        canvas.drawPath(path, Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(c, Colors.white, .2)!, c]).createShader(path.getBounds()));
      }
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / k
        ..color = c == null ? Wood.dark.withValues(alpha: .45) : Colors.white.withValues(alpha: .8));
      if (i == fresh) {
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 / k
          ..color = Wood.glow);
      }
    }
    canvas.drawPath(outline, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / k
      ..color = Wood.deep.withValues(alpha: .6));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TaiwanPainter old) => old.filled.length != filled.length || old.k != k || old.fresh != fresh;
}

/// The voice line [Strings.fullOnly] for something only the full version has.
Future<void> sayFullOnly(WidgetRef ref, String what) => speak(ref, Strings.fullOnly(what));

/// [child] moving [anim]'s way for four seconds (a finished tangram or pattern-block picture).
class Moving extends StatefulWidget {
  const Moving({super.key, required this.anim, required this.child});

  final String anim;
  final Widget child;

  @override
  State<Moving> createState() => _MovingState();
}

class _MovingState extends State<Moving> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = Size(box.maxWidth.isFinite ? box.maxWidth : 200, box.maxHeight.isFinite ? box.maxHeight : 200);
        return SizedBox.fromSize(
          size: size,
          child: Stack(clipBehavior: Clip.none, children: [
            AnimatedBuilder(
              animation: _c,
              builder: (_, child) => AliveState._move(widget.anim, _c.value, Offset.zero & size, size * .6, child!),
              child: widget.child,
            ),
          ]),
        );
      });
}

var _visits = 0;

/// A new value each time, so going to the same puzzle again starts it afresh.
String visit() => '${++_visits}';
