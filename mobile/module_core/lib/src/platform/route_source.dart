import "package:rxdart/rxdart.dart";

import "../routing/app_routes.dart";

/// Exposes the currently active [AppRoute] so pure-Dart code (cubits, services)
/// can check which page is visible without depending on Flutter or GoRouter.
///
/// The Flutter app provides a concrete implementation backed by GoRouter.
/// See also: [LifecycleSource] for app-level lifecycle.
abstract interface class RouteSource {
  ValueStream<AppRoute?> get currentRouteStream;
}

extension RouteSourceX on RouteSource {
  AppRoute? get currentRoute => currentRouteStream.value;
}
