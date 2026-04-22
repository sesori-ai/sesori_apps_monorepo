import "package:flutter/widgets.dart";

import "scroll_follow_tracker.dart";

/// Wraps a scrollable [child] with the gesture plumbing a
/// [ScrollFollowTracker] needs:
///
/// - `Listener.onPointerSignal` — trackpad two-finger scroll / mouse
///   wheel. Forwards to [ScrollFollowTracker.handlePointerSignal].
/// - `Listener.onPointerPanZoomStart` — trackpad pan-zoom gesture.
///   Forwards to [ScrollFollowTracker.handlePointerPanZoomStart].
/// - `NotificationListener<ScrollNotification>` — drag, momentum,
///   programmatic events. Forwards to
///   [ScrollFollowTracker.handleScrollNotification].
///
/// Rebuilds when [tracker] notifies so [detachedOverlayBuilder]
/// toggles with `tracker.following`. The overlay is stacked on top
/// of [child] using a [Stack]; [detachedOverlayBuilder] should return
/// a `Positioned` (or equivalent) child.
///
/// [child] is expected to be a scrollable configured with
/// `tracker.scrollController`. The widget does not create or own the
/// scroll controller — it only wires gesture intent.
class FollowDetachScrollable extends StatefulWidget {
  final ScrollFollowTracker tracker;
  final Widget child;
  final WidgetBuilder? detachedOverlayBuilder;

  const FollowDetachScrollable({
    super.key,
    required this.tracker,
    required this.child,
    required this.detachedOverlayBuilder,
  });

  @override
  State<FollowDetachScrollable> createState() => _FollowDetachScrollableState();
}

class _FollowDetachScrollableState extends State<FollowDetachScrollable> {
  @override
  void initState() {
    super.initState();
    widget.tracker.addListener(_onFollowChanged);
  }

  @override
  void didUpdateWidget(covariant FollowDetachScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tracker, widget.tracker)) {
      oldWidget.tracker.removeListener(_onFollowChanged);
      widget.tracker.addListener(_onFollowChanged);
    }
  }

  @override
  void dispose() {
    widget.tracker.removeListener(_onFollowChanged);
    super.dispose();
  }

  void _onFollowChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final overlayBuilder = widget.detachedOverlayBuilder;
    return Stack(
      children: [
        Listener(
          onPointerSignal: (event) => widget.tracker.handlePointerSignal(event: event),
          onPointerPanZoomStart: (_) => widget.tracker.handlePointerPanZoomStart(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) =>
                widget.tracker.handleScrollNotification(notification: notification),
            child: widget.child,
          ),
        ),
        if (!widget.tracker.following && overlayBuilder != null) overlayBuilder(context),
      ],
    );
  }
}
