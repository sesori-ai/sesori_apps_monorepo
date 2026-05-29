import "dart:convert";
import "dart:math";

import "package:crypto/crypto.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/markdown_styles.dart";
import "../../core/widgets/sesori_background_widget.dart";
import "../../core/widgets/sesori_logo.dart";
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
        getIt<LifecycleSource>(),
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

  Future<void> _loginWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        if (mounted) {
          context.read<LoginCubit>().onMissingAppleIdToken();
        }
        return;
      }

      if (!mounted) return;

      await context.read<LoginCubit>().loginWithApple(
        idToken: idToken,
        nonce: rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        logd("Apple Sign-In cancelled by user");
        return;
      }
      if (mounted) {
        context.read<LoginCubit>().onAppleSignInError();
      }
    } on Exception catch (_) {
      if (mounted) {
        context.read<LoginCubit>().onAppleSignInError();
      }
    }
  }

  String _generateNonce({int length = 32}) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
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
    final isLoading = state is LoginAuthenticating || state is LoginAwaitingConfirmation || state is LoginPolling;

    return Scaffold(
      body: BlocListener<LoginCubit, LoginState>(
        listenWhen: (previous, current) => current is LoginSuccess,
        listener: (context, state) {
          // Relay connection is handled reactively: AuthManager emits
          // AuthState.authenticated → ConnectionService connects. The
          // connection overlay shows progress; navigation proceeds immediately.
          context.goRoute(const AppRoute.projects());
        },
        child: Stack(
          children: [
            const Positioned.fill(child: SesoriBackgroundWidget()),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisSize: .min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Material(
                            type: MaterialType.transparency,
                            child: Column(
                              mainAxisSize: .min,
                              children: [
                                const SesoriLogo(),
                                Text(
                                  loc.loginTitle,
                                  style: zyra.textTheme.textSm.regular,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc.loginSubtitle,
                                  style: zyra.textTheme.displaySm.bold,
                                ),
                              ],
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(32, 86, 32, 24),
                              child: Column(
                                mainAxisSize: .min,
                                children: [
                                  const SizedBox(height: 24),
                                  LoginProviderButtons(
                                    isLoading: isLoading,
                                    showEmailForm: _showEmailForm,
                                    showApple: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
                                    onGithubSelected: () => _loginWithProvider(AuthProvider.github),
                                    onAppleSelected: _loginWithApple,
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
                                    LoginAwaitingConfirmation(:final userCode) => Padding(
                                      padding: const EdgeInsetsDirectional.only(top: 16),
                                      child: Column(
                                        children: [
                                          Text(
                                            loc.loginAwaitingConfirmation(userCode),
                                            style: zyra.textTheme.textSm.regular.copyWith(
                                              color: zyra.colors.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: zyra.colors.bgBrandSolid.withAlpha(26),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: zyra.colors.bgBrandSolid.withAlpha(77),
                                              ),
                                            ),
                                            child: Text(
                                              userCode,
                                              style: zyra.textTheme.textXl.bold.copyWith(
                                                color: zyra.colors.bgBrandSolid,
                                                letterSpacing: 4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    LoginPolling(:final userCode) => Padding(
                                      padding: const EdgeInsetsDirectional.only(top: 16),
                                      child: Column(
                                        children: [
                                          Text(
                                            loc.loginPolling,
                                            style: zyra.textTheme.textSm.regular.copyWith(
                                              color: zyra.colors.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          if (userCode != null) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: zyra.colors.bgBrandSolid.withAlpha(26),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: zyra.colors.bgBrandSolid.withAlpha(77),
                                                ),
                                              ),
                                              child: Text(
                                                userCode,
                                                style: zyra.textTheme.textXl.bold.copyWith(
                                                  color: zyra.colors.bgBrandSolid,
                                                  letterSpacing: 4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    LoginTimeout() => Padding(
                                      padding: const EdgeInsetsDirectional.only(top: 16),
                                      child: Text(
                                        loc.loginTimeout,
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
                                    LoginFailed() => const SizedBox.shrink(),
                                    LoginTimeout() => Padding(
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
                                                  loc.loginTimeout,
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
                                    LoginAwaitingConfirmation() => const SizedBox.shrink(),
                                    LoginPolling() => const SizedBox.shrink(),
                                    LoginSuccess() => const SizedBox.shrink(),
                                  },
                                  const SizedBox(height: 22),
                                  MarkdownBody(
                                    data: loc.loginAgreementText,
                                    onTapLink: handleMarkdownLinkTap,
                                    styleSheet: buildAgreementMarkdownStyleSheet(zyra: zyra),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: _LoginErrorBanner(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating error notification anchored to the top of the login screen.
///
/// Matches the Figma `zyraAlertsNotifications` placement: it slides down
/// into view from above (snackbar-style) while the [LoginCubit] state is
/// [LoginFailed], and slides back up out of view otherwise. The last
/// failure reason is retained so the message stays readable during the
/// slide-out animation.
class _LoginErrorBanner extends StatefulWidget {
  const _LoginErrorBanner({required this.state});

  final LoginState state;

  @override
  State<_LoginErrorBanner> createState() => _LoginErrorBannerState();
}

class _LoginErrorBannerState extends State<_LoginErrorBanner> {
  static const _animationDuration = Duration(milliseconds: 250);

  LoginFailedReason? _lastReason;

  @override
  void initState() {
    super.initState();
    _captureReason();
  }

  @override
  void didUpdateWidget(_LoginErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _captureReason();
  }

  void _captureReason() {
    final state = widget.state;
    if (state is LoginFailed) {
      _lastReason = state.reason;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isVisible = widget.state is LoginFailed;
    final reason = _lastReason;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(30, 8, 30, 0),
        child: IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedSlide(
            duration: _animationDuration,
            curve: Curves.easeOutCubic,
            offset: isVisible ? Offset.zero : const Offset(0, -2),
            child: AnimatedOpacity(
              duration: _animationDuration,
              opacity: isVisible ? 1 : 0,
              child: reason == null
                  ? const SizedBox.shrink()
                  : ZyraAlertsNotification(
                      title: loc.loginAuthenticationFailedTitle,
                      message: _getErrorMessage(loc: loc, reason: reason),
                      onClose: () =>
                          context.read<LoginCubit>().onDismissedLoginFailureError(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _getErrorMessage({
  required AppLocalizations loc,
  required LoginFailedReason reason,
}) {
  return switch (reason) {
    LoginFailedReason.browserOpenFailed => loc.loginBrowserOpenFailed,
    LoginFailedReason.appleIdTokenMissing => loc.appleIdTokenMissing,
    LoginFailedReason.emailRequired => loc.emailRequired,
    LoginFailedReason.passwordRequired => loc.passwordRequired,
    LoginFailedReason.unknown => loc.loginError,
  };
}
