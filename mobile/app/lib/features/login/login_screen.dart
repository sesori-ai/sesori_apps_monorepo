import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../l10n/app_localizations.dart";
import "email_login_form.dart";
import "login_provider_buttons.dart";

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(
        getIt<OAuthFlowProvider>(),
        getIt<UrlLauncher>(),
        getIt<AuthSession>(),
      ),
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
  bool _showEmailForm = false;

  Future<void> _loginWithProvider(OAuthProvider provider) async {
    await context.read<LoginCubit>().loginWithProvider(provider);
  }

  void _showEmailLogin() {
    setState(() {
      _showEmailForm = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final loc = context.loc;
    final state = context.watch<LoginCubit>().state;
    final isLoading = state is LoginAuthenticating || state is LoginAwaitingCallback;

    return Scaffold(
      body: BlocListener<LoginCubit, LoginState>(
        listenWhen: (previous, current) => current is LoginSuccess,
        listener: (context, state) {
          // Relay connection is handled reactively: AuthManager emits
          // AuthState.authenticated → ConnectionService connects. The
          // connection overlay shows progress; navigation proceeds immediately.
          context.goRoute(const AppRoute.projects());
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: zyra.colors.bgBrandSolid.withAlpha(102),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.terminal_rounded,
                      size: 56,
                      color: zyra.colors.bgBrandSolid,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.appTitle,
                    style: zyra.textTheme.textXl.bold,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loc.loginSubtitle,
                    style: zyra.textTheme.textSm.regular.copyWith(
                      color: zyra.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  LoginProviderButtons(
                    isLoading: isLoading,
                    showEmailForm: _showEmailForm,
                    onGithubSelected: () => _loginWithProvider(AuthProvider.github),
                    onGoogleSelected: () => _loginWithProvider(AuthProvider.google),
                    onShowEmailForm: _showEmailLogin,
                  ),
                  if (_showEmailForm) ...[
                    const SizedBox(height: 8),
                    EmailLoginForm(
                      key: ValueKey(_showEmailForm),
                    ),
                  ],
                  switch (state) {
                    LoginAuthenticating() => Padding(
                      padding: const EdgeInsetsDirectional.only(top: 16),
                      child: Text(
                        loc.loginAuthenticating,
                        style: zyra.textTheme.textSm.regular.copyWith(
                          color: zyra.colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    LoginAwaitingCallback() => Padding(
                      padding: const EdgeInsetsDirectional.only(top: 16),
                      child: Text(
                        loc.loginAwaitingCallback,
                        style: zyra.textTheme.textSm.regular.copyWith(
                          color: zyra.colors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    LoginIdle() => const SizedBox.shrink(),
                    LoginFailed() => const SizedBox.shrink(),
                    LoginSuccess() => const SizedBox.shrink(),
                  },
                  switch (state) {
                    LoginFailed(:final error) => Padding(
                      padding: const EdgeInsetsDirectional.only(top: 24),
                      child: Card(
                        color: zyra.colors.bgErrorPrimary,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: zyra.colors.fgErrorPrimary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getErrorMessage(loc: loc, error: error),
                                  style: zyra.textTheme.textSm.regular.copyWith(
                                    color: zyra.colors.fgErrorPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    LoginIdle() => const SizedBox.shrink(),
                    LoginAuthenticating() => const SizedBox.shrink(),
                    LoginAwaitingCallback() => const SizedBox.shrink(),
                    LoginSuccess() => const SizedBox.shrink(),
                  },
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getErrorMessage({required AppLocalizations loc, required String error}) {
    return switch (error) {
      "loginBrowserOpenFailed" => loc.loginBrowserOpenFailed,
      _ => loc.loginError,
    };
  }
}
