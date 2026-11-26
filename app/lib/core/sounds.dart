import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// The music (design/sounds/make_sounds.py): a xylophone-and-ukulele tune for the workshop, one
/// for each jigsaw box (the night market busier, the temple fair with a little drum, the city
/// brisk), one each for the shape box, the tangram and the pattern blocks, and a lullaby for the
/// rest. While a puzzle is being put together the music is quieter, so the 「咔」 is heard.
enum Music {
  workshop('music_workshop'),
  shapes('music_shapes', quiet: true),
  fruit('music_fruit', quiet: true),
  animals('music_animals', quiet: true),
  night('music_night', quiet: true),
  ride('music_ride', quiet: true),
  temple('music_temple', quiet: true),
  city('music_city', quiet: true),
  tangram('music_tangram', quiet: true),
  blocks('music_blocks', quiet: true),
  rest('music_rest');

  const Music(this.file, {this.quiet = false});

  final String file;
  final bool quiet;

  /// A jigsaw box's music.
  static Music ofBox(String music) => Music.values.firstWhere((m) => m.name == music, orElse: () => Music.workshop);
}

/// Short sounds are named by their file in assets/sounds/ (design/sounds/README.md lists them).
abstract interface class Sounds {
  set music(bool on);
  set effects(bool on);

  void play(String sfx);

  /// [owner] (a screen) wants [music]; the one asked for last plays.
  void hold(Object owner, Music? music);

  void release(Object owner);
}

class MusicHolders {
  final _holders = <Object, Music?>{};

  void hold(Object owner, Music? music) {
    _holders.remove(owner);
    _holders[owner] = music;
  }

  void release(Object owner) => _holders.remove(owner);

  Music? get current => _holders.isEmpty ? null : _holders.values.last;
}

class SilentSounds implements Sounds {
  const SilentSounds();

  @override
  set music(bool on) {}

  @override
  set effects(bool on) {}

  @override
  void play(String sfx) {}

  @override
  void hold(Object owner, Music? music) {}

  @override
  void release(Object owner) {}
}

/// Remembers the sounds played, and whether music and effects are on (tests).
class RecordingSounds implements Sounds {
  final played = <String>[];
  final _holders = MusicHolders();
  var musicOn = true, effectsOn = true;

  Music? get music => _holders.current;

  @override
  set music(bool on) => musicOn = on;

  @override
  set effects(bool on) => effectsOn = on;

  @override
  void play(String sfx) => played.add(sfx);

  @override
  void hold(Object owner, Music? music) => _holders.hold(owner, music);

  @override
  void release(Object owner) => _holders.release(owner);
}

/// How every sound plays: on Android the media stream (the media volume,
/// heard with the phone on vibrate or silent like the voice), never taking
/// the audio focus, so sounds never stop one another or the voice; on
/// iPhone a mixing 「ambient」 session as before.
final soundContext = AudioContext(
  android: const AudioContextAndroid(
    usageType: AndroidUsageType.media,
    contentType: AndroidContentType.music,
    audioFocus: AndroidAudioFocus.none,
  ),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);

/// The player the music loops on (a slow stand-in in the tests).
abstract interface class MusicLoop {
  Future<void> stop();
  Future<void> play(String file, double volume);
}

/// Plays through audioplayers: a pool per sound, one looping player for the
/// music; quiet while the app is in the background.
class SystemSounds implements Sounds {
  SystemSounds({MusicLoop? loop}) {
    _loop = loop ?? _PlayerLoop(_ready);
    _lifecycle = AppLifecycleListener(onHide: () => _setAway(true), onShow: () => _setAway(false));
  }

  static const _sfxVolume = 0.85, _musicVolume = 0.35, _quietVolume = 0.2;

  late final AppLifecycleListener _lifecycle;
  late final MusicLoop _loop;
  final _pools = <String, Future<AudioPool>>{};
  final _holders = MusicHolders();
  Future<void>? _setUp;

  /// The music wanted now, and the music the loop was last started with.
  Music? _playing, _sounding;

  /// Switches of the music, one after the other: a stop asked for while a
  /// start is still loading waits for it, so the wrong tune never plays and
  /// the music never starts after it was stopped (menus tapped through quickly,
  /// the app hidden).
  Future<void> _switching = Future.value();
  var _music = true, _effects = true, _away = false;

  @override
  set music(bool on) {
    _music = on;
    _update();
  }

  @override
  set effects(bool on) => _effects = on;

  void _setAway(bool away) {
    _away = away;
    _update();
  }

  Future<void> _ready() => _setUp ??= AudioPlayer.global.setAudioContext(soundContext);

  @override
  void play(String sfx) {
    if (!_effects || _away || sfx.isEmpty) return;
    unawaited(_play(sfx));
  }

  Future<void> _play(String sfx) async {
    try {
      await _ready();
      final pool = await (_pools[sfx] ??= AudioPool.create(source: AssetSource('sounds/$sfx.wav'), maxPlayers: 4, audioContext: soundContext));
      await pool.start(volume: _sfxVolume);
    } catch (_) {
      _pools.remove(sfx);
    }
  }

  @override
  void hold(Object owner, Music? music) {
    _holders.hold(owner, music);
    _update();
  }

  @override
  void release(Object owner) {
    _holders.release(owner);
    _update();
  }

  void _update() {
    final wanted = !_music || _away ? null : _holders.current;
    if (wanted == _playing) return;
    _playing = wanted;
    _switching = _switching.then((_) => _apply());
  }

  /// Makes the loop play what is wanted now (a later wish queues another).
  Future<void> _apply() async {
    final music = _playing;
    if (music == _sounding) return;
    try {
      await _loop.stop();
      _sounding = null;
      if (music == null) return;
      await _loop.play(music.file, music.quiet ? _quietVolume : _musicVolume);
      _sounding = music;
    } catch (_) {
      _sounding = null;
    }
  }

  void dispose() {
    _lifecycle.dispose();
    final loop = _loop;
    if (loop is _PlayerLoop) loop.dispose();
  }
}

class _PlayerLoop implements MusicLoop {
  _PlayerLoop(this._ready);

  final Future<void> Function() _ready;
  AudioPlayer? _player;

  Future<AudioPlayer> _get() async {
    await _ready();
    var p = _player;
    if (p == null) {
      p = _player = AudioPlayer();
      await p.setAudioContext(soundContext);
      await p.setReleaseMode(ReleaseMode.loop);
    }
    return p;
  }

  @override
  Future<void> stop() async => (await _get()).stop();

  @override
  Future<void> play(String file, double volume) async {
    final p = await _get();
    await p.setVolume(volume);
    await p.play(AssetSource('sounds/$file.wav'));
  }

  void dispose() => unawaited(_player?.dispose());
}
