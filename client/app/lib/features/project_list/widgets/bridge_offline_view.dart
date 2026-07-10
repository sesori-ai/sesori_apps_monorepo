part of "../project_list_screen.dart";

/// Shown when the account has a bridge registered but none is connected — the
/// user already completed setup, so instead of the install onboarding they are
/// asked to reconnect. Mirrors the Figma "bridge disconnected" state: the
/// connection graphic with a "Disconnected" status caption and the machine
/// name of the bridge being reached, a "Reconnect" CTA, the always-visible
/// "Start your bridge" command, a "Why is this needed?" explainer, and an
/// expandable "Install commands" disclosure at the end for when the bridge
/// needs to be (re)installed. The "Need help?" support menu ([_NeedHelpMenu])
/// is not part of this scroll flow — it rides the scaffold's floating-action
/// slot.
///
/// A body, not a page: it is hosted in the project list's own page scroll (see
/// [ProjectListScreen]) so the large title collapses into the bar as the
/// expanded install commands scroll. Centred while it fits the viewport; the
/// enclosing sliver grows past it once it doesn't.
class _BridgeOfflineView extends StatefulWidget {
  const _BridgeOfflineView({required this.bridges});

  /// The account's registered bridges, most recently seen first. Names the
  /// machine the app is trying to reach; empty when the lookup failed (e.g.
  /// the phone itself is offline), which hides the machine row.
  final List<BridgeSummary> bridges;

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
          const SizedBox(height: PregoSpacing.lg),
          // "Disconnected ⊗" status caption: the crossed circle reads as part
          // of the caption, mirroring the check on the onboarding's connected
          // status line. Merged so screen readers announce it as one unit.
          MergeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    loc.projectsBridgeOfflineDisconnected,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                  child: Icon(
                    TablerRegular.circle_x,
                    size: 14,
                    color: prego.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.bridges.isNotEmpty) ...[
            const SizedBox(height: PregoSpacing.xxs),
            Center(child: _MachineNameRow(bridges: widget.bridges)),
          ],
          const SizedBox(height: PregoSpacing.x5l),
          PregoButtonsSolid(
            label: loc.projectsBridgeOfflineReconnect,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.xl,
            leadingIcon: TablerRegular.rotate_clockwise,
            fullWidth: true,
            isLoading: _reconnecting,
            onPressed: _reconnect,
          ),
          // Always visible: the bridge is already installed here, so the common
          // recovery is to (re)start it rather than reinstall.
          const SizedBox(height: PregoSpacing.xl),
          _InfoLabel(
            title: loc.projectsBridgeOfflineStartBridge,
            info: loc.projectsBridgeOfflineStartBridgeInfo,
          ),
          const SizedBox(height: PregoSpacing.md),
          const _CommandBoxFrame(
            child: _CommandActionRow(
              command: BridgeInstall.runCommand,
              copiedEvent: AnalyticsEvent.runCommandCopied(
                surface: OnboardingSurface.bridgeOffline,
              ),
              sharedEvent: AnalyticsEvent.runCommandShared(
                surface: OnboardingSurface.bridgeOffline,
              ),
            ),
          ),
          const SizedBox(height: PregoSpacing.xl),
          const _WhyBridgeButton(surface: OnboardingSurface.bridgeOffline),
          const SizedBox(height: PregoSpacing.xl),
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
                  _InstallCommandBoxes(surface: OnboardingSurface.bridgeOffline),
                  // Bottom breathing room so the last install box can be
                  // scrolled clear of the "Need help?" button pinned in the
                  // bottom-right corner. Inside the disclosure so the collapsed
                  // body keeps its exact vertical centring.
                  SizedBox(height: PregoSpacing.x6l),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The machine identity row under the "Disconnected" caption: a laptop glyph
/// and the most recently seen registered bridge's machine name (the hostname
/// the bridge registered with the auth server). With more than one registered
/// bridge a trailing chevron opens a flat anchored menu listing every machine,
/// so the user can tell which computers this account knows about; with a
/// single bridge the row is a plain, non-tappable label.
class _MachineNameRow extends StatelessWidget {
  const _MachineNameRow({required this.bridges});

  /// Most recently seen first (as sorted by `RegisteredBridgesService`); the
  /// first entry is the one named in the row. Never empty — the host omits
  /// the row entirely when no bridges are known.
  final List<BridgeSummary> bridges;

  /// Human-readable label for a bridge's reported platform id. Falls back to
  /// the raw value for platforms this app version doesn't know yet.
  static String _platformLabel({required String platform}) {
    return switch (platform) {
      "macos" => "macOS",
      "windows" => "Windows",
      "linux" => "Linux",
      _ => platform,
    };
  }

  Widget _buildRow(BuildContext context) {
    final prego = context.prego;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: Icon(TablerRegular.device_laptop, size: 12, color: prego.colors.textSecondary),
          ),
        ),
        Flexible(
          child: Text(
            bridges.first.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
          ),
        ),
        if (bridges.length > 1)
          SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Icon(TablerRegular.chevron_down, size: 12, color: prego.colors.textSecondary),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (bridges.length == 1) return _buildRow(context);

    // Several machines registered: the row becomes the trigger of a flat
    // anchored menu listing all of them, most recently seen first, with the
    // named (most recent) one marked selected. Purely informational — tapping
    // an entry only dismisses the menu. Flat on every platform so the popup
    // matches its flat text trigger instead of morphing in as glass.
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 260,
      // MergeSemantics folds the machine name, the button role, and the tap
      // action into a single node, so screen readers announce which machine
      // the row names and can activate the menu from that same node — the
      // bare nested GestureDetector would otherwise surface as a second,
      // unlabelled tappable node.
      triggerBuilder: (context, toggle) => MergeSemantics(
        child: Semantics(
          button: true,
          label: context.loc.projectsBridgeOfflineMachinesSemantics,
          onTap: toggle,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: toggle,
            child: _buildRow(context),
          ),
        ),
      ),
      entries: [
        for (final (index, bridge) in bridges.indexed)
          PregoMenuItem(
            leadingIcon: TablerRegular.device_laptop,
            title: bridge.name,
            subtitle: _platformLabel(platform: bridge.platform),
            isSelected: index == 0,
            onTap: () {},
          ),
      ],
    );
  }
}
