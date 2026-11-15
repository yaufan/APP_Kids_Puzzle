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
import '../../core/shapes.dart';
import '../../core/sounds.dart';
import '../common/board_view.dart';
import '../common/play_page.dart';

/// 形狀洞洞 (docs/design.md): the shape box and the six inset boards. Whole pieces into holes of
/// the same shape; nothing to turn.
class ShapesMenu extends ConsumerStatefulWidget {
  const ShapesMenu({super.key});

  @override
  ConsumerState<ShapesMenu> createState() => _ShapesMenuState();
}

class _ShapesMenuState extends ConsumerState<ShapesMenu> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, Strings.shapesPick);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final g = ref.watch(gameProvider);
    Widget card(String key, String label, Widget art, Color color, VoidCallback tap, {bool done = false}) => Semantics(
          key: ValueKey(key),
          container: true,
          button: true,
          label: label,
          excludeSemantics: true,
          onTap: tap,
          child: Pressable(
            onTap: tap,
            sound: 'open',
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 160,
                padding: const EdgeInsets.all(8),
                decoration: woodBox(color, radius: 20),
                child: Column(children: [
                  Container(
                    height: 100,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(14)),
                    child: art,
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
              if (done) const Positioned(right: -4, top: -6, child: Icon(Icons.check_circle_rounded, color: Wood.green, size: 30)),
            ]),
          ),
        );
    return WithMusic(
      music: Music.shapes,
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: Column(children: [
              TopBar(title: Strings.shapesTitle, onHome: () => context.go('/')),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                  Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                    card('shape-box', Strings.shapeBox, const Art('ui/mode_shapes'), Wood.red, () => context.go('/shapes/box')),
                    for (final b in lib.insets)
                      card('inset-${b.id}', b.zh, Art('inset/${b.items.first.actor}'), b.color, () => context.go('/shapes/inset?board=${b.id}'), done: g.insets.contains(b.id)),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The shape box: a lid with holes; each shape drops in through its own hole ("咚"). When all are
/// in, the box opens and they dance; then the next round has one more hole.
class ShapeBoxScreen extends ConsumerStatefulWidget {
  const ShapeBoxScreen({super.key, this.round});

  final int? round;

  @override
  ConsumerState<ShapeBoxScreen> createState() => _ShapeBoxScreenState();
}

class _ShapeBoxScreenState extends ConsumerState<ShapeBoxScreen> with HushOnLeave {
  late final Level _level = ref.read(gameProvider).settings.level;
  late final int _round = widget.round ?? ref.read(gameProvider).shapeRound;
  late final List<ToyShape> _shapes = ShapeRounds.of(_level)[_round];
  late final (List<Offset>, double) _holes = ShapeRounds.holes(_shapes.length);
  late final Board _board = Board([
    for (var i = 0; i < _shapes.length; i++)
      Slot(id: 'hole$i', kind: _shapes[i].name, at: _holes.$1[i], outline: _shapes[i].path(_holes.$2).shift(_holes.$1[i])),
  ]);
  late final List<Piece> _pieces = [
    for (var i = 0; i < _shapes.length; i++) Piece(id: 'shape$i', kind: _shapes[i].name, size: Size.square(_holes.$2)),
  ]..shuffle(ref.read(randomProvider));
  final _hint = ValueNotifier(0);
  late String _line = _shapes.length == 1 ? Strings.shapeAsk(_shapes.first.zh) : Strings.shapeAsk('形狀');
  var _cheer = 0, _placed = 0;
  var _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, _line);
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  ToyShape _of(String kind) => ToyShape.values.byName(kind);

  void _placed_(Piece p, Slot s) {
    _placed++;
    final shape = _of(p.kind);
    final say = ref.read(gameProvider).settings.talk && talkNow(_level, _placed);
    setState(() {
      _cheer++;
      if (say) _line = Strings.shapeIn(shape.look, shape.zh);
    });
    if (say) speak(ref, _line);
  }

  void _finish() {
    final now = ref.read(clockProvider)();
    ref.read(gameProvider.notifier).change((g) => widget.round == null ? g.finishShapes(now) : g.did(now));
    sfx(ref, 'open');
    setState(() {
      _done = true;
      _line = Strings.shapesDone;
    });
    speak(ref, _line);
  }

  @override
  Widget build(BuildContext context) {
    final size = _holes.$2;
    return PlayPage(
      title: Strings.shapeBox,
      music: Music.shapes,
      line: _line,
      cheer: _cheer,
      onHint: () => _hint.value++,
      done: _done
          ? DonePanel(
              title: Strings.shapesDone,
              show: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
                for (var i = 0; i < _shapes.length; i++)
                  Bob(
                    phase: i * .17,
                    amount: 8,
                    period: 900,
                    child: SizedBox(width: 64, height: 64, child: WoodShape(path: _shapes[i].path(60).shift(const Offset(32, 32)), color: _shapes[i].color)),
                  ),
              ]),
              buttons: DoneButtons(
                onAgain: () => context.go('/shapes/box?again=$_round&v=${visit()}'),
                onNext: () => context.go('/shapes/box?v=${visit()}'),
                onHome: () => context.go('/'),
                nextLabel: Strings.nextOne,
              ),
            )
          : null,
      child: PuzzleBoard(
        board: _board,
        pieces: _pieces,
        boardSize: ShapeRounds.lid,
        hint: _hint,
        hintAfter: hintAfter(ref),
        placeSound: 'drop',
        onPlaced: _placed_,
        onDone: _finish,
        back: (context, scale) => CustomPaint(painter: _LidPainter(_shapes, _holes.$1, size, scale, faint: _level == Level.small)),
        pieceView: (p, scale, lifted) => SizedBox.square(
          dimension: size * scale,
          child: WoodShape(path: _of(p.kind).path(size * scale).shift(Offset(size * scale / 2, size * scale / 2)), color: _of(p.kind).color, lifted: lifted, seed: p.id.hashCode),
        ),
      ),
    );
  }
}

