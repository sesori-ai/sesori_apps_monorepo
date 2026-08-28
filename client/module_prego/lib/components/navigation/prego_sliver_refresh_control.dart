import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// How much further than the normal trigger a pull must travel to arm the
/// second stage. Far enough that an ordinary refresh never reaches it by
/// accident, close enough to be discoverable once the caption appears.
const double _deepPullFactor = 1.8;
const Duration _captionMotionDuration = Duration(milliseconds: 180);
const Duration _captionReducedMotionDuration = Duration(milliseconds: 200);
const Curve _captionEaseOut = Cubic(0.23, 1, 0.32, 1);

/// A second stage for a pull-to-refresh, opted into with its captions.
///
/// One value rather than a callback plus two loose strings, so a host cannot
/// open the deep pull without telling the user what crossing it will do.
class const PregoDeepRefresh({
  /// Runs **the moment the pull passes the deep threshold** — not on release.
  /// There is no release-gated commit to hang it on, so once the threshold is
  /// crossed the action has started and the host must offer its own way to
  /// cancel. Never awaited, so a long-running second stage cannot hold the
  /// spinner.
  ///
  /// It *replaces* the ordinary refresh rather than adding to it: a gesture
  /// that fires this never dispatches one, because this reaches the same
  /// backend and settles into a refresh of its own.
  required final void Function() onDeepRefresh,

  /// Shown once the pull passes the ordinary trigger, inviting the user to
  /// keep going. It is the only thing this control says: once the threshold is
  /// crossed the control empties itself and the host's own progress surface
  /// takes over reporting.
  required final String pullCaption,
});

/// The pull-to-refresh control every Prego surface uses.
///
/// Wraps [CupertinoSliverRefreshControl] and owns the whole two-stage gesture:
/// the threshold, the captions, and dispatching both callbacks.
///
/// The second stage commits while the finger is still down, because the
/// underlying control offers no release-gated commit to hang it on. The
/// ordinary refresh is the other way round: the underlying control arms its
/// task at the trigger, but this dispatches the host's callback only once the
/// pull is let go, when the gesture has either fired the second stage or never
/// will. A gesture that fired it runs no ordinary refresh at all.
///
/// Hosts differ in where the indicator sits, not in how the pull behaves, so
/// they supply [decorate] and get identical gesture semantics for free — which
/// is why this exists rather than a parameter on one scaffold.
class const PregoSliverRefreshControl({
  super.key,
  required final Future<void> Function() _onRefresh,

  /// The second stage. `null` leaves the control behaving exactly as a bare
  /// [CupertinoSliverRefreshControl].
  required final PregoDeepRefresh? _deepRefresh,

  /// Wraps the built indicator so a host can position it without owning any
  /// gesture logic. `null` paints it where the control puts it.
  required final Widget Function(BuildContext context, Widget indicator)? _decorate,

  /// Reports the space the control currently holds open, for hosts that lay
  /// out against it. Zero whenever the control is inactive.
  required final void Function(double extent)? _onPulledExtentChanged,
}) extends StatefulWidget {
  @override
  State<PregoSliverRefreshControl> createState() => _PregoSliverRefreshControlState();
}

class _PregoSliverRefreshControlState() extends State<PregoSliverRefreshControl> {
  /// The furthest this gesture has pulled, reset between gestures.
  ///
  /// The control reports the pull distance continuously but fires `onRefresh`
  /// once, so the decision has to survive that frame. Tracking the furthest
  /// point rather than the mode is deliberate: this refresh control reports
  /// `RefreshIndicatorMode.done` while the finger is still down and still
  /// pulling, so no mode reliably means "dragging". Backing off after passing
  /// the threshold therefore keeps the second stage armed, which matches what
  /// the caption promised at the moment it was passed.
  double _maxPulledExtent = 0;

  /// Whether this gesture has already run its second stage, so one pull can
  /// only rescan once however far it travels.
  bool _deepFired = false;

  /// Completes once the pending refresh may proceed: when the pull is let go,
  /// or as soon as the second stage fires, whichever comes first. `null`
  /// whenever no refresh is pending.
  Completer<void>? _letGo;

