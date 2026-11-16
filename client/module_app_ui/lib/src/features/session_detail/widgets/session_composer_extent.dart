import "package:flutter/scheduler.dart";
import "package:material_ui/material_ui.dart";

/// Hears, for a shell, how far a session page's composer rises over the bottom
/// of the page, with the cards and notices docked above it, so a surface that
/// floats over the page can stop above it. It hears 0 while the page shows no
/// composer, as on a read-only or archived session or before the first load.
///
/// The extent arrives once the frame that laid the composer out has ended, as
/// a size observer's does.
class const SessionComposerExtentScope({
  super.key,
  required final ValueChanged<double> onExtentChanged,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(SessionComposerExtentScope oldWidget) => onExtentChanged != oldWidget.onExtentChanged;
}

/// Tells the nearest [SessionComposerExtentScope] the composer's [extent],
/// and 0 once it leaves the page.
class const SessionComposerExtentReport({
  super.key,
  required final double extent,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<SessionComposerExtentReport> createState() => _SessionComposerExtentReportState();
}

class _SessionComposerExtentReportState() extends State<SessionComposerExtentReport> {
  ValueChanged<double>? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _listener = context.dependOnInheritedWidgetOfExactType<SessionComposerExtentScope>()?.onExtentChanged;
    _report(extent: widget.extent);
  }

  @override
  void didUpdateWidget(SessionComposerExtentReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.extent != oldWidget.extent) _report(extent: widget.extent);
  }

  @override
  void dispose() {
    _report(extent: 0);
    super.dispose();
  }

  /// The extent is known while the frame lays out, when nothing else may be
  /// rebuilt, so the listener hears of it after the frame.
  void _report({required double extent}) {
    if (_listener case final listener?) {
      SchedulerBinding.instance.addPostFrameCallback((_) => listener(extent));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
