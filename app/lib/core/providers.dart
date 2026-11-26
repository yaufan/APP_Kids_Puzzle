import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board.dart';
import 'content.dart';
import 'game.dart';
import 'sounds.dart';
import 'store.dart';
import 'voice.dart';

/// What time it is (tests and screenshots set it): the play-time limit and parent mode's minutes
/// use it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Dice (tests give a seeded one): the tray's order, the pieces' first turn.
final randomProvider = Provider<math.Random>((ref) => math.Random());

/// The boxes and puzzles (assets/*.json, loaded at start).
final libraryProvider = Provider<Library>((ref) => throw StateError('libraryProvider is set in main()'));

final storeProvider = Provider<GameStore>((ref) => MemoryStore());
final savedGameProvider = Provider<Game>((ref) => const Game());
final soundsProvider = Provider<Sounds>((ref) => const SilentSounds());
final voiceProvider = Provider<Voice>((ref) => const SilentVoice());

/// The game; every change is saved straight away.
final gameProvider = NotifierProvider<GameNotifier, Game>(GameNotifier.new);

class GameNotifier extends Notifier<Game> {
  @override
  Game build() => ref.read(savedGameProvider);

  void change(Game Function(Game g) f) {
    final next = f(state);
    if (identical(next, state)) return;
    state = next;
    ref.read(storeProvider).write(next.toJson());
  }

  void settings(Settings Function(Settings s) f) => change((g) => g.withSettings(f(g.settings)));
}

/// When this sitting started (reset when a parent lets play go on). The app closed and opened
/// again within ten minutes goes on with the sitting it saved ([Sitting]).
final sessionStartProvider = NotifierProvider<SessionStart, DateTime>(SessionStart.new);

class SessionStart extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = ref.read(clockProvider)();
    return ref.read(gameProvider).sitting?.startAt(now) ?? now;
  }

  void restart() => state = ref.read(clockProvider)();

  /// Time [d] a parent spent in parent mode (or the app in the background) is not the child's:
  /// the sitting starts that much later (never later than now).
  void pause(Duration d) {
    if (d.isNegative) return;
    final now = ref.read(clockProvider)(), later = state.add(d);
    state = later.isAfter(now) ? now : later;
  }

  /// The phone's clock moved by [d]: the sitting's start moves with it.
  void shift(Duration d) => state = state.add(d);
}

/// Whether a puzzle is being put together right now: when the play time runs out, it may be
/// finished first (at most two more minutes, docs/design.md 「休息」).
final busyProvider = NotifierProvider<Busy, bool>(Busy.new);

class Busy extends Notifier<bool> {
  Object? _owner;
  var _celebrating = false;

  @override
  bool build() => false;

  /// Whether the puzzle on screen was just finished and its picture is coming alive (a few
  /// seconds): the rest waits for it, even after the two minutes.
  bool get celebrating => state && _celebrating;

  /// [owner] (a puzzle's page) is being put together ([v]), or was just finished ([celebrating]).
  /// A page going away never clears the busy of the page that came after it (再拼一次 and 下一張
  /// put the new page up before the old one is gone).
  void set(bool v, {Object? owner, bool celebrating = false}) {
    if (!ref.mounted) return;
    if (v) {
      _owner = owner;
      _celebrating = celebrating;
    } else {
      if (owner != null && _owner != null && !identical(owner, _owner)) return;
      _owner = null;
      _celebrating = false;
    }
    if (state != v) state = v;
  }
}

/// A puzzle left before it was finished (the home button, the phone's back key, the rest): the
/// pieces on the board and the order of the rest.
class Kept {
  const Kept(this.board, this.pieces);

  final Board board;
  final List<Piece> pieces;
}

/// The puzzles left half done (by picture and size, tangram figure, pattern-block card), so the
/// child finds the pieces where they were on coming back (until the app is closed).
final keptProvider = Provider<Map<String, Kept>>((ref) => <String, Kept>{});

/// Things said only once per app start (the welcome).
final onceProvider = Provider<Set<String>>((ref) => <String>{});
