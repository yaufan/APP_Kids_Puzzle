import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../app/wood.dart';
import '../../core/board.dart';
import '../../core/content.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';
import '../common/board_view.dart';
import '../common/play_page.dart';

/// The seven pieces' colours (the two large triangles differ, as do the two small ones).
const tanColors = [Wood.red, Wood.blue, Wood.orange, Wood.green, Wood.purple, Wood.yellow, Wood.teal];

/// The colour of the [i]th piece of a figure of [kind].
Color tanColor(TanFigure f, int i) {
  final kind = f.slots[i].kind;
  final same = [for (var k = 0; k < i; k++) if (f.slots[k].kind == kind) k].length;
  return switch (kind) {
    'L' => same == 0 ? tanColors[0] : tanColors[1],
    'M' => tanColors[2],
    'S' => same == 0 ? tanColors[3] : tanColors[4],
    'Q' => tanColors[5],
    _ => tanColors[6],
  };
}

/// 七巧板: the figures of the child's level (小小 6, 中 8, 大 10). In the free version, 中 and 大
/// also get 小小's set to play, theirs locked.
class TangramList extends ConsumerStatefulWidget {
  const TangramList({super.key});

  @override
  ConsumerState<TangramList> createState() => _TangramListState();
}

class _TangramListState extends ConsumerState<TangramList> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, '${Strings.tangramTitle}！要拼哪一個？');
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final g = ref.watch(gameProvider);
    final s = g.settings;
    final sets = [if (!s.tangramOpen(s.level)) Level.small, s.level];
    return WithMusic(
      music: Music.tangram,
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: Column(children: [
              TopBar(title: Strings.tangramTitle, onHome: () => context.go('/')),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth > 700 ? 170.0 : (box.maxWidth - 56) / 3;
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                    for (final set in sets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                          for (final f in lib.tangramsAt(set))
                            () {
                              final open = s.tangramOpen(set);
                              void tap() {
                                if (!open) {
                                  sayFullOnly(ref, '${set.zh}的七巧板');
                                  return;
                                }
                                context.go('/tangram/play?id=${f.id}');
                              }

                              return Semantics(
                                key: ValueKey('tan-${f.id}'),
                                container: true,
                                button: true,
                                label: f.zh,
                                excludeSemantics: true,
                                onTap: tap,
                                child: Pressable(
                                  onTap: tap,
                                  sound: open ? 'open' : 'tap',
                                  child: Stack(clipBehavior: Clip.none, children: [
                                    Container(
                                      width: w,
                                      padding: const EdgeInsets.all(8),
                                      decoration: woodBox(Wood.light, radius: 18),
                                      child: Column(children: [
                                        SizedBox(height: w * .75, child: CustomPaint(painter: FigurePainter(f, colored: g.tangrams.contains(f.id)), size: Size(w, w * .75))),
                                        const SizedBox(height: 4),
                                        Text(f.zh, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ]),
                                    ),
                                    if (!open) const Positioned(right: -4, top: -6, child: LockBadge()),
                                    if (g.tangrams.contains(f.id)) const Positioned(right: -4, top: -6, child: Icon(Icons.check_circle_rounded, color: Wood.green, size: 28)),
                                  ]),
                                ),
                              );
                            }(),
                        ]),
                      ),
                  ]);
                }),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A tangram figure: its shadow, or (when [colored]) its pieces in their colours with its eyes.
class FigurePainter extends CustomPainter {
  FigurePainter(this.f, {this.colored = false, this.lines = false, this.exact = false});

  final TanFigure f;
  final bool colored;
  final bool lines;

  /// Fill the box exactly (the board under the pieces) instead of fitting with a margin.
  final bool exact;

