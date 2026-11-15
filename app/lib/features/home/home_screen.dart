import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/content.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';
import '../common/play_page.dart';
import '../parent/parent_gate.dart';

/// The workshop (docs/design.md 「工坊」): the Taiwan puzzle on the wall, the toy boxes on the
/// shelf, the helper at the bottom, and the parent's lock (held down, so a child does not open it
/// by chance).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with HushOnLeave {
  late String _line;
  var _cheer = 0;

  @override
  void initState() {
    super.initState();
    final h = ref.read(gameProvider).helper ?? Helper.pangolin;
    final first = ref.read(onceProvider).add('welcome');
    _line = first ? Strings.welcome(h) : Strings.whatNow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, _line);
    });
  }

  void _open(Mode m) {
    final s = ref.read(gameProvider).settings;
    if (!s.open(m)) {
      sfx(ref, 'tap');
      setState(() => _line = Strings.fullOnly(m.zh));
      speak(ref, _line);
      return;
    }
    sfx(ref, 'open');
    context.go(m.path);
  }

  void _helper() {
    final h = ref.read(gameProvider).helper ?? Helper.pangolin;
    sfx(ref, h.sound);
    setState(() {
      _cheer++;
      _line = '${h.call}${Strings.whatNow}';
    });
    speak(ref, _line);
  }

  Future<void> _parent() async {
    if (!await showParentGate(context) || !mounted) return;
    context.go('/parent');
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(gameProvider);
    final lib = ref.watch(libraryProvider);
    final s = g.settings;
    final modes = [for (final m in Mode.values) if (s.shows(m)) m];
    return WithMusic(
      music: Music.workshop,
      child: Scaffold(
        body: WallBg(
          child: SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              final wide = box.maxWidth > 700;
              final taiwan = Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: woodBox(Wood.light, radius: 22),
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  SizedBox(
                    height: (box.maxHeight * (wide ? .34 : .27)).clamp(150.0, 420.0),
                    child: TaiwanView(onPiece: (p) {
                      sfx(ref, 'tap');
                      context.go('/taiwan?pic=${p.id}');
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(Strings.taiwan, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      const Text(Strings.taiwanNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Wood.inkSoft)),
                      const SizedBox(height: 8),
                      Text(Strings.taiwanCount(g.pictures.length, lib.pictures.length), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Wood.green)),
                    ]),
                  ),
                ]),
              );
              final shelf = Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                for (final m in modes) _ToyBox(mode: m, locked: !s.open(m), width: wide ? 250 : (box.maxWidth - 44) / 2, onTap: () => _open(m)),
              ]);
              return Stack(children: [
                ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
                  Row(children: [
                    _ParentLock(onOpen: _parent),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: woodBox(Wood.yellow, radius: 16),
                      child: const Text(Strings.appName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Wood.ink)),
                    ),
                    const Spacer(),
                    const SizedBox(width: 52),
                  ]),
                  const SizedBox(height: 12),
                  taiwan,
                  const SizedBox(height: 16),
                  shelf,
                ]),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Flexible(child: HelperSays(text: _line, cheer: _cheer, size: 84, onTap: _helper)),
                    const SizedBox(width: 6),
                    RoundButton(
                      label: Strings.change,
                      icon: Icons.swap_horiz_rounded,
                      size: 44,
                      color: Wood.paper,
                      // The helper stays until another is picked (a rest that starts on the
                      // picking screen still shows the child's own helper asleep).
                      onTap: () => context.go('/helper'),
                    ),
                  ]),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _ToyBox extends StatelessWidget {
  const _ToyBox({required this.mode, required this.locked, required this.width, required this.onTap});

  final Mode mode;
  final bool locked;
  final double width;
  final VoidCallback onTap;

  static const colors = {Mode.shapes: Wood.red, Mode.jigsaw: Wood.teal, Mode.tangram: Wood.blue, Mode.blocks: Wood.green};

  @override
  Widget build(BuildContext context) => Semantics(
        key: ValueKey('mode-${mode.name}'),
        container: true,
        button: true,
        label: mode.zh,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          sound: null,
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              decoration: woodBox(colors[mode]!, radius: 22),
              child: Column(children: [
                Container(
                  height: width * .56,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.all(8),
                  child: Opacity(opacity: locked ? .5 : 1, child: Art('ui/mode_${mode.name}')),
                ),
                const SizedBox(height: 6),
                Text(mode.zh, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white, shadows: [Shadow(color: Wood.ink.withValues(alpha: .4), offset: const Offset(0, 1.5))])),
              ]),
            ),
            if (locked) const Positioned(right: -4, top: -6, child: LockBadge(size: 32)),
          ]),
        ),
      );
}

/// The parent's lock: held down for a second (a ring fills up), so a child does not open it.
class _ParentLock extends StatefulWidget {
  const _ParentLock({required this.onOpen});

  final VoidCallback onOpen;

  @override
  State<_ParentLock> createState() => _ParentLockState();
}

class _ParentLockState extends State<_ParentLock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _pointer = null;
        _c.value = 0;
        widget.onOpen();
      }
    });
  int? _pointer;
  Offset _from = Offset.zero;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _stop() {
    _pointer = null;
    _c.reverse();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: Strings.parent,
        excludeSemantics: true,
        onTap: widget.onOpen,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (_pointer != null) return;
            _pointer = e.pointer;
            _from = e.position;
            _c.forward();
          },
          // Only a finger held still on the lock opens it (not one scrolling the workshop).
          onPointerMove: (e) {
            if (e.pointer == _pointer && (e.position - _from).distance > tapSlop) _stop();
          },
          onPointerUp: (e) {
            if (e.pointer == _pointer) _stop();
          },
          onPointerCancel: (e) {
            if (e.pointer == _pointer) _stop();
          },
          child: SizedBox(
            width: 52,
            height: 52,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _c,
                builder: (_, _) => SizedBox(width: 46, height: 46, child: CircularProgressIndicator(value: _c.value, strokeWidth: 4, color: Wood.orange, backgroundColor: Colors.transparent)),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: woodBox(Colors.white, radius: 19, shadow: false, rim: 1.5),
                child: const Icon(Icons.lock_outline_rounded, size: 22, color: Wood.inkSoft),
              ),
            ]),
          ),
        ),
      );
}
