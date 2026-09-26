import "dart:async";
import "dart:math" as math;

import "package:clock/clock.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
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
const double _noticeGap = 16;
const Duration _logoDuration = Duration(milliseconds: 200);

/// Desktop sign-in: every sign-in method through the shared [LoginCubit].
/// GitHub, Apple and Google go through the browser; email signs in inline.
class const LoginScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider<LoginCubit>(
      create: (_) => LoginCubit(
        oAuthFlowProvider: getIt(),
        urlLauncher: getIt(),
        authSession: getIt(),
        lifecycleSource: getIt(),
        installationAnalyticsService: getIt(),
      ),
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

class const _ProviderSignIn({required final VoidCallback onShowEmailForm}) extends StatefulWidget {
  @override
  State<_ProviderSignIn> createState() => _ProviderSignInState();
}

class _ProviderSignInState() extends State<_ProviderSignIn> {
  /// The provider whose button spins while its sign-in starts.
  OAuthProvider? _starting;

  void _start({required OAuthProvider provider}) {
    setState(() => _starting = provider);
    unawaited(context.read<LoginCubit>().loginWithProvider(provider));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return BlocBuilder<LoginCubit, LoginState>(
      builder: (context, state) {
        final heading = _Heading(title: loc.desktopLoginTitle, subtitle: loc.desktopLoginSubtitle);
        if (state case LoginPolling(:final handoff)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              _DesktopHandoffCard(handoff: handoff),
            ],
          );
        }

        // LoginSuccess counts as busy: the auth gate flips a moment later, and
        // re-enabled buttons would flash and allow a duplicate tap.
        final isBusy = state is LoginAuthenticating || state is LoginSuccess;
        final notice = switch (state) {
          LoginTimeout() => _Notice(title: loc.desktopLoginExpiredTitle, message: loc.desktopLoginExpiredMessage),
          LoginFailed(reason: LoginFailedReason.declined) => _Notice(
            title: loc.desktopLoginDeclinedTitle,
            message: loc.desktopLoginDeclinedMessage,
          ),
          LoginFailed(:final reason) => _Notice(
            title: loc.loginAuthenticationFailedTitle,
            message: reason.localizedMessage(loc: loc),
          ),
          LoginIdle() || LoginAuthenticating() || LoginPolling() || LoginSuccess() => null,
        };

        Widget provider({required String label, required IconData icon, required OAuthProvider provider}) =>
            PregoButtonsSolid(
              label: label,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              leadingIcon: icon,
              fullWidth: true,
              isLoading: state is LoginAuthenticating && _starting == provider,
              onPressed: isBusy ? null : () => _start(provider: provider),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A notice covers the heading, which keeps its footprint, so the
            // buttons stay put while a failure appears and clears. Only the
            // footprint stays: screen readers skip the covered heading.
            Stack(
              clipBehavior: Clip.none,
              children: [
                Visibility(
                  visible: notice == null,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: heading,
                ),
                if (notice != null) PositionedDirectional(start: 0, end: 0, bottom: _noticeGap, child: notice),
              ],
            ),
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
              fullWidth: true,
              onPressed: isBusy ? null : widget.onShowEmailForm,
            ),
          ],
        );
      },
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

