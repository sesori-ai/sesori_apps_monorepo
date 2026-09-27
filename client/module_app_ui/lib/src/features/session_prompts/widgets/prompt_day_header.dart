import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// The fixed height of a [PromptDayHeaderDelegate] header at [textScaler].
double promptDayHeaderExtent({required TextScaler textScaler}) => textScaler.scale(12) * 18 / 12 + PregoSpacing.md * 2;

/// Pins a day's heading over the Prompts screen's rows while that day's rows
/// scroll under it.
class PromptDayHeaderDelegate({
  required final String label,
  required final double extent,

  /// How much of the heading shows, from 0 to 1, while a search folds its
  /// day away or brings it back; it takes that share of [extent].
  required final double shown,
}) extends SliverPersistentHeaderDelegate {
  @override
  double get maxExtent => extent * shown;

  @override
  double get minExtent => maxExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final prego = context.prego;
    // A header drawn shorter than its extent is invalid sliver geometry.
    return SizedBox(
      height: maxExtent,
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.topStart,
            minHeight: extent,
            maxHeight: extent,
            child: Opacity(
              opacity: shown,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.xl),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Semantics(
                    header: true,
                    child: Text(
                      label,
                      style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(PromptDayHeaderDelegate oldDelegate) =>
      label != oldDelegate.label || extent != oldDelegate.extent || shown != oldDelegate.shown;
}
