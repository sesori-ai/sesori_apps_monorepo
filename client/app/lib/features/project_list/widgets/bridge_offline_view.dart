part of "../project_list_screen.dart";

/// Shown when the account has a bridge registered but none is connected — the
/// user already completed setup, so instead of the install onboarding they are
/// asked to bring the bridge back up: the connection graphic over a heading
/// that names the computer ("dev-laptop is offline") and when it was last
/// seen, then the account's other online computers to switch to
/// ([OtherComputersCard]), then the always-visible start-the-bridge command,
/// and quiet "Why is this needed?" and "Install commands" links, the latter a
/// disclosure for when the bridge needs to be (re)installed. The quiet
/// "Need help?" support menu ([_NeedHelpMenu]) closes the page below this body
/// (see [ProjectListView]).
///
/// There is no reconnect button: reconnecting is what the page already does on
/// its own and on pull-to-refresh, so the design spends the space on the
/// command the user actually has to run.
///
/// A body, not a page: it is hosted in the project list's own page scroll (see
/// [ProjectListScreen]) so the expanded install commands scroll under a fixed
/// bar. Anchored to the top of that page at the design's offset; the enclosing
/// sliver grows past the viewport once the body outgrows it.
class const _BridgeOfflineView({
  /// The computer the app is trying to reach. Null while the lookup has no
  /// answer, or when it failed (e.g. the phone itself is offline); the heading
  /// then says "Bridge offline" and the last-seen line is hidden.
  required final BridgeSummary? bridge,
  required final ComputerSwitchCallback onSwitchComputer,
}) extends StatefulWidget {
  @override
  State<_BridgeOfflineView> createState() => _BridgeOfflineViewState();
}

class _BridgeOfflineViewState() extends State<_BridgeOfflineView> {
  /// Whether the "Install commands" disclosure is expanded.
  bool _showInstallCommands = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final bridge = widget.bridge;
    final lastSeenAt = bridge?.lastSeenAt;
    final title = bridge == null ? loc.projectsBridgeOfflineTitle : loc.projectsBridgeOfflineComputerTitle(bridge.name);

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
          // Cross-fades when the lookup lands and the generic heading gives way
          // to the computer's name.
          AnimatedSwitcher(
            duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
            child: Text(
              title,
              key: ValueKey(title),
              textAlign: TextAlign.center,
              style: prego.textTheme.textMd.medium.copyWith(color: prego.colors.textPrimary),
            ),
          ),
          // How long the bridge has been gone separates "I just closed the
          // laptop lid" from "this has been down for days". Refreshed by the
          // screen's minute ticker.
          if (lastSeenAt != null) ...[
            const SizedBox(height: PregoSpacing.xxs),
            Text(
              loc.projectsBridgeOfflineLastSeen(context.formatTimestamp(lastSeenAt.millisecondsSinceEpoch)),
              textAlign: TextAlign.center,
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
            ),
          ],
          OtherComputersCard(onSwitchComputer: widget.onSwitchComputer),
          const SizedBox(height: PregoSpacing.x5l),
          // Always visible: the bridge is already installed here, so the common
          // recovery is to (re)start it rather than reinstall.
          Text(
            loc.projectsBridgeOfflineStartBridge,
            textAlign: TextAlign.center,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
          ),
          const SizedBox(height: PregoSpacing.md),
          _CommandBoxFrame(
            child: _CommandActionRow(
              command: BridgeInstall.runCommand,
              reportCopied: (cubit) => cubit.reportRunCommandCopied(surface: OnboardingSurface.bridgeOffline),
              reportShared: (cubit) => cubit.reportRunCommandShared(surface: OnboardingSurface.bridgeOffline),
            ),
          ),
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
                  label: loc.projectsBridgeOfflineInstallCommands,
                  hierarchy: PregoButtonsSolidHierarchy.tertiary,
                  size: PregoButtonsSolidSize.sm,
                  trailingIcon: _showInstallCommands ? TablerRegular.chevron_up : TablerRegular.chevron_down,
                  fullWidth: false,
                  onPressed: () => setState(() => _showInstallCommands = !_showInstallCommands),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            // maintainState keeps the install boxes mounted while collapsed so
            // the selected install method survives closing and reopening the
            // disclosure.
            child: Visibility(
              visible: _showInstallCommands,
              maintainState: true,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: PregoSpacing.lg),
                  _InstallCommandBoxes(surface: OnboardingSurface.bridgeOffline),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