class _LidPainter extends CustomPainter {
  _LidPainter(this.shapes, this.at, this.size, this.scale, {required this.faint});

  final List<ToyShape> shapes;
  final List<Offset> at;
  final double size;
  final double scale;
  final bool faint;

  @override
  void paint(Canvas canvas, Size box) {
    WoodPaint.board(canvas, Offset.zero & box, color: Wood.light, radius: 26 * scale + 6, seed: 5, depth: 6);
    for (var i = 0; i < shapes.length; i++) {
      final path = shapes[i].path(size * scale).shift(at[i] * scale);
      WoodPaint.hole(canvas, path, board: Wood.light);
      if (faint) canvas.drawPath(path, Paint()..color = shapes[i].color.withValues(alpha: .28));
    }
  }

  @override
  bool shouldRepaint(_LidPainter old) => old.scale != scale;
}

/// An inset board: a wooden board with holes, each piece a painted wooden cut-out with a little
/// knob. 小小 sees the picture faintly in each hole; 中 and 大 only its shape.
class InsetScreen extends ConsumerStatefulWidget {
  const InsetScreen({super.key, required this.boardId});

  final String boardId;

  @override
  ConsumerState<InsetScreen> createState() => _InsetScreenState();
}

class _InsetScreenState extends ConsumerState<InsetScreen> with HushOnLeave {
  late final InsetBoard _b = ref.read(libraryProvider).insets.firstWhere((b) => b.id == widget.boardId);
  late final Level _level = ref.read(gameProvider).settings.level;
  late final Board _board = Board([
    for (final it in _b.items)
      Slot(id: it.actor, kind: it.actor, at: it.at, outline: Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: it.at, width: it.size * .92, height: it.size * .92), Radius.circular(it.size * .3)))),
  ]);
  late final List<Piece> _pieces = [for (final it in _b.items) Piece(id: it.actor, kind: it.actor, size: Size.square(it.size))]..shuffle(ref.read(randomProvider));
  final _hint = ValueNotifier(0);
  late String _line = '${_b.zh}！${Strings.shapeAsk('它們')}';
  var _cheer = 0, _placed = 0;
  var _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, _line);
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    super.dispose();
  }

  void _onPlaced(Piece p, Slot s) {
    _placed++;
    final item = _b.items.firstWhere((i) => i.actor == p.id);
    final lib = ref.read(libraryProvider);
    final pic = lib.pictures.where((x) => x.actor == item.actor).firstOrNull;
    sfx(ref, pic?.sound ?? 'pop');
    final say = ref.read(gameProvider).settings.talk && talkNow(_level, _placed);
    setState(() {
      _cheer++;
      _line = say ? item.line : item.zh;
    });
    speak(ref, _line);
  }

  void _finish() {
    final now = ref.read(clockProvider)();
    ref.read(gameProvider.notifier).change((g) => g.finishInset(_b.id, now));
    sfx(ref, 'done');
    setState(() {
      _done = true;
      _line = Strings.insetDone(_b.zh);
    });
    speak(ref, _line);
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final i = lib.insets.indexOf(_b);
    final next = lib.insets[(i + 1) % lib.insets.length];
    return PlayPage(
      title: _b.zh,
      music: Music.shapes,
      line: _line,
      cheer: _cheer,
      onHint: () => _hint.value++,
      done: _done
          ? DonePanel(
              title: Strings.insetDone(_b.zh),
              show: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                for (var k = 0; k < _b.items.length; k++) Bob(phase: k * .19, amount: 7, period: 1000, child: SizedBox(width: 70, height: 70, child: Art('inset/${_b.items[k].actor}'))),
              ]),
              buttons: DoneButtons(
                onAgain: () => context.go('/shapes/inset?board=${_b.id}&v=${visit()}'),
                onNext: () => context.go('/shapes/inset?board=${next.id}'),
                onHome: () => context.go('/'),
                nextLabel: Strings.nextOne,
              ),
            )
          : null,
      child: PuzzleBoard(
        board: _board,
        pieces: _pieces,
        boardSize: InsetBoard.size,
        hint: _hint,
        hintAfter: hintAfter(ref),
        onPlaced: _onPlaced,
        onDone: _finish,
        back: (context, scale) => Stack(children: [
          Positioned.fill(child: WoodBoard(color: Color.lerp(_b.color, Wood.light, .65)!, radius: 24 * scale + 6, seed: 7)),
          for (final it in _b.items)
            Positioned(
              left: (it.at.dx - it.size / 2) * scale,
              top: (it.at.dy - it.size / 2) * scale,
              width: it.size * scale,
              height: it.size * scale,
              child: Stack(fit: StackFit.expand, children: [
                Art('inset/${it.actor}_hole'),
                if (_level == Level.small) Opacity(opacity: .3, child: Art('inset/${it.actor}')),
              ]),
            ),
        ]),
        pieceView: (p, scale, lifted) => SizedBox.square(dimension: p.size.width * scale, child: Art('inset/${p.id}')),
      ),
    );
  }
}
