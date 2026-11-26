import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/content.dart';
import '../../core/providers.dart';
import '../../core/sounds.dart';
import '../parent/parent_gate.dart';

/// The play time is up (docs/design.md 「休息」): the workshop's lights go down, the moon is in the
/// window, the helper sleeps its own way (甲甲 curls into a ball…), and the child is sent off to
/// tidy up toys and do a real puzzle: 「換你去做了！去收玩具、拼真的拼圖吧！」 Only a parent
/// (through the gate) or an hour's wait lets play go on.
class RestScreen extends ConsumerStatefulWidget {
  const RestScreen({super.key});

  @override
  ConsumerState<RestScreen> createState() => _RestScreenState();
}

class _RestScreenState extends ConsumerState<RestScreen> with HushOnLeave {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      sfx(ref, 'night');
      speak(ref, '${Strings.restTitle}${Strings.restLine}');
    });
  }

  Future<void> _parent() async {
    if (!await showParentGate(context, pass: false) || !mounted) return;
    ref.read(gameProvider.notifier).change((g) => g.playOn());
    ref.read(sessionStartProvider.notifier).restart();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final h = ref.watch(gameProvider.select((g) => g.helper)) ?? Helper.pangolin;
    return WithMusic(
      music: Music.rest,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Wood.night1, Wood.night2, Color(0xFF7A5E4A)], stops: [0, .62, .63])),
          child: SafeArea(
            child: LayoutBuilder(builder: (context, box) {
              final w = math.min(box.maxWidth, 600.0);
              return Center(
                child: SizedBox(
                  width: w,
                  child: Stack(children: [
                    Positioned(left: w * .3, right: w * .3, top: box.maxHeight * .05, height: w * .4, child: const Art('ui/window')),
                    for (final (x, y) in [(.12, .1), (.85, .08), (.08, .3), (.9, .28)])
                      Positioned(left: w * x, top: box.maxHeight * y, width: 18, height: 18, child: Bob(amount: 2, phase: x, child: const Art('ui/star'))),
                    Positioned(
                      left: w * .2,
                      right: w * .2,
                      top: box.maxHeight * .3,
                      height: w * .5,
                      child: Stack(alignment: Alignment.bottomCenter, children: [
                        const Positioned(left: 0, right: 0, bottom: 0, height: 60, child: Art('ui/cushion', fit: BoxFit.fill)),
                        Positioned(bottom: 22, child: Bob(amount: 2, period: 3200, child: HelperView(size: w * .38, pose: 'sleep'))),
                        Positioned(right: w * .02, top: 0, child: Text('Z z z', style: TextStyle(fontSize: w * .05, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: .85)))),
                      ]),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: box.maxHeight * .12,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                        decoration: woodBox(Wood.paper, radius: 24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text(Strings.restTitle, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Wood.ink)),
                          const SizedBox(height: 6),
                          const Text(Strings.restLine, textAlign: TextAlign.center, style: TextStyle(fontSize: 21, height: 1.5, color: Wood.ink)),
                          const SizedBox(height: 4),
                          Text(h.sleeps, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Wood.inkSoft)),
                        ]),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: Semantics(
                        container: true,
                        button: true,
                        label: Strings.parent,
                        excludeSemantics: true,
                        onTap: _parent,
                        child: Pressable(
                          onTap: _parent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: woodBox(Colors.white.withValues(alpha: .9), radius: 20, shadow: false),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.lock_outline_rounded, color: Wood.inkSoft, size: 20),
                              SizedBox(width: 6),
                              Text(Strings.restNote, style: TextStyle(fontSize: 14, color: Wood.inkSoft)),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
