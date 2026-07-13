import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "../../core/di/injection.dart";
import "../home/home_placeholder.dart";
import "../login/login_screen.dart";

/// Root gate: constructs the [AuthGateCubit] and renders the surface that
/// matches the signed-in/out truth.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthGateCubit>(
      create: (_) => AuthGateCubit(getIt()),
      child: const AuthGateView(),
    );
  }
}

/// Renders the current [AuthGateState]; split from [AuthGate] so tests can
/// drive it with a stubbed cubit.
class AuthGateView extends StatelessWidget {
  const AuthGateView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthGateCubit, AuthGateState>(
      builder: (context, state) {
        return switch (state) {
          AuthGateChecking() => const Scaffold(body: Center(child: CircularProgressIndicator())),
          AuthGateSignedOut() => const LoginScreen(),
          AuthGateSignedIn(:final user) => HomePlaceholder(user: user),
        };
      },
    );
  }
}