/// An expired or failed sign-in, drawn over the heading above the buttons.
class const _Notice({required final String title, required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgErrorPrimary,
        borderRadius: BorderRadius.circular(PregoRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(TablerRegular.alert_circle, size: 20, color: colors.fgErrorPrimary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: prego.textTheme.textSm.bold.copyWith(color: colors.textPrimary)),
                  Text(message, style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A browser sign-in waiting for the user, in place of the provider buttons:
/// the device name the browser page will ask to confirm, how long the link
/// stays valid, and ways to reopen, copy or abandon it.
class const _DesktopHandoffCard({required final LoginHandoff handoff}) extends StatefulWidget {
  @override
  State<_DesktopHandoffCard> createState() => _DesktopHandoffCardState();
}

class _DesktopHandoffCardState() extends State<_DesktopHandoffCard> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (ticker) {
      setState(() {});
      if (_remaining() == Duration.zero) ticker.cancel();
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  Duration _remaining() {
    final remaining = widget.handoff.oauth.expiresAt.difference(clock.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _copyLink() async {
    final popups = PregoPopupAlertPresenter.of(context);
    final copied = context.loc.desktopLoginLinkCopied;
    if (!await copyTextToClipboard(text: widget.handoff.oauth.authUrl.toString(), operation: "sign-in link")) return;
    popups.show(title: copied, variant: PregoPopupAlertsNotificationsVariant.info);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final colors = prego.colors;
    final cubit = context.read<LoginCubit>();
    final handoff = widget.handoff;
    final remaining = _remaining();
    final countdown = "${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, "0")}";

    Widget header({required Widget leading, required String title, required Color color}) => Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: prego.textTheme.textLg.bold.copyWith(color: color)),
        ),
      ],
    );
    Widget button({
      required String label,
      required IconData? icon,
      required PregoButtonsSolidHierarchy hierarchy,
      required VoidCallback onPressed,
    }) => PregoButtonsSolid(
      label: label,
      leadingIcon: icon,
      hierarchy: hierarchy,
      size: PregoButtonsSolidSize.md,
      onPressed: onPressed,
    );
    void reopen() => unawaited(cubit.reopenBrowser());
    void copyLink() => unawaited(_copyLink());

    final (title, message, actions) = switch (handoff.browser) {
      LoginBrowserLaunch.opened => (
        header(
          leading: const SizedBox.square(dimension: 18, child: PregoActivityIndicator(color: null)),
          title: loc.desktopLoginWaitingTitle,
          color: colors.textPrimary,
        ),
        _waitingMessage(handoff: handoff),
        [
          button(
            label: loc.desktopLoginOpenAgain,
            icon: TablerRegular.world,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            onPressed: reopen,
          ),
          button(
            label: loc.desktopLoginCopyLink,
            icon: null,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            onPressed: copyLink,
          ),
        ],
      ),
      LoginBrowserLaunch.failed => (
        header(
          leading: Icon(TablerRegular.alert_circle, size: 22, color: colors.fgErrorPrimary),
          title: loc.desktopLoginBrowserFailedTitle,
          color: colors.textErrorPrimary,
        ),
        Text(loc.desktopLoginBrowserFailedMessage),
        [
          button(
            label: loc.desktopLoginCopyLink,
            icon: null,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            onPressed: copyLink,
          ),
          button(
            label: loc.desktopLoginTryAgain,
            icon: null,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            onPressed: reopen,
          ),
        ],
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.bgSecondary,
            border: Border.all(color: colors.borderSecondary),
            borderRadius: BorderRadius.circular(PregoRadius.x2l),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 22, 22, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 10),
                DefaultTextStyle.merge(
                  style: prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
                  child: message,
                ),
                const SizedBox(height: 12),
                Text(
                  loc.desktopLoginExpiresIn(countdown),
                  style: prego.textTheme.textXs.regular.copyWith(color: colors.textTertiary),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: PregoButtonsSolid(
            label: loc.desktopLoginCancelHandoff,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.md,
            onPressed: () => unawaited(cubit.cancel()),
          ),
        ),
      ],
    );
  }

  /// The waiting copy with the device name set off, so it is easy to match on
  /// the browser page. The copy is formatted around a marker to find where
  /// the name goes.
  Widget _waitingMessage({required LoginHandoff handoff}) {
    final prego = context.prego;
    final loc = context.loc;
    const marker = "\u0000";
    return switch (loc.desktopLoginWaitingMessage(handoff.provider.label, marker).split(marker)) {
      [final before, final after] => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: before),
            TextSpan(
              text: handoff.oauth.deviceName,
              style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
            ),
            TextSpan(text: after),
          ],
        ),
      ),
      _ => Text(loc.desktopLoginWaitingMessage(handoff.provider.label, handoff.oauth.deviceName)),
    };
  }
}
