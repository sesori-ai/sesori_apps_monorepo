import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../routing/app_router.dart";

/// Mobile-shell lifecycle registration for the shared GoRouter route source.
@Singleton(as: RouteSource)
class MobileGoRouterRouteSource() extends GoRouterRouteSource implements Disposable {
  this : super(router: appRouter);

  @override
  FutureOr<void> onDispose() => dispose();
}
