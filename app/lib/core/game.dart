import 'dart:math' as math;

import 'board.dart';
import 'content.dart';
import 'jigsaw.dart';

/// What a parent set (parent mode, docs/design.md 「家長模式」).
class Settings {
  const Settings({
    this.level = Level.small,
    this.minutes = 15,
    this.magnet = Magnet.normal,
    this.hints = true,
    this.faint = true,
    this.edgesFirst = true,
    this.tapTurn = true,
    this.talk = true,
    this.voice = true,
    this.slow = false,
    this.music = true,
    this.sounds = true,
    this.full = true,
    this.modes = const {Mode.shapes, Mode.jigsaw, Mode.tangram, Mode.blocks},
    this.boxes = allBoxes,
  });

  final Level level;

  /// How long one sitting may be before a rest.
  final int minutes;
  final Magnet magnet;

  /// A place lights up when nothing was put down for a while.
  final bool hints;

  /// The jigsaw's picture shows faintly under the pieces (小小 and 中).
  final bool faint;

  /// 12 pieces or more: corners and edges come first.
  final bool edgesFirst;

  /// 大's tangram: a tap turns a piece (off: pieces turn themselves upright as at 中).
  final bool tapTurn;

  /// The helper says where things go (上面、旁邊、轉一轉…).
  final bool talk;
  final bool voice;
  final bool slow;
  final bool music;
  final bool sounds;

  /// The full version (everything); on while testing.
  final bool full;

  /// The toy boxes on the shelf (at least one).
  final Set<Mode> modes;

  /// The jigsaw boxes shown (at least one).
  final Set<String> boxes;

  static const minuteChoices = [10, 15, 20, 30];
  static const allBoxes = {'fruit', 'animals', 'night', 'ride', 'temple', 'city'};
  static const freeBoxes = {'fruit', 'animals'};

  /// Whether [m] can be played in this version at this level (照著拼 is for 中 and 大, and only in
  /// the full version).
  bool open(Mode m) => switch (m) {
        Mode.blocks => full && level != Level.small,
        _ => true,
      };

  /// Whether [m] is on the shelf at this level (照著拼 starts at 中; a parent can take boxes off).
  bool shows(Mode m) => modes.contains(m) && (m != Mode.blocks || level != Level.small);

  bool boxOpen(String box) => full || freeBoxes.contains(box);

  /// The tangram sets that can be played: 小小's is free, 中's and 大's are in the full version.
  bool tangramOpen(Level set) => full || set == Level.small;

  Turning tangramTurning(Level set) => switch (set) {
        Level.small => Turning.none,
        Level.middle => Turning.auto,
        Level.big => tapTurn ? Turning.tap : Turning.auto,
      };

  /// A parent's choices kept sensible: at least one toy box and one jigsaw box that can be played.
  /// 照著拼 alone is not enough at 小小 (it starts at 中) or in the free version (it is locked):
  /// the shape box comes back, so the shelf is never empty.
  static Set<Mode> tidyModes(Set<Mode> m, {Level level = Level.small, bool full = true}) =>
      m.any((x) => x != Mode.blocks || (full && level != Level.small)) ? m : {...m, Mode.shapes};

  static Set<String> tidyBoxes(Set<String> b, {bool full = true}) {
    final out = {for (final x in b) if (allBoxes.contains(x)) x};
    if (!out.any((x) => full || freeBoxes.contains(x))) out.add('fruit');
    return out;
  }

