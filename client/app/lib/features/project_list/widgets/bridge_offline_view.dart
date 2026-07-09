part of "../project_list_screen.dart";

/// Shown when the account has a bridge registered but none is connected — the
/// user already completed setup, so instead of the install onboarding they are
/// asked to reconnect. Mirrors the Figma "bridge disconnected" state: the
/// connection graphic, a "Reconnect" CTA, and an expandable "Install commands"
/// disclosure for when the bridge needs to be (re)installed or restarted.
///
/// A body, not a page: it is hosted in the project list's own page scroll (see
/// [ProjectListScreen]) so the large title collapses into the bar as the
/// expanded install commands scroll. Centred while it fits the viewport; the
/// enclosing sliver grows past it once it doesn't.
class _BridgeOfflineView extends StatefulWidget {
  const _BridgeOfflineView();

  @override
  State<_BridgeOfflineView> createState() => _BridgeOfflineViewState();
}

class _BridgeOfflineViewState extends State<_BridgeOfflineView> {
  /// True while a [reconnectBridge] attempt is in flight, so the Reconnect
  /// button can show its spinner. Reset in a `finally` guarded by `mounted`
  /// since a successful reconnect emits a new state that unmounts this view.
  bool _reconnecting = false;

  /// Whether the "Install commands" disclosure is expanded.
  bool _showInstallCommands = false;

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);
    try {
      await context.read<ProjectListCubit>().reconnectBridge();
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(child: Center(child: ConnectionGraphic.connectionOff())),
          const SizedBox(height: 18),
          Text(
            loc.projectsBridgeOfflineTitle,
            textAlign: TextAlign.center,
            style: prego.textTheme.textLg.medium.copyWith(color: prego.colors.textPrimary),
          ),
          const SizedBox(height: 28),
          PregoButtonsSolid(
            label: loc.projectsBridgeOfflineReconnect,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.xl,
            leadingIcon: TablerRegular.refresh,
            fullWidth: true,
            isLoading: _reconnecting,
            onPressed: _reconnect,
          ),
          const SizedBox(height: 18),
          // expanded semantics so screen readers announce the open/closed state
          // of the install-commands disclosure; MergeSemantics folds it onto the
          // button's own node.
          MergeSemantics(
            child: Semantics(
              expanded: _showInstallCommands,
              child: PregoButtonsSolid(
                label: loc.projectsBridgeOfflineInstallCommands,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                size: PregoButtonsSolidSize.xl,
                trailingIcon: _showInstallCommands ? TablerRegular.chevron_up : TablerRegular.chevron_down,
                fullWidth: true,
                onPressed: () => setState(() => _showInstallCommands = !_showInstallCommands),
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
                  _InstallCommandBoxes(),
                ],
              ),
            ),
          ),
          // Always visible: the bridge is already installed here, so the common
          // recovery is to (re)start it rather than reinstall.
          const SizedBox(height: PregoSpacing.xl),
          const _RunBridgeCommand(),
        ],
      ),
    );
  }
}

/// The bridge-offline "Run the bridge" command: a label and a single-command
/// box showing [BridgeInstall.runCommand]. Always visible (unlike the collapsed
/// install commands) because the bridge is already installed, so the common
/// recovery is to start it. Reuses the onboarding command-box chrome
/// ([_CommandBoxFrame] / [_CommandActionRow]) so it matches the install
/// commands.
class _RunBridgeCommand extends StatelessWidget {
  const _RunBridgeCommand();

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.projectsBridgeOfflineRunBridge,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
        ),
        const SizedBox(height: PregoSpacing.md),
        const _CommandBoxFrame(
          child: _CommandActionRow(command: BridgeInstall.runCommand),
        ),
      ],
    );
  }
}
