/// Reduced-motion support for the Prego design system's animated components.
library;

import "package:flutter/material.dart";

/// Whether the platform is currently asking for reduced motion.
///
/// Two sources have to be consulted: [MediaQuery] only carries Android's
/// "Remove animations", while iOS's "Reduce Motion" surfaces solely through
/// [AccessibilityFeatures.reduceMotion]. Checking one of them leaves the other
/// platform's users with motion they asked not to see.
///
/// Changes to the second source don't rebuild dependents on their own —
/// [PregoReducedMotionStateMixin] owns the observer that reacts to them.
bool prefersReducedMotion(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return true;
  return View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
}

/// Keeps a repeating animation in step with the platform's reduced-motion
/// preference.
///
/// A repeating [AnimationController] schedules a frame every vsync for as long
/// as it runs, so an indicator that merely *paints* a static frame under
/// reduced motion still costs a frame a tick. Implementers therefore expose
/// [startMotion]/[stopMotion] and this mixin decides which to call, from the
/// preference and the component's own [motionEnabled].
///
/// The mixin owns the [WidgetsBindingObserver] registration that makes
/// [didChangeAccessibilityFeatures] fire — without it, toggling iOS Reduce
/// Motion while the widget is on screen would never be noticed.
///
/// [syncMotion] runs on [didChangeDependencies] and on accessibility changes.
/// Components with their own reasons to re-evaluate — a changed widget
/// configuration, a timer elapsing — call it themselves; it is deliberately not
/// wired into `didUpdateWidget`, so a component can settle its own state before
/// the animation is re-synced against it.
mixin PregoReducedMotionStateMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  /// Whether the component wants to animate at all, ignoring the platform
  /// preference. A component that is idle, or not yet visible, returns false.
  bool get motionEnabled;

  /// Start the repeating animation. Called only when motion is both wanted and
  /// allowed, and only when it isn't already running.
  void startMotion();

  /// Stop the repeating animation and settle it on a presentable frame.
  /// [AnimationController.stop] leaves `value` wherever the animation happened
  /// to be, which is rarely the frame a component wants to rest on.
  void stopMotion();

  /// Whether the animation should be running right now.
  bool get motionAllowed => motionEnabled && !prefersReducedMotion(context);

  /// Start or stop the animation to match [motionAllowed].
  void syncMotion() {
    if (motionAllowed) {
      startMotion();
    } else {
      stopMotion();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncMotion();
  }

  @override
  void didChangeAccessibilityFeatures() {
    super.didChangeAccessibilityFeatures();
    if (!mounted) return;
    // The painted frame, not just the ticker, depends on the preference.
    setState(() {});
    syncMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
