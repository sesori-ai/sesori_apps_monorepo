import "dart:math" as math;

import "package:material_ui/material_ui.dart";

import "../models/diff_file_view_model.dart";
import "diff_file_widget.dart";

/// [SliverPersistentHeaderDelegate] that renders a [DiffFileWidget] as a
/// pinned sticky header inside a [SliverMainAxisGroup].
class DiffFileHeaderDelegate({
  required final DiffFileViewModel viewModel,
  required final bool isExpanded,
  required final VoidCallback onToggle,

  /// Key attached to the header's [SizedBox] so callers can locate the
  /// header inside the scrollable (e.g. via [Scrollable.ensureVisible] after
  /// the owning file is collapsed). Nullable because callers may not need
  /// the header to be addressable, but the constructor is `required` to
  /// follow the project-wide named-argument convention.
  required final Key? headerKey,

  /// The text scaling around the header, which its fixed extent must hold.
  required final TextScaler textScaler,
}) extends SliverPersistentHeaderDelegate {
  /// 6px padding top and bottom, an 18px code line and a 0.5px border make
  /// 30.5px; 36 leaves room for modest text scaling, and larger text grows it.
  /// The line is the scaled 12px font on its 18/12 height, as the text lays it
  /// out under a nonlinear system scaler too.
  double get _extent => math.max(36, 12.5 + textScaler.scale(12) * 18 / 12);

  @override
  double get maxExtent => _extent;

  @override
  double get minExtent => _extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // SliverPersistentHeader gives the child BoxConstraints(minHeight: 0,
    // maxHeight: maxExtent) — the child is NOT forced to fill the extent.
    // If the child renders shorter than maxExtent, paintExtent < layoutExtent
    // which is an invalid SliverGeometry (assertion failure in debug,
    // rendering glitch in release). Forcing exact height prevents this.
    return SizedBox(
      key: headerKey,
      height: maxExtent,
      child: DiffFileWidget(
        viewModel: viewModel,
        isExpanded: isExpanded,
        onToggle: onToggle,
      ),
    );
  }

  @override
  bool shouldRebuild(DiffFileHeaderDelegate oldDelegate) {
    return !identical(viewModel, oldDelegate.viewModel) ||
        isExpanded != oldDelegate.isExpanded ||
        headerKey != oldDelegate.headerKey ||
        textScaler != oldDelegate.textScaler;
  }
}