  @override
  void paint(Canvas canvas, Size size) {
    final k = exact ? size.width / f.size.width : math.min(size.width / f.size.width, size.height / f.size.height) * .92;
    final o = exact ? Offset.zero : Offset((size.width - f.size.width * k) / 2, (size.height - f.size.height * k) / 2);
    for (var i = 0; i < f.slots.length; i++) {
      final path = polygonPath(f.slots[i].points, scale: k, offset: o);
      if (colored) {
        WoodPaint.piece(canvas, path, tanColor(f, i), seed: i, depth: math.max(1.5, k * .08), grain: k > 30);
      } else {
        canvas.drawPath(path, Paint()..color = Wood.hole);
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = lines ? const Color(0xFFE7CFA8) : Wood.hole);
      }
    }
    final eye = f.eye;
    if (colored && eye != null) {
      final r = math.max(2.5, k * .09);
      final at = eye * k + o;
      final spots = f.eyes == 2 ? [at - Offset(r * 2.2, 0), at + Offset(r * 2.2, 0)] : [at];
      for (final e in spots) {
        canvas.drawCircle(e, r, Paint()..color = Wood.ink);
        canvas.drawCircle(e - Offset(r * .35, r * .35), r * .35, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(FigurePainter old) => old.f != f || old.colored != colored;
}

/// Putting a figure together (docs/design.md 「七巧板」 and 「轉動和翻面」). Left half done, the
/// pieces stay where they were for when the child comes back to the same figure.
class TangramScreen extends ConsumerStatefulWidget {
  const TangramScreen({super.key, required this.figureId});

  final String figureId;

  @override
  ConsumerState<TangramScreen> createState() => _TangramScreenState();
}

class _TangramScreenState extends ConsumerState<TangramScreen> with HushOnLeave {
  late final Library _lib = ref.read(libraryProvider);
  late final TanFigure _f = _lib.tangrams.firstWhere((t) => t.id == widget.figureId);
  late final Turning _turning = ref.read(gameProvider).settings.tangramTurning(_f.level);
  late final Map<String, Kept> _keep = ref.read(keptProvider);
  late final String _keepKey = 'tangram/${widget.figureId}/${_turning.name}';
  late final Kept? _kept = _keep.remove(_keepKey);
  late final Board _board = _kept?.board ?? Board([
    for (var i = 0; i < _f.slots.length; i++)
      Slot(
        id: 's$i',
        kind: _f.slots[i].kind,
        at: _f.slots[i].at,
        angle: _f.slots[i].angle,
        flip: _f.slots[i].flip,
        symmetry: _lib.tanKinds[_f.slots[i].kind]!.symmetry,
        chiral: _f.slots[i].kind == 'P',
        outline: _f.slots[i].path,
      ),
  ]);
  late final List<Piece> _pieces = _kept?.pieces ?? () {
    final r = ref.read(randomProvider);
    final out = <Piece>[];
    for (var i = 0; i < _f.slots.length; i++) {
      final s = _f.slots[i];
      final kind = _lib.tanKinds[s.kind]!;
      var angle = s.angle, flip = s.flip;
      if (_turning != Turning.none) {
        // Turned some other way (a whole turn of its symmetry would look the same).
        final steps = kind.symmetry ~/ 45;
        angle = s.angle + 45 * (steps <= 1 ? 0 : 1 + r.nextInt(steps - 1));
        if (_turning == Turning.tap && s.kind == 'P' && r.nextBool()) flip = !flip;
      }
      out.add(Piece(id: 'p$i', kind: s.kind, size: shapeBox(kind), angle: angle, flip: flip));
    }
    return out..shuffle(r);
  }();
  final _hint = ValueNotifier(0);
  late String _line = switch (_turning) {
    Turning.none => '${_f.zh}的影子！把形狀放進去！',
    Turning.auto => '${_f.zh}的影子！${Strings.tanHowToAuto}',
    Turning.tap => '${_f.zh}的影子！${Strings.tanHowTo}',
  };
  var _cheer = 0, _placed = 0;
  var _done = false;

  @override
  void initState() {
    super.initState();
    _placed = _board.placed.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, _line);
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    if (!_done && !_board.done && _board.placed.isNotEmpty) _keep[_keepKey] = Kept(_board, _pieces);
    super.dispose();
  }

  void _say(String line) {
    setState(() => _line = line);
    speak(ref, line);
  }

  void _onPlaced(Piece p, Slot s) {
    _placed++;
    setState(() => _cheer++);
    if (_board.done) return;
    if (ref.read(gameProvider).settings.talk && talkNow(_f.level, _placed, special: _turning == Turning.tap)) _say(Strings.tanPlaced(_lib.tanKinds[p.kind]!.zh));
  }

  void _finish() {
    final now = ref.read(clockProvider)();
    ref.read(gameProvider.notifier).change((g) => g.finishTangram(_f.id, now));
    sfx(ref, 'done');
    setState(() => _done = true);
    _say(Strings.tanDone(_f.zh));
  }

  int _colorIndex(Piece p) => int.parse(p.id.substring(1));

  @override
  Widget build(BuildContext context) {
    final set = _lib.tangramsAt(_f.level);
    final next = set[(set.indexOf(_f) + 1) % set.length];
    return PlayPage(
      title: '${Strings.tangramTitle}：${_f.zh}',
      music: Music.tangram,
      line: _line,
      cheer: _cheer,
      onHint: () => _hint.value++,
      onHome: () => context.go('/tangram'),
      done: _done
          ? DonePanel(
              title: Strings.tanDone(_f.zh),
              show: SizedBox(height: 200, child: Moving(anim: _f.anim, child: CustomPaint(painter: FigurePainter(_f, colored: true)))),
              buttons: DoneButtons(
                onAgain: () => context.go('/tangram/play?id=${_f.id}&v=${visit()}'),
                onNext: () => context.go('/tangram/play?id=${next.id}'),
                onHome: () => context.go('/'),
                nextLabel: Strings.nextOne,
              ),
            )
          : null,
      child: PuzzleBoard(
        board: _board,
        pieces: _pieces,
        boardSize: _f.size,
        turning: _turning,
        hint: _hint,
        hintAfter: hintAfter(ref),
        onPlaced: _onPlaced,
        onDone: _finish,
        onWrongTurn: (p, s) => _say(p.kind == 'P' && p.flip != s.flip ? Strings.flipIt : Strings.turnIt),
        onHelpTurn: (p) => _say(Strings.helpTurn(ref.read(gameProvider).helper ?? Helper.pangolin)),
        back: (context, scale) => CustomPaint(painter: FigurePainter(_f, lines: _f.lines, exact: true)),
        pieceView: (p, scale, lifted) => shapePiece(_lib.tanKinds[p.kind]!, tanColor(_f, _colorIndex(p)), scale, lifted, seed: _colorIndex(p)),
      ),
    );
  }
}
