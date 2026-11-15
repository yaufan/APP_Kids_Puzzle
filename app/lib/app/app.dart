import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/content.dart';
import '../core/jigsaw.dart';
import '../core/providers.dart';
import '../features/blocks/blocks_screen.dart';
import '../features/helper/helper_screen.dart';
import '../features/home/home_screen.dart';
import '../features/jigsaw/jigsaw_screen.dart';
import '../features/jigsaw/picture_list.dart';
import '../features/parent/parent_gate.dart';
import '../features/parent/parent_screen.dart';
import '../features/rest/rest_screen.dart';
import '../features/shapes/shapes_screen.dart';
import '../features/tangram/tangram_screen.dart';
import 'strings.dart';
import 'theme.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final resting = ref.read(gameProvider).resting(ref.read(clockProvider)());
  final router = GoRouter(
    initialLocation: resting ? '/rest' : '/',
    // Always start here, whatever page another app asks the phone to open.
    overridePlatformDefaultLocation: true,
    redirect: (_, state) {
      final at = state.matchedLocation;
      if (at == '/parent') return ParentPass.take() ? null : '/';
      if (at == '/rest') return null;
      final g = ref.read(gameProvider);
      final lib = ref.read(libraryProvider);
      final s = g.settings;
      if (g.helper == null && at != '/helper') return '/helper';
      final q = state.uri.queryParameters;
      for (final m in Mode.values) {
        if (at.startsWith(m.path) && (!s.shows(m) || !s.open(m))) return '/';
      }
      if (at == '/shapes/inset' && !lib.insets.any((b) => b.id == q['board'])) return '/shapes';
      if (at == '/jigsaw/box') {
        final id = q['id'];
        if (id == null || !lib.box.containsKey(id) || !s.boxes.contains(id) || !s.boxOpen(id)) return '/jigsaw';
      }
      if (at == '/jigsaw/play') {
        final p = lib.picture[q['pic']];
        final c = Cut.values.asNameMap()[q['cut']];
        if (p == null || !s.boxOpen(p.box) || !s.boxes.contains(p.box)) return '/jigsaw';
        if (c == null || !g.cutsOpen(s.level).contains(c)) return '/jigsaw/box?id=${p.box}';
      }
      if (at == '/tangram/play') {
        final t = lib.tangrams.where((t) => t.id == q['id']).firstOrNull;
        if (t == null || !s.tangramOpen(t.level)) return '/tangram';
      }
      if (at == '/blocks/play' && !lib.cards.any((c) => c.id == q['id'])) return '/blocks';
      if (at == '/taiwan' && !g.pictureDone(q['pic'] ?? '')) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/helper', builder: (_, _) => const HelperScreen()),
      GoRoute(path: '/shapes', builder: (_, _) => const ShapesMenu()),
      GoRoute(path: '/shapes/box', builder: (_, s) => ShapeBoxScreen(key: ValueKey(s.uri.toString()), round: int.tryParse(s.uri.queryParameters['again'] ?? '')?.clamp(0, 5))),
      GoRoute(path: '/shapes/inset', builder: (_, s) => InsetScreen(key: ValueKey(s.uri.toString()), boardId: s.uri.queryParameters['board']!)),
      GoRoute(path: '/jigsaw', builder: (_, _) => const BoxList()),
      GoRoute(path: '/jigsaw/box', builder: (_, s) => PictureList(key: ValueKey(s.uri.toString()), boxId: s.uri.queryParameters['id']!)),
      GoRoute(path: '/jigsaw/play', builder: (_, s) => JigsawScreen(key: ValueKey(s.uri.toString()), pictureId: s.uri.queryParameters['pic']!, cut: Cut.values.byName(s.uri.queryParameters['cut']!))),
      GoRoute(path: '/taiwan', builder: (_, s) => AliveScreen(key: ValueKey(s.uri.toString()), pictureId: s.uri.queryParameters['pic']!)),
      GoRoute(path: '/tangram', builder: (_, _) => const TangramList()),
      GoRoute(path: '/tangram/play', builder: (_, s) => TangramScreen(key: ValueKey(s.uri.toString()), figureId: s.uri.queryParameters['id']!)),
      GoRoute(path: '/blocks', builder: (_, _) => const CardList()),
      GoRoute(path: '/blocks/play', builder: (_, s) => BlocksScreen(key: ValueKey(s.uri.toString()), cardId: s.uri.queryParameters['id']!)),
      GoRoute(path: '/rest', builder: (_, _) => const RestScreen()),
      GoRoute(path: '/parent', builder: (_, _) => const ParentScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class PuzzleApp extends ConsumerWidget {
  const PuzzleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameProvider.select((g) => g.settings));
    ref.read(soundsProvider)
      ..music = settings.music
      ..effects = settings.sounds;
    return MaterialApp.router(
      title: Strings.appName,
      debugShowCheckedModeBanner: false,
      theme: WoodTheme.light(),
      locale: const Locale('zh', 'TW'),
      supportedLocales: const [Locale('zh', 'TW')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: ref.watch(routerProvider),
      builder: (_, child) => RestGuard(child: child ?? const SizedBox()),
    );
  }
}

/// Keeps the parent's play time (docs/design.md 「每次玩多久」): when the sitting has gone on for
/// the minutes they set, the puzzle being put together may be finished (at most two more
/// minutes), then the workshop's lights go down and the helper sleeps; an hour later (or when a
/// parent says so) play can go on. Away from the app for ten minutes counts as a rest; time in
/// parent mode or with the app in the background is not the child's play time. It also counts
/// today's minutes for parent mode.
class RestGuard extends ConsumerStatefulWidget {
  const RestGuard({super.key, required this.child});

  final Widget child;

  static const check = Duration(seconds: 2);
  static const awayIsRest = Duration(minutes: 10);

  /// How long a puzzle being put together may go on after the time is up.
  static const finishUp = Duration(minutes: 2);

  /// Played seconds are saved this often.
  static const saveEvery = 30;

  @override
  ConsumerState<RestGuard> createState() => _RestGuardState();
}

class _RestGuardState extends ConsumerState<RestGuard> {
  Timer? _timer;
  AppLifecycleListener? _life;
  DateTime? _away;

  /// When parent mode was opened (its time is given back to the child).
  DateTime? _parentSince;

  /// When the time ran out while a puzzle was being put together.
  DateTime? _overSince;
  var _unsaved = 0;

  @override
  void initState() {
    super.initState();
    ref.read(sessionStartProvider);
    _timer = Timer.periodic(RestGuard.check, (_) => _check());
    _life = AppLifecycleListener(
      onHide: () {
        _save();
        _away = ref.read(clockProvider)();
      },
      onShow: () {
        final away = _away;
        _away = null;
        if (away != null && ref.read(clockProvider)().difference(away) >= RestGuard.awayIsRest) ref.read(sessionStartProvider.notifier).restart();
        _check();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life?.dispose();
    super.dispose();
  }

  void _save() {
    if (_unsaved <= 0) return;
    final s = _unsaved;
    _unsaved = 0;
    ref.read(gameProvider.notifier).change((g) => g.played(ref.read(clockProvider)(), s));
  }

  void _check() {
    if (!mounted) return;
    final now = ref.read(clockProvider)();
    final g = ref.read(gameProvider);
    final router = ref.read(routerProvider);
    final path = router.state.matchedLocation;
    // Not while the app is out of sight (its timer can go on in the background).
    final playing = _away == null && !path.startsWith('/parent') && path != '/rest' && path != '/helper';
    if (playing) {
      _unsaved += RestGuard.check.inSeconds;
      if (_unsaved >= RestGuard.saveEvery) _save();
    }
    if (path.startsWith('/parent')) {
      _parentSince ??= now;
      return;
    }
    final parentSince = _parentSince;
    if (parentSince != null) {
      _parentSince = null;
      ref.read(sessionStartProvider.notifier).pause(now.difference(parentSince));
    }
    if (g.restSince != null) {
      if (g.resting(now)) {
        if (path != '/rest') router.go('/rest');
        return;
      }
      ref.read(gameProvider.notifier).change((g) => g.playOn());
      ref.read(sessionStartProvider.notifier).restart();
      _overSince = null;
      if (path == '/rest') router.go('/');
      return;
    }
    if (path == '/rest') return;
    if (now.difference(ref.read(sessionStartProvider)) >= Duration(minutes: g.settings.minutes)) {
      final over = _overSince ??= now;
      if (ref.read(busyProvider) && now.difference(over) < RestGuard.finishUp) return;
      _overSince = null;
      _save();
      ref.read(gameProvider.notifier).change((g) => g.rest(now));
      router.go('/rest');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
