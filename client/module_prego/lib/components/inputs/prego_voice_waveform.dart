/// The live voice-recording waveform: amplitude bars marching leftward as the
/// microphone listens.
library;

import "dart:async";

import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

import "../../motion/prego_reduced_motion.dart";
import "../../utils/lerp_utils.dart";

/// A scrolling amplitude waveform for an in-progress voice recording.
///
/// Renders on a fixed grid of slots: slots that already carry a sample from
/// [amplitudeStream] draw as [barColor] bars scaled by their amplitude, the
/// not-yet-recorded remainder to their left draws as [dotColor] resting dots —
/// the Figma `Recording input container` waveform. The newest sample enters at
/// the trailing edge and the history slides left one slot per sample, eased
/// between samples by a repaint ticker so the march is smooth rather than
/// stepped at the sample rate.
///
/// [flattenProgress] drives the drag-to-cancel presentation: at 0 the bars are
/// live, at 1 every bar has settled into a [dotColor] resting dot, matching
/// the `Deleting` state of the design. Values in between interpolate, so the
/// waveform deflates continuously as the finger approaches the cancel target.
///
/// Painted by a single [CustomPainter] behind its own [RepaintBoundary]: at a
/// sample cadence of ~10 Hz plus a per-frame slide, widget-per-bar approaches
/// rebuild the element tree far too often for a composer that must stay at
/// 60fps during recording.
///
/// The waveform is decorative — the composer carries the recording semantics —
/// so it is excluded from semantics.
class const PregoVoiceWaveform({
  super.key,

  /// Normalized microphone amplitude samples in [0, 1], one per
  /// [sampleInterval] while the recorder listens.
  required final Stream<double> amplitudeStream,

  /// Colour of the recorded amplitude bars.
  required final Color barColor,

  /// Colour of the not-yet-recorded resting dots, and of every bar once
  /// [flattenProgress] reaches 1.
  required final Color dotColor,

  /// 0 → live waveform, 1 → fully flattened to resting dots. Null renders
  /// live. Listened to directly by the painter, so scrubbing it (e.g. from a
  /// drag gesture) repaints without rebuilding the widget.
  final ValueListenable<double>? flattenProgress,

  /// Height of the paint band; a full-amplitude bar spans it exactly.
  final double height = 24,

  /// Expected spacing between [amplitudeStream] events, used to ease the
  /// slide between consecutive samples.
  final Duration sampleInterval = const Duration(milliseconds: 100),
}) extends StatefulWidget {
  @override
  State<PregoVoiceWaveform> createState() => _PregoVoiceWaveformState();
}

