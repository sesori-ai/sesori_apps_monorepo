import "package:flutter/foundation.dart";
import "package:go_router/go_router.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Surface-neutral [RouteSource] backed by a product shell's [GoRouter].
///
/// Product shells own their route tables and register a thin lifecycle adapter
/// around this source. Keeping the route-tree traversal here gives mobile and
/// desktop identical current-route semantics as cockpit screens move between
/// them.
class GoRouterRouteSource._({required final GoRouterDelegate _routerDelegate}) implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRouteStream = BehaviorSubject<AppRouteDef?>.seeded(
    _matchRoute(_currentPath(_routerDelegate.currentConfiguration)),
  );

  new({required GoRouter router}) : this._(routerDelegate: router.routerDelegate);

  this {
    _routerDelegate.addListener(_onRouteChanged);
  }

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRouteStream.stream;

  @override
  String? get currentLocation => _currentLocation(_routerDelegate.currentConfiguration);

  Future<void> dispose() async {
    _routerDelegate.removeListener(_onRouteChanged);
    await _currentRouteStream.close();
  }

  void _onRouteChanged() {
    final AppRouteDef? matchedRoute = _matchRoute(_currentPath(_routerDelegate.currentConfiguration));
    if (_currentRouteStream.valueOrNull == matchedRoute) {
      return;
    }
    _currentRouteStream.add(matchedRoute);
  }

  /// The path of the topmost match, including imperatively pushed ones.
  ///
  /// [RouteMatchList.uri] deliberately omits [ImperativeRouteMatch] entries,
  /// so it still reports the last `go`/`replace` destination while a `push`ed
  /// screen is visible. Walking the match tree from the top reports what the
  /// user is actually looking at.
  static String? _currentPath(RouteMatchList configuration) => _topMatchedLocation(configuration.matches);

  /// As [_currentPath], but retaining the query string.
  ///
  /// A match carries no query of its own; the owning [RouteMatchList] does via
  /// [RouteMatchList.uri]. An imperatively pushed route brings its own list, so
  /// descending into it reports the pushed location's query rather than the
  /// last `go`/`replace` destination.
  static String? _currentLocation(RouteMatchList configuration) =>
      _topLocation(matches: configuration.matches, owner: configuration);

  static String? _topLocation({
    required List<RouteMatchBase> matches,
    required RouteMatchList owner,
  }) {
    for (final RouteMatchBase match in matches.reversed) {
      final String? location = switch (match) {
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
    for (final RouteMatchBase match in matches.reversed) {
      final String? location = switch (match) {
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

  /// Routes sorted by match precedence, computed once because the route table
  /// is static.
  static final List<AppRouteDef> _orderedRoutes = AppRouteDef.values.toList()
    ..sort((first, second) => _compareMatchPrecedence(first: first, second: second));

  /// A literal segment beats a parameter at the first place paths disagree, so
  /// `/projects/:id/sessions/new` is tried before
  /// `/projects/:id/sessions/:sessionId`. Failing that, the deeper path wins.
  static int _compareMatchPrecedence({required AppRouteDef first, required AppRouteDef second}) {
    final List<String> firstSegments = first.path.split("/");
    final List<String> secondSegments = second.path.split("/");
    for (var index = 0; index < firstSegments.length && index < secondSegments.length; index++) {
      final bool firstIsParameter = firstSegments[index].startsWith(":");
      if (firstIsParameter != secondSegments[index].startsWith(":")) return firstIsParameter ? 1 : -1;
    }
    return secondSegments.length.compareTo(firstSegments.length);
  }

  static final Map<AppRouteDef, RegExp> _regexByRoute = <AppRouteDef, RegExp>{
    for (final AppRouteDef route in AppRouteDef.values) route: _buildRegex(route),
  };

  @visibleForTesting
  static AppRouteDef? matchRouteForTesting(String path) => _matchRoute(path);

  static AppRouteDef? _matchRoute(String? path) {
    if (path == null) return null;
    for (final AppRouteDef route in _orderedRoutes) {
      final RegExp? regex = _regexByRoute[route];
      if (regex != null && regex.hasMatch(path)) {
        return route;
      }
    }
    return null;
  }

  static RegExp _buildRegex(AppRouteDef route) {
    final String regexPath = route.path
        .split("/")
        .map((segment) => segment.startsWith(":") ? "[^/]+" : RegExp.escape(segment))
        .join("/");

    return RegExp("^$regexPath\$");
  }
}
