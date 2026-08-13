import "package:flutter/foundation.dart";
import "package:flutter/material.dart";

import "prego_top_navigation.dart";

/// Publishes the live top-bar geometry of a Prego scaffold to descendants.
class const PregoTopBarInsetScope({
  super.key,
  required final double baseInset,
  required final ValueListenable<double> bannerHeight,
  required super.child,
}) extends InheritedWidget {
  @override
  bool updateShouldNotify(PregoTopBarInsetScope oldWidget) =>
      baseInset != oldWidget.baseInset || !identical(bannerHeight, oldWidget.bannerHeight);
}

/// Returns the current top inset, including any visible navigation banner.
double pregoTopBarInsetOf(BuildContext context) {
  final scope = context.dependOnInheritedWidgetOfExactType<PregoTopBarInsetScope>();
  if (scope == null) {
    return MediaQuery.paddingOf(context).top + PregoTopNavigation.barHeight;
  }
  return scope.baseInset + scope.bannerHeight.value;
}

/// Rebuilds [builder] as the enclosing top-navigation banner changes height.
class const PregoTopBarInsetBuilder({
  super.key,
  required final Widget Function(BuildContext context, double topInset, Widget? child) builder,
  final Widget? child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PregoTopBarInsetScope>();
    if (scope == null) {
      return builder(
        context,
        MediaQuery.paddingOf(context).top + PregoTopNavigation.barHeight,
        child,
      );
    }
    return ValueListenableBuilder<double>(
      valueListenable: scope.bannerHeight,
      builder: (context, bannerHeight, child) => builder(
        context,
        scope.baseInset + bannerHeight,
        child,
      ),
      child: child,
    );
  }
}
