import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// When this sitting started (reset when a parent lets play go on).
final sessionStartProvider = NotifierProvider<SessionStart, DateTime>(SessionStart.new);

class SessionStart extends Notifier<DateTime> {
  @override
  DateTime build() => ref.read(clockProvider)();

  void restart() => state = ref.read(clockProvider)();

  /// Time [d] a parent spent in parent mode is not the child's: the sitting starts that much
  /// later (never later than now).
  void pause(Duration d) {
    if (d.isNegative) return;
    final now = ref.read(clockProvider)(), later = state.add(d);
    state = later.isAfter(now) ? now : later;
  }
}

/// Whether a puzzle is being put together right now: when the play time runs out, it may be
/// finished first (at most two more minutes, docs/design.md 「休息」).
final busyProvider = NotifierProvider<Busy, bool>(Busy.new);

class Busy extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) {
    if (ref.mounted && state != v) state = v;
  }
}

/// Things said only once per app start (the welcome).
final onceProvider = Provider<Set<String>>((ref) => <String>{});
