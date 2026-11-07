part of "bridge_onboarding.dart";

/// Shown when the account has a bridge registered but none is connected — the
/// user already completed setup, so instead of the install onboarding they are
/// asked to bring the bridge back up: the connection graphic over a heading
/// that names the computer ("dev-laptop is offline") and when it was last
/// seen, then the account's other online computers to switch to
/// ([OtherComputersCard]), then how to start that computer's bridge (see
/// [_StartBridgeInstructions]), and quiet "Why is this needed?" and install
/// links, the latter a disclosure for when the bridge needs to be
/// (re)installed, again by how it was installed: "Reinstall Sesori Desktop"
/// holds the Sesori Desktop download card, "Install commands" the CLI
/// installers, and for an unknown kind both, the card first. The quiet
/// "Need help?" support menu ([NeedHelpMenu]) closes the page below this body
/// (see [DisconnectedComputerSlivers]).
///
/// There is no reconnect button: reconnecting is what the page already does on
/// its own and on pull-to-refresh, so the design spends the space on the
/// step the user actually has to take.
///
/// A body, not a page: it is hosted in its page's own scroll (see
/// [DisconnectedComputerSlivers]) so the expanded install commands scroll under a fixed
/// bar. Anchored to the top of that page at the design's offset; the enclosing
/// sliver grows past the viewport once the body outgrows it.
class const BridgeOfflineView({
  super.key,

  /// The computer the app is trying to reach. Null while the lookup has no
  /// answer, or when it failed (e.g. the phone itself is offline); the heading
  /// then says "Bridge offline" and the last-seen line is hidden.
  required final BridgeSummary? bridge,
  required final ComputerSwitchCallback onSwitchComputer,
}) extends StatefulWidget {
  @override
  State<BridgeOfflineView> createState() => _BridgeOfflineViewState();
}

class _BridgeOfflineViewState() extends State<BridgeOfflineView> {
  /// Whether the install disclosure is expanded.
  bool _showInstallCommands = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    const desktopCard = _DesktopDownloadCard(surface: OnboardingSurface.bridgeOffline);
    const commandBoxes = _InstallCommandBoxes(surface: OnboardingSurface.bridgeOffline);
    final (String disclosureLabel, List<Widget> installOptions) = switch (widget.bridge) {
      // Sesori Desktop is reinstalled from its download; the CLI installers
      // would install a second, standalone bridge.
      BridgeSummary(kind: BridgeKind.desktop) => (loc.projectsBridgeOfflineReinstallDesktop, const [desktopCard]),
      BridgeSummary(kind: BridgeKind.cli) => (loc.projectsBridgeOfflineInstallCommands, const [commandBoxes]),
      BridgeSummary(kind: null) || null => (
        loc.projectsBridgeOfflineInstallCommands,
        const [desktopCard, SizedBox(height: PregoSpacing.xl), commandBoxes],
      ),
    };
    // maintainState keeps the install boxes mounted while collapsed so the
    // selected install method survives closing and reopening the disclosure.
    final installCommands = Visibility(
      visible: _showInstallCommands,
      maintainState: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: PregoSpacing.lg),
          ...installOptions,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Figma hangs the graphic 90px below the bar. Off the spacing scale,
          // so it is written out. Anchored rather than centred: the composition
          // reads from the top down, and centring would move the graphic as the
          // install-commands disclosure grows the body beneath it.
          const SizedBox(height: 90),
          const ExcludeSemantics(child: Center(child: ConnectionGraphic.connectionOff())),
          const SizedBox(height: PregoSpacing.lg),
          // The last-seen time is refreshed by the screen's minute ticker.
          ComputerOfflineHeading(bridge: widget.bridge),
          OtherComputersCard(onSwitchComputer: widget.onSwitchComputer),
          const SizedBox(height: PregoSpacing.x5l),
          // Always visible: the bridge is already installed here, so the common
          // recovery is to (re)start it rather than reinstall.
          _StartBridgeInstructions(bridge: widget.bridge),
          const SizedBox(height: PregoSpacing.xl),
          const _WhyBridgeButton(surface: OnboardingSurface.bridgeOffline),
          const SizedBox(height: PregoSpacing.xs),
          // expanded semantics so screen readers announce the open/closed state
          // of the install-commands disclosure; MergeSemantics folds it onto the
          // button's own node.
          MergeSemantics(
            child: Semantics(
              expanded: _showInstallCommands,
              // A quiet link, the same weight as "Why is this needed?".
              child: Center(
                child: PregoButtonsSolid(
                  label: disclosureLabel,
                  hierarchy: PregoButtonsSolidHierarchy.tertiary,
                  size: PregoButtonsSolidSize.sm,
                  trailingIcon: _showInstallCommands ? TablerRegular.chevron_up : TablerRegular.chevron_down,
                  fullWidth: false,
                  onPressed: () => setState(() => _showInstallCommands = !_showInstallCommands),
                ),
              ),
            ),
          ),
          // Under reduced motion no wrapper at all: a zero-length AnimatedSize
          // would re-dirty itself mid-layout.
          context.isReducedMotion
              ? installCommands
              : AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: installCommands,
                ),
        ],
      ),
    );
  }
}

/// How to start the offline computer's bridge, by how it was installed: Sesori
/// Desktop starts its bundled bridge with the app and puts no `sesori-bridge`
/// command on PATH, so it gets no command box; the command-line bridge gets
/// the start command. When the kind is unknown (no bridge named, a bridge
/// registered before kind existed, or a server that does not report it), both
/// are shown, each labelled.
class const _StartBridgeInstructions({required final BridgeSummary? bridge}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final style = prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary);
    Widget instruction(String text) => Text(text, textAlign: TextAlign.center, style: style);
    final runCommandBox = _CommandBoxFrame(
      child: _CommandActionRow(
        command: BridgeInstall.runCommand,
        reportCopied: (cubit) => cubit.reportRunCommandCopied(surface: OnboardingSurface.bridgeOffline),
        reportShared: (cubit) => cubit.reportRunCommandShared(surface: OnboardingSurface.bridgeOffline),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (bridge) {
        BridgeSummary(kind: BridgeKind.desktop, :final name) => [
          instruction(loc.projectsBridgeOfflineOpenDesktop(name)),
        ],
        BridgeSummary(kind: BridgeKind.cli) => [
          instruction(loc.projectsBridgeOfflineStartBridge),
          const SizedBox(height: PregoSpacing.md),
          runCommandBox,
        ],
        BridgeSummary(kind: null) || null => [
          instruction(loc.projectsBridgeOfflineDesktopOption),
          const SizedBox(height: PregoSpacing.lg),
          instruction(loc.projectsBridgeOfflineTerminalOption),
          const SizedBox(height: PregoSpacing.md),
          runCommandBox,
        ],
      },
    );
  }
}
