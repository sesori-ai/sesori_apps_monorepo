import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Builds a modal's heavy [child] once the route's entry transition has
/// finished, with a spinner in its place until then.
///
/// Laying out tens of kilobytes of Markdown or highlighted code in a modal's
/// first frame holds that frame long enough to swallow the tap's ripple and
/// skip the entry transition. Short content lays out within a frame, so it
/// builds at once instead of flashing a spinner.
class const DeferUntilRouteOpen({
  super.key,

  /// Length of the text [child] renders, which decides whether it is heavy
  /// enough to wait for. Read once, when this widget is first built.
  required final int contentLength,
  required final Widget child,
}) extends StatefulWidget {
  // ponytail: calibrated from #1768, where 42 KB of Markdown cost a 45 ms
  // frame on macOS; slower phones stall from roughly this size.
  static const _minDeferredLength = 5000;

  @override
  State<DeferUntilRouteOpen> createState() => _DeferUntilRouteOpenState();
}

class _DeferUntilRouteOpenState() extends State<DeferUntilRouteOpen> {
  static const _placeholderHeight = 220.0;

  /// The entry transition while it still runs; null once [child] builds.
  Animation<double>? _opening;

  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    // Only a transition running forward completes later: a modal opened
    // without one, under reduced motion, is already open.
    final entry = ModalRoute.of(context)?.animation;
    if (widget.contentLength >= DeferUntilRouteOpen._minDeferredLength &&
        entry != null &&
        entry.status == AnimationStatus.forward) {
      _opening = entry..addStatusListener(_onEntryStatus);
    }
  }

  void _onEntryStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _opening?.removeStatusListener(_onEntryStatus);
    setState(() => _opening = null);
  }

  @override
  void dispose() {
    _opening?.removeStatusListener(_onEntryStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_opening == null) return widget.child;
    return const SizedBox(
      height: _placeholderHeight,
      child: Center(child: PregoActivityIndicator(color: null)),
    );
  }
}
