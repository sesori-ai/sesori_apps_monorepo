import "package:material_ui/material_ui.dart";

import "prego_animated_sliver_list.dart";

/// The box-layout form of [PregoAnimatedSliverList], for keyed rows that live
/// inside a column rather than a scroll view's sliver list.
///
/// The list sizes itself to its rows and never scrolls on its own; the
/// surrounding page owns scrolling.
class const PregoAnimatedList<T>({
  super.key,

  /// The items currently present in the source list.
  required final List<T> items,

  /// Returns the stable, unique identity of an item across list updates.
  required final Key Function(T item) itemKey,

  /// Builds an item at its current index.
  required final Widget Function(BuildContext context, int index, T item) itemBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ponytail: a shrink-wrapped scroll view reuses the sliver list's
    // reconciliation instead of restating it for box layout. Build a real
    // AnimatedList-based twin if a caller ever needs a long or lazy list.
    return CustomScrollView(
      shrinkWrap: true,
      // The page owns the primary scroll position; this list never scrolls and
      // must not attach a second position to that controller.
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        PregoAnimatedSliverList<T>(items: items, itemKey: itemKey, itemBuilder: itemBuilder),
      ],
    );
  }
}
