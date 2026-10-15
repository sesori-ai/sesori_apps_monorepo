import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Mobile-shell composition for the shared computers view.
class const ComputersScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ComputerSwitcherCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
        BlocProvider(
          create: (_) => ComputersCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) => ComputersView(
          chrome: SettingsPageOwnBar(
            title: context.loc.computersTitle,
            connectionBanner: ConnectionBanner.maybeFor(context),
          ),
          // The dispatcher lands on the new computer's Projects root, which
          // replaces this page.
          onSwitchComputer: ({required bridgeId, required source}) =>
              unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source)),
          // The phone runs no bridge of its own.
          localBridgeTurnOffActionBuilder: null,
        ),
      ),
    );
  }
}
