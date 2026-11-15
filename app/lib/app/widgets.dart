import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/content.dart';
import '../core/providers.dart';
import '../core/sounds.dart';
import '../core/voice.dart';
import 'strings.dart';
import 'theme.dart';

/// A drawing from assets/art/ (nothing at all if it is missing).
class Art extends StatelessWidget {
  const Art(this.path, {super.key, this.fit = BoxFit.contain, this.alignment = Alignment.center});

  /// Under assets/art/, without ".svg" (train/wheel).
  final String path;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/art/$path.svg', fit: fit, alignment: alignment, excludeFromSemantics: true, errorBuilder: (_, _, _) => const SizedBox.expand());
}

/// The screen that spoke last (its WidgetRef), so a screen going away
/// hushes only its own line, never the next screen's first one.
Object? _speaker;

/// Says [text] out loud (if the parent left the voice on), in the helper's voice, slower if the
/// parent asked. Completes when the line has been said (or cut off by the next one).
Future<void> speak(WidgetRef ref, String text) {
  final g = ref.read(gameProvider);
  if (!g.settings.voice || text.isEmpty) return Future.value();
  _speaker = ref;
  return ref.read(voiceProvider).say(text, slow: g.settings.slow, pitch: (g.helper ?? Helper.pangolin).pitch);
}

/// A screen that stops its own voice when the child leaves it (home, the
/// rest), so a question does not go on over the next screen.
mixin HushOnLeave<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  late final Voice _hush;
  late final Object _me;

  @override
  void initState() {
    super.initState();
    _hush = ref.read(voiceProvider);
    _me = ref;
  }

  @override
  void dispose() {
    if (identical(_speaker, _me)) {
      _speaker = null;
      _hush.stop();
    }
    super.dispose();
  }
}

/// Runs [then] after [min], and not before the line [after] has been said
/// (at most [atMost] of waiting for it), so a slow voice is not cut off by
/// the next line; [cancel] stops it.
class Later {
  Later(Duration min, VoidCallback then, {Future<void>? after, Duration atMost = const Duration(seconds: 10)}) : _then = then {
    _timer = Timer(min, () {
      _timeUp = true;
      _fire();
    });
    if (after == null) {
      _heard = true;
    } else {
      after.timeout(atMost).then((_) => _hear(), onError: (_) => _hear());
    }
  }

  final VoidCallback _then;
  late final Timer _timer;
  var _timeUp = false, _heard = false, _over = false;

  void _hear() {
    _heard = true;
    _fire();
  }

  void _fire() {
    if (_over || !_timeUp || !_heard) return;
    _over = true;
    _then();
  }

  void cancel() {
    _over = true;
    _timer.cancel();
  }
}

void sfx(WidgetRef ref, String name) => ref.read(soundsProvider).play(name);

/// A finger that slides further than this is scrolling a list, not tapping.
const tapSlop = 24.0;

/// Shrinks a little while pressed and fires when the finger lifts on it
/// (raw pointer events: a touch counts at once, no gesture to wait for). A
/// finger that slid along (scrolling the list it is in) is not a tap.
class Pressable extends ConsumerStatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.sound = 'tap'});

  final Widget child;
  final VoidCallback? onTap;
  final String? sound;

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  int? _pointer;
  Offset _from = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: enabled && _pointer == null
          ? (e) => setState(() {
                _pointer = e.pointer;
                _from = e.position;
              })
          : null,
      onPointerMove: (e) {
        if (e.pointer == _pointer && (e.position - _from).distance > tapSlop) setState(() => _pointer = null);
      },
      onPointerCancel: (e) {
        if (e.pointer == _pointer) setState(() => _pointer = null);
      },
      onPointerUp: (e) {
        if (e.pointer != _pointer) return;
        setState(() => _pointer = null);
        final box = context.findRenderObject() as RenderBox?;
        if (!enabled || box == null || !(Offset.zero & box.size).inflate(12).contains(e.localPosition)) return;
        final s = widget.sound;
        if (s != null) ref.read(soundsProvider).play(s);
        widget.onTap!();
      },
      child: AnimatedScale(scale: _pointer != null ? 0.93 : 1, duration: const Duration(milliseconds: 90), child: widget.child),
    );
  }
}

/// A painted wooden button or card: lit from the top, a darker edge, its thickness below.
BoxDecoration woodBox(Color color, {double radius = 22, bool shadow = true, Color? ring, double rim = 2}) => BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, .2)!, color, Color.lerp(color, Wood.deep, .08)!],
        stops: const [0, .5, 1],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ring ?? (color == Colors.white || color == Wood.paper ? Wood.line : Wood.edge(color)), width: ring == null ? rim : 4),
      boxShadow: shadow ? [BoxShadow(color: Color.lerp(color, Wood.deep, .55)!, offset: const Offset(0, 4)), BoxShadow(color: Wood.ink.withValues(alpha: .12), offset: const Offset(2, 7), blurRadius: 4)] : null,
    );

