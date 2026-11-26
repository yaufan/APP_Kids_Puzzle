import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:puzzle_workshop/app/app.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/core/providers.dart';
import 'package:puzzle_workshop/core/sounds.dart';
import 'package:puzzle_workshop/core/store.dart';
import 'package:puzzle_workshop/core/voice.dart';
import 'package:puzzle_workshop/core/board.dart';
import 'package:puzzle_workshop/features/common/board_view.dart';

final shotKey = GlobalKey();

Map<String, dynamic> _json(String name) => jsonDecode(File('assets/$name.json').readAsStringSync()) as Map<String, dynamic>;

/// The boxes and puzzles, read from the asset files.
final lib = Library.parse(_json('content'), _json('tangram'), _json('blocks'), _json('taiwan'));

/// The app on a phone screen, starting from [game].
class TestApp {
  TestApp(this.tester, this.store, this.sounds, this.voice);

  final WidgetTester tester;
  final MemoryStore store;
  final RecordingSounds sounds;
  final RecordingVoice voice;
  DateTime now = DateTime(2026, 11, 15, 10);

  ProviderContainer get container => ProviderScope.containerOf(tester.element(find.byType(PuzzleApp)));
  Game get game => container.read(gameProvider);
  void change(Game Function(Game g) f) => container.read(gameProvider.notifier).change(f);

  static Future<TestApp> start(WidgetTester tester,
      {Game game = const Game(helper: Helper.pangolin), Size size = const Size(1080, 2340), double ratio = 2.75, String at = '/', int seed = 1, RecordingVoice? voice, DateTime? now}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final store = MemoryStore();
    final app = TestApp(tester, store, RecordingSounds(), voice ?? RecordingVoice());
    if (now != null) app.now = now;
    await tester.pumpWidget(RepaintBoundary(
      key: shotKey,
      child: ProviderScope(
        overrides: [
          libraryProvider.overrideWithValue(lib),
          storeProvider.overrideWithValue(store),
          savedGameProvider.overrideWithValue(game),
          randomProvider.overrideWithValue(math.Random(seed)),
          soundsProvider.overrideWithValue(app.sounds),
          voiceProvider.overrideWithValue(app.voice),
          clockProvider.overrideWithValue(() => app.now),
        ],
        child: const PuzzleApp(),
      ),
    ));
    if (at != '/') app.go(at);
    await app.settle();
    return app;
  }

  void go(String location) => container.read(routerProvider).go(location);

  String get location => container.read(routerProvider).state.matchedLocation;

  /// Lets the pictures load and the screen move on [ms] milliseconds.
  Future<void> settle([int ms = 400]) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(Duration(milliseconds: ms ~/ 6));
    }
  }

  Future<void> tapLabel(String label, {int ms = 400}) async {
    await tester.tap(find.bySemanticsLabel(label).last, warnIfMissed: false);
    await settle(ms);
  }

  /// Scrolls a list until [label] shows, then taps it.
  Future<void> scrollTap(String label, {int ms = 400}) async {
    final f = find.bySemanticsLabel(label);
    if (f.evaluate().isEmpty || !tester.getRect(f.last).overlaps(Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio)) {
      await tester.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).first);
      await settle(200);
    }
    await tapLabel(label, ms: ms);
  }

  Future<void> end() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Real fonts for screenshots instead of the test font's boxes.
Future<void> loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter';
  final fonts = {
    'MaterialIcons': ['$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'],
    'Huninn': ['assets/fonts/jf-openhuninn-2.1.ttf'],
    'Roboto': ['assets/fonts/jf-openhuninn-2.1.ttf'],
  };
  for (final MapEntry(key: family, value: paths) in fonts.entries) {
    final loader = FontLoader(family);
    for (final path in paths.where((p) => File(p).existsSync())) {
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }
}

Future<void> shoot(WidgetTester tester, String device, String name) => tester.runAsync(() async {
      final boundary = shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/screenshots/$device/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });

/// Holds a finger down on [finder] for [ms] milliseconds, frame by frame.
Future<void> hold(TestApp app, Finder finder, int ms) async {
  final g = await app.tester.startGesture(app.tester.getCenter(finder));
  await app.tester.pump(const Duration(milliseconds: 50));
  for (var t = 0; t < ms; t += 100) {
    await app.tester.pump(const Duration(milliseconds: 100));
  }
  await g.up();
  await app.tester.pump(const Duration(milliseconds: 50));
}

/// Drags a finger from [from] to [to] in small steps (raw pointer moves).
Future<void> dragFinger(TestApp app, Offset from, Offset to) async {
  final g = await app.tester.startGesture(from);
  await app.tester.pump(const Duration(milliseconds: 30));
  for (var i = 1; i <= 8; i++) {
    await g.moveTo(Offset.lerp(from, to, i / 8)!);
    await app.tester.pump(const Duration(milliseconds: 20));
  }
  await g.up();
  await app.tester.pump(const Duration(milliseconds: 30));
}

/// The board on screen.
PuzzleBoardState boardOf(WidgetTester t) => t.state<PuzzleBoardState>(find.byType(PuzzleBoard));

/// Puts pieces where they go, one drag each (turning and flipping them first with taps if the board
/// wants that), until the board is done or [n] are placed.
Future<int> solve(TestApp app, {int? n, Future<void> Function(int placed)? after}) async {
  var placed = 0;
  for (var guard = 0; guard < 80; guard++) {
    final b = boardOf(app.tester);
    if (b.board.done || (n != null && placed >= n)) break;
    Piece? p;
    Slot? s;
    for (final q in b.trayPieces) {
      final home = b.board.home(q);
      if (home != null) {
        p = q;
        s = home;
        break;
      }
    }
    if (p == null || s == null) break;
    await turnRight(app, b, p, s);
    await dragFinger(app, b.pieceAt(p), b.fingerFor(p, s));
    await app.settle(300);
    placed++;
    if (after != null) await after(placed);
  }
  return placed;
}

/// With tap turning: taps [p] (and its flip button) until it looks like [s] needs.
Future<void> turnRight(TestApp app, PuzzleBoardState b, Piece p, Slot s) async {
  if (b.widget.turning != Turning.tap) return;
  if (s.chiral && p.flip != s.flip) {
    await app.tester.tapAt(b.flipAt(p)!);
    await app.settle(250);
  }
  for (var k = 0; k < 8 && !Board.sameTurn(p.angle, p.flip, s); k++) {
    await app.tester.tapAt(b.pieceAt(p));
    await app.settle(250);
  }
}

/// Answers the parent gate (it asks a sum written in characters).
Future<void> answerGate(TestApp app) async {
  const digits = '零一二三四五六七八九';
  final q = app.tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere((t) => t.contains('加') && t.contains('等於'));
  final sum = digits.indexOf(q[0]) + digits.indexOf(q[2]);
  for (final c in '$sum'.split('')) {
    await app.tester.tap(find.byKey(ValueKey('gate-key-$c')));
    await app.settle(150);
  }
  await app.settle(600);
}