  Settings copyWith({Level? level, int? minutes, Magnet? magnet, bool? hints, bool? faint, bool? edgesFirst, bool? tapTurn, bool? talk, bool? voice, bool? slow, bool? music, bool? sounds, bool? full, Set<Mode>? modes, Set<String>? boxes}) =>
      Settings(
        level: level ?? this.level,
        minutes: minutes ?? this.minutes,
        magnet: magnet ?? this.magnet,
        hints: hints ?? this.hints,
        faint: faint ?? this.faint,
        edgesFirst: edgesFirst ?? this.edgesFirst,
        tapTurn: tapTurn ?? this.tapTurn,
        talk: talk ?? this.talk,
        voice: voice ?? this.voice,
        slow: slow ?? this.slow,
        music: music ?? this.music,
        sounds: sounds ?? this.sounds,
        full: full ?? this.full,
        modes: tidyModes(modes ?? this.modes, level: level ?? this.level, full: full ?? this.full),
        boxes: tidyBoxes(boxes ?? this.boxes, full: full ?? this.full),
      );

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'minutes': minutes,
        'magnet': magnet.name,
        'hints': hints,
        'faint': faint,
        'edgesFirst': edgesFirst,
        'tapTurn': tapTurn,
        'talk': talk,
        'voice': voice,
        'slow': slow,
        'music': music,
        'sounds': sounds,
        'full': full,
        'modes': [for (final m in Mode.values) if (modes.contains(m)) m.name],
        'boxes': (boxes.toList()..sort()),
      };

  factory Settings.fromJson(Map<String, dynamic> j) {
    final m = j['minutes'], md = j['modes'], bx = j['boxes'];
    bool flag(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    final full = flag('full', true);
    final level = Level.values.asNameMap()[j['level']] ?? Level.small;
    return Settings(
      level: level,
      minutes: m is int && minuteChoices.contains(m) ? m : 15,
      magnet: Magnet.values.asNameMap()[j['magnet']] ?? Magnet.normal,
      hints: flag('hints', true),
      faint: flag('faint', true),
      edgesFirst: flag('edgesFirst', true),
      tapTurn: flag('tapTurn', true),
      talk: flag('talk', true),
      voice: flag('voice', true),
      slow: flag('slow', false),
      music: flag('music', true),
      sounds: flag('sounds', true),
      full: full,
      modes: md is List ? tidyModes({for (final n in md) ?Mode.values.asNameMap()[n]}, level: level, full: full) : const {Mode.shapes, Mode.jigsaw, Mode.tangram, Mode.blocks},
      boxes: bx is List ? tidyBoxes({for (final n in bx) if (n is String) n}, full: full) : allBoxes,
    );
  }
}

/// What was played today (parent mode).
class DayLog {
  const DayLog(this.day, {this.seconds = 0, this.done = 0});

  final String day;
  final int seconds;

  /// Puzzles finished today (of every kind).
  final int done;

  Map<String, dynamic> toJson() => {'day': day, 'seconds': seconds, 'done': done};

  static DayLog? fromJson(dynamic j) {
    if (j is! Map || j['day'] is! String || Days.parse(j['day'] as String) == null) return null;
    final s = j['seconds'], d = j['done'];
    return DayLog(j['day'] as String, seconds: s is int && s > 0 ? s : 0, done: d is int && d > 0 ? d : 0);
  }
}

abstract final class Days {
  static String key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? parse(String k) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(k);
    if (m == null) return null;
    final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    return key(d) == k ? d : null;
  }
}

/// The sitting going on when the app was last in sight (docs/design.md
/// 「每次玩多久」): the play time used so far, and when. Opened again within
/// [goesOn], the same sitting goes on and the time the app was closed is not
/// play time; later it is a new sitting.
class Sitting {
  const Sitting(this.used, this.seen);

  final Duration used;
  final DateTime seen;

  /// Closed (or in the background) this long counts as a rest.
  static const goesOn = Duration(minutes: 10);

  /// When the sitting began, opened again at [now]: as much play time used
  /// as before. A clock moved back meanwhile gives no extra time either.
  DateTime? startAt(DateTime now) => now.difference(seen) >= goesOn ? null : now.subtract(used);

  Map<String, dynamic> toJson() => {'used': used.inSeconds, 'seen': seen.toIso8601String()};

  static Sitting? fromJson(dynamic j) {
    if (j is! Map || j['used'] is! int || j['seen'] is! String) return null;
    final seen = DateTime.tryParse(j['seen'] as String);
    if (seen == null) return null;
    return Sitting(Duration(seconds: math.max(0, math.min(j['used'] as int, 24 * 3600))), seen);
  }
}

/// The parent gate's wrong answers (kept, so closing the app does not end a
/// wait): three in a row and it waits 1 minute, then 5, then 15. A right
/// answer starts over.
class GateLock {
  const GateLock({this.misses = 0, this.waits = 0, this.since});

  /// Wrong answers since the last wait.
  final int misses;

  /// How many waits there were (the next one is longer).
  final int waits;

  /// When the last wait began.
  final DateTime? since;

  static const maxMisses = 3;
  static const lengths = [Duration(minutes: 1), Duration(minutes: 5), Duration(minutes: 15)];

  Duration get length => lengths[(waits - 1).clamp(0, lengths.length - 1)];

  /// Waiting at [now]. A clock moved back (now before the wait began) is no
  /// wait, so it can never last for ever.
  bool locked(DateTime now) {
    final s = since;
    if (s == null) return false;
    final d = now.difference(s);
    return !d.isNegative && d < length;
  }

  /// How long is left of the wait at [now].
  Duration left(DateTime now) => locked(now) ? since!.add(length).difference(now) : Duration.zero;

  /// One more wrong answer at [now].
  GateLock miss(DateTime now) => misses + 1 >= maxMisses ? GateLock(waits: math.min(waits + 1, 99), since: now) : GateLock(misses: misses + 1, waits: waits, since: since);

