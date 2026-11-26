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

/// The pattern blocks' colours (as in kindergartens).
const blockColors = {
  'hex': Wood.yellow,
  'trap': Wood.red,
  'rhomb': Wood.blue,
  'tri': Wood.green,
  'square': Wood.orange,
  'thin': Color(0xFFE8D2A6),
};

/// The blocks in the tray for [card]: 中 gets the card's own blocks. 大 (any way of filling the
/// outline is right) also gets a few more of each block that fits another way, and a triangle for
/// every bit of the outline a triangle fits: whatever was put down before, the rest can always be
/// filled with triangles, so the board can never be left with holes no block in the tray fits.
List<Piece> blockPieces(BlockCard card, Map<String, ShapeKind> kinds, {required bool fill}) {
  final counts = <String, int>{};
  for (final s in card.slots) {
    counts[s.kind] = (counts[s.kind] ?? 0) + 1;
  }
  if (fill) {
    // Enough of the small blocks to fill a hexagon or a trapezoid another way.
    for (final k in {for (final s in card.extra) s.kind}) {
      counts[k] = (counts[k] ?? 0) + (k == 'tri' ? 4 : 2);
    }
    final triCells = {
      for (final s in [...card.slots, ...card.extra])
        if (s.kind == 'tri') ...s.cells,
    };
    if (triCells.length > (counts['tri'] ?? 0)) counts['tri'] = triCells.length;
  }
  const order = ['hex', 'trap', 'rhomb', 'tri', 'square', 'thin'];
  return [
    for (final k in order)
      for (var i = 0; i < (counts[k] ?? 0); i++) Piece(id: '$k$i', kind: k, size: shapeBox(kinds[k]!)),
  ];
}

/// 照著拼 (docs/design.md, 中 and 大): the cards.
class CardList extends ConsumerStatefulWidget {
  const CardList({super.key});

  @override
  ConsumerState<CardList> createState() => _CardListState();
}

