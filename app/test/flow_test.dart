import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/app/strings.dart';
import 'package:puzzle_workshop/core/board.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/core/jigsaw.dart';
import 'package:puzzle_workshop/features/common/play_page.dart';

import 'helpers.dart';

/// A visit as a child (and a parent) would play it: every toy box at every level, on a phone and a
/// tablet, with screenshots in `build/screenshots/<device>/`.
void main() {
  setUpAll(loadFonts);

  for (final MapEntry(key: device, value: (size, ratio)) in {'phone': (const Size(1080, 2340), 2.75), 'tablet': (const Size(1620, 2160), 2.0)}.entries) {
    testWidgets('a day in the workshop ($device)', (tester) async {
      final app = await TestApp.start(tester, game: const Game(), size: size, ratio: ratio, seed: 3);
      Future<void> shot(String name) => shoot(tester, device, name);
      void level(Level l) => app.change((g) => g.withSettings(g.settings.copyWith(level: l)));

      // ---- The first time: pick a helper.
      expect(app.location, '/helper');
      expect(app.voice.said.last, Strings.pickLine);
      await shot('01_helper');
      await app.tapLabel('甲甲', ms: 2600);
      expect(app.game.helper, Helper.pangolin);
      expect(app.sounds.played, contains('sniff'));
      expect(app.location, '/');
      await app.settle(600);
      expect(app.voice.said.last, Strings.welcome(Helper.pangolin));
      await shot('02_home');
      expect(find.bySemanticsLabel('照著拼'), findsNothing, reason: '小小 has three toy boxes');

      // ---- 小小: the shape box, one hole; then two holes by taps only.
      await app.tapLabel('形狀洞洞', ms: 700);
      expect(app.location, '/shapes');
      await shot('03_shapes_menu');
      await app.tapLabel('形狀盒', ms: 800);
      await shot('04_shape_box');
      await solve(app);
      await app.settle(900);
      expect(app.sounds.played, contains('drop'));
      expect(app.voice.said.last, Strings.shapesDone);
      await shot('05_shape_box_done');
      await app.tapLabel(Strings.nextOne, ms: 900);
      var b = boardOf(tester);
      expect(b.board.slots.length, 2);
      for (var i = 0; i < 2; i++) {
        final p = b.trayPieces.first;
        await tester.tapAt(b.pieceAt(p));
        await app.settle(300);
        expect(b.board.placed.containsKey(p.id), isFalse, reason: 'a tap picks it up, it does not put it down');
        final s = b.board.home(p)!;
        await tester.tapAt(b.fingerFor(p, s) - const Offset(0, 0));
        await app.settle(500);
        expect(b.board.placed[p.id], s, reason: 'a tap on its hole sends it there');
      }
      await app.settle(900);
      expect(app.game.shapeRound, 2);

      // ---- The fruit inset board: a piece let go on another hole floats back.
      app.go('/shapes/inset?board=fruit');
      await app.settle(900);
      await shot('06_inset');
      b = boardOf(tester);
      final p0 = b.trayPieces.first;
      final wrong = b.board.slots.firstWhere((s) => s.kind != p0.kind);
      await dragFinger(app, b.pieceAt(p0), b.fingerFor(p0, wrong));
      await app.settle(500);
      expect(b.board.placed, isEmpty);
      expect(app.sounds.played.last, 'back');
      await solve(app, after: (n) async {
        if (n == 3) await shot('07_inset_half');
      });
      await app.settle(900);
      expect(app.game.insets, contains('fruit'));
      await shot('08_inset_done');
      await app.tapLabel(Strings.home, ms: 900);

      // ---- 拼圖: the fruit box, 西瓜 in two halves.
      await app.tapLabel('拼圖', ms: 800);
      await shot('09_jigsaw_boxes');
      await app.tapLabel('水果盒', ms: 800);
      await shot('10_jigsaw_pictures');
      await app.tapLabel('西瓜', ms: 900);
      expect(app.location, '/jigsaw/play');
      await shot('11_jigsaw_r2');
      await solve(app);
      await app.settle(1500);
      expect(app.game.pictures, ['watermelon']);
      expect(app.sounds.played, containsAll(['done', 'pop', 'star']));
      await shot('12_jigsaw_done');
      expect(app.voice.said, contains(Strings.taiwanPlus));

      // ---- 七巧板 小小: a house.
      app.go('/tangram');
      await app.settle(800);
      await shot('13_tangram_list');
      await app.tapLabel('房子', ms: 900);
      await shot('14_tangram_small');
      await solve(app);
      await app.settle(1200);
      expect(app.game.tangrams, contains('house'));
      await shot('15_tangram_small_done');

      // ---- 中: look-alike shapes, a 9-piece jigsaw with dashed outlines, a cat that turns itself upright, pattern blocks.
      level(Level.middle);
      app.go('/');
      await app.settle(800);
      await shot('16_home_middle');
      expect(find.bySemanticsLabel('照著拼'), findsWidgets);
      app.go('/shapes/box');
      await app.settle(900);
      await shot('17_shape_box_alike');
      await solve(app);
      await app.settle(900);
      app.change((g) => g.copyWith(cutsDone: {'r4': 3, 'r6': 3, 't4': 3, 't6': 3}));
      app.go('/jigsaw/box?id=animals');
      await app.settle(900);
      await tester.tap(find.byKey(const ValueKey('cut-t9')));
      await app.settle(400);
      await app.tapLabel('台灣黑熊', ms: 900);
      expect(boardOf(tester).widget.pieces.length, 9);
      await solve(app, after: (n) async {
        if (n == 4) await shot('18_jigsaw_t9_middle');
      });
      await app.settle(1500);
      await shot('19_jigsaw_t9_done');
      app.go('/tangram/play?id=cat');
      await app.settle(900);
      b = boardOf(tester);
      expect(b.widget.turning, Turning.auto);
      await shot('20_tangram_middle');
      await solve(app);
      await app.settle(1200);
      await shot('21_tangram_middle_done');
      app.go('/');
      await app.settle(600);
      await app.tapLabel('照著拼', ms: 800);
      await shot('22_blocks_cards');
      await app.tapLabel('小花', ms: 900);
      await shot('23_blocks_middle');
      await solve(app, after: (n) async {
        if (n == 3) await shot('24_blocks_middle_half');
      });
      await app.settle(1200);
      expect(app.game.cards, contains('flower'));
      await shot('25_blocks_done');

      // ---- 大: 24 pieces with the edges first, a seven-piece tangram turned by taps, blocks filled another way.
      level(Level.big);
      app.change((g) => g.copyWith(cutsDone: {'t9': 3, 't12': 3, 't16': 3, 't20': 3}));
      app.go('/jigsaw/play?pic=mrt&cut=t24');
      await app.settle(900);
      b = boardOf(tester);
      final jig = Jigsaw('mrt', Cut.t24);
      final parts = {for (final p in jig.pieces) p.id: p.part};
      expect(b.trayPieces.length, 6);
      expect(b.trayPieces.where((p) => parts[p.id] == Part.corner).length, 4, reason: 'the four corners come first');
      expect(b.trayPieces.every((p) => parts[p.id] != Part.middle), isTrue, reason: 'then the edges');
      await solve(app, after: (n) async {
        if (n == 10) await shot('26_jigsaw_t24');
      });
      await app.settle(1500);
      await shot('27_jigsaw_t24_done');
      app.go('/tangram/play?id=house7');
      await app.settle(900);
      b = boardOf(tester);
      expect(b.widget.turning, Turning.tap);
      // Let a piece go on its place turned the wrong way: it floats back and the right way shows.
      final tp = b.trayPieces.firstWhere((p) => !Board.sameTurn(p.angle, p.flip, b.board.home(p)!));
      await dragFinger(app, b.pieceAt(tp), b.fingerFor(tp, b.board.home(tp)!));
      await app.settle(500);
      expect(b.board.placed.containsKey(tp.id), isFalse);
      expect(app.voice.said.last, anyOf(Strings.turnIt, Strings.flipIt));
      await shot('28_tangram_big_turn');
      await solve(app);
      await app.settle(1200);
      expect(app.game.tangrams, contains('house7'));
      await shot('29_tangram_big_done');
      app.go('/blocks/play?id=butterfly');
      await app.settle(900);
      b = boardOf(tester);
      final hexCells = b.board.slots.firstWhere((s) => s.kind == 'hex').cells.toSet();
      for (var i = 0; i < 2; i++) {
        final trap = b.trayPieces.firstWhere((p) => p.kind == 'trap');
        final spot = b.board.slots.firstWhere((s) => s.kind == 'trap' && s.cells.every(hexCells.contains) && b.board.isFree(s));
        await dragFinger(app, b.pieceAt(trap), b.fingerFor(trap, spot));
        await app.settle(400);
        expect(b.board.placed[trap.id], spot);
      }
      await shot('30_blocks_big');
      await solve(app);
      await app.settle(1200);
      expect(app.voice.said.last, Strings.blocksDone('蝴蝶') + Strings.blocksOther);
      await shot('31_blocks_big_done');

      // ---- The Taiwan puzzle: a piece shows its picture again.
      app.go('/');
      await app.settle(800);
      await shot('32_home_taiwan');
      final tw = tester.getRect(find.byType(TaiwanView).first);
      final piece = lib.taiwan.pieces[Library.taiwanPiece(lib.picture['watermelon']!.index)];
      final c = piece.fold(Offset.zero, (a, p) => a + p) / piece.length.toDouble();
      await tester.tapAt(tw.topLeft + c * (tw.width / lib.taiwan.size.width));
      await app.settle(900);
      expect(app.location, '/taiwan');
      await shot('33_taiwan_alive');
      await app.tapLabel(Strings.home, ms: 800);

      // ---- Parent mode through the gate (the lock is held down).
      await hold(app, find.bySemanticsLabel(Strings.parent), 1100);
      await app.settle(600);
      await shot('34_gate');
      await answerGate(app);
      expect(app.location, '/parent');
      await shot('35_parent');
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await app.settle(500);
      await shot('36_parent_more');
      app.go('/');
      await app.settle(2600);

      // ---- The play time runs out: the helper sleeps.
      app.now = app.now.add(const Duration(minutes: 16));
      await app.settle(2600);
      expect(app.location, '/rest');
      expect(app.voice.said.last, '${Strings.restTitle}${Strings.restLine}');
      await shot('37_rest');
      expect(tester.takeException(), isNull);
      await app.end();
    }, timeout: const Timeout(Duration(minutes: 20)));
  }
}
