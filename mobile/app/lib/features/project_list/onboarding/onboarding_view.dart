part of "../project_list_screen.dart";

// ===========================================================================
// Bridge-not-connected onboarding ("Let's connect your computer")
// ===========================================================================

class _BridgeOnboardingView extends StatefulWidget {
  const _BridgeOnboardingView();

  @override
  State<_BridgeOnboardingView> createState() => _BridgeOnboardingViewState();
}

class _BridgeOnboardingViewState extends State<_BridgeOnboardingView> {
  /// Selected install platform tab. `false` = Linux/Mac (default), `true` = Windows.
  bool _isWindows = false;

  String get _installCommand => _isWindows ? BridgeInstall.windowsCommand : BridgeInstall.macLinuxCommand;

  Future<void> _copyCommand() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    await Clipboard.setData(ClipboardData(text: _installCommand));
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.projectsOnboardingCommandCopied),
        duration: kSnackBarDuration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final zyra = context.zyra;

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        // Recovery affordance: pull down to re-attempt the bridge connection.
        // Escaping this state is otherwise passive (it waits for a connection
        // event), which can strand a never-connected bridge.
        onRefresh: () => context.read<ProjectListCubit>().reconnectBridge(),
        child: SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: ZyraSpacing.md),
              const Center(child: ExcludeSemantics(child: _OnboardingHero())),
              const SizedBox(height: ZyraSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.xl),
                child: Text(
                  loc.projectsOnboardingTitle,
                  textAlign: TextAlign.center,
                  style: zyra.textTheme.displayXs.medium.copyWith(color: zyra.colors.textPrimary),
                ),
              ),
              const SizedBox(height: ZyraSpacing.x4l),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(ZyraSpacing.xl, 0, ZyraSpacing.xl, ZyraSpacing.x3l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OnboardingStep(
                      number: 1,
                      titleAction: loc.projectsOnboardingStep1Action,
                      titleAccent: loc.projectsOnboardingBridgeName,
                      child: _CommandBlock(
                        installCommand: _installCommand,
                        runCommand: BridgeInstall.runCommand,
                        isWindows: _isWindows,
                        onSelectUnix: () => setState(() => _isWindows = false),
                        onSelectWindows: () => setState(() => _isWindows = true),
                        onCopy: _copyCommand,
                      ),
                    ),
                    const SizedBox(height: ZyraSpacing.x4l),
                    _OnboardingStep(
                      number: 2,
                      titleAction: loc.projectsOnboardingStep2Action,
                      titleAccent: loc.projectsOnboardingStep2Accent,
                      child: const _AccountLine(),
                    ),
                    const SizedBox(height: ZyraSpacing.x4l),
                    _OnboardingStep(
                      number: 3,
                      titleAction: loc.projectsOnboardingStep3Title,
                      child: Text(
                        loc.projectsOnboardingStep3Detail,
                        style: zyra.textTheme.textSm.regular.copyWith(color: zyra.colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One numbered onboarding step: a hanging number, a two-tone title, and a
/// body widget.
class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.titleAction,
    this.titleAccent,
    required this.child,
  });

  final int number;
  final String titleAction;
  final String? titleAccent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final titleStyle = zyra.textTheme.textLg.medium;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: titleAction,
                style: titleStyle.copyWith(color: colors.textPrimary),
              ),
              if (titleAccent != null)
                TextSpan(
                  text: " $titleAccent",
                  style: titleStyle.copyWith(color: colors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: ZyraSpacing.sm),
        child,
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$number.", style: titleStyle.copyWith(color: colors.textPrimary)),
        const SizedBox(width: ZyraSpacing.lg),
        Expanded(child: content),
      ],
    );
  }
}

/// Step 2 detail line. Shows "Use {account} with {Provider}" when the
/// signed-in account is known, falling back to a generic prompt otherwise.
class _AccountLine extends StatelessWidget {
  const _AccountLine();

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final loc = context.loc;
    final baseStyle = zyra.textTheme.textSm.regular.copyWith(color: colors.textSecondary);

    final authState = getIt<AuthSession>().currentState;
    final (String? account, String? provider) = switch (authState) {
      AuthAuthenticated(:final user) => (user.providerUsername, user.provider),
      AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => (null, null),
    };

    if (account != null && account.isNotEmpty && provider != null && provider.isNotEmpty) {
      return Text.rich(
        TextSpan(
          style: baseStyle,
          children: [
            TextSpan(text: loc.projectsOnboardingAccountPrefix),
            TextSpan(
              text: account,
              style: baseStyle.copyWith(color: colors.textPrimary),
            ),
            TextSpan(text: loc.projectsOnboardingAccountSuffix(_providerDisplayName(provider))),
          ],
        ),
      );
    }

    return Text(loc.projectsOnboardingAccountFallback, style: baseStyle);
  }

  /// Canonical, brand-correct display names for known auth providers. Naive
  /// first-letter capitalisation would render e.g. "Github" instead of "GitHub".
  static const _providerDisplayNames = {
    "google": "Google",
    "github": "GitHub",
    "apple": "Apple",
    "openai": "OpenAI",
    "anthropic": "Anthropic",
  };

  static String _providerDisplayName(String provider) {
    final mapped = _providerDisplayNames[provider.toLowerCase()];
    if (mapped != null) return mapped;
    return provider.isEmpty ? provider : "${provider[0].toUpperCase()}${provider.substring(1)}";
  }
}