  /// Runs the ordinary refresh, once the gesture has chosen its stage.
  ///
  /// The underlying control arms its task the moment the pull crosses the
  /// ordinary trigger, while the finger is still down and the deeper threshold
  /// is still reachable. Dispatching there means the refresh races the pull:
  /// its read can land before the user commits, so nothing downstream can tell
  /// a plain refresh from the opening half of a scan. Waiting for the release
  /// makes the question answerable — by then the gesture has either fired the
  /// second stage or it never will.
  Future<void> _runRefresh() async {
    // Already fired before this even started. One fast move can cross both
    // thresholds in a single frame, and the control only *schedules* this from
    // its builder, so the release the second stage asked for found nothing to
    // release. Finishing here is what hands the reserve back on that path too.
    if (_deepFired) return;
    final letGo = Completer<void>();
    _letGo = letGo;
    try {
      await letGo.future;
      // The scan supersedes this read: it reaches the same backend, imports
      // through it, and settles into a list refresh of its own. Running one
      // here as well would only queue work behind the scan and hold the pull
      // open for the length of it.
      if (_deepFired) return;
      await widget._onRefresh();
    } finally {
      if (identical(_letGo, letGo)) _letGo = null;
    }
  }

  /// Releases a pending refresh from waiting on the gesture.
  void _markLetGo() {
    if (_letGo case final letGo? when !letGo.isCompleted) letGo.complete();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: _runRefresh,
      builder: (context, refreshState, pulledExtent, triggerDistance, indicatorExtent) {
        widget._onPulledExtentChanged?.call(
          refreshState == RefreshIndicatorMode.inactive ? 0 : pulledExtent,
        );
        final deepRefresh = widget._deepRefresh;
        final deepThreshold = triggerDistance * _deepPullFactor;
        if (refreshState == RefreshIndicatorMode.inactive) {
          _maxPulledExtent = 0;
          _deepFired = false;
        } else if (pulledExtent > _maxPulledExtent) {
          _maxPulledExtent = pulledExtent;
        }
        // Anything past `armed` means the finger is off: the underlying control
        // only leaves `armed` once the extent has fallen back to the height it
        // holds on its own.
        if (refreshState != RefreshIndicatorMode.drag && refreshState != RefreshIndicatorMode.armed) {
          _markLetGo();
        }
        if (deepRefresh != null && !_deepFired && _maxPulledExtent >= deepThreshold) {
          _deepFired = true;
          // Finish the pending refresh now rather than on release. The
          // underlying control reserves an indicator's height from the moment
          // it arms its task, and only gives it back once that task is done —
          // so waiting for the release leaves the list sitting one indicator
          // below the top, then dropping. Finishing here means the reserve is
          // already gone by the time the finger lifts, and the list springs
          // straight to the top. There is nothing left to wait for anyway: a
          // fired pull runs no ordinary refresh.
          _markLetGo();
          // After this frame, because the refresh control calls its builder
          // from inside the sliver's layout and the callback is user code.
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => deepRefresh.onDeepRefresh(),
            debugLabel: "PregoSliverRefreshControl.deepRefresh",
          );
        }

        // Once the second stage has fired the control has nothing left to say:
        // the host's own progress surface is already on screen reporting the
        // run, so a spinner and a caption beside it would report the same thing
        // twice. Emptying it also stops the pulled area from reading as
        // something still waiting to happen.
        if (_deepFired) {
          return widget._decorate?.call(context, const SizedBox.shrink()) ?? const SizedBox.shrink();
        }

        final indicator = CupertinoSliverRefreshControl.buildRefreshIndicator(
          context,
          refreshState,
          pulledExtent,
          triggerDistance,
          indicatorExtent,
        );
        // The caption follows the *live* extent, because the extent is what
        // decides whether there is room. Once the finger lifts the control
        // collapses to a held indicator extent far shorter than the trigger,
        // and a caption pinned inside it would sit on top of the spinner.
        final invite = deepRefresh != null && pulledExtent > triggerDistance;
        final content = _CaptionedIndicator(
          indicator: indicator,
          caption: invite ? deepRefresh.pullCaption : null,
        );
        return widget._decorate?.call(context, content) ?? content;
      },
    );
  }
}