  Map<String, dynamic> toJson() => {'misses': misses, 'waits': waits, if (since != null) 'since': since!.toIso8601String()};

  static GateLock fromJson(dynamic j) {
    if (j is! Map) return const GateLock();
    final m = j['misses'], w = j['waits'], s = j['since'];
    return GateLock(
      misses: m is int ? m.clamp(0, maxMisses - 1) : 0,
      waits: w is int ? w.clamp(0, 99) : 0,
      since: s is String ? DateTime.tryParse(s) : null,
    );
  }
}

/// Everything kept on the phone. One small file (store.dart).
class Game {
  const Game({
    this.settings = const Settings(),
    this.helper,
    this.pictures = const [],
    this.cutsDone = const {},
    this.cuts = const {},
    this.shapeRounds = const {},
    this.insets = const {},
    this.tangrams = const {},
    this.cards = const {},
    this.today,
    this.restSince,
    this.sitting,
    this.gate = const GateLock(),
  });

  final Settings settings;

  /// The workshop helper the child picked (null: not picked yet).
  final Helper? helper;

  /// The pictures finished at least once, oldest first (each is a piece of the Taiwan puzzle).
  final List<String> pictures;

  /// Pictures finished at each size (Cut.name → how many).
  final Map<String, int> cutsDone;

  /// The size the child last picked at each level.
  final Map<Level, Cut> cuts;

  /// The shape box's next round: 'small' or 'alike' → 0 to 5.
  final Map<String, int> shapeRounds;

  /// Inset boards, tangram figures and pattern-block cards finished.
  final Set<String> insets;
  final Set<String> tangrams;
  final Set<String> cards;
  final DayLog? today;

  /// When the play time ran out (null: playing).
  final DateTime? restSince;

  /// The sitting when the app was last in sight (null: none to go on with).
  final Sitting? sitting;
  final GateLock gate;

  static const restLength = Duration(hours: 1);

  /// Resting for an hour after the time ran out. A clock moved back (now before the rest began)
  /// does not lock the app: it counts as rested. (While the app is open, RestGuard moves the rest
  /// back with the clock, so moving the clock back does not end it early either.)
  bool resting(DateTime now) {
    final since = restSince;
    if (since == null) return false;
    final d = now.difference(since);
    return !d.isNegative && d < restLength;
  }

  // ---- the jigsaw's ladder

  /// The sizes a child can pick at level [l]: the first, and each next one after
  /// [Cut.toNext] pictures at the size before it.
  List<Cut> cutsOpen(Level l) {
    final ladder = Cut.ladder(l);
    final out = [ladder.first];
    for (var i = 1; i < ladder.length; i++) {
      if ((cutsDone[ladder[i - 1].name] ?? 0) < Cut.toNext) break;
      out.add(ladder[i]);
    }
    return out;
  }

  /// The size to start with at level [l]: the last one picked if it is open, else the biggest open.
  Cut cutFor(Level l) {
    final open = cutsOpen(l);
    final c = cuts[l];
    return c != null && open.contains(c) ? c : open.last;
  }

  int get shapeRound => shapeRounds[settings.level == Level.small ? 'small' : 'alike'] ?? 0;

  bool pictureDone(String id) => pictures.contains(id);

  // ---- changes

  Game copyWith({
    Settings? settings,
    Helper? helper,
    bool clearHelper = false,
    List<String>? pictures,
    Map<String, int>? cutsDone,
    Map<Level, Cut>? cuts,
    Map<String, int>? shapeRounds,
    Set<String>? insets,
    Set<String>? tangrams,
    Set<String>? cards,
    DayLog? today,
    DateTime? restSince,
    bool clearRest = false,
    Sitting? sitting,
    bool clearSitting = false,
    GateLock? gate,
  }) =>
      Game(
        settings: settings ?? this.settings,
        helper: clearHelper ? null : (helper ?? this.helper),
        pictures: pictures ?? this.pictures,
        cutsDone: cutsDone ?? this.cutsDone,
        cuts: cuts ?? this.cuts,
        shapeRounds: shapeRounds ?? this.shapeRounds,
        insets: insets ?? this.insets,
        tangrams: tangrams ?? this.tangrams,
        cards: cards ?? this.cards,
        today: today ?? this.today,
        restSince: clearRest ? null : (restSince ?? this.restSince),
        sitting: clearSitting ? null : (sitting ?? this.sitting),
        gate: gate ?? this.gate,
      );

  Game withSettings(Settings s) => copyWith(settings: s);

  Game pick(Helper h) => copyWith(helper: h);

  Game pickCut(Level l, Cut c) => copyWith(cuts: {...cuts, l: c});