class _CardListState extends ConsumerState<CardList> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, '${Strings.blocksTitle}！要拼哪一張？');
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final g = ref.watch(gameProvider);
    return WithMusic(
      music: Music.blocks,
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: Column(children: [
              TopBar(title: Strings.blocksTitle, onHome: () => context.go('/')),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth > 700 ? 170.0 : (box.maxWidth - 56) / 3;
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                    Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                      for (final c in lib.cards)
                        Semantics(
                          key: ValueKey('card-${c.id}'),
                          container: true,
                          button: true,
                          label: c.zh,
                          excludeSemantics: true,
                          onTap: () => context.go('/blocks/play?id=${c.id}'),
                          child: Pressable(
                            onTap: () => context.go('/blocks/play?id=${c.id}'),
                            sound: 'open',
                            child: Stack(clipBehavior: Clip.none, children: [
                              Container(
                                width: w,
                                padding: const EdgeInsets.all(8),
                                decoration: woodBox(Wood.paper, radius: 18),
                                child: Column(children: [
                                  SizedBox(height: w * .8, child: CustomPaint(painter: CardPainter(c), size: Size(w, w * .8))),
                                  const SizedBox(height: 4),
                                  Text(c.zh, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                              if (g.cards.contains(c.id)) const Positioned(right: -4, top: -6, child: Icon(Icons.check_circle_rounded, color: Wood.green, size: 28)),
                            ]),
                          ),
                        ),
                    ]),
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

/// A card's picture: its blocks in their colours (or, as the board, its outline to fill).
class CardPainter extends CustomPainter {
  CardPainter(this.card, {this.outline = false, this.lines = false, this.exact = false});

  final BlockCard card;
  final bool outline;
  final bool lines;
  final bool exact;

  @override
  void paint(Canvas canvas, Size size) {
    final k = exact ? size.width / card.size.width : math.min(size.width / card.size.width, size.height / card.size.height) * .9;
    final o = exact ? Offset.zero : Offset((size.width - card.size.width * k) / 2, (size.height - card.size.height * k) / 2);
    for (final s in card.slots) {
      final path = polygonPath(s.points, scale: k, offset: o);
      if (outline) {
        canvas.drawPath(path, Paint()..color = Wood.hole);
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Wood.hole);
      } else {
        WoodPaint.piece(canvas, path, blockColors[s.kind]!, depth: math.max(1.2, k * .06), grain: false);
      }
    }
    if (outline && lines) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFFE7CFA8);
      for (final s in card.slots) {
        final path = polygonPath(s.points, scale: k, offset: o);
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 8) {
            canvas.drawPath(m.extractPath(d, math.min(d + 4.5, m.length)), p);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(CardPainter old) => old.card != card;
}

/// Copying a card with pattern blocks: 中 has each block's place drawn in dashes and needs the
/// card's own blocks; 大 only has the outline and any blocks that fill it are right. Left half
/// done, the blocks stay where they were for when the child comes back to the same card.
class BlocksScreen extends ConsumerStatefulWidget {
  const BlocksScreen({super.key, required this.cardId});

  final String cardId;

  @override
  ConsumerState<BlocksScreen> createState() => _BlocksScreenState();
}

class _BlocksScreenState extends ConsumerState<BlocksScreen> with HushOnLeave {
  late final Library _lib = ref.read(libraryProvider);
  late final BlockCard _c = _lib.cards.firstWhere((c) => c.id == widget.cardId);
  late final bool _fill = ref.read(gameProvider).settings.level == Level.big;
  late final Map<String, Kept> _keep = ref.read(keptProvider);
  late final String _keepKey = 'blocks/${widget.cardId}/$_fill';
  late final Kept? _kept = _keep.remove(_keepKey);
  late final Board _board = _kept?.board ?? Board([
    for (var i = 0; i < _c.slots.length; i++) _slot('s$i', _c.slots[i]),
    if (_fill)
      for (var i = 0; i < _c.extra.length; i++) _slot('x$i', _c.extra[i]),
  ], need: _c.cells);
  late final List<Piece> _pieces = _kept?.pieces ?? blockPieces(_c, _lib.blockKinds, fill: _fill);
  final _hint = ValueNotifier(0);
  late String _line = _fill ? Strings.blocksAskFill : Strings.blocksAsk;
  var _cheer = 0, _placed = 0;
  var _done = false, _other = false;

  Slot _slot(String id, ShapeSlot s) => Slot(
        id: id,
        kind: s.kind,
        at: s.at,
        angle: s.angle,
        symmetry: _lib.blockKinds[s.kind]!.symmetry,
        cells: s.cells,
        outline: s.path,
      );

  @override
  void initState() {
    super.initState();
    _placed = _board.placed.length;
    _other = _board.placed.values.any((s) => s.id.startsWith('x'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, '${_c.zh}！$_line');
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    if (!_done && !_board.done && _board.placed.isNotEmpty) _keep[_keepKey] = Kept(_board, _pieces);
    super.dispose();
  }

  void _onPlaced(Piece p, Slot s) {
    _placed++;
    if (s.id.startsWith('x')) _other = true;
    setState(() => _cheer++);
    if (_board.done || !ref.read(gameProvider).settings.talk || !talkNow(Level.middle, _placed)) return;
    setState(() => _line = Strings.blockPlaced(_lib.blockKinds[p.kind]!.zh));
    speak(ref, _line);
  }

  void _finish() {
    final now = ref.read(clockProvider)();
    ref.read(gameProvider.notifier).change((g) => g.finishCard(_c.id, now));
    sfx(ref, 'done');
    final line = Strings.blocksDone(_c.zh) + (_other ? Strings.blocksOther : '');
    setState(() {
      _done = true;
      _line = line;
    });
    speak(ref, line);
  }

  @override
  Widget build(BuildContext context) {
    final i = _lib.cards.indexOf(_c);
    final next = _lib.cards[(i + 1) % _lib.cards.length];
    return PlayPage(
      title: '${Strings.blocksTitle}：${_c.zh}',
      music: Music.blocks,
      line: _line,
      cheer: _cheer,
      onHint: () => _hint.value++,
      onHome: () => context.go('/blocks'),
      above: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          height: 92,
          width: 130,
          padding: const EdgeInsets.all(6),
          decoration: woodBox(Wood.paper, radius: 14),
          child: CustomPaint(painter: CardPainter(_c)),
        ),
      ),
      done: _done
          ? DonePanel(
              title: _line,
              show: SizedBox(height: 190, child: Moving(anim: 'hop', child: CustomPaint(painter: CardPainter(_c)))),
              buttons: DoneButtons(
                onAgain: () => context.go('/blocks/play?id=${_c.id}&v=${visit()}'),
                onNext: () => context.go('/blocks/play?id=${next.id}'),
                onHome: () => context.go('/'),
                nextLabel: Strings.nextOne,
              ),
            )
          : null,
      child: PuzzleBoard(
        board: _board,
        pieces: _pieces,
        boardSize: _c.size,
        turning: Turning.auto,
        stacks: true,
        countDots: true,
        hint: _hint,
        hintAfter: hintAfter(ref),
        onPlaced: _onPlaced,
        onDone: _finish,
        back: (context, scale) => CustomPaint(painter: CardPainter(_c, outline: true, lines: !_fill, exact: true)),
        pieceView: (p, scale, lifted) => shapePiece(_lib.blockKinds[p.kind]!, blockColors[p.kind]!, scale, lifted, seed: p.id.hashCode),
      ),
    );
  }
}