class _PregoVoiceWaveformState()
    extends State<PregoVoiceWaveform>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, PregoReducedMotionStateMixin {
  /// Only the trailing ~2× a composer width of history can ever be visible;
  /// older samples have scrolled off and are dropped.
  static const int _maxSamples = 256;

  /// Drives the between-sample slide. The value itself is unused — the painter
  /// reads [_sinceLastSample] — the controller only schedules repaints.
  late final AnimationController _slide = AnimationController(vsync: this, duration: const Duration(seconds: 1));

  /// Bumped on every accepted sample so the painter repaints even while the
  /// slide ticker is off (reduced motion).
  final ValueNotifier<int> _sampleTick = ValueNotifier<int>(0);

  final List<double> _samples = <double>[];
  final Stopwatch _clock = Stopwatch()..start();
  Duration _lastSampleAt = Duration.zero;
  StreamSubscription<double>? _subscription;

  @override
  bool get motionEnabled => true;

  @override
  void startMotion() {
    if (!_slide.isAnimating) _slide.repeat();
  }

  @override
  void stopMotion() {
    if (_slide.isAnimating) _slide.stop();
  }

  @override
  void initState() {
    super.initState();
    _subscription = widget.amplitudeStream.listen(_addSample);
  }

  @override
  void didUpdateWidget(PregoVoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudeStream != widget.amplitudeStream) {
      _subscription?.cancel();
      _samples.clear();
      _subscription = widget.amplitudeStream.listen(_addSample);
    }
    syncMotion();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _sampleTick.dispose();
    _slide.dispose();
    super.dispose();
  }

  void _addSample(double amplitude) {
    _samples.add(amplitude.clamp(0.0, 1.0));
    if (_samples.length > _maxSamples) _samples.removeAt(0);
    _lastSampleAt = _clock.elapsed;
    _sampleTick.value++;
  }

  /// Fraction of [PregoVoiceWaveform.sampleInterval] elapsed since the last
  /// sample, clamped to one interval — the eased slide's progress.
  double _sinceLastSample() {
    if (_samples.isEmpty) return 1;
    final elapsed = (_clock.elapsed - _lastSampleAt).inMicroseconds;
    return (elapsed / widget.sampleInterval.inMicroseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      // The slide repaints every frame while recording; the boundary keeps
      // that repaint off the surrounding composer layer.
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: CustomPaint(
            painter: _VoiceWaveformPainter(
              repaint: Listenable.merge([
                _slide,
                _sampleTick,
                ?widget.flattenProgress,
              ]),
              samples: _samples,
              slidePhase: _sinceLastSample,
              // Under reduced motion the ticker is off and bars snap one slot
              // per sample instead of sliding.
              slideEnabled: () => motionAllowed,
              flattenProgress: widget.flattenProgress,
              barColor: widget.barColor,
              dotColor: widget.dotColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the waveform grid: right-aligned recorded bars, resting dots for the
/// unrecorded remainder.
class _VoiceWaveformPainter({
  required super.repaint,

  /// Live view of the recorded history — newest last. Owned and mutated by the
  /// state; the repaint listenable ticks after every change.
  required final List<double> samples,

  /// Progress [0, 1] through the current inter-sample slide.
  required final double Function() slidePhase,

  /// Whether to ease between samples (false snaps, for reduced motion).
  required final bool Function() slideEnabled,
  required final ValueListenable<double>? flattenProgress,
  required final Color barColor,
  required final Color dotColor,
}) extends CustomPainter {
  /// Bar/dot geometry from the Figma waveform: 3px-wide pills on a 6.5px
  /// grid, resting at 6px tall.
  static const double _barWidth = 3;
  static const double _slotPitch = 6.5;
  static const double _restingHeight = 6;

  @override
  void paint(Canvas canvas, Size size) {
    // The newest bar slides in from beyond the trailing edge; without the
    // clip it would paint over whatever sits right of the waveform.
    canvas.clipRect(Offset.zero & size);
    final flatten = (flattenProgress?.value ?? 0).clamp(0.0, 1.0);
    final paintBar = Paint()..color = lerpColorNonNull(barColor, dotColor, flatten);
    final paintDot = Paint()..color = dotColor;

    final slotCount = (size.width / _slotPitch).floor();
    if (slotCount <= 0) return;

    // While a new sample settles in, the whole strip slides the remaining
    // fraction of one slot leftward — a conveyor rather than a 10 Hz step.
    final phase = slideEnabled() ? slidePhase() : 1.0;
    final slideOffset = (1 - phase) * _slotPitch;

    final centerY = size.height / 2;

    // Trailing edge holds the newest sample; earlier slots walk left through
    // the history and past its start into resting dots.
    for (var slot = 0; slot < slotCount + 1; slot++) {
      final sampleIndex = samples.length - 1 - slot;
      final x = size.width - _barWidth - slot * _slotPitch + slideOffset;
      if (x + _barWidth < 0) break;

      final double height;
      final Paint paint;
      if (sampleIndex >= 0) {
        var amplitude = samples[sampleIndex];
        // The newest bar grows in over its slide, so it doesn't pop to full
        // height at the trailing edge.
        if (sampleIndex == samples.length - 1) amplitude *= phase;
        final live = _restingHeight + amplitude * (size.height - _restingHeight);
        height = lerpDoubleNonNull(live, _restingHeight, flatten);
        paint = paintBar;
      } else {
        height = _restingHeight;
        paint = paintDot;
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - height / 2, _barWidth, height),
          const Radius.circular(_barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) {
    // The repaint listenable covers samples, slide, and flatten; a rebuilt
    // painter only truly differs by configuration.
    return oldDelegate.barColor != barColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.samples != samples ||
        oldDelegate.flattenProgress != flattenProgress;
  }
}
