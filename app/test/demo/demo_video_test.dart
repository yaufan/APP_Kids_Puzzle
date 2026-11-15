// Records a demo video of 拼拼樂工坊 being played: a scripted child (a white
// dot where the finger is) with a caption under the phone screen; the music
// and sounds the app asked for are written down and mixed in afterwards by
// tools/demo_audio.py.
//
//   flutter test test/demo/demo_video_test.dart --dart-define=DEMO=true
//   python3 ../tools/demo_audio.py
//
// Needs ffmpeg; writes build/demo/demo.mp4, chapters.txt and sounds.txt.
// Skipped in normal test runs.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/app/app.dart';
import 'package:puzzle_workshop/app/strings.dart';
import 'package:puzzle_workshop/core/board.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/core/providers.dart';
import 'package:puzzle_workshop/core/sounds.dart';
import 'package:puzzle_workshop/core/store.dart';
import 'package:puzzle_workshop/core/voice.dart';
import 'package:puzzle_workshop/features/common/board_view.dart';
import 'package:puzzle_workshop/features/common/play_page.dart';
import 'package:puzzle_workshop/features/parent/parent_gate.dart';

import '../helpers.dart' show lib, loadFonts;

const _phone = Size(390, 844);
const _captionHeight = 84.0;
const _fps = 10;
const _demo = bool.fromEnvironment('DEMO');

/// The music and the sounds asked for, with the frame they were asked at.
class _Recording implements Sounds {
  _Recording(this.frame);

  final int Function() frame;
  final lines = <String>[];
  final _holders = MusicHolders();
  Music? _playing;

  @override
  set music(bool on) {}

  @override
  set effects(bool on) {}

  @override
  void play(String sfx) => lines.add('${frame()} sfx $sfx');

  @override
  void hold(Object owner, Music? music) {
    _holders.hold(owner, music);
    _changed();
  }

  @override
  void release(Object owner) {
    _holders.release(owner);
    _changed();
  }

  void _changed() {
    final now = _holders.current;
    if (now == _playing) return;
    _playing = now;
    lines.add('${frame()} music ${now?.file ?? '-'}');
  }
}

