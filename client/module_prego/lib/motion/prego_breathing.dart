/// A slow breath for a glyph that says something is live.
library;

import "dart:async";
import "dart:math" as math;

import "package:clock/clock.dart";
import "package:material_ui/material_ui.dart";

import "prego_reduced_motion.dart";

/// One device-clock-aligned opacity shared by every breathing glyph, so a list
/// of them breathes together and costs one timer however many there are.
///
/// Like the AI sparkle's loop, a recursive one-shot timer steps at 40 FPS,
/// plenty for a slow fade, and exists only while at least one glyph follows it.
final class _BreathClock._() extends ChangeNotifier {
  static final instance = _BreathClock._();
  static const _period = Duration(milliseconds: 1600);
  static const _step = Duration(milliseconds: 25);

  /// The opacity at the bottom of a breath.
  static const _faded = 0.35;

  Timer? _timer;
  double _opacity = 1;

  double get opacity => _opacity;

  @override
  void addListener(VoidCallback listener) {
    final needsTimer = !hasListeners;
    super.addListener(listener);
    if (needsTimer) {
      _sampleClock();
      _scheduleNextStep();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _scheduleNextStep() {
    final remainder = clock.now().millisecondsSinceEpoch % _step.inMilliseconds;
    _timer = Timer(Duration(milliseconds: _step.inMilliseconds - remainder), () {
      _timer = null;
      _sampleClock();
      notifyListeners();
      if (hasListeners) _scheduleNextStep();
    });
  }

  void _sampleClock() {
    final now = clock.now().millisecondsSinceEpoch;
    final sampled = now - now % _step.inMilliseconds;
    final phase = (sampled % _period.inMilliseconds) / _period.inMilliseconds;
    // Full at the start of a breath and faded halfway, easing at both ends.
    _opacity = _faded + (1 - _faded) * (1 + math.cos(2 * math.pi * phase)) / 2;
  }
}

/// [child] fading to about a third and back every 1.6 seconds, as a sign that
/// something it stands for is live. Every breathing glyph on screen shares one
/// phase.
///
/// Reduced motion, a route out of sight and a backgrounded app hold [child]
/// at full opacity and stop the clock. The fade only changes the layer's
/// opacity, so [child] never repaints for it.
class const PregoBreathing({super.key, required final Widget child}) extends StatefulWidget {
  @override
  State<PregoBreathing> createState() => _PregoBreathingState();
}

class _PregoBreathingState() extends State<PregoBreathing> with WidgetsBindingObserver, PregoReducedMotionStateMixin {
  final _clock = _BreathClock.instance;
  final _opacity = ValueNotifier<double>(1);
  late final _animation = Animation<double>.fromValueListenable(_opacity);
  bool _following = false;

  bool get _appIsVisible {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed || lifecycle == AppLifecycleState.inactive;
  }

  @override
  bool get motionEnabled => TickerMode.valuesOf(context).enabled && _appIsVisible;

  @override
  void startMotion() {
    if (_following) return;
    _following = true;
    _clock.addListener(_follow);
    _follow();
  }

  @override
  void stopMotion() {
    _stopFollowing();
    _opacity.value = 1;
  }

  void _follow() => _opacity.value = _clock.opacity;

  void _stopFollowing() {
    if (!_following) return;
    _clock.removeListener(_follow);
    _following = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    syncMotion();
  }

  @override
  void dispose() {
    _stopFollowing();
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: _animation, child: widget.child);
}
