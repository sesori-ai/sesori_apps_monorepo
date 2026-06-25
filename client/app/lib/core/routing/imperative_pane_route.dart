import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";

class ImperativePaneRouteScope extends InheritedWidget {
  final bool isImperative;

  const ImperativePaneRouteScope({
    super.key,
    required this.isImperative,
    required super.child,
  });

  static ImperativePaneRouteScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ImperativePaneRouteScope>();
  }

  @override
  bool updateShouldNotify(ImperativePaneRouteScope oldWidget) {
    return isImperative != oldWidget.isImperative;
  }
}

/// Returns true when the current go_router page came from an imperative push.
///
/// go_router stores imperatively pushed routes as [ImperativeRouteMatch] entries
/// that wrap the pushed route's normal match list. The pane uses this to keep
/// base declarative details chrome-free in split mode while still showing a back
/// button for pushed child details.
bool isImperativePaneRoute(BuildContext context) {
  final scoped = ImperativePaneRouteScope.maybeOf(context);
  if (scoped != null) return scoped.isImperative;

  return isImperativePaneState(context: context, state: GoRouterState.of(context));
}

bool isImperativePaneState({required BuildContext context, required GoRouterState state}) {
  // ignore: no_slop_linter/avoid_raw_go_router, reads router match stack for imperative route detection; no navigation is performed
  final router = GoRouter.maybeOf(context);
  if (router == null) return false;

  final matches = router.routerDelegate.currentConfiguration.matches;
  return _containsImperativePageKey(matches: matches, pageKey: state.pageKey);
}

bool _containsImperativePageKey({
  required List<RouteMatchBase> matches,
  required ValueKey<String> pageKey,
}) {
  for (final match in matches) {
    switch (match) {
      case ImperativeRouteMatch(pageKey: final routePageKey, :final matches):
        if (routePageKey == pageKey || _containsPageKey(matches: matches.matches, pageKey: pageKey)) {
          return true;
        }
      case ShellRouteMatch(:final matches):
        if (_containsImperativePageKey(matches: matches, pageKey: pageKey)) {
          return true;
        }
      case RouteMatch():
        break;
    }
  }
  return false;
}

bool _containsPageKey({
  required List<RouteMatchBase> matches,
  required ValueKey<String> pageKey,
}) {
  for (final match in matches) {
    switch (match) {
      case RouteMatch(pageKey: final routePageKey) when routePageKey == pageKey:
        return true;
      case ShellRouteMatch(:final matches):
        if (_containsPageKey(matches: matches, pageKey: pageKey)) {
          return true;
        }
      case ImperativeRouteMatch(:final matches):
        if (_containsPageKey(matches: matches.matches, pageKey: pageKey)) {
          return true;
        }
      case RouteMatch():
        break;
    }
  }
  return false;
}
