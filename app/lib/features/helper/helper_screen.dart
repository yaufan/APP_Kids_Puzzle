import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/content.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';

/// The first time (and whenever the child wants another): pick the workshop's helper from six
/// Taiwanese animals. A tap makes it say hello in its own way; then the workshop opens.
class HelperScreen extends ConsumerStatefulWidget {
  const HelperScreen({super.key});

  @override
  ConsumerState<HelperScreen> createState() => _HelperScreenState();
}

class _HelperScreenState extends ConsumerState<HelperScreen> with HushOnLeave {
  Helper? _picked;
  final _hops = <Helper, int>{};
  Later? _later;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) speak(ref, Strings.pickLine);
    });
  }

  @override
  void dispose() {
    _later?.cancel();
    super.dispose();
  }

  void _pick(Helper h) {
    if (_picked != null) return;
    sfx(ref, h.sound);
    setState(() {
      _picked = h;
      _hops[h] = (_hops[h] ?? 0) + 1;
    });
    ref.read(gameProvider.notifier).change((g) => g.pick(h));
    final said = speak(ref, '${h.call}${Strings.hello(h)}');
    _later = Later(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/');
    }, after: said);
  }

  @override
  Widget build(BuildContext context) => WithMusic(
        music: Music.workshop,
        child: Scaffold(
          body: WallBg(
            child: SafeArea(
              child: LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth > 700 ? 3 : 2;
                final cell = ((box.maxWidth - 32 - 12 * (cols - 1)) / cols).clamp(100.0, 230.0);
                return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      decoration: woodBox(Wood.light, radius: 18),
                      child: const Text(Strings.pickTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 12, children: [
                    for (final h in Helper.values)
                      Semantics(
                        key: ValueKey('helper-${h.name}'),
                        container: true,
                        button: true,
                        label: h.zh,
                        excludeSemantics: true,
                        onTap: () => _pick(h),
                        child: Pressable(
                          onTap: () => _pick(h),
                          sound: null,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _picked == null || _picked == h ? 1 : .4,
                            child: Container(
                              width: cell,
                              padding: const EdgeInsets.all(10),
                              decoration: woodBox(_picked == h ? Wood.glow : Wood.paper, radius: 24),
                              child: Column(children: [
                                Hop(trigger: _hops[h] ?? 0, child: HelperView(helper: h, size: cell * .72, pose: _picked == h ? 'cheer' : 'idle')),
                                Text(h.zh, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                                Text(h.animal, style: const TextStyle(fontSize: 15, color: Wood.inkSoft)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                  ]),
                ]);
              }),
            ),
          ),
        ),
      );
}
