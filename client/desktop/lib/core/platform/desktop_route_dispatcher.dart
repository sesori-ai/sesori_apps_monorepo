import "dart:async";

import "package:flutter/widgets.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/desktop_router.dart";

/// Desktop implementation of typed route-stack replacement requests.
@LazySingleton(as: RouteDispatcher)
class DesktopRouteDispatcher implements RouteDispatcher {
  final void Function(String route) _goRoute;
  final Future<void> Function(String route) _pushRoute;
  final Future<void> _routerReady;
  Future<void> _pendingReplace = Future<void>.value();

  new()
    // ignore: no_slop_linter/avoid_raw_go_router, typed RouteStack boundary
    : _goRoute = desktopRouter.go,
      // ignore: no_slop_linter/avoid_raw_go_router, typed RouteStack boundary
      _pushRoute = ((route) => desktopRouter.push<void>(route)),
      _routerReady = WidgetsBinding.instance.endOfFrame;

  @visibleForTesting
  new test({
    required void Function(String route) goRoute,
    required Future<void> Function(String route) pushRoute,
    required Future<void> routerReady,
  }) : _goRoute = goRoute,
       _pushRoute = pushRoute,
       _routerReady = routerReady;

  @override
  void replaceStack({required RouteStack stack}) {
    _pendingReplace = _pendingReplace
        .then(
          (_) => _replaceStack(stack: stack),
          onError: (_, _) => _replaceStack(stack: stack),
        )
        .catchError((Object error, StackTrace stackTrace) {
          logw("Failed to replace the desktop notification route stack", error, stackTrace);
        });
  }

  Future<void> _replaceStack({required RouteStack stack}) async {
    if (stack.paths.isEmpty) {
      return;
    }
    await _routerReady;
    _goRoute(stack.paths.first);
    for (final routePath in stack.paths.skip(1)) {
      // Awaiting a push waits until that route is popped, so later stack
      // entries must be dispatched without awaiting completion.
      unawaited(_pushRoute(routePath));
    }
  }

  @visibleForTesting
  Future<void> flushPendingForTesting() => _pendingReplace;
}