void main() {
  testWidgets('demo video', skip: !_demo, (tester) async {
    await tester.runAsync(loadFonts);
    tester.view.physicalSize = Size(_phone.width * 3, (_phone.height + _captionHeight) * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    var frameCount = 0;
    var now = DateTime(2026, 11, 15, 10);
    final track = _Recording(() => frameCount);
    final finger = ValueNotifier<Offset?>(null);
    final caption = ValueNotifier<String>('');
    final key = GlobalKey();
    final store = MemoryStore();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [
          SizedBox.fromSize(
            size: _phone,
            child: MediaQuery(
              data: const MediaQueryData(size: _phone, devicePixelRatio: 3, padding: EdgeInsets.only(top: 24)),
              child: Stack(children: [
                ProviderScope(
                  overrides: [
                    libraryProvider.overrideWithValue(lib),
                    storeProvider.overrideWithValue(store),
                    savedGameProvider.overrideWithValue(const Game()),
                    soundsProvider.overrideWithValue(track),
                    voiceProvider.overrideWithValue(const SilentVoice()),
                    randomProvider.overrideWithValue(math.Random(5)),
                    clockProvider.overrideWithValue(() => now),
                  ],
                  child: const PuzzleApp(),
                ),
                IgnorePointer(child: ValueListenableBuilder(valueListenable: finger, builder: (_, at, _) => _Finger(at))),
              ]),
            ),
          ),
          SizedBox(
            width: _phone.width,
            height: _captionHeight,
            child: ColoredBox(
              color: const Color(0xFF8A5A33),
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: caption,
                  builder: (_, text, _) => Text(text, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Huninn', color: Colors.white, fontSize: 17, height: 1.35)),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));

    final rec = (await tester.runAsync(() => _Recorder.start(key)))!;
    final marks = <String>[];
    void mark(String name) => marks.add('$name $frameCount');
    Future<void> frames(int n) async {
      for (var i = 0; i < n; i++) {
        frameCount++;
        await tester.runAsync(() async {
          await rec.capture();
          await Future<void>.delayed(const Duration(milliseconds: 15));
        });
        await tester.pump(const Duration(milliseconds: 1000 ~/ _fps));
      }
    }

    Future<void> seconds(double s) => frames((s * _fps).round());
    Future<void> touch(Offset at) async {
      finger.value = at;
      await frames(2);
      await tester.tapAt(at);
      await frames(2);
      finger.value = null;
    }

    Offset at(String l) => tester.getCenter(find.bySemanticsLabel(l).last);
    Future<void> label(String l) => touch(at(l));
    ProviderContainer container() => ProviderScope.containerOf(tester.element(find.byType(PuzzleApp)));
    void change(Game Function(Game) f) => container().read(gameProvider.notifier).change(f);
    void go(String to) => container().read(routerProvider).go(to);
    PuzzleBoardState board() => tester.state<PuzzleBoardState>(find.byType(PuzzleBoard));

    Future<void> drag(Offset from, Offset to, {int steps = 10}) async {
      finger.value = from;
      final g = await tester.startGesture(from);
      await frames(2);
      for (var k = 1; k <= steps; k++) {
        final p = Offset.lerp(from, to, Curves.easeInOut.transform(k / steps))!;
        finger.value = p;
        await g.moveTo(p);
        await frames(1);
      }
      await g.up();
      finger.value = null;
      await frames(4);
    }

    /// Puts [n] pieces (or all) where they go, turning them first when the board wants taps.
    Future<void> place({int? n, double pause = .3}) async {
      var done = 0;
      while (n == null || done < n) {
        final b = board();
        if (b.board.done) break;
        Piece? p;
        Slot? s;
        for (final q in b.trayPieces) {
          final h = b.board.home(q);
          if (h != null) {
            p = q;
            s = h;
            break;
          }
        }
        if (p == null || s == null) break;
        if (b.widget.turning == Turning.tap) {
          if (s.chiral && p.flip != s.flip) {
            await touch(b.flipAt(p)!);
            await frames(3);
          }
          for (var k = 0; k < 8 && !Board.sameTurn(p.angle, p.flip, s); k++) {
            await touch(b.pieceAt(p));
            await frames(3);
          }
        }
        await drag(b.pieceAt(p), b.fingerFor(p, s));
        await seconds(pause);
        done++;
      }
    }

    // ---- Opening: pick a helper.
    mark('helper');
    caption.value = '拼拼樂工坊：2 歲半～5 歲的拼圖、七巧板和形狀積木\n彩繪木頭風，放對了「咔」一聲吸進去';
    await seconds(3);
    caption.value = '第一次打開：從六隻台灣動物選一個工坊小幫手\n（穿山甲、石虎、黑熊、藍鵲、梅花鹿、獼猴）';
    await seconds(3);
    await label('甲甲');
    await seconds(3);

    mark('home');
    caption.value = '工坊：上面是「台灣大拼圖」，拼好一張圖就多一塊\n下面是玩具盒（小小有三個，照著拼從中開始）';
    await seconds(4.5);

    // ---- 形狀洞洞.
    mark('shapes');
    caption.value = '形狀洞洞：形狀盒一次多一個洞，咚！掉進去';
    await label('形狀洞洞');
    await seconds(1.5);
    await label('形狀盒');
    await seconds(1.5);
    await place();
    await seconds(3);
    caption.value = '嵌板：木頭片上有小把手，小小看得到淡淡的圖\n放錯了只會輕輕飄回去，沒有「嗶」';
    go('/shapes/inset?board=fruit');
    await seconds(2);
    var b = board();
    final wrong = b.trayPieces.first;
    final far = b.board.slots.firstWhere((s) => s.kind != wrong.kind);
    await drag(b.pieceAt(wrong), b.fingerFor(wrong, far));
    await seconds(1.5);
    await place(n: 2);
    caption.value = '還不會拖的小朋友：點一下拿起來，再點它的洞，它就自己飛過去';
    b = board();
    final tp = b.trayPieces.first;
    await touch(b.pieceAt(tp));
    await seconds(1);
    await touch(b.fingerFor(tp, b.board.home(tp)!));
    await seconds(1.5);
    await place();
    await seconds(3.5);

    // ---- 拼圖.
    mark('jigsaw');
    caption.value = '拼圖：六盒 48 張台灣的圖，同一張圖可以拼 2～24 塊\n同一個塊數拼好 3 張，就多一個大一點的可以選';
    go('/jigsaw');
    await seconds(2.5);
    await label('動物盒');
    await seconds(2);
    change((g) => g.withSettings(g.settings.copyWith(level: Level.middle)).copyWith(cutsDone: {'r4': 3, 'r6': 3, 't4': 3}));
    await frames(3);
    await touch(tester.getCenter(find.byKey(const ValueKey('cut-t6'))));
    await seconds(1);
    await label('台灣黑熊');
    caption.value = '托盤一次給 6 塊，放好一塊補一塊\n靠近對的位置會發亮，放開就「咻—咔」吸進去';
    await seconds(2);
    await place(pause: .5);
    caption.value = '拼好了：圖動起來，發出自己的聲音\n台灣大拼圖多一塊！沒有分數、沒有星星';
    await seconds(6);

    mark('jigsaw_big');
    caption.value = '大（4～5 歲）：24 塊真的拼圖形狀\n12 塊以上先給四個角和邊邊（學「先拼邊框」）';
    change((g) => g.withSettings(g.settings.copyWith(level: Level.big)).copyWith(cutsDone: {'t9': 3, 't12': 3, 't16': 3, 't20': 3}));
    go('/jigsaw/play?pic=mrt&cut=t24');
    await seconds(3);
    await place(n: 10, pause: .1);
    await seconds(1);
    await place(pause: .05);
    await seconds(5);

    // ---- 七巧板.
    mark('tangram');
    caption.value = '七巧板 中：塊放近了自己轉正\n（研究說 5 歲左右才開始會在腦子裡轉東西）';
    change((g) => g.withSettings(g.settings.copyWith(level: Level.middle)));
    go('/tangram/play?id=cat');
    await seconds(3);
    await place(pause: .6);
    await seconds(4);
    caption.value = '七巧板 大：點一下轉 45 度，平行四邊形按「翻」\n轉錯了：淡淡的正確方向出現，兩次以後小幫手幫你轉';
    change((g) => g.withSettings(g.settings.copyWith(level: Level.big)));
    go('/tangram/play?id=house7');
    await seconds(3);
    b = board();
    final tw = b.trayPieces.firstWhere((p) => !Board.sameTurn(p.angle, p.flip, b.board.home(p)!));
    await drag(b.pieceAt(tw), b.fingerFor(tw, b.board.home(tw)!));
    await seconds(2.5);
    await place(pause: .4);
    await seconds(4);

    // ---- 照著拼.
    mark('blocks');
    caption.value = '照著拼（中）：看小卡片，用形狀積木拼出一樣的\n托盤上的點點是還有幾個';
    change((g) => g.withSettings(g.settings.copyWith(level: Level.middle)));
    go('/blocks/play?id=flower');
    await seconds(3);
    await place(pause: .5);
    await seconds(3.5);
    caption.value = '照著拼（大）：只有外框，怎麼填滿都對\n兩個梯形也是一個六角形！';
    change((g) => g.withSettings(g.settings.copyWith(level: Level.big)));
    go('/blocks/play?id=butterfly');
    await seconds(2.5);
    b = board();
    final hex = b.board.slots.firstWhere((s) => s.kind == 'hex').cells.toSet();
    for (var i = 0; i < 2; i++) {
      final trap = b.trayPieces.firstWhere((p) => p.kind == 'trap');
      final spot = b.board.slots.firstWhere((s) => s.kind == 'trap' && s.cells.every(hex.contains) && b.board.isFree(s));
      await drag(b.pieceAt(trap), b.fingerFor(trap, spot));
      await seconds(.6);
    }
    await place(pause: .4);
    await seconds(4);

    // ---- The Taiwan puzzle.
    mark('taiwan');
    caption.value = '台灣大拼圖：點一塊，那張圖再動一次';
    go('/');
    await seconds(2.5);
    final rect = tester.getRect(find.byType(TaiwanView).first);
    final piece = lib.taiwan.pieces[Library.taiwanPiece(lib.picture['bear']!.index)];
    final c = piece.fold(Offset.zero, (a, p) => a + p) / piece.length.toDouble();
    await touch(rect.topLeft + c * (rect.width / lib.taiwan.size.width));
    await seconds(5);
    await label(Strings.home);
    await seconds(1.5);

    // ---- Parent mode.
    mark('parent');
    caption.value = '家長模式：左上角的鎖要按住，再回答家長關卡';
    final lock = at(Strings.parent);
    finger.value = lock;
    final g = await tester.startGesture(lock);
    await seconds(1.2);
    await g.up();
    finger.value = null;
    await seconds(1);
    const digits = '零一二三四五六七八九';
    final q = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere((t) => t.contains('加') && t.contains('等於'));
    for (final d in '${digits.indexOf(q[0]) + digits.indexOf(q[2])}'.split('')) {
      await touch(tester.getCenter(find.byKey(ValueKey('gate-key-$d'))));
      await frames(3);
    }
    await seconds(1.5);
    caption.value = '難度、玩多久、進度（小朋友看不到）\n一起玩的小提醒：多說「上面、旁邊、轉一轉」';
    await seconds(4);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await seconds(3);
    caption.value = '轉動、磁鐵強弱、提示、淡淡的圖、先給邊邊\n要出現的玩具盒和拼圖盒、聲音';
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await seconds(3.5);
    go('/');
    await seconds(2.5);

    // ---- Rest.
    mark('rest');
    now = now.add(const Duration(minutes: 16));
    caption.value = '時間到了（預設 15 分鐘）：小幫手睡覺\n「換你去做了！去收玩具、拼真的拼圖吧！」';
    await seconds(6);
    caption.value = '';
    mark('end');
    await seconds(.5);
    expect(ParentPass.take(), isFalse);
    await tester.runAsync(() async {
      await rec.finish();
      File('build/demo/chapters.txt').writeAsStringSync('${marks.join('\n')}\n');
      File('build/demo/sounds.txt').writeAsStringSync('fps $_fps\nframes $frameCount\n${track.lines.join('\n')}\n');
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }, timeout: const Timeout(Duration(minutes: 40)));
}

class _Finger extends StatelessWidget {
  const _Finger(this.at);

  final Offset? at;

  @override
  Widget build(BuildContext context) {
    final p = at;
    if (p == null) return const SizedBox.expand();
    return Stack(children: [
      Positioned(
        left: p.dx - 22,
        top: p.dy - 22,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.55),
            border: Border.all(color: const Color(0xFF4A3B32).withValues(alpha: 0.5), width: 3),
          ),
        ),
      ),
    ]);
  }
}

/// Streams frames of [key]'s boundary into ffmpeg.
class _Recorder {
  _Recorder(this._key, this._ffmpeg);

  final GlobalKey _key;
  final Process _ffmpeg;

  static Future<_Recorder> start(GlobalKey key) async {
    Directory('build/demo').createSync(recursive: true);
    final size = Size(_phone.width * 2, (_phone.height + _captionHeight) * 2);
    final ffmpeg = await Process.start('ffmpeg', [
      '-y', '-loglevel', 'error',
      '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '${size.width.toInt()}x${size.height.toInt()}', '-r', '$_fps', '-i', '-',
      '-vf', 'fps=30', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '24', '-movflags', '+faststart', 'build/demo/demo_silent.mp4',
    ]);
    ffmpeg.stderr.listen(stderr.add);
    return _Recorder(key, ffmpeg);
  }

  Future<void> capture() async {
    final boundary = _key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    _ffmpeg.stdin.add(bytes!.buffer.asUint8List());
    await _ffmpeg.stdin.flush();
  }

  Future<void> finish() async {
    await _ffmpeg.stdin.flush();
    await _ffmpeg.stdin.close();
    final code = await _ffmpeg.exitCode;
    if (code != 0) throw StateError('ffmpeg failed ($code)');
  }
}
