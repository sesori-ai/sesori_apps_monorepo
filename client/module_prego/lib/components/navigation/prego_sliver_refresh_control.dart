import "package:cupertino_ui/cupertino_ui.dart" show CupertinoSliverRefreshControl, RefreshIndicatorMode;
import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// How much further than the normal trigger a pull must travel to arm the
/// second stage. Far enough that an ordinary refresh never reaches it, close
/// enough to be discoverable once the caption appears.
const double _deepPullFactor = 1.6;

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
  /// keep going.
  required final String pullCaption,

  /// Shown once [onDeepRefresh] has fired, so the caption reports what has
  /// already started rather than what releasing would do. It gives way to the
  /// host's own progress surface as the pull retracts.
  required final String deepCaption,
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

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      onRefresh: widget._onRefresh,
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
          // After this frame, because the refresh control calls its builder
          // from inside the sliver's layout and the callback is user code.
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => deepRefresh.onDeepRefresh(),
            debugLabel: "PregoSliverRefreshControl.deepRefresh",
          );
        }

        final indicator = CupertinoSliverRefreshControl.buildRefreshIndicator(
          context,
          refreshState,
          pulledExtent,
          triggerDistance,
          indicatorExtent,
        );
        // Both phases follow the *live* extent, because the extent is what
        // decides whether there is room. Once the finger lifts the control
        // collapses to a held indicator extent far shorter than the trigger,
        // and a caption pinned inside it would sit on top of the spinner.
        // Retracting loses nothing: the host's progress surface takes over as
        // the pull collapses, which is where the rest of the run is reported.
        final caption = deepRefresh == null || pulledExtent <= triggerDistance
            ? null
            : _deepFired
            ? deepRefresh.deepCaption
            : deepRefresh.pullCaption;
        final content = caption == null
            ? indicator
            : _CaptionedIndicator(indicator: indicator, caption: caption, fired: _deepFired);
        return widget._decorate?.call(context, content) ?? content;
      },
    );
  }


}

/// The stock indicator with the stage-two caption beneath it.
///
/// Both sit inside the extent the refresh control already reserved, so the
/// caption never paints over the first row of the list below. The control
/// constrains this builder to the whole pulled extent, which is at least the
/// trigger distance whenever a caption is shown, so there is always room.
class const _CaptionedIndicator({
  required final Widget indicator,
  required final String caption,
  required final bool fired,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Stack(
      alignment: Alignment.center,
      children: [
        indicator,
        Positioned(
          bottom: prego.spacing.md,
          // Cross-faded and keyed on the phase, so passing the threshold reads
          // as one label becoming another rather than a flicker.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: _CaptionLabel(
              // The phase, not the text: a host changing wording mid-pull must
              // not look like the stage changed.
              key: ValueKey(fired),
              caption: caption,
              fired: fired,
            ),
          ),
        ),
      ],
    );
  }
}

/// One phase of the caption.
///
/// The invitation is quiet and text-only. Once the second stage has fired the
/// label takes the brand colour and gains its icon, so the moment of commitment
/// is visible at a glance rather than needing the wording to be read.
class const _CaptionLabel({
  super.key,
  required final String caption,
  required final bool fired,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final color = fired ? prego.colors.textBrandSecondary : prego.colors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fired) ...[
          Icon(TablerRegular.rotate_clockwise, size: prego.spacing.lg, color: color),
          SizedBox(width: prego.spacing.sm),
        ],
        // Flexible so the ellipsis can actually engage: a Row measures a plain
        // Text against the space it asks for, so at large accessibility text
        // scales an unconstrained label overflows instead of truncating.
        Flexible(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: fired
                ? prego.textTheme.textXs.medium.copyWith(color: color)
                : prego.textTheme.textXs.regular.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
