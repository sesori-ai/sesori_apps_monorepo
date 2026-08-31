import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../home/desktop_home.dart";
import "../login/login_screen.dart";

/// Root gate: constructs the [AuthGateCubit] and renders the surface that
/// matches the signed-in/out truth.
class const AuthGate({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthGateCubit>(
      create: (_) => AuthGateCubit(authSession: getIt(), logoutOrchestrator: getIt()),
      child: const AuthGateView(),
    );
  }
}

/// Renders the current [AuthGateState]; split from [AuthGate] so tests can
/// drive it with a stubbed cubit.
class const AuthGateView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AuthGateState state = context.watch<AuthGateCubit>().state;
    return BlocListener<AuthGateCubit, AuthGateState>(
      listenWhen: (previous, current) => previous is! AuthGateSignedIn && current is AuthGateSignedIn,
      listener: (context, _) {
        // The auth gate itself stays local-only. Once the signed-in
        // destination is entered, explicitly start the relay for token-only
        // restores that intentionally remain AuthInitial.
        unawaited(context.read<ConnectionOverlayCubit>().ensureConnected());
      },
      child: switch (state) {
        AuthGateChecking() => Scaffold(
          body: Center(child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)),
        ),
        AuthGateSignedOut() => const LoginScreen(),
        AuthGateSignedIn(:final user) => DesktopHome(user: user),
      },
    );
  }
}
