import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/core/content.dart';

import 'helpers.dart';

/// Every picture and sound the program asks for exists (docs/art.md), and no picture uses what
/// flutter_svg cannot draw.
void main() {
  bool has(String path) => File('assets/art/$path.svg').existsSync();

  test('every picture the screens ask for is drawn', () {
    final wanted = [
      for (final p in lib.pictures) ...['pictures/${p.id}', 'backs/${p.id}', 'actors/${p.actor}'],
      for (final b in lib.insets)
        for (final i in b.items) ...['inset/${i.actor}', 'inset/${i.actor}_hole'],
      for (final h in Helper.values)
        for (final pose in ['idle', 'cheer', 'sleep']) 'helpers/${h.name}_$pose',
      for (final m in Mode.values) 'ui/mode_${m.name}',
      for (final n in ['floor', 'window', 'star', 'cushion']) 'ui/$n',
    ];
    expect([for (final p in wanted) if (!has(p)) p], isEmpty, reason: 'draw these in design/art/');
  });

  test('no picture is left over', () {
    final actors = Directory('assets/art/actors').listSync().map((f) => f.uri.pathSegments.last.replaceAll('.svg', '')).toSet();
    expect(actors, {for (final p in lib.pictures) p.actor, for (final b in lib.insets) for (final i in b.items) i.actor});
    expect(Directory('assets/art/pictures').listSync().length, 48);
  });

  test('no picture uses what flutter_svg cannot draw, and none is too big', () {
    final bad = <String>[];
    var n = 0;
    for (final f in Directory('assets/art').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.svg')) continue;
      n++;
      final text = f.readAsStringSync();
      if (f.lengthSync() > 90 * 1024) bad.add('${f.path} too big');
      for (final no in ['<filter', '<mask', '<style', 'style=', '<text', '<image', '<pattern', 'mix-blend']) {
        if (text.contains(no)) bad.add('${f.path} uses $no');
      }
      for (final m in RegExp(r'clip-path="url\(#([^)]+)\)"').allMatches(text)) {
        if (!text.contains('<clipPath id="${m.group(1)}"')) bad.add('${f.path}: clip ${m.group(1)} missing');
      }
      if (!text.trimRight().endsWith('</svg>')) bad.add('${f.path} is cut off');
    }
    expect(n, greaterThan(230));
    expect(bad, isEmpty);
  });

  test('every sound the app plays is there', () {
    final names = {
      'tap', 'pick', 'near', 'snap', 'back', 'turn', 'flip', 'drop', 'pop', 'done', 'star', 'open', 'night', 'sparkle',
      for (final p in lib.pictures) p.sound,
      for (final h in Helper.values) h.sound,
      for (final m in ['workshop', 'shapes', 'fruit', 'animals', 'night', 'ride', 'temple', 'city', 'tangram', 'blocks', 'rest']) 'music_$m',
    };
    expect([for (final s in names) if (!File('assets/sounds/$s.wav').existsSync()) s], isEmpty);
    final played = RegExp(r"""(?:sfx\(ref, |_sfx\(|placeSound: )'([a-z_]+)'""");
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      for (final m in played.allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used, isNotEmpty);
    expect(used.difference(names), isEmpty, reason: 'a sound the code plays that is not made');
    final files = Directory('assets/sounds').listSync().map((f) => f.uri.pathSegments.last.replaceAll('.wav', '')).toSet();
    expect(files.difference(names), isEmpty, reason: 'a sound nobody plays');
  });

  test('the font is there', () {
    expect(File('assets/fonts/jf-openhuninn-2.1.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-jf-openhuninn.txt').existsSync(), isTrue);
  });
}
