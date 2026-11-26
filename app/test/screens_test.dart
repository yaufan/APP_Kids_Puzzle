import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/app/strings.dart';
import 'package:puzzle_workshop/app/widgets.dart';
import 'package:puzzle_workshop/core/board.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/core/providers.dart';
import 'package:puzzle_workshop/core/sounds.dart';
import 'package:puzzle_workshop/core/voice.dart';
import 'package:puzzle_workshop/features/parent/parent_gate.dart';

import 'helpers.dart';

/// A music player that takes as long as the test says to start a tune.
class SlowLoop implements MusicLoop {
  final calls = <String>[];
  String? playing;
  Completer<void>? loading;

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = null;
  }

  @override
  Future<void> play(String file, double volume) async {
    calls.add('play $file');
    final c = loading = Completer<void>();
    await c.future;
    playing = file;
  }
}

/// The lessons from the sibling apps' reviews: play time, the voice between screens, fingers,
/// switches a parent turned off, and a small phone.
void main() {
  testWidgets('time in parent mode is not the child\'s play time', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    ParentPass.grant();
    app.go('/parent');
    await app.settle(2600);
    app.now = app.now.add(const Duration(minutes: 20));
    await app.settle(2600);
    expect(app.location, '/parent');
    app.go('/');
    await app.settle(2600);
    expect(app.location, '/', reason: 'the child has played 10 of the 15 minutes');
    app.now = app.now.add(const Duration(minutes: 6));
    await app.settle(2600);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('today\'s minutes do not count while the app is in the background', (tester) async {
    final app = await TestApp.start(tester);
    await app.settle(2600);
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    for (var i = 0; i < 4; i++) {
      await app.settle(30000);
    }
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    await app.settle(400);
    expect(app.game.log(app.now).seconds, lessThan(10), reason: 'two minutes away are not two minutes played');
    await app.end();
  });

  testWidgets('a puzzle being put together may be finished when the time is up, two minutes at most', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/inset?board=animals');
    await app.settle(900);
    app.now = app.now.add(const Duration(minutes: 16));
    await app.settle(2600);
    expect(app.location, '/shapes/inset', reason: 'busy: it can be finished');
    await solve(app);
    await app.settle(2600);
    expect(app.location, '/shapes/inset', reason: 'the celebration is not cut short');
    await app.settle(2600);
    await app.settle(2600);
    expect(app.location, '/rest', reason: 'done: now the rest');
    await app.end();
  });

  testWidgets('…but not more than two minutes', (tester) async {
    final app2 = await TestApp.start(tester);
    app2.go('/jigsaw/play?pic=bear&cut=r2');
    await app2.settle(900);
    expect(app2.container.read(busyProvider), isTrue);
    app2.now = app2.now.add(const Duration(minutes: 16));
    await app2.settle(2600);
    expect(app2.location, '/jigsaw/play');
    app2.now = app2.now.add(const Duration(minutes: 2, seconds: 5));
    await app2.settle(2600);
    expect(app2.location, '/rest', reason: 'not more than two minutes');
    await app2.end();
  });

  testWidgets('leaving a screen stops its voice, but never the next screen\'s first line', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes');
    await app.settle(1200);
    expect(app.voice.stops, 0);
    ParentPass.grant();
    app.go('/parent');
    await app.settle(1200);
    expect(app.voice.stops, 1, reason: 'the question does not go on over parent mode');
    app.go('/tangram');
    await app.settle(1200);
    app.go('/');
    await app.settle(1200);
    expect(app.voice.stops, 1, reason: 'the tangram\'s line was cut by the workshop\'s own first line, never by a stop after it');
    expect(app.voice.said.last, Strings.whatNow);
    await app.end();
  });

  testWidgets('the next step waits until a slow line has been said, but not for ever', (tester) async {
    final line = Completer<void>();
    var ran = 0;
    Later(const Duration(milliseconds: 500), () => ran++, after: line.future);
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 0, reason: 'still speaking');
    line.complete();
    await tester.pump();
    expect(ran, 1);
    Later(const Duration(milliseconds: 500), () => ran++, after: Completer<void>().future, atMost: const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(ran, 2, reason: 'a voice that never says it is done does not hold the game up');
    Later(const Duration(milliseconds: 500), () => ran++).cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(ran, 2);
  });

  testWidgets('only the first finger moves a piece; a second finger does not drop it', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/inset?board=fruit');
    await app.settle(900);
    final b = boardOf(tester);
    final p = b.trayPieces.first;
    final s = b.board.home(p)!;
    final g1 = await tester.startGesture(b.pieceAt(p), pointer: 1);
    await tester.pump(const Duration(milliseconds: 50));
    await g1.moveTo(b.pieceAt(p) + const Offset(30, -60));
    await tester.pump(const Duration(milliseconds: 50));
    final other = b.trayPieces[1];
    final g2 = await tester.startGesture(b.pieceAt(other), pointer: 2);
    await g2.moveTo(b.fingerFor(other, b.board.home(other)!));
    await tester.pump(const Duration(milliseconds: 50));
    await g2.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(b.board.placed, isEmpty, reason: 'the second finger moved nothing and dropped nothing');
    await g1.moveTo(b.fingerFor(p, s));
    await tester.pump(const Duration(milliseconds: 50));
    await g1.up();
    await app.settle(400);
    expect(b.board.placed.keys, [p.id]);
    await app.end();
  });

  testWidgets('a cancelled touch puts the piece back: not a drop, not a miss', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/inset?board=animals');
    await app.settle(900);
    final b = boardOf(tester);
    final p = b.trayPieces.first;
    final g = await tester.startGesture(b.pieceAt(p));
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(b.fingerFor(p, b.board.home(p)!));
    await tester.pump(const Duration(milliseconds: 50));
    await g.cancel();
    await app.settle(600);
    expect(b.board.placed, isEmpty);
    expect(b.trayPieces.map((q) => q.id), contains(p.id));
    expect(app.sounds.played.where((s) => s == 'back'), isEmpty, reason: 'nothing went wrong');
    await app.end();
  });

  testWidgets('a piece never leaves the screen and keeps clear of its edges', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/box');
    await app.settle(900);
    final b = boardOf(tester);
    final p = b.trayPieces.first;
    final g = await tester.startGesture(b.pieceAt(p));
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveTo(const Offset(-300, -500));
    await tester.pump(const Duration(milliseconds: 50));
    final at = b.pieceAt(p);
    final screen = tester.getRect(find.byType(Scaffold).first);
    expect(at.dx, greaterThanOrEqualTo(screen.left + 24));
    expect(at.dy, greaterThanOrEqualTo(screen.top));
    await g.up();
    await app.settle(600);
    expect(b.trayPieces.map((q) => q.id), contains(p.id), reason: 'it floats back to the tray');
    await app.end();
  });

  testWidgets('a quick tap picks a piece; a tap on its place sends it there; a tap elsewhere sends it back', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/inset?board=ride');
    await app.settle(900);
    final b = boardOf(tester);
    final p = b.trayPieces.first;
    await tester.tapAt(b.pieceAt(p));
    await app.settle(300);
    expect(b.board.placed, isEmpty);
    final home = b.board.home(p)!;
    final wrong = b.board.slots.reduce((a, c) => (c.at - home.at).distance > (a.at - home.at).distance ? c : a);
    await tester.tapAt(b.fingerFor(p, wrong));
    await app.settle(500);
    expect(b.board.placed, isEmpty);
    await tester.tapAt(b.pieceAt(p));
    await app.settle(300);
    await tester.tapAt(b.fingerFor(p, b.board.home(p)!));
    await app.settle(500);
    expect(b.board.placed.keys, [p.id]);
    await app.end();
  });

  testWidgets('each switch silences only its own sound, and what a parent turned off stays off', (tester) async {
    final app = await TestApp.start(tester);
    final g = app.container.read(gameProvider.notifier);
    g.settings((s) => s.copyWith(sounds: false));
    await app.settle();
    expect(app.sounds.effectsOn, isFalse);
    expect(app.sounds.musicOn, isTrue);
    app.go('/shapes');
    await app.settle(900);
    expect(app.voice.said.last, Strings.shapesPick, reason: 'the voice still speaks');
    g.settings((s) => s.copyWith(sounds: true, music: false));
    await app.settle();
    expect(app.sounds.effectsOn, isTrue);
    expect(app.sounds.musicOn, isFalse);
    g.settings((s) => s.copyWith(music: true, voice: false));
    final said = app.voice.said.length;
    app.go('/tangram');
    await app.settle(900);
    expect(app.voice.said.length, said, reason: 'the voice is off');
    expect(app.sounds.musicOn && app.sounds.effectsOn, isTrue);

    g.settings((s) => s.copyWith(modes: {Mode.shapes, Mode.jigsaw}));
    app.go('/');
    await app.settle(600);
    expect(find.bySemanticsLabel('七巧板'), findsNothing);
    app.go('/tangram');
    await app.settle();
    expect(app.location, '/');
    final saved = Game.fromJson(app.store.saved, lib);
    expect(saved.settings.modes, {Mode.shapes, Mode.jigsaw}, reason: 'still off after saving');
    expect(saved.settings.voice, isFalse);
    await app.end();
  });

  testWidgets('a small phone (360 × 640): 24 pieces are at least 44 points; the tray stays on screen', (tester) async {
    final app = await TestApp.start(tester, size: const Size(1080, 1920), ratio: 3, game: const Game(helper: Helper.deer, settings: Settings(level: Level.big), cutsDone: {'t9': 3, 't12': 3, 't16': 3, 't20': 3}));
    app.go('/jigsaw/play?pic=train&cut=t24');
    await app.settle(900);
    final b = boardOf(tester);
    expect(400 / 6 * b.scale, greaterThanOrEqualTo(44));
    expect(300 / 4 * b.scale, greaterThanOrEqualTo(44));
    final pts = [for (final p in b.trayPieces) b.pieceAt(p)];
    for (final p in pts) {
      expect(p.dx > 0 && p.dx < 360 && p.dy > 0 && p.dy < 640, isTrue);
      expect(pts.where((q) => (q - p).distance < 40).length, 1, reason: 'tray pieces do not sit on each other');
    }
    await solve(app, n: 3);
    expect(b.board.placed.length, 3);
    await app.end();
  });

  testWidgets('大: a piece let go turned the wrong way twice is turned by the helper', (tester) async {
    final app = await TestApp.start(tester, game: const Game(helper: Helper.macaque, settings: Settings(level: Level.big)));
    app.go('/tangram/play?id=rocket7');
    await app.settle(900);
    final b = boardOf(tester);
    expect(b.widget.turning, Turning.tap);
    // Turned wrong for every place of its shape (one turned right for the other big triangle would
    // go there: test/rules_test.dart).
    final p = b.trayPieces.firstWhere((q) => b.board.slots.where((s) => s.kind == q.kind).every((s) => !Board.sameTurn(q.angle, q.flip, s)));
    final s = b.board.home(p)!;
    for (var i = 0; i < 2; i++) {
      await dragFinger(app, b.pieceAt(p), b.fingerFor(p, s));
      await app.settle(600);
      expect(b.board.placed, isEmpty);
    }
    expect(app.voice.said.last, Strings.helpTurn(Helper.macaque));
    expect(Board.sameTurn(p.angle, p.flip, s), isTrue);
    await dragFinger(app, b.pieceAt(p), b.fingerFor(p, b.board.home(p)!));
    await app.settle(500);
    expect(b.board.placed.keys, [p.id]);
    expect(app.voice.pitches.last, Helper.macaque.pitch, reason: 'in the helper\'s own voice');
    await app.end();
  });

  // ---------------------------------------------------------------- the code review (2026-11-15)

  void hide(WidgetTester tester) {
    for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  void show(WidgetTester tester) {
    for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
  }

  testWidgets('a palm resting on the board does not stop another finger from moving a piece', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/inset?board=fruit');
    await app.settle(900);
    final b = boardOf(tester);
    final p = b.trayPieces.first;
    final s = b.board.home(p)!;
    final elsewhere = b.board.slots.firstWhere((x) => x.id != s.id);
    final palm = await tester.startGesture(b.fingerFor(p, elsewhere), pointer: 1);
    await tester.pump(const Duration(milliseconds: 300));
    final g = await tester.startGesture(b.pieceAt(p), pointer: 2);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 6; i++) {
      await g.moveTo(Offset.lerp(b.pieceAt(p), b.fingerFor(p, s), i / 6)!);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await g.up();
    await app.settle(400);
    expect(b.board.placed.keys, [p.id]);
    await palm.up();
    await app.settle(300);
    expect(b.board.placed.keys, [p.id], reason: 'the palm lifting does nothing');
    await app.end();
  });

  testWidgets('the app going away mid-drag puts the piece back, and the next touch works', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/shapes/inset?board=animals');
    await app.settle(900);
    final b = boardOf(tester);
    final p = b.trayPieces.first;
    final g1 = await tester.startGesture(b.pieceAt(p), pointer: 1);
    await tester.pump(const Duration(milliseconds: 50));
    await g1.moveTo(b.pieceAt(p) + const Offset(20, -120));
    await tester.pump(const Duration(milliseconds: 50));
    hide(tester);
    await app.settle(600);
    show(tester);
    await app.settle(600);
    expect(b.board.placed, isEmpty);
    expect(b.trayPieces.map((q) => q.id), contains(p.id), reason: 'back in the tray');
    final q = b.trayPieces.last;
    await dragFinger(app, b.pieceAt(q), b.fingerFor(q, b.board.home(q)!));
    await app.settle(400);
    expect(b.board.placed.keys, [q.id], reason: 'the finger that never lifted does not block the board');
    await g1.up();
    await app.end();
  });

  testWidgets('大 照著拼: the helper\'s paw lights a place even when the first stack has nowhere left to go', (tester) async {
    final app = await TestApp.start(tester, game: const Game(helper: Helper.bear, settings: Settings(level: Level.big)));
    app.go('/blocks/play?id=flower');
    await app.settle(900);
    final b = boardOf(tester);
    final hex = b.trayPieces.firstWhere((p) => p.kind == 'hex');
    await dragFinger(app, b.pieceAt(hex), b.fingerFor(hex, b.board.slots.firstWhere((s) => s.kind == 'hex')));
    await app.settle(400);
    expect(b.board.placed.keys, [hex.id]);
    expect(b.trayPieces.first.kind, 'trap');
    expect(b.board.home(b.trayPieces.first), isNull, reason: 'no trapezoid fits beside the hexagon');
    await app.tapLabel(Strings.help);
    expect(b.glowing, isNotEmpty, reason: 'a triangle\'s place lights up');
    expect(b.board.slots.firstWhere((s) => s.id == b.glowing.first).kind, 'tri');
    await app.end();
  });

  testWidgets('下一張: the new picture may be finished when the time is up, too', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/jigsaw/play?pic=bear&cut=r2');
    await app.settle(900);
    await solve(app);
    await app.settle(5000);
    await app.tapLabel(Strings.next, ms: 900);
    expect(app.location, '/jigsaw/play');
    await app.settle(600);
    expect(app.container.read(busyProvider), isTrue, reason: 'the picture going away did not take the new one\'s busy with it');
    app.now = app.now.add(const Duration(minutes: 16));
    await app.settle(2600);
    expect(app.location, '/jigsaw/play', reason: 'it may be finished');
    await app.end();
  });

  testWidgets('a puzzle finished at the end of the two minutes still comes alive before the rest', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/jigsaw/play?pic=mango_ice&cut=r2');
    await app.settle(900);
    app.now = app.now.add(const Duration(minutes: 16));
    await app.settle(2600);
    expect(app.location, '/jigsaw/play');
    await solve(app);
    await app.settle(600);
    app.now = app.now.add(const Duration(minutes: 2, seconds: 5));
    await app.settle(2600);
    expect(app.location, '/jigsaw/play', reason: 'the picture is coming alive');
    await app.settle(2600);
    expect(app.location, '/rest', reason: 'then the rest, without waiting any longer');
    await app.end();
  });

  testWidgets('minutes in the background are not the sitting\'s, and the rest never starts there', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    hide(tester);
    app.now = app.now.add(const Duration(minutes: 8));
    await app.settle(4200);
    expect(app.location, '/', reason: 'nothing happens out of sight');
    show(tester);
    await app.settle(2600);
    expect(app.location, '/', reason: 'the child has played 10 of the 15 minutes');
    app.now = app.now.add(const Duration(minutes: 6));
    await app.settle(2600);
    expect(app.location, '/rest');
    await app.end();
  });

  testWidgets('a phone clock moved back gives no extra play time and does not end the rest', (tester) async {
    final app = await TestApp.start(tester);
    app.now = app.now.add(const Duration(minutes: 10));
    await app.settle(2600);
    app.now = app.now.subtract(const Duration(hours: 1));
    await app.settle(2600);
    expect(app.location, '/');
    app.now = app.now.add(const Duration(minutes: 6));
    await app.settle(2600);
    expect(app.location, '/rest', reason: '16 minutes were played');
    app.now = app.now.subtract(const Duration(minutes: 30));
    await app.settle(2600);
    expect(app.location, '/rest', reason: 'the rest still has most of its hour to go');
    app.now = app.now.add(const Duration(minutes: 61));
    await app.settle(2600);
    expect(app.location, '/');
    await app.end();
  });

  testWidgets('the last piece\'s words are said in full before the done line', (tester) async {
    final voice = RecordingVoice(speaking: const Duration(milliseconds: 1500));
    final app = await TestApp.start(tester, voice: voice);
    for (final (at, done) in [('/shapes/box', Strings.shapesDone), ('/shapes/inset?board=fruit', Strings.insetDone(lib.insets.first.zh))]) {
      app.go(at);
      await app.settle(2000);
      await solve(app);
      await app.settle(4000);
      expect(voice.said.last, done, reason: at);
      final last = voice.said[voice.said.length - 2];
      expect(voice.cut, isNot(contains(last)), reason: '$at: 「$last」 was cut off');
    }
    await app.end();
  });

  testWidgets('a finger scrolling a list is not a tap on what it started on', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/jigsaw/box?id=fruit');
    await app.settle(900);
    final card = find.bySemanticsLabel(lib.box['fruit']!.pictures[2].zh).last;
    final before = tester.getCenter(card);
    // A short swipe: the finger lifts still on the card it started on.
    await tester.dragFrom(before, const Offset(0, -50));
    await app.settle(600);
    expect(before.dy - tester.getCenter(card).dy, greaterThan(20), reason: 'the list scrolled');
    expect(app.location, '/jigsaw/box', reason: 'no picture opened');
    await app.tapLabel(lib.box['fruit']!.pictures[2].zh);
    expect(app.location, '/jigsaw/play', reason: 'a tap still opens it');
    await app.end();
  });

  test('the speech engine starting up: the newest line is the one said', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('flutter_tts');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final spoken = <String>[];
    final ready = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'awaitSpeakCompletion') await ready.future;
      if (call.method == 'speak') spoken.add(call.arguments as String);
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final v = SystemVoice();
    final first = v.say(Strings.pickLine);
    final second = v.say(Strings.hello(Helper.deer));
    ready.complete();
    await Future.wait([first, second]);
    expect(spoken, [Strings.hello(Helper.deer)], reason: 'the older line is not said after the newer one');
    await v.say(Strings.whatNow);
    expect(spoken.last, Strings.whatNow);
  });

  testWidgets('switching the helper: the old one stays until another is picked; the new one is kept, voice and all', (tester) async {
    final app = await TestApp.start(tester, game: const Game(helper: Helper.bear));
    await app.tapLabel(Strings.change, ms: 900);
    expect(app.location, '/helper');
    expect(app.game.helper, Helper.bear);
    app.now = app.now.add(const Duration(minutes: 16));
    await app.settle(2600);
    expect(app.location, '/rest');
    expect(find.text(Helper.bear.sleeps), findsOneWidget, reason: 'the child\'s own helper sleeps its own way');
    app.change((g) => g.playOn());
    app.container.read(sessionStartProvider.notifier).restart();
    app.go('/helper');
    await app.settle(900);
    await app.tapLabel(Helper.deer.zh, ms: 2600);
    expect(app.location, '/');
    expect(Game.fromJson(app.store.saved, lib).helper, Helper.deer);
    expect(app.voice.pitches.last, Helper.deer.pitch);
    await app.end();
  });

  testWidgets('大 照著拼 on a phone: a big stack\'s dots fit its narrow place in the tray', (tester) async {
    final app = await TestApp.start(tester, game: const Game(helper: Helper.bear, settings: Settings(level: Level.big)));
    app.go('/blocks/play?id=butterfly');
    await app.settle(900);
    final b = boardOf(tester);
    expect(b.trayPieces.map((p) => p.kind), ['hex', 'trap', 'rhomb', 'tri'], reason: 'four stacks: four narrow places on a phone');
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == '還有 16 個'), findsOneWidget, reason: 'a triangle for every bit of the butterfly');
    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    await app.end();
  });

  group('round 1 fixes', () {
    void hide(WidgetTester tester) {
      for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    void show(WidgetTester tester) {
      for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(s);
      }
    }

    /// Whether the app asked the phone to close it (the back key's default).
    Future<bool> back(TestApp app) async {
      var closed = false;
      app.tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemNavigator.pop') closed = true;
        return null;
      });
      await app.tester.binding.handlePopRoute();
      await app.settle(900);
      app.tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      return closed;
    }

    Future<void> openGate(TestApp app) async {
      await hold(app, find.bySemanticsLabel(Strings.parent), 1100);
      await app.settle(900);
    }

    const big = Game(helper: Helper.pangolin, settings: Settings(level: Level.big));

    testWidgets('the back key never closes the app: it does what the home button does', (tester) async {
      final app = await TestApp.start(tester, game: big);
      app.go('/jigsaw/play?pic=pineapple&cut=t9');
      await app.settle(900);
      expect(await back(app), isFalse);
      expect(app.location, '/jigsaw/box', reason: 'like the home button: back to the box');
      expect(await back(app), isFalse);
      expect(app.location, '/');
      expect(await back(app), isFalse, reason: 'in the workshop it does nothing');
      expect(app.location, '/');
      app.go('/tangram/play?id=house7');
      await app.settle(900);
      expect(await back(app), isFalse);
      expect(app.location, '/tangram');
      ParentPass.grant();
      app.go('/parent');
      await app.settle();
      expect(await back(app), isFalse);
      expect(app.location, '/', reason: 'parent mode goes to the workshop');
      await openGate(app);
      expect(find.byKey(const ValueKey('gate-key-1')), findsOneWidget);
      expect(await back(app), isFalse);
      await app.settle(900);
      expect(find.byKey(const ValueKey('gate-key-1')), findsNothing, reason: 'only the gate closes');
      expect(app.location, '/');
      app.change((g) => g.rest(app.now));
      await app.settle(2600);
      expect(app.location, '/rest');
      expect(await back(app), isFalse);
      expect(app.location, '/rest', reason: 'the rest stays');
      await app.end();
    });

    testWidgets('a puzzle left half done (home, back key) is there as it was on coming back; a finished one starts afresh', (tester) async {
      final app = await TestApp.start(tester, game: big);
      app.go('/jigsaw/play?pic=pineapple&cut=t9');
      await app.settle(900);
      await solve(app, n: 3);
      final placed = {...boardOf(tester).board.placed.keys};
      expect(placed.length, 3);
      await app.tapLabel(Strings.home, ms: 900);
      expect(app.location, '/jigsaw/box');
      app.go('/jigsaw/play?pic=pineapple&cut=t9');
      await app.settle(900);
      expect(boardOf(tester).board.placed.keys.toSet(), placed, reason: 'the three pieces are where they were');
      expect(boardOf(tester).trayPieces.map((p) => p.id).toSet().intersection(placed), isEmpty, reason: 'and not in the tray again');
      expect(await back(app), isFalse);
      app.go('/jigsaw/play?pic=pineapple&cut=t9');
      await app.settle(900);
      expect(boardOf(tester).board.placed.keys.toSet(), placed);
      app.go('/jigsaw/play?pic=pineapple&cut=t12');
      await app.settle(900);
      expect(app.location, '/jigsaw/box', reason: 't12 is not open yet');
      app.go('/jigsaw/play?pic=pineapple&cut=t9');
      await app.settle(900);
      await solve(app);
      await app.settle(1600);
      expect(app.game.pictureDone('pineapple'), isTrue);
      await app.tapLabel(Strings.home, ms: 900);
      app.go('/jigsaw/play?pic=pineapple&cut=t9');
      await app.settle(900);
      expect(boardOf(tester).board.placed, isEmpty, reason: 'finished: a new puzzle');
      // The tangram and the pattern blocks keep theirs too.
      app.go('/tangram/play?id=house7');
      await app.settle(900);
      await solve(app, n: 2);
      final tan = {...boardOf(tester).board.placed.keys};
      app.go('/tangram');
      await app.settle(900);
      app.go('/tangram/play?id=house7');
      await app.settle(900);
      expect(boardOf(tester).board.placed.keys.toSet(), tan);
      app.go('/blocks/play?id=butterfly');
      await app.settle(900);
      await solve(app, n: 2);
      final blocks = {...boardOf(tester).board.placed.keys};
      app.go('/blocks');
      await app.settle(900);
      app.go('/blocks/play?id=butterfly');
      await app.settle(900);
      expect(boardOf(tester).board.placed.keys.toSet(), blocks);
      expect(boardOf(tester).board.done, isFalse);
      await app.end();
    });

    testWidgets('closed and opened again within ten minutes, the sitting goes on', (tester) async {
      final first = await TestApp.start(tester);
      first.now = first.now.add(const Duration(minutes: 12));
      await first.settle(2600);
      hide(tester);
      await first.settle();
      final saved = Game.fromJson(first.store.saved, lib);
      expect(saved.sitting, isNotNull);
      expect(saved.sitting!.used.inMinutes, 12);
      final closedAt = first.now;
      // (Frames only come with the app in sight: closed after it is back.)
      show(tester);
      await first.end();
      final app = await TestApp.start(tester, game: saved, now: closedAt.add(const Duration(minutes: 5)));
      app.now = app.now.add(const Duration(minutes: 2));
      await app.settle(2600);
      expect(app.location, '/');
      app.now = app.now.add(const Duration(minutes: 2));
      await app.settle(2600);
      expect(app.location, '/rest', reason: 'closing the app gave no new 15 minutes');
      await app.end();
    });

    testWidgets('a sitting saved before going away goes on only within ten minutes', (tester) async {
      final t0 = DateTime(2026, 11, 15, 10);
      final soon = await TestApp.start(tester, game: Game(helper: Helper.pangolin, sitting: Sitting(const Duration(minutes: 12), t0.subtract(const Duration(minutes: 4)))));
      soon.now = soon.now.add(const Duration(minutes: 4));
      await soon.settle(2600);
      expect(soon.location, '/rest', reason: '12 + 4 minutes');
      await soon.end();
      final late = await TestApp.start(tester, game: Game(helper: Helper.pangolin, sitting: Sitting(const Duration(minutes: 14), t0.subtract(const Duration(minutes: 11)))));
      late.now = late.now.add(const Duration(minutes: 10));
      await late.settle(2600);
      expect(late.location, '/', reason: 'ten minutes away was a rest');
      await late.end();
      final back = await TestApp.start(tester, game: Game(helper: Helper.pangolin, sitting: Sitting(const Duration(minutes: 14), t0.add(const Duration(hours: 2)))));
      back.now = back.now.add(const Duration(minutes: 1, seconds: 10));
      await back.settle(2600);
      expect(back.location, '/rest', reason: 'a clock moved back while closed gives no extra time');
      await back.end();
    });

    testWidgets('parent mode left in the background is closed: the workshop, and the gate again', (tester) async {
      final app = await TestApp.start(tester);
      ParentPass.grant();
      app.go('/parent');
      await app.settle();
      hide(tester);
      await app.settle();
      show(tester);
      await app.settle();
      expect(app.location, '/');
      app.go('/parent');
      await app.settle();
      expect(app.location, '/', reason: 'the pass was used up');
      await app.end();
    });

    testWidgets('the parent gate closes when the app goes away, and its time is not play time', (tester) async {
      final app = await TestApp.start(tester);
      app.now = app.now.add(const Duration(minutes: 10));
      await app.settle(2600);
      await openGate(app);
      expect(find.byKey(const ValueKey('gate-key-1')), findsOneWidget);
      app.now = app.now.add(const Duration(minutes: 20));
      await app.settle(2600);
      expect(app.location, '/', reason: 'twenty minutes on the gate are not play time');
      hide(tester);
      await app.settle();
      show(tester);
      await app.settle(1200);
      expect(find.byKey(const ValueKey('gate-key-1')), findsNothing, reason: 'a child finds the workshop');
      app.now = app.now.add(const Duration(minutes: 4));
      await app.settle(2600);
      expect(app.location, '/');
      app.now = app.now.add(const Duration(minutes: 2));
      await app.settle(2600);
      expect(app.location, '/rest', reason: '10 + 6 minutes played');
      await app.end();
    });

    testWidgets('the gate and parent mode close by themselves after five minutes without a touch', (tester) async {
      final app = await TestApp.start(tester);
      await openGate(app);
      expect(find.byKey(const ValueKey('gate-key-1')), findsOneWidget);
      await tester.pump(const Duration(minutes: 4));
      await tester.tap(find.byKey(const ValueKey('gate-key-0')));
      await tester.pump(const Duration(minutes: 4));
      expect(find.byKey(const ValueKey('gate-key-1')), findsOneWidget, reason: 'a touch starts the five minutes again');
      await tester.pump(const Duration(minutes: 1, seconds: 5));
      await app.settle(1200);
      expect(find.byKey(const ValueKey('gate-key-1')), findsNothing);
      ParentPass.grant();
      app.go('/parent');
      await app.settle();
      await tester.pump(const Duration(minutes: 5, seconds: 5));
      await app.settle();
      expect(app.location, '/');
      await app.end();
    });

    testWidgets('the rest\'s gate lets play go on but does not open parent mode', (tester) async {
      final app = await TestApp.start(tester);
      app.change((g) => g.rest(app.now));
      await app.settle(2600);
      expect(app.location, '/rest');
      await app.tapLabel(Strings.parent, ms: 900);
      await answerGate(app);
      await app.settle(2600);
      expect(app.location, '/');
      app.go('/parent');
      await app.settle();
      expect(app.location, '/', reason: 'no pass left over');
      await app.end();
    });

    testWidgets('the gate\'s wait grows (1, 5, 15 minutes) and is kept when the app is closed', (tester) async {
      var lock = const GateLock();
      final t = DateTime(2026, 11, 15, 10);
      for (final (at, wait) in [(0, 1), (2, 5), (10, 15), (30, 15)]) {
        for (var i = 0; i < 3; i++) {
          lock = lock.miss(t.add(Duration(minutes: at)));
        }
        expect(lock.left(t.add(Duration(minutes: at))), Duration(minutes: wait));
      }
      expect(lock.locked(t.add(const Duration(minutes: 20))), isFalse, reason: 'a clock moved back is no wait');
      final app = await TestApp.start(tester);
      await openGate(app);
      for (var i = 0; i < 6 && find.textContaining('請等').evaluate().isEmpty; i++) {
        await tester.tap(find.byKey(const ValueKey('gate-key-0')));
        await app.settle(100);
      }
      expect(find.textContaining('請等'), findsOneWidget);
      final saved = Game.fromJson(app.store.saved, lib);
      expect(saved.gate.locked(app.now), isTrue);
      await app.end();
      final again = await TestApp.start(tester, game: saved);
      await openGate(again);
      expect(find.textContaining('請等'), findsOneWidget, reason: 'still waiting after the app was closed');
      await again.end();
    });

    testWidgets('a quick change of music never plays the wrong tune or plays on after a stop', (tester) async {
      final loop = SlowLoop();
      final sounds = SystemSounds(loop: loop);
      final owner = Object();
      sounds.hold(owner, Music.workshop);
      await tester.pump();
      expect(loop.calls, ['stop', 'play ${Music.workshop.file}']);
      sounds.hold(owner, Music.tangram);
      await tester.pump();
      sounds.hold(owner, null);
      await tester.pump();
      loop.loading!.complete();
      await tester.pump();
      expect(loop.playing, isNull, reason: 'stopped after the start that was loading, not before it');
      expect(loop.calls, ['stop', 'play ${Music.workshop.file}', 'stop']);
      sounds.hold(owner, Music.tangram);
      await tester.pump();
      loop.loading!.complete();
      await tester.pump();
      expect(loop.playing, Music.tangram.file);
      sounds.dispose();
    });
  });
}
