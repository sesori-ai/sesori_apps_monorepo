import "package:flutter/foundation.dart";
import "package:material_ui/material_ui.dart";

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
double pregoTopBarInsetOf({
  required BuildContext context,
  required double fallbackTopPadding,
}) {
  final scope = context.dependOnInheritedWidgetOfExactType<PregoTopBarInsetScope>();
  if (scope == null) {
    return fallbackTopPadding + PregoTopNavigation.barHeight;
  }
  return scope.baseInset + scope.bannerHeight.value;
}

final Expando<_PregoRootTopBarInsets> _pregoRootTopBarInsetsByOverlay = Expando<_PregoRootTopBarInsets>();

/// Publishes the current root inset for [owner]. A newly mounted publisher
/// becomes active; updates from an older mounted scaffold retain its place so
/// a covered route cannot displace the topmost route during a shared rebuild.
void publishPregoRootTopBarInset({
  required OverlayState overlay,
  required Object owner,
  required double inset,
}) {
  final insets = _pregoRootTopBarInsetsByOverlay[overlay] ??= _PregoRootTopBarInsets();
  insets.publish(owner: owner, inset: inset);
}

/// Removes [owner] and restores the previous mounted scaffold when the active
/// route unmounts.
void clearPregoRootTopBarInset({required OverlayState overlay, required Object owner}) {
  _pregoRootTopBarInsetsByOverlay[overlay]?.clear(owner: owner);
}

/// Returns the active top-bar inset published for [overlay], or `null` when no
/// Prego scaffold is mounted in that overlay.
double? pregoRootTopBarInsetFor(OverlayState overlay) => _pregoRootTopBarInsetsByOverlay[overlay]?.activeInset;

final class _PregoRootTopBarInsets() {
  final Map<Object, double> _mounted = <Object, double>{};

  double? get activeInset => _mounted.isEmpty ? null : _mounted.values.last;

  void publish({required Object owner, required double inset}) {
    _mounted[owner] = inset;
  }

  void clear({required Object owner}) {
    _mounted.remove(owner);
  }
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
