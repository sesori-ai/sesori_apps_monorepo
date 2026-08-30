import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "core/di/injection.dart";
import "features/auth_gate/auth_gate.dart";

/// Root widget of the Sesori desktop app.
///
/// Owns the eager desktop bridge controller, Prego themes, and sign-in gate.
class const SesoriDesktopApp({required final bool hiddenLaunch, super.key}) extends StatelessWidget {
  static const String _appTitle = "Sesori";

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BridgeControlCubit>(
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
          logoutTracker: getIt(),
          urlLauncher: getIt(),
          launchAtLogin: getIt(),
          hiddenLaunch: hiddenLaunch,
        );
        unawaited(cubit.initialize());
        return cubit;
      },
      child: MaterialApp(
        title: _appTitle,
        debugShowCheckedModeBanner: false,
        theme: buildPregoThemeData(brightness: Brightness.light),
        darkTheme: buildPregoThemeData(brightness: Brightness.dark),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    );
  }
}
