import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

/// The new-session options while the bridge is still being asked what it can
/// run: one shimmering bar per option row, laid out on the rows' own rhythm so
/// nothing shifts when the real controls arrive.
class NewSessionOptionsSkeleton extends StatelessWidget {
  const NewSessionOptionsSkeleton({super.key, required this.rowHeight, required this.rowSpacing});

  /// Height of an options row, so a bar sits where its control will.
  final double rowHeight;

  /// Gap between options rows.
  final double rowSpacing;

  /// Bar widths, in the order the rows they stand in for appear: the harness
  /// picker, then the dedicated-workspace toggle.
  static const List<double> _barWidths = [96, 132];

  /// Height of a placeholder bar — the cap height of the text it replaces.
  static const double _barHeight = 12;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return PregoShimmer(
      semanticLabel: context.loc.newSessionOptionsLoadingSemantics,
      child: Padding(
        // Line the bars up with the row content, which sits inside the
        // trigger's own horizontal padding.
        padding: EdgeInsetsDirectional.only(start: prego.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: rowSpacing,
          children: [
            for (final width in _barWidths)
              SizedBox(
                height: rowHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PregoSkeletonBar(height: _barHeight, width: width),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
