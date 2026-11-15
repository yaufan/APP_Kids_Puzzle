import 'package:flutter_tts/flutter_tts.dart';

/// Reads things out for children who cannot read yet, in Taiwanese Mandarin, a little higher or
/// lower for each helper.
abstract interface class Voice {
  /// Says [zh]; [slow] for a slower voice, [pitch] the helper's.
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15});
  Future<void> stop();
}

class SystemVoice implements Voice {
  FlutterTts? _tts;
  double? _rate, _pitch;

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;
    final tts = _tts = FlutterTts();
    await tts.awaitSpeakCompletion(true);
    await tts.setLanguage('zh-TW');
    return tts;
  }

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) async {
    try {
      final tts = await _engine();
      await tts.stop();
      final rate = slow ? 0.32 : 0.45;
      if (rate != _rate) {
        _rate = rate;
        await tts.setSpeechRate(rate);
      }
      if (pitch != _pitch) {
        _pitch = pitch;
        await tts.setPitch(pitch);
      }
      if (zh.isNotEmpty) await tts.speak(zh);
    } catch (_) {
      // No speech engine (tests, or a phone without one): the pictures and the words on screen
      // are enough.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}

class SilentVoice implements Voice {
  const SilentVoice();

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) async {}

  @override
  Future<void> stop() async {}
}

/// Remembers what was said, at which pitch, and how often it was stopped (tests).
class RecordingVoice implements Voice {
  final said = <String>[];
  final pitches = <double>[];
  var stops = 0;

  @override
  Future<void> say(String zh, {bool slow = false, double pitch = 1.15}) async {
    said.add(zh);
    pitches.add(pitch);
  }

  @override
  Future<void> stop() async => stops++;
}
