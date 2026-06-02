part of "../project_list_screen.dart";

// ===========================================================================
// Bridge onboarding checklist
//
// One shared 3-step checklist drives both empty Projects states:
// * disconnected — "Set up Sesori Bridge" (steps pending, folder button
//   disabled). See [_BridgeOnboardingView].
// * connected, no projects — "Your bridge is connected" (steps 1 & 2 ticked,
//   folder button live). See [_ConnectedEmptyView].
// ===========================================================================

/// Not-yet-connected onboarding ("Set up Sesori Bridge"). Wraps the shared
/// [_OnboardingChecklist] in a pull-to-refresh that re-attempts the bridge
/// connection.
class _BridgeOnboardingView extends StatelessWidget {
  const _BridgeOnboardingView();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: RefreshIndicator(
        // Recovery affordance: pull down to re-attempt the bridge connection.
        // Escaping this state is otherwise passive (it waits for a connection
        // event), which can strand a never-connected bridge.
        onRefresh: () => context.read<ProjectListCubit>().reconnectBridge(),
        child: const SingleChildScrollView(
          clipBehavior: Clip.none,
          physics: AlwaysScrollableScrollPhysics(),
          child: _OnboardingChecklist(connected: false),
        ),
      ),
    );
  }
}

/// The shared onboarding body: hero illustration, title, and the three setup
/// steps. Stateful because Step 1's install command block has its own
/// platform tab selection, used by both the connected and disconnected states.
///
/// [connected] switches between the two states:
/// * `false` — pending steps with hanging numbers and a disabled folder button.
/// * `true`  — steps 1 & 2 ticked, the "Signed in" wording, and a live folder
///   button wired to [onOpenFolder].
class _OnboardingChecklist extends StatefulWidget {
  const _OnboardingChecklist({required this.connected, this.onOpenFolder});

  final bool connected;

  /// Invoked by the Step 3 folder button. Non-null only when [connected]; left
  /// null while disconnected, which renders the button in its disabled state.
  final VoidCallback? onOpenFolder;

  @override
  State<_OnboardingChecklist> createState() => _OnboardingChecklistState();
}

class _OnboardingChecklistState extends State<_OnboardingChecklist> {
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
    final connected = widget.connected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: ZyraSpacing.md),
        Center(
          child: ExcludeSemantics(
            child: connected ? const _OnboardingHero.cli() : const _OnboardingHero.offline(),
          ),
        ),
        const SizedBox(height: ZyraSpacing.x2l),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZyraSpacing.xl),
          child: Text(
            connected ? loc.projectsConnectedTitle : loc.projectsOnboardingTitle,
            textAlign: TextAlign.center,
            style: zyra.textTheme.displayXs.medium.copyWith(color: zyra.colors.textPrimary),
          ),
        ),
        // 68px hero/title-block → steps gap from Figma (no exact spacing token:
        // sits between x7l=64 and x8l=80).
        const SizedBox(height: 68),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(ZyraSpacing.xl, 0, ZyraSpacing.xl, ZyraSpacing.x3l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingStep(
                number: 1,
                completed: connected,
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
                completed: connected,
                titleAction: connected ? loc.projectsConnectedStep2Action : loc.projectsOnboardingStep2Action,
                titleAccent: loc.projectsOnboardingStep2Accent,
                child: _AccountLine(connected: connected),
              ),
              const SizedBox(height: ZyraSpacing.x4l),
              _OnboardingStep(
                number: 3,
                titleAction: loc.projectsOnboardingStep3Title,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        connected ? loc.projectsConnectedStep3Detail : loc.projectsOnboardingStep3Detail,
                        style: zyra.textTheme.textSm.regular.copyWith(color: zyra.colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: ZyraSpacing.lg),
                    // Folder button: disabled (dimmed) while disconnected, since
                    // adding a project isn't possible yet; live and wired to
                    // [onOpenFolder] once the bridge is connected. When live it
                    // is the sole add-project CTA (the FAB is hidden in this
                    // state), so it carries a screen-reader label.
                    ZyraButtonsIconGlass(
                      icon: TablerOutline.folder_plus,
                      size: ZyraButtonsIconGlassSize.lg,
                      iconSize: 30,
                      semanticLabel: connected ? loc.projectsOnboardingOpenFolder : null,
                      onPressed: widget.onOpenFolder,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One numbered onboarding step: a hanging number (or a check mark once
/// [completed]), a two-tone title, and a body widget.
class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.titleAction,
    this.titleAccent,
    this.completed = false,
    required this.child,
  });

  final int number;
  final String titleAction;
  final String? titleAccent;

  /// When `true`, the hanging number is replaced by a check mark — the step is
  /// already done (the connected state ticks the install & sign-in steps).
  final bool completed;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final colors = zyra.colors;
    final loc = context.loc;
    final titleStyle = zyra.textTheme.textLg.medium;

    // Leading marker sized to the title's line box so the check mark sits on
    // the title's baseline, matching the number it replaces.
    final fontSize = titleStyle.fontSize ?? 18.0;
    final heightMultiple = titleStyle.height;
    final lineHeight = heightMultiple == null ? fontSize : fontSize * heightMultiple;
    final leading = completed
        ? SizedBox(
            height: lineHeight,
            child: Icon(
              TablerOutline.check,
              size: 20,
              color: colors.textPrimary,
              semanticLabel: loc.projectsOnboardingStepCompleted,
            ),
          )
        : Text("$number.", style: titleStyle.copyWith(color: colors.textPrimary));

    // The marker hangs at the left margin and the title indents past it, but
    // the step body spans the full width below — matching the Figma layout.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: ZyraSpacing.lg),
            Expanded(
              child: Text.rich(
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
            ),
          ],
        ),
        const SizedBox(height: ZyraSpacing.sm),
        child,
      ],
    );
  }
}

/// Step 2 detail line. Shows the signed-in account as "Use {account} with
/// {Provider}" (or just "{account} with {Provider}" once [connected]), falling
/// back to a state-appropriate line when the account is unknown.
class _AccountLine extends StatelessWidget {
  const _AccountLine({required this.connected});

  /// Whether the bridge is connected (the "Signed in" state). When connected,
  /// the "Use " prefix is dropped and the account-unknown fallback confirms the
  /// signed-in state rather than prompting a sign-in — which would contradict
  /// the ticked "Signed in" heading above it.
  final bool connected;

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
            if (!connected) TextSpan(text: loc.projectsOnboardingAccountPrefix),
            TextSpan(
              text: account,
              style: baseStyle.copyWith(color: colors.textPrimary),
            ),
            TextSpan(text: loc.projectsOnboardingAccountSuffix(_providerDisplayName(provider))),
          ],
        ),
      );
    }

    return Text(
      connected ? loc.projectsConnectedAccountFallback : loc.projectsOnboardingAccountFallback,
      style: baseStyle,
    );
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
