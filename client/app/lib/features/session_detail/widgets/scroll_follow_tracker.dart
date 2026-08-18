import "dart:async";

import "package:flutter/foundation.dart" show TargetPlatform, defaultTargetPlatform, kIsWeb;
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/widgets.dart";

/// Which edge a scrollable should "follow" when auto-pinned.
///
/// - [min] — follows offset `0`. Matches the visual bottom of a
///   `reverse: true` ListView (newest-at-bottom chat list).
/// - [max] — follows `maxScrollExtent`. Matches the visual bottom of a
///   normal non-reversed ListView (growing output tailed from the end).
enum ScrollFollowEdge() { min, max }

/// Maintains the "following vs detached" state of a scrollable derived
/// from scroll and pointer events, and exposes snapshot access via
/// [following] plus `ChangeNotifier` subscription.
///
/// Owns a [ScrollController] and exposes small hooks the scrollable
/// wires to `Listener` / `NotificationListener`:
///
/// - [handlePointerSignal] — trackpad/wheel scroll. Detaches.
/// - [handlePointerPanZoomStart] — trackpad two-finger pan. Detaches.
/// - [handleScrollNotification] — drag / momentum events. Detaches on
///   user-initiated starts, reattaches on settle near the follow edge.
///
/// Design rules (enforced by deliberately small API surface):
///
/// - A single `_following` flag is the only state. No `_userScrollActive`
///   flag, no race-prone captures of old pixels/maxScrollExtent.
/// - The tracker never rewrites `position.pixels` except when the
///   caller explicitly asks via [animateToEdge] or [scheduleJumpToEdge].
/// - [scheduleJumpToEdge] works for both edges and is cheap to call
///   on every rebuild (coalesced to one post-frame jump per frame,
///   skipped entirely when `pixels` is already at the edge). It is
///   necessary for [ScrollFollowEdge.max] tailing to track growing
///   content, and serves as a belt-and-braces pin for
///   [ScrollFollowEdge.min] in case `reverse: true` sliver correction
///   leaves `pixels` even slightly off `0` after an append.
class ScrollFollowTracker({
    required final ScrollFollowEdge edge,
    final double _edgeTolerance = 20.0,
  }) extends ChangeNotifier {
  this : scrollController = _createScrollController();

  final ScrollController scrollController;

  bool _following = true;
  bool _snapScheduled = false;
  bool _detachSuppressed = false;

  /// Whether the scrollable is currently pinned to [edge].
  bool get following => _following;

  /// Immediately enter detached mode if not already detached.
  void detach() {
    if (_detachSuppressed || !_following) return;
    _following = false;
    notifyListeners();
  }

  /// Suppress detaching for the duration of a gesture that must not
  /// disturb follow mode — specifically the horizontal timestamp "peek",
  /// which slides rows sideways without scrolling. The scrollable still
  /// fires a spurious drag-start as it claims the pointer, so this also
  /// re-attaches if that already flipped us to detached. Subsequent
  /// [detach] calls are no-ops until [releaseDetachSuppression].
  void suppressDetach() {
    _detachSuppressed = true;
    if (!_following) {
      _following = true;
      notifyListeners();
    }
  }

  /// Lifts the [suppressDetach] guard once the peek gesture ends.
  void releaseDetachSuppression() => _detachSuppressed = false;

  /// Hook for `Listener.onPointerSignal` (trackpad two-finger scroll,
  /// mouse wheel). Detaches on any pointer scroll event.
  void handlePointerSignal({required PointerSignalEvent event}) {
    if (event is PointerScrollEvent && _hasScrollableRange) detach();
  }

  /// Hook for `Listener.onPointerPanZoomStart` (trackpad pan-zoom).
  /// Detaches on gesture start.
  void handlePointerPanZoomStart() {
    if (_hasScrollableRange) detach();
  }

  /// Whether the attached scrollable actually has room to scroll. A list
  /// shorter than its viewport (min == max) is still draggable/wheelable via
  /// `AlwaysScrollableScrollPhysics` (used so the chat always overscrolls), but
  /// any such gesture only rubber-bands back to the edge — never leaving it —
  /// so it must not detach and flash the jump-to-latest pill. Mirrors the guard
  /// in [_isUserScrollStart] for the touch-drag path.
  bool get _hasScrollableRange {
    if (!scrollController.hasClients) return false;
    final position = scrollController.position;
    return position.maxScrollExtent > position.minScrollExtent;
  }

  /// Hook for `NotificationListener<ScrollNotification>.onNotification`.
  /// Returns `false` so the notification continues to bubble.
  bool handleScrollNotification({required ScrollNotification notification}) {
    if (notification.depth != 0) return false;

    if (_isUserScrollStart(notification: notification)) {
      detach();
    } else if (notification is ScrollEndNotification) {
      _maybeReattach(metrics: notification.metrics);
    }
    return false;
  }

  /// Animate to [edge] and enter follow mode. Used for "Jump to latest"
  /// / "Follow output" button taps.
  Future<void> animateToEdge({
    Duration duration = const Duration(milliseconds: 180),
    Curve curve = Curves.easeOut,
  }) async {
    if (!_following) {
      _following = true;
      notifyListeners();
    }
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      _edgeOffset(metrics: scrollController.position),
      duration: duration,
      curve: curve,
    );
  }

  /// Coalesces a single post-frame `jumpTo(edge)` while following. Safe
  /// to call on every rebuild — repeated calls within a frame collapse
  /// into one jump, so tailing a high-frequency streaming source never
  /// stacks overlapping animations. The jump is also skipped when
  /// `pixels` is already within half a pixel of the edge, so it is a
  /// no-op in the common case.
  ///
  /// Primary use is [ScrollFollowEdge.max] tailing of growing content
  /// (e.g. the reasoning modal). For [ScrollFollowEdge.min] reversed
  /// chat lists, it doubles as a belt-and-braces pin — Flutter's
  /// native sliver offset correction usually keeps `pixels` at `0` as
  /// new newest items are appended, but calling this guarantees it.
  void scheduleJumpToEdge() {
    if (!_following || _snapScheduled) return;
    _snapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _snapScheduled = false;
      if (!_following || !scrollController.hasClients) return;
      final position = scrollController.position;
      final target = _edgeOffset(metrics: position);
      if ((position.pixels - target).abs() > 0.5) {
        position.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  bool _isUserScrollStart({required ScrollNotification notification}) {
    // A list whose content is shorter than the viewport has no scrollable
    // range, yet is draggable via `AlwaysScrollableScrollPhysics` (used so the
    // chat always overscrolls). Such a drag can only rubber-band back to the
    // follow edge — it never leaves it — so it must not flip us to detached,
    // which would briefly flash the jump-to-latest pill on a short transcript.
    final metrics = notification.metrics;
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) return false;
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      return true;
    }
    if (notification is UserScrollNotification && notification.direction != ScrollDirection.idle) {
      return true;
    }
    return false;
  }

  void _maybeReattach({required ScrollMetrics metrics}) {
    // No scrollable range → the list can't be away from the follow edge; a
    // bouncing-overscroll release that settles here must not toggle follow
    // state (it would flash the jump-to-latest pill on a short transcript).
    // Pairs with the same guard on the detach path in [_isUserScrollStart].
    if (metrics.maxScrollExtent <= metrics.minScrollExtent) return;
    final distance = (metrics.pixels - _edgeOffset(metrics: metrics)).abs();
    final shouldFollow = distance <= _edgeTolerance;
    if (shouldFollow == _following) return;
    _following = shouldFollow;
    notifyListeners();
  }

  double _edgeOffset({required ScrollMetrics metrics}) {
    return switch (edge) {
      ScrollFollowEdge.min => metrics.minScrollExtent,
      ScrollFollowEdge.max => metrics.maxScrollExtent,
    };
  }
}

