import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart" show OAuthProvider;
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/external_link.dart";
import "login_brand_panel.dart";

/// Window width at and above which the brand panel sits beside the sign-in
/// column; below it the column stands alone with the logo on top.
const double loginSplitMinWidth = 820;

/// The brand panel's share of the window, up to [_brandPanelMaxWidth].
const double _brandPanelWidthFactor = 0.44;
const double _brandPanelMaxWidth = 560;
const double _columnMaxWidth = 380;
const double _buttonGap = 12;
const Duration _logoDuration = Duration(milliseconds: 200);

/// Desktop sign-in: every sign-in method through the shared [LoginCubit].
/// GitHub, Apple and Google go through the browser; email signs in inline.
class const LoginScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LoginCubit>(
          create: (_) => LoginCubit(
            oAuthFlowProvider: getIt(),
            urlLauncher: getIt(),
            authSession: getIt(),
            lifecycleSource: getIt(),
            installationAnalyticsService: getIt(),
          ),
        ),
        BlocProvider<LastSignInProviderCubit>(create: (_) => LastSignInProviderCubit(authSession: getIt())),
      ],
      child: const LoginView(openExternalLink: openDesktopExternalLink),
    );
  }
}

/// Renders the [LoginState]; split from [LoginScreen] so tests can drive it
/// with a stubbed cubit.
class const LoginView({super.key, required final ExternalLinkOpener openExternalLink}) extends StatefulWidget {
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState() extends State<LoginView> {
  bool _showsEmailForm = false;

  void _showEmailForm({required bool shows}) {
    // A failure belongs to the method that produced it, so switching methods
    // clears it: a provider failure never shows inside the email form, and an
    // email failure never outlives the form. The cubit emits synchronously,
    // so the form's first frame already sees the cleared state.
    context.read<LoginCubit>().onDismissedLoginFailureError();
    setState(() => _showsEmailForm = shows);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSplit = constraints.maxWidth >= loginSplitMinWidth;
          // One tree for both layouts, so crossing the breakpoint keeps the
          // column's state, such as a half-typed email, while the panel folds.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LoginBrandPanel(
                isVisible: isSplit,
                width: math.min(_brandPanelMaxWidth, constraints.maxWidth * _brandPanelWidthFactor),
              ),
              Expanded(
                child: _SignInPane(
                  showsLogo: !isSplit,
                  openExternalLink: widget.openExternalLink,
                  child: _showsEmailForm
                      ? _EmailSignIn(onBack: () => _showEmailForm(shows: false))
                      : _ProviderSignIn(onShowEmailForm: () => _showEmailForm(shows: true)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The scrollable sign-in column: the folded layout's logo, the current
/// method's [child], and the legal sentence at the bottom of the window.
class const _SignInPane({
  required final bool showsLogo,
  required final ExternalLinkOpener openExternalLink,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final legalStyle = prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            // The top band stays clear for the window drag area.
            padding: const EdgeInsetsDirectional.fromSTEB(32, PregoTopNavigation.barHeight, 32, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // A short window scrolls; a tall one spreads the free space so
              // the column sits in the middle and the legal line at the bottom.
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _columnMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AnimatedSize(
                        duration: prefersReducedMotion(context) ? Duration.zero : _logoDuration,
                        curve: Curves.easeOut,
                        alignment: Alignment.topCenter,
                        child: showsLogo
                            ? const Padding(
                                padding: EdgeInsetsDirectional.only(bottom: 8),
                                child: Center(child: SesoriLogo(squareSize: 72)),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      child,
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _columnMaxWidth),
                    child: MarkdownBody(
                      data: context.loc.loginAgreementText,
                      onTapLink: buildMarkdownLinkTapHandler(openExternalLink: openExternalLink),
                      styleSheet: MarkdownStyleSheet(
                        p: legalStyle,
                        a: legalStyle.copyWith(
                          color: prego.colors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: WrapAlignment.center,
                        pPadding: EdgeInsets.zero,
                        blockSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class const _Heading({required final String title, required final String subtitle}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: prego.textTheme.displaySm.bold),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class const _ProviderSignIn({required final VoidCallback onShowEmailForm}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final lastUsed = context.watch<LastSignInProviderCubit>().state;

    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        // LoginSuccess counts as busy: the auth gate flips a moment later, and
        // re-enabled buttons would flash and allow a duplicate tap.
        final isBusy = state is LoginAuthenticating || state is LoginPolling || state is LoginSuccess;

        Widget provider({required String label, required IconData icon, required OAuthProvider provider}) =>
            PregoButtonsSolid(
              label: label,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              leadingIcon: icon,
              labelTrailing: provider == lastUsed ? _LastUsedChip(isEnabled: !isBusy) : null,
              fullWidth: true,
              onPressed: isBusy ? null : () => unawaited(context.read<LoginCubit>().loginWithProvider(provider)),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Heading(title: loc.desktopLoginTitle, subtitle: loc.desktopLoginSubtitle),
            provider(label: loc.desktopLoginContinueWithGithub, icon: VESPRSolid.github, provider: AuthProvider.github),
            const SizedBox(height: _buttonGap),
            provider(label: loc.desktopLoginContinueWithApple, icon: VESPRSolid.apple, provider: AuthProvider.apple),
            const SizedBox(height: _buttonGap),
            provider(label: loc.desktopLoginContinueWithGoogle, icon: VESPRSolid.google, provider: AuthProvider.google),
            const SizedBox(height: _buttonGap),
            PregoButtonsSolid(
              label: loc.signInWithEmail,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              size: PregoButtonsSolidSize.xl,
              labelTrailing: lastUsed == AuthProvider.email ? PregoTag(label: loc.desktopLoginLastUsed) : null,
              fullWidth: true,
              onPressed: isBusy ? null : onShowEmailForm,
            ),
            _LoginStatus(state: state),
          ],
        );
      },
    );
  }
}

/// "Last used" on a provider button, tinted like the button's own label.
class const _LastUsedChip({required final bool isEnabled}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: prego.colors.alphaWhite10,
        borderRadius: BorderRadius.circular(PregoRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xxs),
        child: Text(
          context.loc.desktopLoginLastUsed,
          style: prego.textTheme.textXs.medium.copyWith(
            color: isEnabled ? prego.colors.textPrimaryOnWhite : prego.colors.fgDisabled,
          ),
        ),
      ),
    );
  }
}

class const _EmailSignIn({required final VoidCallback onBack}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(title: loc.signInWithEmail, subtitle: loc.desktopLoginEmailSubtitle),
        EmailLoginForm(
          // The auth gate replaces this screen once the session is saved.
          onSignedIn: () {},
          onBack: onBack,
        ),
      ],
    );
  }
}

/// Interim waiting and failure line under the provider buttons.
class const _LoginStatus({required final LoginState state}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final errorStyle = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textErrorPrimary);
    final status = switch (state) {
      LoginIdle() || LoginSuccess() => null,
      LoginAuthenticating() => _StatusRow(message: loc.loginAuthenticating),
      LoginPolling(:final handoff) => Column(
        children: [
          _StatusRow(
            message: handoff.browser == LoginBrowserLaunch.failed ? loc.loginBrowserOpenFailed : loc.loginPolling,
          ),
          const SizedBox(height: 8),
          PregoButtonsSolid(
            label: loc.loginCancel,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.sm,
            onPressed: () => unawaited(context.read<LoginCubit>().cancel()),
          ),
        ],
      ),
      LoginTimeout() => Text(loc.loginTimeout, textAlign: TextAlign.center, style: errorStyle),
      LoginFailed(:final reason) => Text(
        reason.localizedMessage(loc: loc),
        textAlign: TextAlign.center,
        style: errorStyle,
      ),
    };
    if (status == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsetsDirectional.only(top: 20), child: status);
  }
}

class const _StatusRow({required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox.square(
          dimension: 16,
          child: PregoActivityIndicator(color: null),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            message,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
        ),
      ],
    );
  }
}