/// The stock indicator with the stage-two invitation beneath it.
///
/// Both sit inside the extent the refresh control already reserved, so the
/// caption never paints over the first row of the list below. The control
/// constrains this builder to the whole pulled extent, which is at least the
/// trigger distance whenever a caption is shown, so there is always room.
class const _CaptionedIndicator({
  required final Widget indicator,
  required final String? _caption,
}) extends StatefulWidget {
  @override
  State<_CaptionedIndicator> createState() => _CaptionedIndicatorState();
}

class _CaptionedIndicatorState()
    extends State<_CaptionedIndicator>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _visibility = AnimationController(
    vsync: this,
    duration: _captionMotionDuration,
    value: widget._caption == null ? 0 : 1,
    // Android's system setting otherwise compresses the controller duration.
    // Reduced motion deliberately retains a gentle opacity transition here.
    animationBehavior: AnimationBehavior.preserve,
  );
  late String? _shownCaption = widget._caption;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReducedMotionPreference();
  }

  @override
  void didUpdateWidget(_CaptionedIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final caption = widget._caption;
    if (caption != null) _shownCaption = caption;
    if (oldWidget._caption == null && caption != null) {
      _animateVisibilityTo(1);
    } else if (oldWidget._caption != null && caption == null) {
      _animateVisibilityTo(0);
    }
  }

  void _syncReducedMotionPreference() {
    final reducedMotion = prefersReducedMotion(context);
    if (reducedMotion == _reducedMotion) return;
    _reducedMotion = reducedMotion;
    if (_visibility.isAnimating) {
      _animateVisibilityTo(widget._caption == null ? 0 : 1);
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    if (!mounted) return;
    setState(_syncReducedMotionPreference);
  }

  void _animateVisibilityTo(double target) {
    final distance = (target - _visibility.value).abs();
    if (distance == 0) return;
    final fullDuration = _reducedMotion ? _captionReducedMotionDuration : _captionMotionDuration;
    _visibility
        .animateTo(
          target,
          // Keep reversal responsive near the threshold: travelling half the
          // remaining opacity range takes half the full transition time.
          duration: fullDuration * distance,
          curve: _captionEaseOut,
        )
        .whenCompleteOrCancel(() {
          if (!mounted || target != 0 || widget._caption != null || _visibility.value != 0) {
            return;
          }
          setState(() => _shownCaption = null);
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final caption = _shownCaption;
    return Stack(
      alignment: Alignment.center,
      children: [
        widget.indicator,
        if (caption != null)
          Positioned(
            bottom: prego.spacing.md,
            // The controller retargets from its current value when the pull
            // reverses across the trigger. Reduced motion retains this fade but
            // removes the scale, preserving feedback without spatial movement.
            child: ExcludeSemantics(
              key: const ValueKey("prego-deep-refresh-caption-semantics"),
              excluding: widget._caption == null,
              child: AnimatedBuilder(
                animation: _visibility,
                builder: (context, child) {
                  final visibility = _visibility.value;
                  return Opacity(
                    key: const ValueKey("prego-deep-refresh-caption-opacity"),
                    opacity: visibility,
                    child: Transform.scale(
                      key: const ValueKey("prego-deep-refresh-caption-scale"),
                      scale: _reducedMotion ? 1 : 0.94 + 0.06 * visibility,
                      alignment: Alignment.bottomCenter,
                      child: child,
                    ),
                  );
                },
                child: _CaptionLabel(caption: caption),
              ),
            ),
          ),
      ],
    );
  }
}

/// The quiet, text-only invitation to keep pulling.
class const _CaptionLabel({required final String caption}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    // Flexible so the ellipsis can actually engage: a Row measures a plain
    // Text against the space it asks for, so at large accessibility text
    // scales an unconstrained label overflows instead of truncating.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
          ),
        ),
      ],
    );
  }
}
