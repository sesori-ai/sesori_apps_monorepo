import "package:flutter/material.dart";

import "../models/diff_file_view_model.dart";
import "diff_file_widget.dart";

/// [SliverPersistentHeaderDelegate] that renders a [DiffFileWidget] as a
/// pinned sticky header inside a [SliverMainAxisGroup].
class DiffFileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DiffFileViewModel viewModel;
  final bool isExpanded;
  final VoidCallback onToggle;

  DiffFileHeaderDelegate({
    required this.viewModel,
    required this.isExpanded,
    required this.onToggle,
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
    return DiffFileWidget(
      viewModel: viewModel,
      isExpanded: isExpanded,
      onToggle: onToggle,
    );
  }

  @override
  bool shouldRebuild(DiffFileHeaderDelegate oldDelegate) {
    return !identical(viewModel, oldDelegate.viewModel) || isExpanded != oldDelegate.isExpanded;
  }
}
