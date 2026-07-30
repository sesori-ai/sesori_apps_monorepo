part of "../project_list_screen.dart";

/// Shown when the account has a bridge registered but none is connected — the
/// user already completed setup, so instead of the install onboarding they are
/// asked to bring the bridge back up. Mirrors the Figma "bridge disconnected"
/// state (node 2325:48309): the connection graphic over the machine name of
/// the bridge being reached and a "Disconnected · <last seen>" status line,
/// then the always-visible start-the-bridge command, a "Why is this needed?"
/// explainer, and an expandable "Install commands" disclosure at the end for
/// when the bridge needs to be (re)installed. The "Need help?" support menu
/// ([_NeedHelpMenu]) is not part of this scroll flow — it rides the scaffold's
/// floating-action slot.
///
/// There is no reconnect button: reconnecting is what the page already does on
/// its own and on pull-to-refresh, so the design spends the space on the
/// command the user actually has to run.
///
/// A body, not a page: it is hosted in the project list's own page scroll (see
/// [ProjectListScreen]) so the expanded install commands scroll under a fixed
/// bar. Anchored to the top of that page at the design's offset; the enclosing
/// sliver grows past the viewport once the body outgrows it.
class _BridgeOfflineView extends StatefulWidget {
  const _BridgeOfflineView({required this.bridge});

  /// The machine the app is trying to reach — the account's most recently seen
  /// registered bridge. Null while the lookup has no answer, or when it failed
  /// (e.g. the phone itself is offline); the machine row is hidden then.
  final BridgeSummary? bridge;

  @override
  State<_BridgeOfflineView> createState() => _BridgeOfflineViewState();
}

class _BridgeOfflineViewState extends State<_BridgeOfflineView> {
  /// Whether the "Install commands" disclosure is expanded.
  bool _showInstallCommands = false;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final bridge = widget.bridge;
    final lastSeenAt = bridge?.lastSeenAt;

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
          // The machine identity leads: the graphic already says "not
          // connected", so the open question is which machine is unreachable.
          // The status line answers the follow-up underneath it.
          if (bridge != null) ...[
            Center(child: _MachineNameRow(name: bridge.name)),
            const SizedBox(height: PregoSpacing.xxs),
          ],
          Text(
            lastSeenAt == null
                ? loc.projectsBridgeOfflineDisconnected
                // How long the bridge has been gone separates "I just closed
                // the laptop lid" from "this has been down for days". Refreshed
                // by the screen's minute ticker.
                : loc.projectsBridgeOfflineDisconnectedSince(
                    context.formatTimestamp(lastSeenAt.millisecondsSinceEpoch),
                  ),
            textAlign: TextAlign.center,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x5l),
          // Always visible: the bridge is already installed here, so the common
          // recovery is to (re)start it rather than reinstall.
          _InfoLabel(
            title: loc.projectsBridgeOfflineStartBridge,
            info: loc.projectsBridgeOfflineStartBridgeInfo,
            centered: true,
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
                  // scrolled clear of the "Need help?" button floating at the
                  // bottom of the page.
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

/// The machine identity row naming the bridge being reached (the hostname the
/// bridge registered with the auth server), shown beside a laptop glyph. A
/// static, non-interactive label — the account runs a single bridge at a time,
/// so there is nothing to act on here.
///
/// Reads in `text-primary`: it is the headline of the offline body, with the
/// status line beneath it as the quiet second read.
class _MachineNameRow extends StatelessWidget {
  const _MachineNameRow({required this.name});

  /// The registered bridge's machine name.
  final String name;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final color = prego.colors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Center(
            child: Icon(TablerRegular.device_laptop, size: 12, color: color),
          ),
        ),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textSm.regular.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
