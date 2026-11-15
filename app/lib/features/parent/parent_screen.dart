import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/strings.dart';
import '../../app/theme.dart';
import '../../app/version.dart';
import '../../core/board.dart';
import '../../core/content.dart';
import '../../core/game.dart';
import '../../core/providers.dart';
import '../common/play_page.dart';

/// Parent mode (after the gate, docs/design.md 「家長模式」): the level and the play time, turning,
/// the helps (faint picture, magnet, hints, edges first), the voice and sounds, which toy boxes
/// and jigsaw boxes show, progress the child does not see, a few words on playing together, and
/// the full version.
class ParentScreen extends ConsumerWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = ref.watch(gameProvider);
    final lib = ref.watch(libraryProvider);
    final s = g.settings;
    final game = ref.read(gameProvider.notifier);
    final now = ref.read(clockProvider)();

    Widget section(String title, List<Widget> children, {Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, color: Wood.inkSoft, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...children,
              ]),
            ),
          ),
        );

    Widget toggle(String label, bool value, void Function(bool)? set, {Key? key, String? note}) => SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: const TextStyle(fontSize: 17)),
          subtitle: note == null ? null : Text(note, style: const TextStyle(fontSize: 13, color: Wood.inkSoft)),
          value: value,
          onChanged: set,
        );

    Widget chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) pick, String keyOf) => Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in values)
            ChoiceChip(
              key: ValueKey('$keyOf-${v is Enum ? v.name : v}'),
              label: Text(label(v), style: const TextStyle(fontSize: 16)),
              selected: v == selected,
              onSelected: (_) => pick(v),
              selectedColor: const Color(0xFFFFE3B8),
              showCheckmark: false,
            ),
        ]);

    const note = TextStyle(fontSize: 14, height: 1.5, color: Wood.inkSoft);
    final log = g.log(now);

    return Scaffold(
      backgroundColor: Wood.parentBg,
      appBar: AppBar(
        backgroundColor: Wood.parentBg,
        title: const Text(Strings.parentTitle),
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: Strings.back, onPressed: () => context.go('/')),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        section(Strings.levelTitle, [
          chips(Level.values, s.level, Strings.levelLine, (v) => game.settings((x) => x.copyWith(level: v)), 'level'),
          const SizedBox(height: 10),
          const Text(Strings.levelNote, style: note),
        ]),
        section(Strings.playTime, [
          chips(Settings.minuteChoices, s.minutes, Strings.minutes, (v) => game.settings((x) => x.copyWith(minutes: v)), 'minutes'),
          const SizedBox(height: 10),
          const Text(Strings.playTimeNote, style: note),
          if (g.resting(now)) ...[
            const SizedBox(height: 10),
            const Text(Strings.resting, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            FilledButton(
              key: const ValueKey('play-on'),
              onPressed: () {
                game.change((g) => g.playOn());
                ref.read(sessionStartProvider.notifier).restart();
                context.go('/');
              },
              child: const Text(Strings.playOn),
            ),
          ],
        ]),
        section(Strings.progressTitle, [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(width: 90, child: TaiwanView()),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Strings.progress(g.pictures.length, g.insets.length, g.tangrams.length, g.cards.length), style: const TextStyle(fontSize: 16, height: 1.5)),
                const SizedBox(height: 6),
                for (final l in Level.values) Text(Strings.cutNow(l, g.cutsOpen(l).last), style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 6),
                Text(Strings.today(log.seconds ~/ 60, log.done), style: const TextStyle(fontSize: 16)),
              ]),
            ),
          ]),
        ]),
        section(Strings.together, [const Text(Strings.togetherNote, style: TextStyle(fontSize: 15, height: 1.6))]),
        section(Strings.turnTitle, [
          toggle(Strings.tapTurn, s.tapTurn, (v) => game.settings((x) => x.copyWith(tapTurn: v)), key: const ValueKey('tap-turn'), note: Strings.tapTurnNote),
        ]),
        section(Strings.helpTitle, [
          toggle(Strings.faint, s.faint, (v) => game.settings((x) => x.copyWith(faint: v)), key: const ValueKey('faint'), note: Strings.faintNote),
          const SizedBox(height: 6),
          const Text(Strings.magnet, style: TextStyle(fontSize: 17)),
          const SizedBox(height: 6),
          chips(Magnet.values, s.magnet, Strings.magnetLine, (v) => game.settings((x) => x.copyWith(magnet: v)), 'magnet'),
          const SizedBox(height: 6),
          toggle(Strings.hints, s.hints, (v) => game.settings((x) => x.copyWith(hints: v)), key: const ValueKey('hints')),
          toggle(Strings.edgesFirst, s.edgesFirst, (v) => game.settings((x) => x.copyWith(edgesFirst: v)), key: const ValueKey('edges')),
        ]),
        section(Strings.voiceTitle, [
          toggle(Strings.voice, s.voice, (v) => game.settings((x) => x.copyWith(voice: v)), key: const ValueKey('voice')),
          toggle(Strings.talk, s.talk, (v) => game.settings((x) => x.copyWith(talk: v)), key: const ValueKey('talk'), note: Strings.talkNote),
          toggle(Strings.slow, s.slow, (v) => game.settings((x) => x.copyWith(slow: v)), key: const ValueKey('slow')),
          toggle(Strings.music, s.music, (v) => game.settings((x) => x.copyWith(music: v)), key: const ValueKey('music')),
          toggle(Strings.effects, s.sounds, (v) => game.settings((x) => x.copyWith(sounds: v)), key: const ValueKey('effects')),
        ]),
        section(Strings.modesTitle, [
          const Text(Strings.modesNote, style: note),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final m in Mode.values)
              FilterChip(
                key: ValueKey('mode-on-${m.name}'),
                label: Text(m.zh, style: const TextStyle(fontSize: 15)),
                selected: s.modes.contains(m),
                onSelected: (on) => game.settings((x) => x.copyWith(modes: on ? {...x.modes, m} : ({...x.modes}..remove(m)))),
              ),
          ]),
          const SizedBox(height: 12),
          const Text(Strings.boxesTitle, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final b in lib.boxes)
              FilterChip(
                key: ValueKey('box-on-${b.id}'),
                avatar: s.boxOpen(b.id) ? null : const Icon(Icons.lock_rounded, size: 16),
                label: Text(b.zh, style: const TextStyle(fontSize: 15)),
                selected: s.boxes.contains(b.id),
                selectedColor: b.color.withValues(alpha: .35),
                onSelected: (on) => game.settings((x) => x.copyWith(boxes: on ? {...x.boxes, b.id} : ({...x.boxes}..remove(b.id)))),
              ),
          ]),
        ]),
        section(Strings.otherTitle, [
          OutlinedButton.icon(
            key: const ValueKey('change-helper'),
            onPressed: () {
              game.change((g) => g.copyWith(clearHelper: true));
              context.go('/helper');
            },
            icon: const Icon(Icons.pets_rounded),
            label: const Text(Strings.changeHelper),
          ),
        ]),
        section(Strings.fullVersion, [
          const Text(Strings.fullNote, style: note),
          toggle(Strings.fullSwitch, s.full, (v) => game.settings((x) => x.copyWith(full: v)), key: const ValueKey('full')),
        ]),
        section(Strings.about, [
          const Text(Strings.privacy, style: TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 6),
          Text(Strings.version(appVersion), style: note),
        ]),
      ]),
    );
  }
}