/// A round button with an icon.
class RoundButton extends StatelessWidget {
  const RoundButton({super.key, required this.label, required this.icon, this.onTap, this.size = 50, this.color = Colors.white, this.sound = 'tap'});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final String? sound;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          sound: sound,
          child: Container(
            width: size,
            height: size,
            decoration: woodBox(color, radius: size / 2),
            child: Icon(icon, size: size * 0.54, color: color == Colors.white ? Wood.ink : Colors.white),
          ),
        ),
      );
}

/// A wide glossy pill with a word.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, this.onTap, this.color = Wood.green, this.icon, this.height = 58, this.sound = 'tap', this.expand = false});

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final double height;
  final String? sound;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final light = color.computeLuminance() > .6;
    final fg = light ? Wood.ink : Colors.white;
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        sound: sound,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height * 0.4),
          decoration: woodBox(color, radius: height / 2),
          child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: height * 0.46, color: fg), const SizedBox(width: 8)],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: height * 0.36, fontWeight: FontWeight.w700, color: fg, shadows: light ? null : [Shadow(color: Wood.ink.withValues(alpha: .35), offset: const Offset(0, 1.5))])),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A speech bubble (tap to hear it again).
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.text, this.onTap, this.size = 18, this.speaker = false, this.tail = true});

  final String text;
  final VoidCallback? onTap;
  final double size;
  final bool speaker;
  final bool tail;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: onTap != null,
        label: text,
        excludeSemantics: true,
        onTap: onTap,
        child: Pressable(
          onTap: onTap,
          sound: null,
          child: Container(
            padding: EdgeInsets.fromLTRB(speaker ? 8 : 16, 9, 16, 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Wood.line, width: 2),
              boxShadow: [BoxShadow(color: Wood.ink.withValues(alpha: .12), offset: const Offset(2, 3))],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (speaker) ...[
                Container(
                  width: size * 1.8,
                  height: size * 1.8,
                  decoration: woodBox(Wood.orange, radius: size, shadow: false, rim: 1.5),
                  child: Icon(Icons.volume_up_rounded, color: Colors.white, size: size * 1.05),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(child: Text(text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: Wood.ink, height: 1.35))),
            ]),
          ),
        ),
      );
}

/// Plays [music] while this is on screen.
class WithMusic extends ConsumerStatefulWidget {
  const WithMusic({super.key, required this.music, required this.child});

  final Music music;
  final Widget child;

  @override
  ConsumerState<WithMusic> createState() => _WithMusicState();
}

class _WithMusicState extends ConsumerState<WithMusic> {
  late final Sounds _sounds = ref.read(soundsProvider);

  @override
  void initState() {
    super.initState();
    _sounds.hold(this, widget.music);
  }

  @override
  void dispose() {
    _sounds.release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shakes its child side to side once each time [trigger] changes.
class Wiggle extends StatefulWidget {
  const Wiggle({super.key, required this.trigger, required this.child, this.amount = 0.1});

  final int trigger;
  final Widget child;
  final double amount;

  @override
  State<Wiggle> createState() => _WiggleState();
}

class _WiggleState extends State<Wiggle> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void didUpdateWidget(Wiggle old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          return Transform.rotate(angle: math.sin(t * math.pi * 4) * (1 - t) * widget.amount, child: child);
        },
        child: widget.child,
      );
}

/// Jumps up once each time [trigger] changes.
class Hop extends StatefulWidget {
  const Hop({super.key, required this.trigger, required this.child, this.height = 24});

  final int trigger;
  final Widget child;
  final double height;

  @override
  State<Hop> createState() => _HopState();
}

class _HopState extends State<Hop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(Hop old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = _c.value;
          final up = math.sin(t * math.pi) * widget.height;
          final squash = 1 + .06 * math.sin(t * math.pi * 2);
          return Transform.translate(offset: Offset(0, -up), child: Transform.scale(scaleX: squash, scaleY: 2 - squash, child: child));
        },
        child: widget.child,
      );
}

/// A gentle bob up and down.
class Bob extends StatefulWidget {
  const Bob({super.key, required this.child, this.phase = 0, this.amount = 4, this.period = 2400});

  final Widget child;
  final double phase;
  final double amount;
  final int period;

  @override
  State<Bob> createState() => _BobState();
}

class _BobState extends State<Bob> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: Duration(milliseconds: widget.period))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.translate(offset: Offset(0, math.sin((_c.value + widget.phase) * 2 * math.pi) * widget.amount), child: child),
        child: widget.child,
      );
}