ScrollController _createScrollController() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
    return _SmoothPointerScrollController();
  }
  return ScrollController();
}

/// Smooths macOS's discrete physical mouse-wheel deltas without touching its
/// trackpad path, which Flutter delivers as native pan/zoom gestures.
class _SmoothPointerScrollController() extends ScrollController {
  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _SmoothPointerScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _SmoothPointerScrollPosition({
  required super.physics,
  required super.context,
  required super.initialPixels,
  required super.keepScrollOffset,
  required super.oldPosition,
  required super.debugLabel,
}) extends ScrollPositionWithSingleContext {
  static const _animationDuration = Duration(milliseconds: 120);

  double? _pointerScrollTarget;
  bool _startingPointerScroll = false;

  @override
  void pointerScroll(double delta) {
    if (delta == 0) {
      _pointerScrollTarget = null;
      super.pointerScroll(delta);
      return;
    }

    // Add rapid wheel ticks to the destination rather than to the partially
    // animated current offset. Otherwise each new tick discards the remaining
    // distance from the previous one and makes fast wheel scrolling feel slow.
    final target = ((_pointerScrollTarget ?? pixels) + delta).clamp(minScrollExtent, maxScrollExtent).toDouble();
    _pointerScrollTarget = target;
    updateUserScrollDirection(delta < 0 ? ScrollDirection.forward : ScrollDirection.reverse);

    _startingPointerScroll = true;
    try {
      unawaited(animateTo(target, duration: _animationDuration, curve: Curves.easeOutCubic));
    } finally {
      _startingPointerScroll = false;
    }
  }

  @override
  void beginActivity(ScrollActivity? newActivity) {
    // A drag, trackpad gesture, programmatic scroll, or completed wheel
    // animation invalidates the accumulated wheel destination.
    if (!_startingPointerScroll) _pointerScrollTarget = null;
    super.beginActivity(newActivity);
  }
}
