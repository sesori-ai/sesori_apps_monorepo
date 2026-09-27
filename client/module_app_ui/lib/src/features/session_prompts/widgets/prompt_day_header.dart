import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The fixed height of a [PromptDayHeaderDelegate] header at [textScaler].
double promptDayHeaderExtent({required TextScaler textScaler}) => textScaler.scale(12) * 18 / 12 + PregoSpacing.md * 2;

/// Pins a day's heading over the Prompts screen's rows while that day's rows
/// scroll under it.
class PromptDayHeaderDelegate({required final String label, required final double extent})
    extends SliverPersistentHeaderDelegate {
  @override
  double get maxExtent => extent;

  @override
  double get minExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final prego = context.prego;
    // A header drawn shorter than its extent is invalid sliver geometry.
    return SizedBox(
      height: extent,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              header: true,
              child: Text(label, style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(PromptDayHeaderDelegate oldDelegate) => label != oldDelegate.label || extent != oldDelegate.extent;
}
