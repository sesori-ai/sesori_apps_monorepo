import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Desktop sign-in: browser + poll OAuth via the shared [LoginCubit].
///
/// GitHub and Google only for now — mobile's Apple path is native-iOS-only,
/// and email login is not part of the desktop browser-poll slice.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (_) => LoginCubit(getIt(), getIt(), getIt(), getIt()),
      child: const LoginView(),
    );
  }
}

/// Renders the [LoginState]; split from [LoginScreen] so tests can drive it
/// with a stubbed cubit.
class LoginView extends StatelessWidget {
  const LoginView({super.key});

  static const String _title = "Sesori";
  static const String _subtitle = "Sign in to continue";
  static const String _githubButton = "Continue with GitHub";
  static const String _googleButton = "Continue with Google";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: BlocBuilder<LoginCubit, LoginState>(
            builder: (context, state) {
              // LoginSuccess counts as busy: the auth gate flips a moment
              // later, and re-enabled buttons would flash + allow a dup tap.
              final bool isBusy = state is LoginAuthenticating || state is LoginPolling || state is LoginSuccess;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(_subtitle, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: isBusy ? null : () => unawaited(context.read<LoginCubit>().loginWithProvider(AuthProvider.github)),
                    child: const Text(_githubButton),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: isBusy ? null : () => unawaited(context.read<LoginCubit>().loginWithProvider(AuthProvider.google)),
                    child: const Text(_googleButton),
                  ),
                  const SizedBox(height: 24),
                  _LoginStatus(state: state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginStatus extends StatelessWidget {
  const _LoginStatus({required this.state});

  final LoginState state;

  static const String _authenticating = "Contacting Sesori…";
  static const String _polling = "Finish signing in using your browser…";
  static const String _timeout = "Sign-in timed out. Please try again.";
  static const String _browserOpenFailed = "Couldn't open your browser. Open it manually and try again.";
  static const String _genericFailure = "Sign-in failed. Please try again.";

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return switch (state) {
      LoginIdle() || LoginSuccess() => const SizedBox.shrink(),
      LoginAuthenticating() => const _StatusRow(message: _authenticating),
      LoginPolling() => const _StatusRow(message: _polling),
      LoginTimeout() => Text(_timeout, textAlign: TextAlign.center, style: TextStyle(color: colors.error)),
      LoginFailed(:final reason) => Text(
        switch (reason) {
          LoginFailedReason.browserOpenFailed => _browserOpenFailed,
          LoginFailedReason.emailRequired ||
          LoginFailedReason.passwordRequired ||
          LoginFailedReason.appleIdTokenMissing ||
          LoginFailedReason.unknown => _genericFailure,
        },
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.error),
      ),
    };
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Flexible(child: Text(message)),
      ],
    );
  }
}
