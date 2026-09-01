import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../features/auth_gate/auth_gate.dart";

/// Root navigator shared by desktop routes and app-wide presentation hosts.
final GlobalKey<NavigatorState> desktopRootNavigatorKey = GlobalKey<NavigatorState>();

/// Desktop cockpit router skeleton.
///
/// Step 14 establishes the module-core route boundary without moving feature
/// screens early. Steps 15–19 extend this table as their shared adaptive
/// screens land; until then the auth gate remains the one rooted destination.
final GoRouter desktopRouter = GoRouter(
  navigatorKey: desktopRootNavigatorKey,
  initialLocation: AppRouteDef.splash.path,
  routes: <RouteBase>[
    GoRoute(
      path: AppRouteDef.splash.path,
      builder: (BuildContext context, GoRouterState state) => const AuthGate(),
    ),
  ],
);
