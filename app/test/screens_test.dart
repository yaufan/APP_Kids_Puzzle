import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/app/strings.dart';
import 'package:puzzle_workshop/app/widgets.dart';
import 'package:puzzle_workshop/core/board.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/core/providers.dart';
import 'package:puzzle_workshop/features/parent/parent_gate.dart';

import 'helpers.dart';

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
    final p = b.trayPieces.firstWhere((q) => !Board.sameTurn(q.angle, q.flip, b.board.home(q)!));
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
}
