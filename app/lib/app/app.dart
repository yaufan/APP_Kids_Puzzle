import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/content.dart';
import '../core/game.dart';
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
import 'widgets.dart';

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
    // The phone's back key never closes the app: a screen's top bar makes it do what its home
    // button does; in the workshop and at the rest it does nothing.
    routes: [
      GoRoute(path: '/', builder: (_, _) => const BackKey(child: HomeScreen())),
      // The first time there is no going back from picking a helper.
      GoRoute(
        path: '/helper',
        builder: (context, _) => BackKey(
          onBack: () {
            if (ref.read(gameProvider).helper != null) GoRouter.of(context).go('/');
          },
          child: const HelperScreen(),
        ),
      ),
      GoRoute(path: '/shapes', builder: (_, _) => const BackKey(child: ShapesMenu())),
      GoRoute(path: '/shapes/box', builder: (_, s) => BackKey(child: ShapeBoxScreen(key: ValueKey(s.uri.toString()), round: int.tryParse(s.uri.queryParameters['again'] ?? '')?.clamp(0, 5)))),
      GoRoute(path: '/shapes/inset', builder: (_, s) => BackKey(child: InsetScreen(key: ValueKey(s.uri.toString()), boardId: s.uri.queryParameters['board']!))),
      GoRoute(path: '/jigsaw', builder: (_, _) => const BackKey(child: BoxList())),
      GoRoute(path: '/jigsaw/box', builder: (_, s) => BackKey(child: PictureList(key: ValueKey(s.uri.toString()), boxId: s.uri.queryParameters['id']!))),
      GoRoute(path: '/jigsaw/play', builder: (_, s) => BackKey(child: JigsawScreen(key: ValueKey(s.uri.toString()), pictureId: s.uri.queryParameters['pic']!, cut: Cut.values.byName(s.uri.queryParameters['cut']!)))),
      GoRoute(path: '/taiwan', builder: (_, s) => BackKey(child: AliveScreen(key: ValueKey(s.uri.toString()), pictureId: s.uri.queryParameters['pic']!))),
      GoRoute(path: '/tangram', builder: (_, _) => const BackKey(child: TangramList())),
      GoRoute(path: '/tangram/play', builder: (_, s) => BackKey(child: TangramScreen(key: ValueKey(s.uri.toString()), figureId: s.uri.queryParameters['id']!))),
      GoRoute(path: '/blocks', builder: (_, _) => const BackKey(child: CardList())),
      GoRoute(path: '/blocks/play', builder: (_, s) => BackKey(child: BlocksScreen(key: ValueKey(s.uri.toString()), cardId: s.uri.queryParameters['id']!))),
      GoRoute(path: '/rest', builder: (_, _) => const BackKey(child: RestScreen())),
      // Parent mode closes by itself after five minutes without a touch.
      GoRoute(
        path: '/parent',
        builder: (context, _) {
          void home() => GoRouter.of(context).go('/');
          return BackKey(onBack: home, child: ParentIdle(onIdle: home, child: const ParentScreen()));
        },
      ),
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
/// minutes, and its picture still comes alive), then the workshop's lights go down and the helper
/// sleeps; an hour later (or when a parent says so) play can go on. Away from the app for ten
/// minutes counts as a rest, closed or in the background: the sitting is kept on the phone, so the
/// app closed and opened again goes on with it. Time on the parent gate, in parent mode or with
/// the app in the background is not the child's play time, and a phone clock moved back gives no
/// extra time. Parent mode left in the background is closed, so a child finds the workshop. It
/// also counts today's minutes for parent mode.
class RestGuard extends ConsumerStatefulWidget {
  const RestGuard({super.key, required this.child});

  final Widget child;

  static const check = Duration(seconds: 2);
  static const awayIsRest = Sitting.goesOn;

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

  /// The clock when last looked at (to see it moved back).
  DateTime? _lastNow;
  var _unsaved = 0;

  @override
  void initState() {
    super.initState();
    ref.read(sessionStartProvider);
    parentGateShowing.addListener(_gate);
    _timer = Timer.periodic(RestGuard.check, (_) => _check());
    _life = AppLifecycleListener(
      onHide: () {
        _save();
        _away = _now();
        // Parent mode is not left open for a child to find: the workshop, and the gate has to be
        // answered again.
        final router = ref.read(routerProvider);
        if (router.state.matchedLocation.startsWith('/parent')) {
          ParentPass.take();
          router.go('/');
        }
      },
      onShow: () {
        final now = _now();
        final away = _away;
        _away = null;
        if (away != null) {
          final d = now.difference(away);
          if (d >= RestGuard.awayIsRest) {
            ref.read(sessionStartProvider.notifier).restart();
            _overSince = null;
          } else if (d > Duration.zero && _parentSince == null) {
            // A few minutes in the background are not play: the sitting (and the two minutes to
            // finish a puzzle) go on where they were. (In parent mode, leaving it gives all of
            // its time back, this included.)
            ref.read(sessionStartProvider.notifier).pause(d);
            _overSince = _overSince?.add(d);
          }
        }
        _check();
      },
    );
  }

  /// Now. If the phone's clock was moved back since the last look (by hand, or set by the
  /// network), every time kept here moves back with it: the child's minutes stay as they were and
  /// the rest still lasts its hour.
  DateTime _now() {
    final now = ref.read(clockProvider)();
    final last = _lastNow;
    _lastNow = now;
    if (last != null && now.isBefore(last)) {
      final back = now.difference(last);
      ref.read(sessionStartProvider.notifier).shift(back);
      _away = _away?.add(back);
      _parentSince = _parentSince?.add(back);
      _overSince = _overSince?.add(back);
      final rest = ref.read(gameProvider).restSince;
      if (rest != null) ref.read(gameProvider.notifier).change((g) => g.copyWith(restSince: rest.add(back)));
    }
    return now;
  }

  /// The parent gate's time is parent time from the moment it opens until it closes (unless it
  /// opened parent mode).
  void _gate() {
    if (_away != null) return;
    if (parentGateShowing.value > 0) {
      _parentSince ??= _now();
      return;
    }
    // (The gate closes while the screens are being put up: just after.)
    Future.microtask(() {
      if (!mounted || _away != null || parentGateShowing.value > 0) return;
      if (ref.read(routerProvider).state.matchedLocation.startsWith('/parent')) return;
      _parentOver(_now());
    });
  }

  /// Parent time is over: given back to the child.
  void _parentOver(DateTime now) {
    final parentSince = _parentSince;
    if (parentSince == null) return;
    _parentSince = null;
    ref.read(sessionStartProvider.notifier).pause(now.difference(parentSince));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _life?.dispose();
    parentGateShowing.removeListener(_gate);
    super.dispose();
  }

  /// Saves the seconds played, and the sitting: how much play time it has used (parent time not
  /// yet given back left out) and when.
  void _save() {
    final now = ref.read(clockProvider)();
    final s = _unsaved;
    _unsaved = 0;
    var used = now.difference(ref.read(sessionStartProvider));
    final p = _parentSince;
    if (p != null && now.isAfter(p)) used -= now.difference(p);
    final sitting = Sitting(used.isNegative ? Duration.zero : used, now);
    ref.read(gameProvider.notifier).change((g) {
      final played = s > 0 ? g.played(now, s) : g;
      // Resting: there is no sitting to go on with.
      return g.restSince != null ? played : played.copyWith(sitting: sitting);
    });
  }

  void _check() {
    if (!mounted) return;
    final now = _now();
    // Nothing while the app is out of sight (its timer can go on in the background): that time is
    // given back when it comes back.
    if (_away != null) return;
    final g = ref.read(gameProvider);
    final router = ref.read(routerProvider);
    final path = router.state.matchedLocation;
    // The parent gate (on top of the workshop or the rest) is parent time too.
    final parent = path.startsWith('/parent') || parentGateShowing.value > 0;
    final playing = !parent && path != '/rest' && path != '/helper';
    if (playing) {
      _unsaved += RestGuard.check.inSeconds;
      if (_unsaved >= RestGuard.saveEvery) _save();
    }
    if (parent) {
      _parentSince ??= now;
      return;
    }
    _parentOver(now);
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
      final busy = ref.read(busyProvider.notifier);
      // A puzzle just finished still comes alive (a few seconds), even after the two minutes.
      if (busy.celebrating || (ref.read(busyProvider) && now.difference(over) < RestGuard.finishUp)) return;
      _overSince = null;
      _save();
      ref.read(gameProvider.notifier).change((g) => g.rest(now));
      router.go('/rest');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
