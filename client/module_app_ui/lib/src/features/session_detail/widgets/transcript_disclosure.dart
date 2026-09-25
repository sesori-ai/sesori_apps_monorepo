import "dart:math";

import "package:flutter/rendering.dart" show RenderSliverPadding;
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "transcript_motion.dart";

/// A transcript row that eases a panel open below it when tapped.
///
/// In the reversed transcript a growing row would push its own header up and
/// away; the disclosure scrolls by the same amount as it grows, so the tapped
/// header stays still while there is room below it.
class const TranscriptDisclosure({
  super.key,
  required final Key toggleKey,
  required final Widget Function({required bool expanded}) headerBuilder,
  required final Widget panel,
}) extends StatefulWidget {
  @override
  State<TranscriptDisclosure> createState() => _TranscriptDisclosureState();
}

class _TranscriptDisclosureState() extends State<TranscriptDisclosure> with SingleTickerProviderStateMixin {
  late final AnimationController _disclosure = AnimationController(vsync: this, duration: transcriptMotionDuration);
  late final CurvedAnimation _panelSize = CurvedAnimation(
    parent: _disclosure,
    curve: transcriptMotionCurve,
    reverseCurve: transcriptMotionReverseCurve,
  );

  /// The user's choice. The panel itself stays mounted until it has closed.
  bool get _expanded => _disclosure.isForwardOrCompleted;

  final _panelKey = GlobalKey();

  /// How much of the panel the transcript has already made room for.
  double _shownFactor = 0;

  @override
  void initState() {
    super.initState();
    _panelSize.addListener(_keepHeaderInPlace);
    _disclosure.addStatusListener(_onDisclosureStatus);
  }

  @override
  void dispose() {
    _panelSize.dispose();
    _disclosure.dispose();
    super.dispose();
  }

  void _toggle() {
    if (context.isReducedMotion) {
      final opening = !_expanded;
      _disclosure.value = opening ? 1 : 0;
      // The panel is not laid out yet, so its height is known only after
      // this frame.
      if (opening) WidgetsBinding.instance.addPostFrameCallback((_) => _keepHeaderInPlace());
    } else if (_expanded) {
      _disclosure.reverse();
    } else {
      _disclosure.forward();
    }
    setState(() {});
  }

  void _onDisclosureStatus(AnimationStatus status) {
    // Drops the closed panel, so its buttons do not stay reachable at zero
    // height.
    if (status.isDismissed) setState(() {});
  }

  /// Runs on every disclosure tick, before layout. A reversed transcript
  /// grows a row upward, which would push the tapped header away (and behind
  /// the floating navigation). Scrolling by the same amount in the same frame
  /// keeps the header still and grows the panel downward, as long as there is
  /// room below the row; past that, the row grows upward like new content.
  void _keepHeaderInPlace() {
    if (!mounted) return;
    final panel = _panelKey.currentContext?.findRenderObject();
    // Not laid out yet: the growth so far is applied once it is.
    if (panel is! RenderBox || !panel.hasSize) return;
    final growth = panel.size.height * (_panelSize.value - _shownFactor);
    _shownFactor = _panelSize.value;
    final scrollable = Scrollable.maybeOf(context);
    final row = context.findRenderObject();
    final viewport = scrollable?.context.findRenderObject();
    if (scrollable == null ||
        scrollable.axisDirection != AxisDirection.up ||
        row is! RenderBox ||
        viewport is! RenderBox ||
        growth == 0) {
      return;
    }
    final position = scrollable.position;
    // A transcript shorter than its viewport cannot scroll; the row grows into
    // the empty space above it instead of bouncing against the range.
    if (position.maxScrollExtent <= position.minScrollExtent) return;
    final double shift;
    if (growth > 0) {
      final rowBottom = row.localToGlobal(Offset(0, row.size.height)).dy;
      // The list's bottom padding keeps the newest row clear of the floating
      // composer, so that strip is no room.
      final covered = context.findAncestorRenderObjectOfType<RenderSliverPadding>()?.resolvedPadding?.bottom ?? 0;
      final viewportBottom = viewport.localToGlobal(Offset(0, viewport.size.height)).dy - covered;
      shift = min(growth, max(0, viewportBottom - rowBottom));
    } else {
      shift = max(growth, position.minScrollExtent - position.pixels);
    }
    if (shift != 0) position.jumpTo(position.pixels + shift);
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          expanded: _expanded,
          child: TextButton(
            key: widget.toggleKey,
            onPressed: _toggle,
            style: TextButton.styleFrom(
              foregroundColor: prego.colors.textSecondary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              alignment: AlignmentDirectional.centerStart,
              // The default stadium hover reads as a pill across the whole row.
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PregoRadius.xs)),
            ),
            child: widget.headerBuilder(expanded: _expanded),
          ),
        ),
        if (!_disclosure.isDismissed)
          SizeTransition(
            sizeFactor: _panelSize,
            alignment: AlignmentDirectional.topStart,
            child: KeyedSubtree(key: _panelKey, child: widget.panel),
          ),
      ],
    );
  }
}
