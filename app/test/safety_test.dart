import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_workshop/app/strings.dart';
import 'package:puzzle_workshop/core/content.dart';
import 'package:puzzle_workshop/core/game.dart';
import 'package:puzzle_workshop/features/common/play_page.dart';
import 'package:puzzle_workshop/features/parent/parent_gate.dart';

import 'helpers.dart';

/// Privacy, the parent gate and the free version (docs/design.md: no network, nothing leaves the
/// phone, parent mode only through the gate).
void main() {
  test('the app asks for no permissions and takes no links from other apps; the name is the same everywhere', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, isNot(contains('uses-permission')), reason: 'no internet, camera, microphone, location…');
    expect(manifest, contains('android:name="flutter_deeplinking_enabled" android:value="false"'));
    expect(manifest, contains('android:label="${Strings.appName}"'));
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'));
    expect(plist, contains('<string>${Strings.appName}</string>'));
    expect(plist, isNot(contains('UsageDescription')), reason: 'no camera, microphone… prompts');
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('source: system')));
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.yaufan.puzzleworkshop"'));
    expect(gradle, contains('System.getenv("PUZZLE_WORKSHOP_KEYSTORE")'));
    expect(gradle, contains('keyAlias = "kidspaint"'));
    for (final dep in ['http', 'dio', 'firebase', 'url_launcher', 'camera', 'image_picker', 'geolocator', 'webview']) {
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('\n  $dep')), reason: dep);
    }
  });

  testWidgets('parent mode and unknown pages cannot be opened without the gate', (tester) async {
    final app = await TestApp.start(tester);
    app.go('/parent');
    await app.settle();
    expect(app.location, '/', reason: 'no pass from the gate');
    ParentPass.grant();
    app.go('/parent');
    await app.settle();
    expect(app.location, '/parent', reason: 'right after the gate');
    app.go('/');
    await app.settle();
    app.go('/parent');
    await app.settle();
    expect(app.location, '/', reason: 'the pass is used up');
    app.go('/jigsaw/play?pic=unicorn&cut=t24');
    await app.settle(900);
    expect(app.location, '/jigsaw');
    app.go('/jigsaw/play?pic=bear&cut=t24');
    await app.settle(900);
    expect(app.location, '/jigsaw/box', reason: '24 pieces are not open for 小小');
    app.go('/tangram/play?id=nothing');
    await app.settle(900);
    expect(app.location, '/tangram');
    await app.end();
  });

  testWidgets('the lock has to be held; the gate asks a sum in characters and waits after three misses', (tester) async {
    final app = await TestApp.start(tester);
    await app.tapLabel(Strings.parent, ms: 600);
    expect(find.textContaining('加'), findsNothing, reason: 'a tap is not enough');
    await hold(app, find.bySemanticsLabel(Strings.parent), 1100);
    await app.settle(600);
    expect(find.textContaining('加'), findsOneWidget);
    // 0 is never the answer (nor 00): three wrong answers whatever the question.
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byKey(const ValueKey('gate-key-0')));
      await app.settle(100);
    }
    expect(find.textContaining('請等'), findsOneWidget);
    expect(app.location, '/');
    await app.end();
  });

  testWidgets('only a finger held still on the lock opens the gate: not a long press elsewhere, not a slide', (tester) async {
    final app = await TestApp.start(tester);
    await hold(app, find.bySemanticsLabel('小幫手'), 1500);
    await hold(app, find.byType(TaiwanView), 1500);
    await app.settle(600);
    expect(find.textContaining('加'), findsNothing, reason: 'a long press elsewhere');
    final g = await tester.startGesture(tester.getCenter(find.bySemanticsLabel(Strings.parent)));
    await tester.pump(const Duration(milliseconds: 300));
    await g.moveBy(const Offset(0, 60));
    for (var t = 0; t < 1200; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await app.settle(600);
    expect(find.textContaining('加'), findsNothing, reason: 'a finger sliding off the lock (scrolling the workshop)');
    expect(app.location, '/');
    await app.end();
  });

  testWidgets('without a helper the child picks one first', (tester) async {
    final app = await TestApp.start(tester, game: const Game());
    expect(app.location, '/helper');
    app.go('/jigsaw');
    await app.settle();
    expect(app.location, '/helper');
    await app.end();
  });

  testWidgets('the free version: locked boxes say so, 照著拼 and the full-version pictures stay closed', (tester) async {
    final app = await TestApp.start(tester, game: const Game(helper: Helper.bear, settings: Settings(full: false, level: Level.middle)));
    app.go('/blocks');
    await app.settle();
    expect(app.location, '/');
    await app.tapLabel('照著拼');
    expect(app.location, '/');
    expect(app.voice.said.last, Strings.fullOnly('照著拼'));
    app.go('/jigsaw/box?id=night');
    await app.settle();
    expect(app.location, '/jigsaw');
    await app.tapLabel('夜市盒');
    expect(app.voice.said.last, Strings.fullOnly('夜市盒'));
    app.go('/tangram/play?id=cat');
    await app.settle();
    expect(app.location, '/tangram');
    expect(find.bySemanticsLabel('房子'), findsWidgets, reason: '小小\'s set is free');
    await app.tapLabel('房子', ms: 800);
    expect(app.location, '/tangram/play');
    await app.end();
  });

  testWidgets('the rest ends after an hour; a clock moved back neither ends it early nor locks the app', (tester) async {
    final app = await TestApp.start(tester);
    app.change((g) => g.rest(app.now));
    await app.settle(2600);
    expect(app.location, '/rest');
    app.now = app.now.subtract(const Duration(hours: 3));
    await app.settle(2600);
    expect(app.location, '/rest', reason: 'the clock went back: the rest goes on, no extra play');
    app.now = app.now.add(const Duration(minutes: 61));
    await app.settle(2600);
    expect(app.location, '/', reason: 'it ends an hour after it began, not three hours later');
    expect(app.game.restSince, isNull);
    await app.end();
  });
}
