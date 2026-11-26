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
import '../../core/jigsaw.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';
import '../common/board_view.dart';
import '../common/play_page.dart';

/// Putting a picture together (docs/design.md 「拼圖」): the frame on top (the picture faint under
/// it for 小小 and 中, dashed outlines for 中 from 9 pieces, only the frame for 大), six pieces at a
/// time in the tray, corners and edges first from 12. Done: the picture comes alive and the Taiwan
/// puzzle gets its piece. Left half done (home, the back key, the rest), the pieces stay where they
/// were for when the child comes back to the same picture and size.
class JigsawScreen extends ConsumerStatefulWidget {
  const JigsawScreen({super.key, required this.pictureId, required this.cut});

  final String pictureId;
  final Cut cut;

  @override
  ConsumerState<JigsawScreen> createState() => _JigsawScreenState();
}

class _JigsawScreenState extends ConsumerState<JigsawScreen> with HushOnLeave {
  late final Library _lib = ref.read(libraryProvider);
  late final Picture _pic = _lib.picture[widget.pictureId]!;
  late final Level _level = ref.read(gameProvider).settings.level;
  late final Jigsaw _jig = Jigsaw(_pic.id, widget.cut);
  late final Map<String, JigsawPiece> _byId = {for (final p in _jig.pieces) p.id: p};
  late final Map<String, Kept> _keep = ref.read(keptProvider);
  late final String _keepKey = 'jigsaw/${widget.pictureId}/${widget.cut.name}';
  late final Kept? _kept = _keep.remove(_keepKey);
  late final Board _board = _kept?.board ??
      Board([
        for (final p in _jig.pieces) Slot(id: p.id, kind: p.id, at: p.center, outline: p.path.shift(p.cell.topLeft - Offset(p.margin, p.margin))),
      ]);
  late final List<Piece> _pieces = _kept?.pieces ??
      [
        for (final p in _jig.order(ref.read(randomProvider), edgesFirst: ref.read(gameProvider).settings.edgesFirst && widget.cut.count >= 12))
          Piece(id: p.id, kind: p.id, size: p.size),
      ];
  final _hint = ValueNotifier(0);
  late String _line = _pic.zh;
  var _cheer = 0, _placed = 0;
  var _done = false, _fresh = false;
  List<Cut> _openBefore = const [];
  Later? _later;

  @override
  void initState() {
    super.initState();
    _placed = _board.placed.length;
    _openBefore = ref.read(gameProvider).cutsOpen(_level);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, '${_pic.zh}，${Strings.pieces(widget.cut.count)}！');
    });
  }

  @override
  void dispose() {
    _hint.dispose();
    _later?.cancel();
    if (!_done && !_board.done && _board.placed.isNotEmpty) _keep[_keepKey] = Kept(_board, _pieces);
    super.dispose();
  }

  void _onPlaced(Piece p, Slot s) {
    _placed++;
    final jp = _byId[p.id]!;
    final say = ref.read(gameProvider).settings.talk && talkNow(_level, _placed, special: jp.part == Part.corner && widget.cut.count >= 9);
    setState(() => _cheer++);
    if (!say || _board.done) return;
    setState(() => _line = widget.cut.tabs ? Strings.partLine(jp, widget.cut) : Strings.rectLine(jp, widget.cut));
    speak(ref, _line);
  }

  void _finish() {
    final now = ref.read(clockProvider)();
    _fresh = !ref.read(gameProvider).pictureDone(_pic.id);
    ref.read(gameProvider.notifier).change((g) => g.finishPicture(_pic.id, widget.cut, now));
    final openNow = ref.read(gameProvider).cutsOpen(_level);
    final bigger = openNow.length > _openBefore.length ? openNow.last : null;
    sfx(ref, 'done');
    sfx(ref, _pic.sound);
    setState(() {
      _done = true;
      _line = _pic.line;
    });
    final said = speak(ref, _pic.line);
    final then = [if (_fresh) Strings.taiwanPlus, if (bigger != null) Strings.bigger(bigger.count)].join();
    if (then.isEmpty) return;
    _later = Later(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_fresh) sfx(ref, 'star');
      speak(ref, then);
    }, after: said);
  }

  bool get _faint => ref.read(gameProvider).settings.faint && (_level == Level.small || (_level == Level.middle && widget.cut.count < 9));
  bool get _outlines => _level == Level.middle && widget.cut.count >= 9;

  @override
  Widget build(BuildContext context) {
    final box = _lib.boxOf(_pic);
    final i = box.pictures.indexOf(_pic);
    final next = box.pictures[(i + 1) % box.pictures.length];
    return PlayPage(
      title: _pic.zh,
      music: Music.ofBox(box.music),
      line: _line,
      cheer: _cheer,
      onHint: () => _hint.value++,
      onHome: () => context.go('/jigsaw/box?id=${box.id}'),
      done: _done
          ? DonePanel(
              title: _pic.zh,
              show: Alive(picture: _pic),
              extra: _fresh
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(height: 90, child: TaiwanView(fresh: _pic.id)),
                      const SizedBox(width: 10),
                      const Text(Strings.taiwanPlus, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Wood.green)),
                    ])
                  : null,
              buttons: DoneButtons(
                onAgain: () => context.go('/jigsaw/play?pic=${_pic.id}&cut=${widget.cut.name}&v=${visit()}'),
                onNext: () => context.go('/jigsaw/play?pic=${next.id}&cut=${ref.read(gameProvider).cutFor(_level).name}'),
                onHome: () => context.go('/'),
              ),
            )
          : null,
      child: PuzzleBoard(
        board: _board,
        pieces: _pieces,
        boardSize: Picture.size,
        hint: _hint,
        hintAfter: hintAfter(ref),
        trayColor: Color.lerp(box.color, Wood.mid, .6)!,
        onPlaced: _onPlaced,
        onDone: _finish,
        back: (context, scale) => Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _FramePainter(scale))),
          if (_faint) Positioned.fill(child: Opacity(opacity: .3, child: Art('pictures/${_pic.id}', fit: BoxFit.fill))),
          if (_outlines) Positioned.fill(child: CustomPaint(painter: _OutlinePainter(_jig, scale))),
        ]),
        pieceView: (p, scale, lifted) => RepaintBoundary(child: JigsawPieceView(piece: _byId[p.id]!, pictureId: _pic.id, scale: scale, lifted: lifted)),
      ),
    );
  }
}

