import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/di/injection.dart";
import "core/widgets/desktop_connection_banner.dart";
import "core/widgets/desktop_sse_toast_listener.dart";
import "features/auth_gate/auth_gate.dart";

final GlobalKey<NavigatorState> _desktopNavigatorKey = GlobalKey<NavigatorState>();

/// Root widget of the Sesori desktop app.
///
/// Owns the eager desktop bridge controller, relay-client connection effects,
/// Prego themes, and sign-in gate.
class const SesoriDesktopApp({required final bool hiddenLaunch, super.key}) extends StatelessWidget {
  static const String _appTitle = "Sesori";

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<ConnectionOverlayCubit>(
          lazy: false,
          create: (_) => ConnectionOverlayCubit(
            getIt<ConnectionService>(),
            getIt<RegisteredBridgesService>(),
          ),
        ),
        BlocProvider<SseToastCubit>(
          lazy: false,
          create: (_) => SseToastCubit(
            connectionService: getIt<ConnectionService>(),
            routeSource: getIt<RouteSource>(),
          ),
        ),
        BlocProvider<BridgeControlCubit>(
          lazy: false,
          create: (_) {
            final BridgeControlCubit cubit = BridgeControlCubit(
              processService: getIt(),
              statusTracker: getIt(),
              systemTray: getIt(),
              windowHost: getIt(),
              applicationTerminator: getIt(),
              logRepository: getIt(),
              instanceService: getIt(),
              takeoverOrchestrator: getIt(),
              logoutTracker: getIt(),
              urlLauncher: getIt(),
              launchAtLogin: getIt(),
              hiddenLaunch: hiddenLaunch,
            );
            unawaited(cubit.initialize());
            return cubit;
          },
        ),
      ],
      child: MaterialApp(
        title: _appTitle,
        debugShowCheckedModeBanner: false,
        navigatorKey: _desktopNavigatorKey,
        theme: buildPregoThemeData(brightness: Brightness.light),
        darkTheme: buildPregoThemeData(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
        builder: (context, child) => _DesktopRootEffects(
          navigatorKey: _desktopNavigatorKey,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class const _DesktopRootEffects({required final Widget child, required final GlobalKey<NavigatorState> navigatorKey})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DesktopSseToastListener(
      navigatorKey: navigatorKey,
      child: Column(
        children: <Widget>[
          DesktopConnectionBanner.maybeFor(context) ?? const SizedBox.shrink(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
