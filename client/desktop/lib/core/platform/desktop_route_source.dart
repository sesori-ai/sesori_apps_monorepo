import "dart:async";

import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/desktop_router.dart";

/// Desktop-shell lifecycle registration for the shared GoRouter route source.
@Singleton(as: RouteSource)
class DesktopRouteSource extends GoRouterRouteSource implements Disposable {
  new() : super(router: desktopRouter);

  @visibleForTesting
  new test({required super.router});

  @override
  FutureOr<void> onDispose() => dispose();
}
