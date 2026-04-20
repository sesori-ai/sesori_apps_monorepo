import "dart:async";

import "package:flutter/widgets.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/app_router.dart";

@LazySingleton(as: RouteDispatcher)
class GoRouterRouteDispatcher implements RouteDispatcher {
  final void Function(String route) _goRoute;
  final Future<void> Function(String route) _pushRoute;
  final Future<void> _routerReady;
  Future<void> _pendingReplace = Future<void>.value();

  GoRouterRouteDispatcher()
    : _goRoute = appRouter.go,
      _pushRoute = ((route) => appRouter.push<void>(route)),
      _routerReady = WidgetsBinding.instance.endOfFrame;

  @visibleForTesting
  GoRouterRouteDispatcher.test({
    required void Function(String route) goRoute,
    required Future<void> Function(String route) pushRoute,
    Future<void>? routerReady,
  }) : _goRoute = goRoute,
       _pushRoute = pushRoute,
       _routerReady = routerReady ?? Future<void>.value();

  @override
  void replaceStack({required RouteStack stack}) {
    _pendingReplace = _pendingReplace.then(
      (_) => _replaceStack(stack: stack),
      onError: (_, __) => _replaceStack(stack: stack),
    ).catchError((Object error, StackTrace stackTrace) {
      logw("Failed to replace notification route stack", error, stackTrace);
    });
  }

  Future<void> _replaceStack({required RouteStack stack}) async {
    if (stack.paths.isEmpty) {
      return;
    }

    await _routerReady;
    _goRoute(stack.paths.first);

    for (final routePath in stack.paths.skip(1)) {
      await _pushRoute(routePath);
    }
  }

  @visibleForTesting
  Future<void> flushPendingForTesting() => _pendingReplace;
}
