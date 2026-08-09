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

  /// Resolved location of the topmost route — path parameters substituted and
  /// the query string kept, for example
  /// `/projects/p1/sessions/s1?readOnly=true`.
  ///
  /// [currentRouteStream] identifies only which *kind* of page is visible.
  /// Callers that must distinguish one session from another, or one variant of
  /// a screen from another, need the resolved location. The query is part of
  /// that: `readOnly` alone separates the editable session detail from the
  /// read-only one. Null before the router resolves its first configuration.
  String? get currentLocation;
}

extension RouteSourceX on RouteSource {
  AppRouteDef? get currentRoute => currentRouteStream.value;
}
