import "package:rxdart/rxdart.dart";

import "../routing/app_routes.dart";

/// Exposes the currently active [AppRouteDef] so pure-Dart code (cubits,
/// services) can check which page is visible without depending on Flutter
/// or GoRouter.
///
/// The Flutter app provides a concrete implementation backed by GoRouter.
/// See also: [LifecycleSource] for app-level lifecycle.
abstract interface class RouteSource {
  ValueStream<AppRouteDef?> get currentRouteStream;

  /// Concrete path of the topmost route, with path parameters substituted and
  /// no query string — for example `/projects/p1/sessions/s1`.
  ///
  /// [currentRouteStream] identifies only which *kind* of page is visible.
  /// Callers that must distinguish one session (or project) from another need
  /// the resolved path. Null before the router resolves its first
  /// configuration.
  String? get currentPath;
}

extension RouteSourceX on RouteSource {
  AppRouteDef? get currentRoute => currentRouteStream.value;
}
