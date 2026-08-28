import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "core/di/injection.dart";
import "features/auth_gate/auth_gate.dart";

/// Root widget of the Sesori desktop app.
///
/// Renders the sign-in gate; the real v1 window contents (status, bridge
/// on/off) arrive with the tray + window slices.
class const SesoriDesktopApp({super.key}) extends StatelessWidget {
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
          applicationTerminator: getIt(),
        );
        unawaited(cubit.initialize());
        return cubit;
      },
      // The window remains visible when tray initialization reports
      // unavailable; step 7 adds hide/show control only for a proven tray.
      child: const MaterialApp(
        title: _appTitle,
        debugShowCheckedModeBanner: false,
        home: AuthGate(),
      ),
    );
  }
}
