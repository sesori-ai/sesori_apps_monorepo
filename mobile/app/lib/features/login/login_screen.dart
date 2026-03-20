import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(getIt<OAuthFlowProvider>(), getIt<UrlLauncher>()),
      child: const _LoginScreenBody(),
    );
  }
}

class _LoginScreenBody extends StatefulWidget {
  const _LoginScreenBody();

  @override
  State<_LoginScreenBody> createState() => _LoginScreenBodyState();
}

class _LoginScreenBodyState extends State<_LoginScreenBody> {
  Future<void> _loginWithProvider(OAuthProvider provider) async {
    await context.read<LoginCubit>().loginWithProvider(provider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;
    final state = context.watch<LoginCubit>().state;
    final isLoading = state is LoginAuthenticating || state is LoginAwaitingCallback;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: .center,
              children: [
                const SizedBox(height: 48),

                // Hero icon
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withAlpha(102),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.terminal_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  loc.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Text(
                  loc.loginSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: .center,
                ),
                const SizedBox(height: 48),

                // GitHub button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : () => _loginWithProvider(OAuthProvider.github),
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.code_rounded, size: 20),
                    label: Text(loc.loginWithGithub),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF24292F),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF24292F).withAlpha(153),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Google button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: isLoading ? null : () => _loginWithProvider(OAuthProvider.google),
                    icon: isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        : Text(
                            "G",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isLoading
                                  ? theme.colorScheme.onSurface.withAlpha(97)
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                    label: Text(loc.loginWithGoogle),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                      side: BorderSide(color: theme.colorScheme.outline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                switch (state) {
                  LoginAuthenticating() => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      loc.loginAuthenticating,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: .center,
                    ),
                  ),
                  LoginAwaitingCallback() => Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      loc.loginAwaitingCallback,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: .center,
                    ),
                  ),
                  _ => const SizedBox.shrink(),
                },

                // Error state
                switch (state) {
                  LoginFailed(:final error) => Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Card(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _getErrorMessage(loc, error),
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _ => const SizedBox.shrink(),
                },

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getErrorMessage(AppLocalizations loc, String error) {
    return switch (error) {
      "loginBrowserOpenFailed" => loc.loginBrowserOpenFailed,
      _ => loc.loginError,
    };
  }
}
