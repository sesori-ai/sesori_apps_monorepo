import "dart:async";

import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:go_router/go_router.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/app_router.dart";

@Singleton(as: RouteSource)
class GoRouterRouteSource._({required final GoRouterDelegate _routerDelegate}) implements RouteSource, Disposable {
  final BehaviorSubject<AppRouteDef?> _currentRouteStream = BehaviorSubject.seeded(
    _matchRoute(_currentPath(_routerDelegate.currentConfiguration)),
  );

  new() : this._(routerDelegate: appRouter.routerDelegate);

  @visibleForTesting
  new test({required GoRouter router}) : this._(routerDelegate: router.routerDelegate);

  this {
    _routerDelegate.addListener(_onRouteChanged);
  }

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRouteStream.stream;

  @override
  String? get currentLocation => _currentLocation(_routerDelegate.currentConfiguration);

  @override
  FutureOr<void> onDispose() {
    _routerDelegate.removeListener(_onRouteChanged);
    _currentRouteStream.close();
  }

  void _onRouteChanged() {
    final matchedRoute = _matchRoute(_currentPath(_routerDelegate.currentConfiguration));
    if (_currentRouteStream.valueOrNull == matchedRoute) {
      return;
    }
    _currentRouteStream.add(matchedRoute);
  }

  /// The path of the topmost match, including imperatively pushed ones.
  ///
  /// [RouteMatchList.uri] deliberately omits [ImperativeRouteMatch] entries, so
  /// it still reports the last `go`/`replace` destination while a `push`ed
  /// screen — settings, new session, diffs — is the one on screen. Walking the
  /// match tree from the top instead reports what the user is actually looking
  /// at.
  static String? _currentPath(RouteMatchList configuration) => _topMatchedLocation(configuration.matches);

  /// As [_currentPath], but keeping the query string.
  ///
  /// A match on its own carries no query — only the [RouteMatchList] owning it
  /// does, via [RouteMatchList.uri]. An imperatively pushed route brings its
  /// own list, so descending into it reports the pushed location's query
  /// rather than the last `go`/`replace` one.
  static String? _currentLocation(RouteMatchList configuration) =>
      _topLocation(matches: configuration.matches, owner: configuration);

  static String? _topLocation({
    required List<RouteMatchBase> matches,
    required RouteMatchList owner,
  }) {
    for (final match in matches.reversed) {
      final location = switch (match) {
        ImperativeRouteMatch(:final matches) => _topLocation(matches: matches.matches, owner: matches),
        ShellRouteMatch(:final matches) => _topLocation(matches: matches, owner: owner),
        RouteMatch() => owner.uri.toString(),
        _ => null,
      };
      if (location != null) return location;
    }
    return null;
  }

  static String? _topMatchedLocation(List<RouteMatchBase> matches) {
    for (final match in matches.reversed) {
      final location = switch (match) {
        ImperativeRouteMatch(:final matches) => _topMatchedLocation(matches.matches),
        ShellRouteMatch(:final matches) => _topMatchedLocation(matches),
        RouteMatch(:final matchedLocation) => matchedLocation,
        // go_router's match hierarchy is not sealed; unknown kinds contribute
        // no path of their own.
        _ => null,
      };
      if (location != null) return location;
    }
    return null;
  }

  /// Routes sorted by match precedence, computed once — the route table is
  /// static.
  static final _orderedRoutes = AppRouteDef.values.toList()
    ..sort((a, b) => _compareMatchPrecedence(first: a, second: b));

  /// A literal segment beats a parameter at the first place the two paths
  /// disagree, so `/projects/:id/sessions/new` is tried before
  /// `/projects/:id/sessions/:sessionId` — otherwise `new` would be read as a
  /// session id. Failing that the deeper path wins, so `/projects/:id/sessions`
  /// is tried before `/projects`.
  static int _compareMatchPrecedence({required AppRouteDef first, required AppRouteDef second}) {
    final firstSegments = first.path.split("/");
    final secondSegments = second.path.split("/");
    for (var index = 0; index < firstSegments.length && index < secondSegments.length; index++) {
      final firstIsParameter = firstSegments[index].startsWith(":");
      if (firstIsParameter != secondSegments[index].startsWith(":")) return firstIsParameter ? 1 : -1;
    }
    return secondSegments.length.compareTo(firstSegments.length);
  }

  static final _regexByRoute = {
    for (final route in AppRouteDef.values) route: _buildRegex(route),
  };

  @visibleForTesting
  static AppRouteDef? matchRouteForTesting(String path) => _matchRoute(path);

  static AppRouteDef? _matchRoute(String? path) {
    if (path == null) return null;
    for (final route in _orderedRoutes) {
      if (_regexByRoute[route] case final regex?) {
        if (!regex.hasMatch(path)) {
          continue;
        }
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
