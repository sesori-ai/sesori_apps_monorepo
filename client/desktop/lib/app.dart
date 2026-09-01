import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/di/injection.dart";
import "core/routing/desktop_router.dart";

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
      child: MaterialApp.router(
        title: _appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildPregoThemeData(brightness: Brightness.light),
        darkTheme: buildPregoThemeData(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: desktopRouter,
        builder: (context, child) => _DesktopRootEffects(
          navigatorKey: desktopRootNavigatorKey,
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
    return SseToastListener(
      navigatorKey: navigatorKey,
      child: Column(
        children: <Widget>[
          ConnectionBanner.maybeFor(context) ?? const SizedBox.shrink(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
