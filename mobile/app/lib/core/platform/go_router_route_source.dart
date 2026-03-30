import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/app_router.dart";

@Singleton(as: RouteSource)
class GoRouterRouteSource implements RouteSource, Disposable {
  final BehaviorSubject<AppRouteDef?> _currentRouteStream;

  GoRouterRouteSource()
    : _currentRouteStream = BehaviorSubject.seeded(
        _matchRoute(appRouter.routerDelegate.currentConfiguration.uri.path),
      ) {
    appRouter.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRouteStream.stream;

  @override
  FutureOr<void> onDispose() {
    appRouter.routerDelegate.removeListener(_onRouteChanged);
    _currentRouteStream.close();
  }

  void _onRouteChanged() {
    final matchedRoute = _matchRoute(appRouter.routerDelegate.currentConfiguration.uri.path);
    if (_currentRouteStream.valueOrNull == matchedRoute) {
      return;
    }
    _currentRouteStream.add(matchedRoute);
  }

  /// Routes sorted longest-path-first so `/projects/:id/sessions` is tried
  /// before `/projects`. Computed once — the route table is static.
  static final _orderedRoutes = AppRouteDef.values.toList()..sort((a, b) => b.path.length.compareTo(a.path.length));

  static final _regexByRoute = {
    for (final route in AppRouteDef.values) route: _buildRegex(route),
  };

  static AppRouteDef? _matchRoute(String path) {
    for (final route in _orderedRoutes) {
      if (_regexByRoute[route]!.hasMatch(path)) {
        return route;
      }
    }
    return null;
  }

  static RegExp _buildRegex(AppRouteDef route) {
    final regexPath = route.path
        .split("/")
        .map((segment) {
          if (segment.startsWith(":")) {
            return "[^/]+";
          }
          return RegExp.escape(segment);
        })
        .join("/");

    return RegExp("^$regexPath\$");
  }
}
