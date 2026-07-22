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
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/login_failed_reason_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/markdown_styles.dart";
import "../../core/widgets/sesori_background_widget.dart";
import "../../core/widgets/sesori_logo.dart";
import "email_login_sheet.dart";
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
  /// While the email sheet is up it renders failures inline, next to the form.
  /// The screen's own banner would otherwise show the same error a second time
  /// over the scrim, so it stands down for the duration.
  bool _isEmailSheetOpen = false;

  /// The option whose button was tapped for the currently pending login flow.
  /// Drives which button shows the loading spinner; cleared when the cubit
  /// reaches a terminal state so a later email-form login cannot resurrect a
  /// stale provider spinner.
  LoginOption? _pendingOption;

  Future<void> _loginWithProvider({
    required LoginOption option,
    required OAuthProvider provider,
  }) async {
    setState(() {
      _pendingOption = option;
    });
    await context.read<LoginCubit>().loginWithProvider(provider);
  }

  Future<void> _loginWithApple() async {
    setState(() {
      _pendingOption = LoginOption.apple;
    });
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
        // Cancelling the native sheet emits no cubit state, so the pending
        // marker must be cleared here.
        if (mounted) {
          setState(() {
            _pendingOption = null;
          });
        }
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

  Future<void> _showEmailLogin() async {
    setState(() => _isEmailSheetOpen = true);
    try {
      await showEmailLoginSheet(
        context: context,
        cubit: context.read<LoginCubit>(),
      );
    } finally {
      if (mounted) setState(() => _isEmailSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final state = context.watch<LoginCubit>().state;
    final isLoading = state is LoginAuthenticating || state is LoginPolling;

    return Scaffold(
      body: BlocListener<LoginCubit, LoginState>(
        listenWhen: (previous, current) =>
            current is LoginSuccess || current is LoginFailed || current is LoginTimeout || current is LoginIdle,
        listener: (context, state) {
          if (state is LoginSuccess) {
            // Relay connection is handled reactively: AuthManager emits
            // AuthState.authenticated → ConnectionService connects. The
            // connection overlay shows progress; navigation proceeds immediately.
            context.goRoute(const AppRoute.projects());
            return;
          }
          if (_pendingOption != null) {
            setState(() {
              _pendingOption = null;
            });
          }
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
                              const Hero(tag: SesoriLogo.heroTag, child: SesoriLogo()),
                              Text(
                                loc.loginTitle,
                                style: prego.textTheme.textSm.regular,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.loginSubtitle,
                                style: prego.textTheme.displaySm.bold,
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
                                  loadingOption: _pendingOption,
                                  showApple: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
                                  onGithubSelected: () => _loginWithProvider(
                                    option: LoginOption.github,
                                    provider: AuthProvider.github,
                                  ),
                                  onAppleSelected: _loginWithApple,
                                  onGoogleSelected: () => _loginWithProvider(
                                    option: LoginOption.google,
                                    provider: AuthProvider.google,
                                  ),
                                  onShowEmailForm: _showEmailLogin,
                                ),
                                switch (state) {
                                  LoginAuthenticating() => Padding(
                                    padding: const EdgeInsetsDirectional.only(top: 16),
                                    child: Text(
                                      loc.loginAuthenticating,
                                      style: prego.textTheme.textSm.regular.copyWith(
                                        color: prego.colors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  LoginPolling() => Padding(
                                    padding: const EdgeInsetsDirectional.only(top: 16),
                                    child: Text(
                                      loc.loginPolling,
                                      style: prego.textTheme.textSm.regular.copyWith(
                                        color: prego.colors.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  LoginTimeout() => Padding(
                                    padding: const EdgeInsetsDirectional.only(top: 16),
                                    child: Text(
                                      loc.loginTimeout,
                                      style: prego.textTheme.textSm.regular.copyWith(
                                        color: prego.colors.textSecondary,
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
                                      color: prego.colors.bgErrorPrimary,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              color: prego.colors.fgErrorPrimary,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                loc.loginTimeout,
                                                style: prego.textTheme.textSm.regular.copyWith(
                                                  color: prego.colors.fgErrorPrimary,
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
                                  LoginPolling() => const SizedBox.shrink(),
                                  LoginSuccess() => const SizedBox.shrink(),
                                },
                                const SizedBox(height: 22),
                                MarkdownBody(
                                  data: loc.loginAgreementText,
                                  onTapLink: handleMarkdownLinkTap,
                                  styleSheet: buildAgreementMarkdownStyleSheet(prego: prego),
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
              child: _isEmailSheetOpen
                  ? const SizedBox.shrink()
                  : _LoginErrorBanner(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating error notification anchored to the top of the login screen.
///
/// Matches the Figma `pregoAlertsNotifications` placement: it slides down
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
                  : PregoPopupAlertsNotifications(
                      title: loc.loginAuthenticationFailedTitle,
                      message: reason.localizedMessage(loc),
                      onClose: () => context.read<LoginCubit>().onDismissedLoginFailureError(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
