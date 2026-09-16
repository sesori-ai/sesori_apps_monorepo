import "dart:async";

import "package:flutter/widgets.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/app_router.dart";

@LazySingleton(as: RouteDispatcher)
class GoRouterRouteDispatcher implements RouteDispatcher {
  final void Function(String route) _goRoute;
  final Future<void> Function(String route) _pushRoute;
  final VoidCallback _dismissPopups;
  final Future<void> _routerReady;
  Future<void> _pendingNavigation = Future<void>.value();

  new()
    : _goRoute = appRouter.go,
      // ignore: no_slop_linter/avoid_raw_go_router
      _pushRoute = ((route) => appRouter.push<void>(route)),
      _dismissPopups = (() {
        appRouter.routerDelegate.navigatorKey.currentState?.popUntil((route) => route is! PopupRoute<Object?>);
      }),
      _routerReady = WidgetsBinding.instance.endOfFrame;

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
    failureMessage: "Failed to dismiss notification popups",
  );

  @override
  void replaceStack({required RouteStack stack}) {
    if (stack.paths.isEmpty) return;
    _enqueue(
      action: () {
        _goRoute(stack.paths.first);
        for (final routePath in stack.paths.skip(1)) {
          // Awaiting a push waits until that route is popped.
          unawaited(_pushRoute(routePath));
        }
      },
      failureMessage: "Failed to replace notification route stack",
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
