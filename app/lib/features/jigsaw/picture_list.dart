import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/jigsaw.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';
import '../common/play_page.dart';

/// 拼圖: the six boxes (水果、動物、夜市、捷運和車車、廟會、城市).
class BoxList extends ConsumerStatefulWidget {
  const BoxList({super.key});

  @override
  ConsumerState<BoxList> createState() => _BoxListState();
}

class _BoxListState extends ConsumerState<BoxList> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, Strings.pickBox);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final g = ref.watch(gameProvider);
    final s = g.settings;
    return WithMusic(
      music: Music.workshop,
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: Column(children: [
              TopBar(title: Strings.jigsawTitle, onHome: () => context.go('/')),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth > 700 ? 220.0 : (box.maxWidth - 44) / 2;
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                    Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                      for (final b in lib.boxes)
                        if (s.boxes.contains(b.id))
                          () {
                            final open = s.boxOpen(b.id);
                            final done = b.pictures.where((p) => g.pictureDone(p.id)).length;
                            void tap() {
                              if (!open) {
                                sayFullOnly(ref, b.zh);
                                return;
                              }
                              context.go('/jigsaw/box?id=${b.id}');
                            }

                            return Semantics(
                              key: ValueKey('box-${b.id}'),
                              container: true,
                              button: true,
                              label: b.zh,
                              excludeSemantics: true,
                              onTap: tap,
                              child: Pressable(
                                onTap: tap,
                                sound: open ? 'open' : 'tap',
                                child: Stack(clipBehavior: Clip.none, children: [
                                  Container(
                                    width: w,
                                    padding: const EdgeInsets.all(8),
                                    decoration: woodBox(b.color, radius: 20),
                                    child: Column(children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(aspectRatio: 4 / 3, child: Opacity(opacity: open ? 1 : .5, child: Art('pictures/${b.pictures.first.id}', fit: BoxFit.cover))),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(b.zh, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                                      Text('$done / ${b.pictures.length}', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: .9))),
                                    ]),
                                  ),
                                  if (!open) const Positioned(right: -4, top: -6, child: LockBadge(size: 32)),
                                ]),
                              ),
                            );
                          }(),
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

/// A box's eight pictures, and how many pieces (a little grid shows the size, no numbers needed).
class PictureList extends ConsumerStatefulWidget {
  const PictureList({super.key, required this.boxId});

  final String boxId;

  @override
  ConsumerState<PictureList> createState() => _PictureListState();
}

class _PictureListState extends ConsumerState<PictureList> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, Strings.pickPicture);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lib = ref.watch(libraryProvider);
    final g = ref.watch(gameProvider);
    final b = lib.box[widget.boxId]!;
    final level = g.settings.level;
    final cut = g.cutFor(level);
    final open = g.cutsOpen(level);
    return WithMusic(
      music: Music.ofBox(b.music),
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: Column(children: [
              TopBar(title: b.zh, onHome: () => context.go('/')),
              SizedBox(
                height: 74,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), children: [
                  for (final c in Cut.ladder(level))
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Semantics(
                        key: ValueKey('cut-${c.name}'),
                        container: true,
                        button: true,
                        selected: c == cut,
                        label: Strings.pieces(c.count),
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: open.contains(c) ? () => ref.read(gameProvider.notifier).change((g) => g.pickCut(level, c)) : null,
                          child: Opacity(
                            opacity: open.contains(c) ? 1 : .35,
                            child: Container(
                              width: 82,
                              padding: const EdgeInsets.all(6),
                              decoration: woodBox(c == cut ? Wood.yellow : Wood.paper, radius: 14, ring: c == cut ? Wood.orange : null),
                              child: Row(children: [
                                Expanded(child: CustomPaint(painter: CutIcon(c), size: const Size(40, 30))),
                                const SizedBox(width: 4),
                                Text('${c.count}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final w = box.maxWidth > 700 ? 230.0 : (box.maxWidth - 44) / 2;
                  return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 100), children: [
                    Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                      for (final p in b.pictures)
                        Semantics(
                          key: ValueKey('pic-${p.id}'),
                          container: true,
                          button: true,
                          label: p.zh,
                          excludeSemantics: true,
                          onTap: () => context.go('/jigsaw/play?pic=${p.id}&cut=${cut.name}'),
                          child: Pressable(
                            onTap: () => context.go('/jigsaw/play?pic=${p.id}&cut=${cut.name}'),
                            sound: 'open',
                            child: Stack(clipBehavior: Clip.none, children: [
                              Container(
                                width: w,
                                padding: const EdgeInsets.all(7),
                                decoration: woodBox(Wood.paper, radius: 18),
                                child: Column(children: [
                                  ClipRRect(borderRadius: BorderRadius.circular(10), child: AspectRatio(aspectRatio: 4 / 3, child: Art('pictures/${p.id}', fit: BoxFit.cover))),
                                  const SizedBox(height: 4),
                                  Text(p.zh, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ]),
                              ),
                              if (g.pictureDone(p.id)) const Positioned(right: -4, top: -6, child: Icon(Icons.check_circle_rounded, color: Wood.green, size: 30)),
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

/// A little picture of a cut: the frame split into its pieces (a dot on each knobbed edge).
class CutIcon extends CustomPainter {
  CutIcon(this.cut);

  final Cut cut;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = h * 4 / 3;
    final r = Rect.fromLTWH((size.width - w) / 2, 0, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()..color = Wood.light);
    final line = Paint()
      ..color = Wood.deep
      ..strokeWidth = 1.4;
    for (var i = 1; i < cut.cols; i++) {
      canvas.drawLine(Offset(r.left + w * i / cut.cols, r.top), Offset(r.left + w * i / cut.cols, r.bottom), line);
    }
    for (var j = 1; j < cut.rows; j++) {
      canvas.drawLine(Offset(r.left, r.top + h * j / cut.rows), Offset(r.right, r.top + h * j / cut.rows), line);
    }
    if (cut.tabs) {
      final dot = Paint()..color = Wood.deep;
      for (var i = 1; i < cut.cols; i++) {
        for (var j = 0; j < cut.rows; j++) {
          canvas.drawCircle(Offset(r.left + w * i / cut.cols, r.top + h * (j + .5) / cut.rows), 1.8, dot);
        }
      }
    }
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Wood.deep);
  }

  @override
  bool shouldRepaint(CutIcon old) => old.cut != cut;
}
