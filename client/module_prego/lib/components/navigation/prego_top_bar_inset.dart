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

/// Live top-bar geometry: the fixed bar inset plus the inline banner's
/// current, possibly animating, height.
typedef PregoTopBarGeometry = ({double baseInset, ValueListenable<double> bannerHeight});

/// Returns the live top-bar geometry of the enclosing Prego scaffold, or
/// `null` when [context] is not below one. Reads without registering a
/// dependency, so it is safe to call outside build.
PregoTopBarGeometry? pregoTopBarGeometryOf({required BuildContext context}) {
  final scope = context.getInheritedWidgetOfExactType<PregoTopBarInsetScope>();
  if (scope == null) return null;
  return (baseInset: scope.baseInset, bannerHeight: scope.bannerHeight);
}

final Expando<_PregoRootTopBarInsets> _pregoRootTopBarInsetsByOverlay = Expando<_PregoRootTopBarInsets>();

/// Opaque identity for one mounted root-inset publisher. This seam is kept out
/// of the package barrel and used only by Prego scaffold/presenter internals.
final class PregoRootTopBarInsetOwner();

/// Publishes the current root geometry for [owner]. A newly mounted publisher
/// becomes active; updates from an older mounted scaffold retain its place so
/// a covered route cannot displace the topmost route during a shared rebuild.
void publishPregoRootTopBarInset({
  required OverlayState overlay,
  required PregoRootTopBarInsetOwner owner,
  required PregoTopBarGeometry geometry,
}) {
  final insets = _pregoRootTopBarInsetsByOverlay[overlay] ??= _PregoRootTopBarInsets();
  insets.publish(owner: owner, geometry: geometry);
}

/// Removes [owner] and restores the previous mounted scaffold when the active
/// route unmounts.
void clearPregoRootTopBarInset({required OverlayState overlay, required PregoRootTopBarInsetOwner owner}) {
  _pregoRootTopBarInsetsByOverlay[overlay]?.clear(owner: owner);
}

/// Returns the active top-bar geometry published for [overlay], or `null` when
/// no Prego scaffold is mounted in that overlay.
PregoTopBarGeometry? pregoRootTopBarInsetFor(OverlayState overlay) =>
    _pregoRootTopBarInsetsByOverlay[overlay]?.activeGeometry;

final class _PregoRootTopBarInsets() {
  final Map<PregoRootTopBarInsetOwner, PregoTopBarGeometry> _mounted =
      <PregoRootTopBarInsetOwner, PregoTopBarGeometry>{};

  PregoTopBarGeometry? get activeGeometry => _mounted.isEmpty ? null : _mounted.values.last;

  void publish({required PregoRootTopBarInsetOwner owner, required PregoTopBarGeometry geometry}) {
    _mounted[owner] = geometry;
  }

  void clear({required PregoRootTopBarInsetOwner owner}) {
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
