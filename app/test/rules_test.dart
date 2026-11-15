import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/core/board.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/core/jigsaw.dart';
import 'package:puzzle_workshop/core/shapes.dart';

import 'helpers.dart';

double area(List<Offset> pts) {
  var a = 0.0;
  for (var i = 0; i < pts.length; i++) {
    final p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.dx * q.dy - q.dx * p.dy;
  }
  return a.abs() / 2;
}

/// [points] (centred) mirrored if [flip], then turned [angle] degrees clockwise, moved to [at].
List<Offset> placed(List<Offset> points, double angle, bool flip, Offset at) {
  final a = angle * math.pi / 180;
  return [
    for (final p in points)
      () {
        final x = flip ? -p.dx : p.dx;
        return Offset(at.dx + x * math.cos(a) - p.dy * math.sin(a), at.dy + x * math.sin(a) + p.dy * math.cos(a));
      }(),
  ];
}

bool sameSet(List<Offset> a, List<Offset> b) => a.length == b.length && a.every((p) => b.any((q) => (p - q).distance < 1e-3));

void main() {
  group('the boxes', () {
    test('six boxes of eight pictures, two free; every actor inside its picture', () {
      expect(lib.boxes.length, 6);
      expect(lib.pictures.length, 48);
      expect({for (final p in lib.pictures) p.id}.length, 48);
      expect([for (final b in lib.boxes) if (b.free) b.id], ['fruit', 'animals']);
      for (final p in lib.pictures) {
        expect((Offset.zero & Picture.size).contains(p.actorBox.topLeft) && p.actorBox.right <= 400 && p.actorBox.bottom <= 300, isTrue, reason: p.id);
        expect(['hop', 'drive', 'fly', 'sway', 'spin', 'wiggle', 'pulse', 'swim', 'nod'], contains(p.anim), reason: p.id);
        expect(p.line, matches(RegExp('上面|下面|旁邊|中間|左邊|右邊|頭上|一顆一顆|裡|跨|後面|過|走到|滾到|飛到|轉')), reason: '${p.id}: a word about where');
      }
    });

    test('the Taiwan puzzle has a piece for every picture, spread over the island', () {
      expect(lib.taiwan.pieces.length, lib.pictures.length);
      expect({for (var i = 0; i < 48; i++) Library.taiwanPiece(i)}.length, 48);
      final sum = lib.taiwan.pieces.fold(0.0, (s, p) => s + area(p));
      expect(sum, closeTo(area(lib.taiwan.outline), area(lib.taiwan.outline) * .03));
    });

    test('six inset boards with five or six pieces, inside the board, not overlapping', () {
      expect(lib.insets.length, 6);
      for (final b in lib.insets) {
        expect(b.items.length, inInclusiveRange(5, 6));
        for (final i in b.items) {
          final r = Rect.fromCenter(center: i.at, width: i.size, height: i.size);
          expect((Offset.zero & InsetBoard.size).inflate(1).contains(r.topLeft) && r.right <= 401 && r.bottom <= 301, isTrue, reason: '${b.id} ${i.actor}');
          for (final j in b.items) {
            if (identical(i, j)) continue;
            expect(r.overlaps(Rect.fromCenter(center: j.at, width: j.size * .98, height: j.size * .98)), isFalse, reason: '${b.id} ${i.actor} ${j.actor}');
          }
        }
      }
    });
  });

  group('the jigsaw', () {
    test('every picture can be cut every way; the pieces fill the picture exactly', () {
      for (final p in lib.pictures.take(48)) {
        for (final c in Cut.values) {
          final j = Jigsaw(p.id, c);
          expect(j.pieces.length, c.count);
          final sum = j.pieces.fold(0.0, (s, q) => s + area(q.outline));
          expect(sum, closeTo(400 * 300, 400 * 300 * .002), reason: '${p.id} ${c.name}');
          for (final q in j.pieces) {
            for (final pt in q.outline) {
              expect(pt.dx >= -.01 && pt.dy >= -.01 && pt.dx <= q.size.width + .01 && pt.dy <= q.size.height + .01, isTrue, reason: '${p.id} ${c.name} ${q.id} knob outside its box');
            }
          }
        }
      }
    });

    test('a picture is cut the same way every time; knobs differ between pictures', () {
      final a = Jigsaw('bear', Cut.t12).pieces[5].outline, b = Jigsaw('bear', Cut.t12).pieces[5].outline, c = Jigsaw('deer', Cut.t12).pieces[5].outline;
      expect(a, b);
      expect(a, isNot(c));
    });

    test('the ladder: 小小 2 to 4 straight pieces, 中 up to 12, 大 9 to 24', () {
      expect([for (final c in Cut.ladder(Level.small)) c.count], [2, 3, 4]);
      expect(Cut.ladder(Level.small).every((c) => !c.tabs), isTrue);
      expect(Cut.ladder(Level.middle).last.count, 12);
      expect([for (final c in Cut.ladder(Level.big)) c.count], [9, 12, 16, 20, 24]);
    });

    test('12 pieces or more: corners, then edges, then the middle', () {
      final j = Jigsaw('mrt', Cut.t24);
      final o = j.order(math.Random(1), edgesFirst: true);
      final parts = [for (final p in o) p.part];
      expect(parts.take(4), everyElement(Part.corner));
      expect(parts.skip(4).take(12), everyElement(Part.edge));
      expect(parts.skip(16), everyElement(Part.middle));
      expect(j.order(math.Random(1), edgesFirst: false).length, 24);
    });

    test('three pictures at a size open the next size; a smaller size is always there', () {
      var g = const Game();
      expect(g.cutsOpen(Level.middle), [Cut.r4]);
      for (var i = 0; i < 3; i++) {
        g = g.finishPicture('bear', Cut.r4, DateTime(2026, 11, 15));
      }
      expect(g.cutsOpen(Level.middle), [Cut.r4, Cut.r6]);
      expect(g.cutFor(Level.middle), Cut.r6);
      g = g.pickCut(Level.middle, Cut.r4);
      expect(g.cutFor(Level.middle), Cut.r4);
      expect(g.pictures, ['bear'], reason: 'a picture is one Taiwan piece, however often it is done');
    });
  });

  group('the board', () {
    Slot slot(String id, String kind, Offset at, {double angle = 0, int sym = 360, bool chiral = false, bool flip = false, List<String>? cells}) =>
        Slot(id: id, kind: kind, at: at, angle: angle, symmetry: sym, chiral: chiral, flip: flip, cells: cells);

    test('a piece goes to the nearest free place of its kind within the magnet', () {
      final b = Board([slot('a', 'tri', const Offset(0, 0)), slot('b', 'tri', const Offset(50, 0)), slot('c', 'sq', const Offset(20, 0))]);
      final p = Piece(id: 'p', kind: 'tri', size: const Size(10, 10));
      expect(b.fit(p, const Offset(30, 0), 40)!.slot.id, 'b', reason: 'the nearer of two places wins');
      expect(b.fit(p, const Offset(100, 0), 40), isNull);
      b.place(p, b.slots[1]);
      expect(b.fit(Piece(id: 'q', kind: 'tri', size: const Size(10, 10)), const Offset(30, 0), 40)!.slot.id, 'a');
      expect(b.done, isFalse);
    });

    test('places sharing cells cannot both be filled; done when every needed cell is', () {
      final b = Board([slot('hex', 'hex', Offset.zero, cells: ['1', '2', '3']), slot('t1', 'tri', Offset.zero, cells: ['1']), slot('t2', 'trap', Offset.zero, cells: ['2', '3'])],
          need: {'1', '2', '3'});
      b.place(Piece(id: 'a', kind: 'tri', size: Size.zero), b.slots[1]);
      expect(b.isFree(b.slots[0]), isFalse);
      b.place(Piece(id: 'b', kind: 'trap', size: Size.zero), b.slots[2]);
      expect(b.done, isTrue);
    });

    test('turned the right way: symmetry and the parallelogram\'s mirror', () {
      final sq = slot('q', 'Q', Offset.zero, angle: 45, sym: 90);
      expect(Board.sameTurn(135, false, sq), isTrue);
      expect(Board.sameTurn(90, false, sq), isFalse);
      final par = slot('p', 'P', Offset.zero, angle: 90, sym: 180, chiral: true);
      expect(Board.sameTurn(270, false, par), isTrue);
      expect(Board.sameTurn(90, true, par), isFalse, reason: 'mirrored is another shape');
      expect(Board.sameTurn(95, false, par), isTrue, reason: 'within 10 degrees');
      expect(Board.nearestTurn(0, 350, 360), 360);
      final b = Board([sq]);
      final p = Piece(id: 'x', kind: 'Q', size: Size.zero, angle: 10);
      expect(b.fit(p, Offset.zero, 1, checkTurn: true)!.turnedRight, isFalse);
      expect(b.fit(p, Offset.zero, 1)!.turnedRight, isTrue, reason: '中: pieces turn themselves');
    });

    test('the tray: six at a time, the next one coming into the place of the one put down', () {
      final pieces = [for (var i = 0; i < 9; i++) Piece(id: '$i', kind: 'k$i', size: Size.zero)];
      final t = Tray(pieces);
      expect([for (final (_, p) in t.shown) p.id], ['0', '1', '2', '3', '4', '5']);
      t.take(pieces[2]);
      expect(t.shown.firstWhere((e) => e.$1 == 2).$2.id, '6');
      expect(t.waiting, 8);
      final s = Tray([Piece(id: 'a', kind: 'tri', size: Size.zero), Piece(id: 'b', kind: 'tri', size: Size.zero), Piece(id: 'c', kind: 'hex', size: Size.zero)], stacks: true);
      expect(s.places, 2);
      expect(s.count('tri'), 2);
      s.take(s.shown.first.$2);
      expect(s.count('tri'), 1);
    });

    test('fingers: a short still touch is a tap; the magnet; nothing near the edges', () {
      expect(Touch.isTap(const Offset(3, 4), const Duration(milliseconds: 100)), isTrue);
      expect(Touch.isTap(const Offset(12, 0), const Duration(milliseconds: 100)), isFalse);
      expect(Touch.isTap(Offset.zero, const Duration(milliseconds: 400)), isFalse);
      expect(Touch.magnet(Level.small, Magnet.normal, 40), 70);
      expect(Touch.magnet(Level.big, Magnet.normal, 40), 28);
      expect(Touch.magnet(Level.middle, Magnet.normal, 200), 100);
      expect(Touch.magnet(Level.small, Magnet.strong, 100), greaterThan(Touch.magnet(Level.small, Magnet.weak, 100)));
      expect(Touch.clamp(const Offset(-50, 900), const Size(400, 800)), const Offset(24, 776));
    });
  });

  group('the shapes', () {
    test('tangram: 6, 8 and 10 figures; each piece drawn where and how its place says', () {
      expect(lib.tangramsAt(Level.small).length, 6);
      expect(lib.tangramsAt(Level.middle).length, 8);
      expect(lib.tangramsAt(Level.big).length, 10);
      const areas = {'L': 2.0, 'M': 1.0, 'S': .5, 'Q': 1.0, 'P': 1.0};
      for (final f in lib.tangrams) {
        final n = f.slots.length;
        expect(n, switch (f.level) { Level.small => inInclusiveRange(2, 3), Level.middle => inInclusiveRange(4, 5), Level.big => 7 }, reason: f.id);
        for (final s in f.slots) {
          expect(area(s.points), closeTo(areas[s.kind]!, 1e-3), reason: '${f.id} ${s.kind}');
          expect(sameSet(placed(lib.tanKinds[s.kind]!.points, s.angle, s.flip, s.at), s.points), isTrue, reason: '${f.id}: a ${s.kind} turned ${s.angle}');
        }
        if (f.level == Level.big) expect(f.slots.fold(0.0, (a, s) => a + area(s.points)), closeTo(8, 1e-3));
      }
    });

    test('pattern blocks: 12 cards; blocks drawn where their places say; 大\'s other ways stay inside', () {
      expect(lib.cards.length, 12);
      for (final c in lib.cards) {
        for (final s in [...c.slots, ...c.extra]) {
          expect(sameSet(placed(lib.blockKinds[s.kind]!.points, s.angle, false, s.at), s.points), isTrue, reason: '${c.id} ${s.kind} ${s.angle}');
          expect(s.cells.every(c.cells.contains), isTrue, reason: c.id);
        }
      }
      final butterfly = lib.cards.firstWhere((c) => c.id == 'butterfly');
      final hex = butterfly.slots.firstWhere((s) => s.kind == 'hex').cells.toSet();
      expect(butterfly.extra.where((s) => s.kind == 'trap' && s.cells.every(hex.contains)).length, greaterThanOrEqualTo(2), reason: 'two trapezoids make a hexagon');
    });

    test('the shape box: six rounds a level, the holes on the lid and apart', () {
      for (final l in Level.values) {
        final rounds = ShapeRounds.of(l);
        expect(rounds.length, 6);
        for (final r in rounds) {
          expect(r.toSet().length, r.length);
          final (at, size) = ShapeRounds.holes(r.length);
          for (var i = 0; i < at.length; i++) {
            expect((Offset.zero & ShapeRounds.lid).deflate(size / 2 - 1).contains(at[i]), isTrue);
            for (var j = i + 1; j < at.length; j++) {
              expect((at[i] - at[j]).distance, greaterThanOrEqualTo(size));
            }
          }
        }
      }
      expect(ShapeRounds.small.map((r) => r.length), [1, 2, 3, 4, 5, 6]);
    });
  });

  group('saving and settings', () {
    test('a game survives saving; what a parent turned off stays off', () {
      final s = const Settings().copyWith(level: Level.big, minutes: 20, hints: false, voice: false, modes: {Mode.jigsaw, Mode.shapes}, boxes: {'fruit', 'city'}, magnet: Magnet.weak);
      final g = Game(settings: s, helper: Helper.magpie, pictures: const ['bear', 'mrt'], cutsDone: const {'t9': 4}, insets: const {'fruit'}, tangrams: const {'cat'});
      final back = Game.fromJson(g.toJson(), lib);
      expect(back.toJson(), g.toJson());
      expect(back.settings.modes, {Mode.jigsaw, Mode.shapes});
      expect(back.settings.boxes, {'fruit', 'city'});
      expect(back.settings.hints, isFalse);
      expect(back.settings.voice, isFalse);
    });

    test('broken or unknown things are left out', () {
      final g = Game.fromJson({
        'settings': {'minutes': 7, 'level': 'huge', 'modes': [], 'boxes': ['nope']},
        'helper': 'dragon',
        'pictures': ['bear', 'bear', 'unicorn', 3],
        'cuts': {'small': 't24', 'big': 't16'},
        'shapeRounds': {'small': 9, 'alike': 2},
        'restSince': 'yesterday',
      }, lib);
      expect(g.settings.minutes, 15);
      expect(g.settings.level, Level.small);
      expect(g.settings.modes, {Mode.shapes}, reason: 'never no toy box at all');
      expect(g.settings.boxes, {'fruit'});
      expect(g.helper, isNull);
      expect(g.pictures, ['bear']);
      expect(g.cuts, {Level.big: Cut.t16}, reason: 't24 is not a 小小 size');
      expect(g.shapeRounds, {'alike': 2});
      expect(g.restSince, isNull);
    });

    test('the free version: shapes, two jigsaw boxes and 小小\'s tangrams; turning boxes off never turns them all off', () {
      const s = Settings(full: false, level: Level.big);
      expect(s.open(Mode.shapes), isTrue);
      expect(s.open(Mode.blocks), isFalse);
      expect(s.boxOpen('fruit'), isTrue);
      expect(s.boxOpen('night'), isFalse);
      expect(s.tangramOpen(Level.small), isTrue);
      expect(s.tangramOpen(Level.big), isFalse);
      expect(Settings.tidyBoxes({'night', 'city'}, full: false), {'night', 'city', 'fruit'}, reason: 'one that can be played comes back, the others stay as they were');
      expect(Settings.tidyBoxes({'night'}), {'night'});
      expect(const Settings(level: Level.small).shows(Mode.blocks), isFalse, reason: '照著拼 starts at 中');
    });

    test('today\'s minutes start again after midnight without spoiling yesterday\'s', () {
      var g = const Game();
      g = g.played(DateTime(2026, 11, 15, 23, 59), 50).did(DateTime(2026, 11, 15, 23, 59));
      expect(g.log(DateTime(2026, 11, 15, 23, 59, 30)).seconds, 50);
      final next = DateTime(2026, 11, 16, 0, 1);
      expect(g.log(next).seconds, 0);
      expect(g.log(next).done, 0);
      g = g.played(next, 30);
      expect(g.log(next).seconds, 30);
      expect(g.today!.day, '2026-11-16');
    });

    test('resting an hour; a clock moved back does not lock the app', () {
      final now = DateTime(2026, 11, 15, 10);
      final g = const Game().rest(now);
      expect(g.resting(now.add(const Duration(minutes: 59))), isTrue);
      expect(g.resting(now.add(const Duration(minutes: 61))), isFalse);
      expect(g.resting(now.subtract(const Duration(minutes: 5))), isFalse);
      expect(g.playOn().restSince, isNull);
    });

    test('the shape box goes round its six rounds', () {
      var g = const Game();
      for (var i = 0; i < 6; i++) {
        g = g.finishShapes(DateTime(2026, 11, 15));
      }
      expect(g.shapeRound, 0);
      expect(g.log(DateTime(2026, 11, 15)).done, 6);
    });
  });
}