/// Little bits of paper flying up when something went right.
class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.trigger});

  final int trigger;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didUpdateWidget(Confetti old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => _c.isAnimating ? CustomPaint(painter: _ConfettiPainter(_c.value, widget.trigger), size: Size.infinite) : const SizedBox.expand(),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.seed);

  final double t;
  final int seed;

  static const colors = [Wood.red, Wood.yellow, Wood.blue, Wood.green, Wood.pink, Wood.purple, Wood.orange];

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(seed);
    for (var i = 0; i < 36; i++) {
      final x0 = size.width * (.2 + .6 * r.nextDouble());
      final vx = (r.nextDouble() - .5) * size.width * .9;
      final vy = -size.height * (.6 + .5 * r.nextDouble());
      final x = x0 + vx * t;
      final y = size.height * .62 + vy * t + size.height * 1.3 * t * t;
      final p = Paint()..color = colors[i % colors.length].withValues(alpha: (1 - t).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 8 + i);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -3, 10, 6), const Radius.circular(2)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}


/// The helper the child picked, in a pose: idle, cheer (when something went right) or sleep.
class HelperView extends ConsumerWidget {
  const HelperView({super.key, this.size = 80, this.helper, this.pose = 'idle'});

  final double size;
  final Helper? helper;
  final String pose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = helper ?? ref.watch(gameProvider.select((g) => g.helper)) ?? Helper.pangolin;
    return SizedBox(width: size, height: size, child: Art('helpers/${h.name}_$pose'));
  }
}

/// The helper with something to say beside it (tap either to hear it again). It jumps whenever
/// [cheer] changes.
class HelperSays extends StatelessWidget {
  const HelperSays({super.key, required this.text, this.onTap, this.size = 76, this.cheer = 0});

  final String text;
  final VoidCallback? onTap;
  final double size;
  final int cheer;

  @override
  Widget build(BuildContext context) {
    final helper = Semantics(
      container: true,
      button: onTap != null,
      label: '小幫手',
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(onTap: onTap, sound: null, child: Hop(trigger: cheer, child: Bob(amount: 2.5, child: HelperView(size: size, pose: cheer > 0 ? 'cheer' : 'idle')))),
    );
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
      helper,
      const SizedBox(width: 6),
      Flexible(child: Bubble(text: text, onTap: onTap, size: 17)),
    ]);
  }
}

/// The bar at the top of a screen: home, the title on a wooden sign, a hint button.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.onHome, this.onHint, this.trailing});

  final String title;
  final VoidCallback? onHome;
  final VoidCallback? onHint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Row(children: [
          onHome == null ? const SizedBox(width: 48) : RoundButton(label: Strings.home, icon: Icons.home_rounded, onTap: onHome, size: 48, color: Wood.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: woodBox(Wood.light, radius: 14),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Wood.ink)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? (onHint == null ? const SizedBox(width: 48) : RoundButton(label: Strings.help, icon: Icons.pets_rounded, onTap: onHint, size: 48, color: Wood.orange, sound: null)),
        ]),
      );
}

/// The workshop's warm wall with a wooden floor along the bottom.
class WallBg extends StatelessWidget {
  const WallBg({super.key, required this.child, this.floor = true});

  final Widget child;
  final bool floor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFBF3E7), Wood.wall])),
        child: Stack(fit: StackFit.expand, children: [
          if (floor) const Positioned(left: 0, right: 0, bottom: 0, height: 90, child: Art('ui/floor', fit: BoxFit.fill)),
          child,
        ]),
      );
}

/// The end of a puzzle: what came alive, and three big buttons (again, next, home). No score.
class DoneButtons extends StatelessWidget {
  const DoneButtons({super.key, this.onAgain, this.onNext, this.onHome, this.nextLabel = Strings.next});

  final VoidCallback? onAgain;
  final VoidCallback? onNext;
  final VoidCallback? onHome;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    Widget one(String label, IconData icon, Color color, VoidCallback? tap) => Column(mainAxisSize: MainAxisSize.min, children: [
          RoundButton(label: label, icon: icon, onTap: tap, size: 66, color: color),
          const SizedBox(height: 6),
          ExcludeSemantics(child: Text(label, style: const TextStyle(fontSize: 15, color: Wood.ink, fontWeight: FontWeight.w700))),
        ]);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      if (onAgain != null) one(Strings.playAgain, Icons.replay_rounded, Wood.orange, onAgain),
      if (onNext != null) one(nextLabel, Icons.play_arrow_rounded, Wood.green, onNext),
      if (onHome != null) one(Strings.home, Icons.home_rounded, Wood.blue, onHome),
    ]);
  }
}

/// A little lock on things only the full version has.
class LockBadge extends StatelessWidget {
  const LockBadge({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: woodBox(Colors.white, radius: size / 2, shadow: false, rim: 1.5),
        child: Icon(Icons.lock_rounded, size: size * .6, color: Wood.inkSoft),
      );
}
