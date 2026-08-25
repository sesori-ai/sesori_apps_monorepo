import "dart:async";

import "package:cupertino_ui/cupertino_ui.dart" show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// How much further than the normal trigger a pull must travel to arm the
/// second stage. Far enough that an ordinary refresh never reaches it by
/// accident, close enough to be discoverable once the caption appears.
const double _deepPullFactor = 1.8;

/// A second stage for a pull-to-refresh, opted into with its captions.
///
/// One value rather than a callback plus two loose strings, so a host cannot
/// open the deep pull without telling the user what crossing it will do.
class const PregoDeepRefresh({
  /// Runs in addition to the ordinary refresh, **the moment the pull passes
  /// the deep threshold** — not on release. There is no release-gated commit to
  /// hang it on, so once the threshold is crossed the action has started and the
  /// host must offer its own way to cancel. Never awaited: the refresh control
  /// settles on the ordinary refresh alone, so a long-running second stage
  /// cannot hold the spinner.
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
/// Both stages commit while the finger is still down, because the underlying
/// control invokes `onRefresh` the moment the pull crosses its trigger rather
/// than on release (`refresh.dart` transitions `drag` straight to `armed` and
/// schedules the task there). The second stage follows the same rule at its own
/// deeper threshold, so a pull refreshes at one depth and additionally runs the
/// host's second action at another.
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

  /// Releases the control from the ordinary refresh when the second stage
  /// fires. `null` whenever no refresh is running.
  Completer<void>? _released;

  /// Runs the ordinary refresh, but stops waiting for it the moment the second
  /// stage fires.
  ///
  /// The control keeps the pull open for exactly as long as this future runs,
  /// so returning early is what retracts the list.
  Future<void> _runRefresh() async {
    final refresh = widget._onRefresh();
    // The refresh outlives this wait whenever the second stage releases it, so
    // nothing downstream is left to observe its failure. Reported rather than
    // discarded: this package has no logger of its own, and the framework's
    // own channel reaches whatever the app installed.
    final reported = refresh.catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: "theme_prego",
          context: ErrorDescription("running a pull-to-refresh"),
        ),
      );
    });
    // Already fired before this even started: one fast move can cross both
    // thresholds in a single frame, and the control only *schedules* the
    // refresh from its builder, so the release below found nothing to release.
    if (_deepFired) return;
    final released = Completer<void>();
    _released = released;
    try {
      await Future.any([reported, released.future]);
    } finally {
      if (identical(_released, released)) _released = null;
    }
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
        if (deepRefresh != null && !_deepFired && _maxPulledExtent >= deepThreshold) {
          _deepFired = true;
          // Stop holding the pull open. The ordinary refresh keeps running, but
          // it reaches the same backend the second stage just put to work, so
          // waiting for it can hold the list open for as long as the whole
          // scan — with nothing in the held space, since the host's own
          // progress surface is what reports the run from here.
          if (_released case final released? when !released.isCompleted) released.complete();
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
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final caption = _caption;
    return Stack(
      alignment: Alignment.center,
      children: [
        indicator,
        Positioned(
          bottom: prego.spacing.md,
          // Faded in and out against an empty box rather than switched between
          // captions, so the invitation arrives as the pull reaches the trigger
          // instead of appearing fully formed. Backing off below the trigger
          // fades it away again.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: caption == null
                ? const SizedBox.shrink()
                : _CaptionLabel(key: const ValueKey("invite"), caption: caption),
          ),
        ),
      ],
    );
  }
}

/// The quiet, text-only invitation to keep pulling.
class const _CaptionLabel({
  super.key,
  required final String caption,
}) extends StatelessWidget {
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