/// One jigsaw piece: the picture cut to its outline, on a slab of wood (its edge and thickness show).
class JigsawPieceView extends StatelessWidget {
  const JigsawPieceView({super.key, required this.piece, required this.pictureId, required this.scale, this.lifted = false});

  final JigsawPiece piece;
  final String pictureId;
  final double scale;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final path = piece.path.transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
    final at = piece.pictureAt * scale;
    return SizedBox(
      width: piece.size.width * scale,
      height: piece.size.height * scale,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: CustomPaint(painter: _SlabPainter(path, lifted, under: true))),
        Positioned.fill(
          child: ClipPath(
            clipper: _PathClip(path),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: at.dx, top: at.dy, width: Picture.size.width * scale, height: Picture.size.height * scale, child: Art('pictures/$pictureId', fit: BoxFit.fill)),
            ]),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _SlabPainter(path, lifted, under: false))),
      ]),
    );
  }
}

class _PathClip extends CustomClipper<Path> {
  _PathClip(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_PathClip old) => old.path != path;
}

class _SlabPainter extends CustomPainter {
  _SlabPainter(this.path, this.lifted, {required this.under});

  final Path path;
  final bool lifted;
  final bool under;

  @override
  void paint(Canvas canvas, Size size) {
    if (under) {
      final d = lifted ? 6.0 : 3.0;
      if (lifted) {
        canvas.drawPath(path.shift(Offset(d, d * 1.6)), Paint()
          ..color = Wood.ink.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      }
      for (var i = d; i > 0; i -= 1.5) {
        canvas.drawPath(path.shift(Offset(0, i)), Paint()..color = Wood.dark);
      }
      return;
    }
    WoodPaint.bevel(canvas, path, width: 2);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Wood.deep.withValues(alpha: .5));
  }

  @override
  bool shouldRepaint(_SlabPainter old) => old.path != path || old.lifted != lifted;
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.scale);

  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final rim = math.max(8.0, 10 * scale);
    WoodPaint.board(canvas, r.inflate(rim), color: Wood.mid, radius: rim * 1.4, seed: 9, depth: 5);
    canvas.drawRect(r, Paint()..color = const Color(0xFFF1E2C9));
    WoodPaint.grain(canvas, Path()..addRect(r), Wood.light, seed: 4, alpha: .12);
    canvas.drawRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Wood.deep.withValues(alpha: .45));
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.scale != scale;
}

class _OutlinePainter extends CustomPainter {
  _OutlinePainter(this.jig, this.scale);

  final Jigsaw jig;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Wood.dark.withValues(alpha: .55);
    for (final p in jig.pieces) {
      final path = p.path.shift(p.cell.topLeft - Offset(p.margin, p.margin)).transform(Matrix4.diagonal3Values(scale, scale, 1).storage);
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 9) {
          canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.scale != scale;
}

/// A piece of the Taiwan puzzle tapped: its picture comes alive again.
class AliveScreen extends ConsumerStatefulWidget {
  const AliveScreen({super.key, required this.pictureId});

  final String pictureId;

  @override
  ConsumerState<AliveScreen> createState() => _AliveScreenState();
}

class _AliveScreenState extends ConsumerState<AliveScreen> with HushOnLeave {
  late final Picture _pic = ref.read(libraryProvider).picture[widget.pictureId]!;
  final _alive = GlobalKey<AliveState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sfx(ref, _pic.sound);
      speak(ref, '${_pic.zh}！${_pic.line}');
    });
  }

  void _again() {
    sfx(ref, _pic.sound);
    _alive.currentState?.replay();
    speak(ref, _pic.line);
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    return WithMusic(
      music: Music.ofBox(lib.boxOf(_pic).music),
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: Column(children: [
              TopBar(title: _pic.zh, onHome: () => context.go('/')),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: woodBox(Wood.mid, radius: 22),
                        child: Semantics(
                          button: true,
                          label: _pic.zh,
                          child: Pressable(onTap: _again, sound: null, child: Alive(key: _alive, picture: _pic)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      HelperSays(text: _pic.line, onTap: _again),
                      const SizedBox(height: 20),
                      DoneButtons(onAgain: _again, onHome: () => context.go('/')),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
