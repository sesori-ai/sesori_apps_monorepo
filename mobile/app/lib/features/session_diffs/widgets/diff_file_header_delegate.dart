import "package:flutter/material.dart";

import "../models/diff_file_view_model.dart";
import "diff_file_widget.dart";

/// [SliverPersistentHeaderDelegate] that renders a [DiffFileWidget] as a
/// pinned sticky header inside a [SliverMainAxisGroup].
class DiffFileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DiffFileViewModel viewModel;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// Optional key attached to the header's [SizedBox] so callers can locate
  /// the header inside the scrollable (e.g. via [Scrollable.ensureVisible]
  /// after the owning file is collapsed). Null is fine — the header just
  /// won't be addressable by key.
  final Key? headerKey;

  DiffFileHeaderDelegate({
    required this.viewModel,
    required this.isExpanded,
    required this.onToggle,
    this.headerKey,
  });

  /// Estimated height: 6px padding top + ~18px content + 6px padding bottom
  /// + 0.5px border ≈ 30.5px. Rounded up with headroom for text scaling.
  static const _kExtent = 36.0;

  @override
  double get maxExtent => _kExtent;

  @override
  double get minExtent => _kExtent;

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
    return !identical(viewModel, oldDelegate.viewModel) || isExpanded != oldDelegate.isExpanded;
  }
}
