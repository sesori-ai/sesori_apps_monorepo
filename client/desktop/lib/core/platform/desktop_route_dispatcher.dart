import "dart:async";

import "package:flutter/widgets.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop product-shell adapter for typed route-stack replacement requests.
///
/// The shell injects both its concrete router and its mounted-readiness fence;
/// shared core code sees only [RouteDispatcher] and [RouteStack].
class DesktopRouteDispatcher implements RouteDispatcher {
  final void Function(String route) _goRoute;
  final Future<void> Function(String route) _pushRoute;
  final VoidCallback _dismissPopups;
  final Future<void> _routerReady;
  Future<void> _pendingNavigation = Future<void>.value();

  new({required GoRouter router, required Future<void> routerReady})
    // ignore: no_slop_linter/avoid_raw_go_router, typed RouteStack boundary
    : _goRoute = router.go,
      // ignore: no_slop_linter/avoid_raw_go_router, typed RouteStack boundary
      _pushRoute = ((route) => router.push<void>(route)),
      _dismissPopups = (() {
        router.routerDelegate.navigatorKey.currentState?.popUntil((route) => route is! PopupRoute<Object?>);
      }),
      _routerReady = routerReady;

  @visibleForTesting
  new test({
    required void Function(String route) goRoute,
    required Future<void> Function(String route) pushRoute,
    required VoidCallback dismissPopups,
    required Future<void> routerReady,
  }) : _goRoute = goRoute,
       _pushRoute = pushRoute,
       _dismissPopups = dismissPopups,
       _routerReady = routerReady;

  @override
  void dismissPopups() => _enqueue(
    action: _dismissPopups,
    failureMessage: "Failed to dismiss desktop notification popups",
  );

  @override
  void replaceStack({required RouteStack stack}) {
    if (stack.paths.isEmpty) return;
    _enqueue(
      action: () {
        _goRoute(stack.paths.first);
        for (final routePath in stack.paths.skip(1)) {
          // Awaiting a push waits until that route is popped, so later stack
          // entries must be dispatched without awaiting completion.
          unawaited(_pushRoute(routePath));
        }
      },
      failureMessage: "Failed to replace the desktop notification route stack",
    );
  }

  void _enqueue({required VoidCallback action, required String failureMessage}) {
    _pendingNavigation = _pendingNavigation
        .then((_) async {
          await _routerReady;
          action();
        })
        .catchError((Object error, StackTrace stackTrace) {
          logw(failureMessage, error, stackTrace);
        });
  }

  @visibleForTesting
  Future<void> flushPendingForTesting() => _pendingNavigation;
}
