import "package:material_ui/material_ui.dart";

/// A transcript row, keyed like the row, that reports while it is built, so
/// the list can measure the rows it has without walking the render tree.
class const TranscriptRowReporter({
  required super.key,
  required final String rowId,
  required final void Function({required String rowId, required BuildContext context}) onMount,
  required final void Function({required String rowId}) onUnmount,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<TranscriptRowReporter> createState() => _TranscriptRowReporterState();
}

class _TranscriptRowReporterState() extends State<TranscriptRowReporter> {
  @override
  void initState() {
    super.initState();
    widget.onMount(rowId: widget.rowId, context: context);
  }

  // A row that takes over another's key, as a launch bubble's echo does,
  // keeps this element under its own id.
  @override
  void didUpdateWidget(TranscriptRowReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rowId == widget.rowId) return;
    oldWidget.onUnmount(rowId: oldWidget.rowId);
    widget.onMount(rowId: widget.rowId, context: context);
  }

  // Not in dispose: a row laid out again in the same frame, after a scroll
  // correction, mounts its replacement before this one is disposed.
  @override
  void deactivate() {
    widget.onUnmount(rowId: widget.rowId);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
