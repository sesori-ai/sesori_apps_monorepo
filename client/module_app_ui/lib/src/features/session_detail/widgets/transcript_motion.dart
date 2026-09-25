import "package:material_ui/material_ui.dart";

import "../../../extensions/build_context_x.dart";

/// How long a transcript row takes to ease in, fold away or open: the 200 ms
/// ease-out every transcript disclosure uses.
const Duration transcriptMotionDuration = Duration(milliseconds: 200);

/// Decelerates both ways: [Curves.easeIn] run backwards starts a fold fast.
const Curve transcriptMotionCurve = Curves.easeOut;
const Curve transcriptMotionReverseCurve = Curves.easeIn;

/// A transcript row that grows in and fades up when [entering], and folds
/// away when [exiting]: its height shrinks from the bottom while it fades
/// and slides up a little, toward the summary it folds into.
///
/// A settled row carries no animation state, no ticker and no clip; the
/// controller exists only once the row has moved. The parent decides reduced
/// motion: it passes `entering: false` and drops exiting rows at once.
class const TranscriptPresence({
  super.key,

  /// Read once, when the row first builds.
  required final bool entering,
  required final bool exiting,

  /// Called once an exiting row has folded away; the parent drops it then.
  required final VoidCallback? onExited,
  required final Widget child,
}) extends StatefulWidget {
  /// How far an exiting row slides up, as a fraction of its height.
  static const double exitSlide = 0.25;

  @override
  State<TranscriptPresence> createState() => _TranscriptPresenceState();
}

class _TranscriptPresenceState() extends State<TranscriptPresence> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  CurvedAnimation? _curve;

  @override
  void initState() {
    super.initState();
    if (widget.entering) _animation(from: 0).forward();
  }

  @override
  void didUpdateWidget(TranscriptPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exiting == widget.exiting) return;
    if (widget.exiting) {
      _animation(from: 1).reverse();
    } else {
      // A step that runs again before it has folded away comes back.
      _animation(from: 1).forward();
    }
  }

  AnimationController _animation({required double from}) {
    final existing = _controller;
    if (existing != null) return existing;
    final controller = _controller = AnimationController(
      vsync: this,
      duration: transcriptMotionDuration,
      value: from,
    );
    _curve = CurvedAnimation(
      parent: controller,
      curve: transcriptMotionCurve,
      reverseCurve: transcriptMotionReverseCurve,
    );
    controller
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status.isDismissed && widget.exiting) widget.onExited?.call();
      });
    return controller;
  }

  @override
  void dispose() {
    _curve?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _curve?.value ?? 1;
    final moving = t < 1;
    // The same widgets at rest and in motion, so the row keeps its state.
    return ClipRect(
      clipBehavior: moving ? Clip.hardEdge : Clip.none,
      child: Align(
        alignment: AlignmentDirectional.topStart,
        widthFactor: 1,
        heightFactor: t,
        child: Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(0, widget.exiting ? -TranscriptPresence.exitSlide * (1 - t) : 0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A column of keyed transcript rows. A row that joins after the first build
/// eases in; a row that leaves stays in place, as it last looked, while it
/// folds away. Only the rows that change animate. Reduced motion shows every
/// change at once.
class const TranscriptPresenceColumn({super.key, required final List<Widget> children}) extends StatefulWidget {
  @override
  State<TranscriptPresenceColumn> createState() => _TranscriptPresenceColumnState();
}

class _TranscriptPresenceColumnState() extends State<TranscriptPresenceColumn> {
  /// The rows shown: the current children with the leaving ones in place.
  late List<Widget> _rows = widget.children;
  final Set<Key> _leaving = {};
  Set<Key> _entering = const {};

  @override
  void didUpdateWidget(TranscriptPresenceColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    final animate = !context.isReducedMotion;
    final next = widget.children;
    final nextKeys = {for (final row in next) row.key};
    final shownKeys = {for (final row in _rows) row.key};
    final rows = <Widget>[];
    final placed = <Key?>{};
    var nextIndex = 0;
    // A new first row, such as a group's first summary, goes above the rows
    // folding into it; other new rows follow the rows leaving before them.
    if (next.firstOrNull case final first? when !shownKeys.contains(first.key)) {
      rows.add(first);
      placed.add(first.key);
      nextIndex = 1;
    }
    for (final row in _rows) {
      if (nextKeys.contains(row.key)) {
        if (placed.contains(row.key)) continue;
        // Place the new rows up to and including this surviving one.
        while (nextIndex < next.length) {
          final candidate = next[nextIndex++];
          rows.add(candidate);
          placed.add(candidate.key);
          if (candidate.key == row.key) break;
        }
      } else if (row.key case final key? when animate) {
        rows.add(row);
        _leaving.add(key);
      }
    }
    for (final candidate in next.skip(nextIndex)) {
      if (placed.add(candidate.key)) rows.add(candidate);
    }
    _leaving.removeWhere(nextKeys.contains);
    _entering = animate
        ? {
            for (final row in next)
              if (row.key case final Key key when !shownKeys.contains(key)) key,
          }
        : const {};
    _rows = rows;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in _rows)
          TranscriptPresence(
            key: ValueKey<Key?>(row.key),
            entering: _entering.contains(row.key),
            exiting: _leaving.contains(row.key),
            onExited: () => setState(() {
              _leaving.remove(row.key);
              _rows = [
                for (final shown in _rows)
                  if (shown.key != row.key) shown,
              ];
            }),
            child: row,
          ),
      ],
    );
  }
}
