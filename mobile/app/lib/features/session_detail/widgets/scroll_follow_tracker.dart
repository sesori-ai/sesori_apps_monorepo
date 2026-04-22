import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/widgets.dart";

/// Which edge a scrollable should "follow" when auto-pinned.
///
/// - [min] — follows offset `0`. Matches the visual bottom of a
///   `reverse: true` ListView (newest-at-bottom chat list).
/// - [max] — follows `maxScrollExtent`. Matches the visual bottom of a
///   normal non-reversed ListView (growing output tailed from the end).
enum ScrollFollowEdge { min, max }

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
/// - For a `reverse: true` list following [ScrollFollowEdge.min],
///   nothing needs to happen on each rebuild — Flutter's native
///   sliver offset correction keeps offset `0` pinned to the newest
///   item as data is appended. [scheduleJumpToEdge] exists for the
///   [ScrollFollowEdge.max] tailing case only.
class ScrollFollowTracker extends ChangeNotifier {
  ScrollFollowTracker({
    required this.edge,
    double edgeTolerance = 20.0,
  }) : _edgeTolerance = edgeTolerance,
       scrollController = ScrollController();

  final ScrollFollowEdge edge;
  final double _edgeTolerance;
  final ScrollController scrollController;

  bool _following = true;
  bool _snapScheduled = false;

  /// Whether the scrollable is currently pinned to [edge].
  bool get following => _following;

  /// Immediately enter detached mode if not already detached.
  void detach() {
    if (!_following) return;
    _following = false;
    notifyListeners();
  }

  /// Hook for `Listener.onPointerSignal` (trackpad two-finger scroll,
  /// mouse wheel). Detaches on any pointer scroll event.
  void handlePointerSignal({required PointerSignalEvent event}) {
    if (event is PointerScrollEvent) detach();
  }

  /// Hook for `Listener.onPointerPanZoomStart` (trackpad pan-zoom).
  /// Detaches on gesture start.
  void handlePointerPanZoomStart() => detach();

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
  /// stacks overlapping animations.
  ///
  /// Only relevant for [ScrollFollowEdge.max] tailing (non-reversed
  /// lists). Reversed chat lists following [ScrollFollowEdge.min] do
  /// not need this — pixel offset `0` stays at the newest item
  /// naturally.
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
    if (notification is ScrollStartNotification && notification.dragDetails != null) {
      return true;
    }
    if (notification is UserScrollNotification && notification.direction != ScrollDirection.idle) {
      return true;
    }
    return false;
  }

  void _maybeReattach({required ScrollMetrics metrics}) {
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