  /// A picture finished at size [c]: a piece of the Taiwan puzzle the first time.
  Game finishPicture(String id, Cut c, DateTime now) =>
      copyWith(pictures: pictures.contains(id) ? pictures : [...pictures, id], cutsDone: {...cutsDone, c.name: (cutsDone[c.name] ?? 0) + 1}).did(now);

  /// A round of the shape box done: the next one (after the sixth, the first again).
  Game finishShapes(DateTime now) {
    final k = settings.level == Level.small ? 'small' : 'alike';
    return copyWith(shapeRounds: {...shapeRounds, k: ((shapeRounds[k] ?? 0) + 1) % 6}).did(now);
  }

  Game finishInset(String id, DateTime now) => copyWith(insets: {...insets, id}).did(now);
  Game finishTangram(String id, DateTime now) => copyWith(tangrams: {...tangrams, id}).did(now);
  Game finishCard(String id, DateTime now) => copyWith(cards: {...cards, id}).did(now);

  // ---- today (parent mode)

  DayLog log(DateTime now) {
    final d = today;
    return d != null && d.day == Days.key(now) ? d : DayLog(Days.key(now));
  }

  Game played(DateTime now, int seconds) {
    final d = log(now);
    return copyWith(today: DayLog(d.day, seconds: d.seconds + seconds, done: d.done));
  }

  Game did(DateTime now) {
    final d = log(now);
    return copyWith(today: DayLog(d.day, seconds: d.seconds, done: d.done + 1));
  }

  /// The play time ran out: the rest begins (and the sitting is over).
  Game rest(DateTime now) => copyWith(restSince: now, clearSitting: true);

  /// Play goes on (a parent said so, or the rest is over): a new sitting.
  Game playOn() => copyWith(clearRest: true, clearSitting: true);

  Map<String, dynamic> toJson() => {
        'version': 1,
        'settings': settings.toJson(),
        if (helper != null) 'helper': helper!.name,
        'pictures': pictures,
        'cutsDone': cutsDone,
        'cuts': {for (final e in cuts.entries) e.key.name: e.value.name},
        'shapeRounds': shapeRounds,
        'insets': insets.toList()..sort(),
        'tangrams': tangrams.toList()..sort(),
        'cards': cards.toList()..sort(),
        if (today != null) 'today': today!.toJson(),
        if (restSince != null) 'restSince': restSince!.toIso8601String(),
        if (sitting != null) 'sitting': sitting!.toJson(),
        'gate': gate.toJson(),
      };

  /// Reads a saved game; anything broken or unknown is left out.
  factory Game.fromJson(Map<String, dynamic>? j, Library lib) {
    if (j == null) return const Game();
    final pics = j['pictures'], cd = j['cutsDone'], cu = j['cuts'], sr = j['shapeRounds'], rest = j['restSince'];
    Set<String> ids(dynamic l, bool Function(String) ok) => {
          if (l is List)
            for (final x in l)
              if (x is String && ok(x)) x,
        };
    final insetIds = {for (final b in lib.insets) b.id};
    final tanIds = {for (final t in lib.tangrams) t.id};
    final cardIds = {for (final c in lib.cards) c.id};
    final seen = <String>{};
    return Game(
      settings: Settings.fromJson(j['settings'] is Map ? (j['settings'] as Map).cast<String, dynamic>() : const {}),
      helper: Helper.values.asNameMap()[j['helper']],
      pictures: [
        if (pics is List)
          for (final p in pics)
            if (p is String && lib.picture.containsKey(p) && seen.add(p)) p,
      ],
      cutsDone: {
        if (cd is Map)
          for (final e in cd.entries)
            if (Cut.values.asNameMap().containsKey(e.key) && e.value is int && (e.value as int) > 0) e.key as String: math.min(e.value as int, 99999),
      },
      cuts: {
        if (cu is Map)
          for (final e in cu.entries)
            if (Level.values.asNameMap()[e.key] != null && Cut.values.asNameMap()[e.value] != null && Cut.ladder(Level.values.byName(e.key as String)).contains(Cut.values.byName(e.value as String)))
              Level.values.byName(e.key as String): Cut.values.byName(e.value as String),
      },
      shapeRounds: {
        if (sr is Map)
          for (final k in const ['small', 'alike'])
            if (sr[k] is int && (sr[k] as int) >= 0 && (sr[k] as int) < 6) k: sr[k] as int,
      },
      insets: ids(j['insets'], insetIds.contains),
      tangrams: ids(j['tangrams'], tanIds.contains),
      cards: ids(j['cards'], cardIds.contains),
      today: DayLog.fromJson(j['today']),
      restSince: rest is String ? DateTime.tryParse(rest) : null,
      sitting: Sitting.fromJson(j['sitting']),
      gate: GateLock.fromJson(j['gate']),
    );
  }
}
