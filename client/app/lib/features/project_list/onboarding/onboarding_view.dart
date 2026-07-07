part of "../project_list_screen.dart";

// ===========================================================================
// Bridge onboarding
//
// One shared onboarding body drives both empty Projects states:
// * disconnected — the connect-your-computer onboarding (connection graphic in
//   its "off" state). See [_BridgeOnboardingView].
// * connected, no projects — the same body with the graphic in its "on" state.
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

/// Opens one of the "Need help?" contact links ([SupportLinks]) through the
/// shared [openExternalLink] helper.
Future<void> _openSupportLink({required String url}) => openExternalLink(url: Uri.parse(url));

/// The shared onboarding body: the phone/PC connection status lines, the
/// connection graphic, and the per-platform install command boxes. The
/// "Need help?" support menu ([_NeedHelpMenu]) is not part of this scroll flow —
/// it rides the scaffold's floating-action slot, pinned to the bottom-right
/// corner above the home indicator.
///
/// [connected] switches the connection graphic between its "off" and "on"
/// states; the rest of the body is shared by both empty Projects states.
class _OnboardingChecklist extends StatelessWidget {
  const _OnboardingChecklist({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: loc.projectsOnboardingPhoneStatusStep),
              const TextSpan(text: " "),
              // "Phone connected" + check icon read as a single success-colored
              // unit confirming the connection.
              TextSpan(
                text: loc.projectsOnboardingPhoneStatusConnected,
                style: TextStyle(color: prego.colors.textSuccessPrimary),
              ),
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                  child: Icon(
                    TablerRegular.circle_check,
                    size: 14,
                    color: prego.colors.textSuccessPrimary,
                  ),
                ),
              ),
            ],
          ),
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PregoSpacing.x4l),
        Center(
          child: ExcludeSemantics(
            child: connected ? const ConnectionGraphic.connectionOn() : const ConnectionGraphic.connectionOff(),
          ),
        ),
        const SizedBox(height: PregoSpacing.lg),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: loc.projectsOnboardingPcStatusStep),
              const TextSpan(text: " "),
              TextSpan(
                text: loc.projectsOnboardingPcStatusRun,
                style: TextStyle(color: prego.colors.textSecondary),
              ),
            ],
          ),
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PregoSpacing.lg),
        // Wrapped so the parent Column's stretch alignment doesn't force the
        // button full-width; fullWidth: false then sizes it to its content.
        Center(
          child: PregoButtonsSolid(
            fullWidth: false,
            leadingIcon: TablerRegular.info_circle,
            label: loc.projectsOnboardingPcStatusWhy,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: () => showPregoBottomSheet<void>(
              context: context,
              title: loc.projectsOnboardingPcStatusWhy,
              builder: (_) => const _WhyBridgeInfoSheet(),
            ),
          ),
        ),
        // 40px gap from the header group to the install boxes (Figma gap-5xl).
        const SizedBox(height: PregoSpacing.x5l),
        const Padding(
          padding: EdgeInsetsDirectional.fromSTEB(PregoSpacing.xl, 0, PregoSpacing.xl, PregoSpacing.x3l),
          child: _InstallCommandBoxes(),
        ),
        // Bottom breathing room so the last install box can be scrolled clear of
        // the "Need help?" button pinned in the bottom-right corner.
        const SizedBox(height: PregoSpacing.x6l),
      ],
    );
  }
}

/// The onboarding support menu: a flat "Need help?" pill that opens a flat
/// anchored menu of support channels (email, Discord, X), each launching an
/// external link. Forced flat on every platform ([PregoAnchorMenu.flat]) so the
/// popup matches its solid pill trigger instead of morphing in as glass.
class _NeedHelpMenu extends StatelessWidget {
  const _NeedHelpMenu();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 200,
      triggerBuilder: (context, toggle) => PregoButtonsSolid(
        leadingIcon: TablerRegular.help,
        label: loc.projectsOnboardingNeedHelp,
        hierarchy: PregoButtonsSolidHierarchy.secondary,
        size: PregoButtonsSolidSize.xl,
        onPressed: toggle,
      ),
      entries: [
        PregoMenuItem(
          leadingIcon: TablerRegular.mail,
          title: loc.projectsOnboardingNeedHelpEmail,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(_openSupportLink(url: SupportLinks.email)),
        ),
        PregoMenuItem(
          leadingIcon: TablerRegular.brand_discord,
          title: loc.projectsOnboardingNeedHelpDiscord,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(_openSupportLink(url: SupportLinks.discord)),
        ),
        PregoMenuItem(
          // Tabler's pinned set ships the legacy bird glyph, not the X mark.
          leadingIcon: TablerRegular.brand_twitter,
          title: loc.projectsOnboardingNeedHelpX,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(_openSupportLink(url: SupportLinks.x)),
        ),
      ],
    );
  }
}

/// The per-platform install commands: a flat iOS-style segmented control that
/// switches between the Unix (macOS/Linux/WSL) and Windows install groups, and
/// a single [_InstallCommandBox] showing the selected group's methods. Shared
/// by the [_OnboardingChecklist] and the bridge-offline reconnect disclosure
/// ([_BridgeOfflineView]) so both stay in sync; callers supply their own
/// surrounding padding.
class _InstallCommandBoxes extends StatefulWidget {
  const _InstallCommandBoxes();

  @override
  State<_InstallCommandBoxes> createState() => _InstallCommandBoxesState();
}

class _InstallCommandBoxesState extends State<_InstallCommandBoxes> {
  /// Index of the selected platform group; 0 (Unix) initially.
  int _selectedOs = 0;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    // The two platform groups the segmented control switches between. Built
    // per-frame so the labels/commands follow the active locale.
    final osGroups = <({String label, List<_InstallMethod> methods})>[
      (
        label: loc.projectsOnboardingInstallUnixLabel,
        methods: [
          _InstallMethod(label: loc.projectsOnboardingInstallUnixMethod, command: BridgeInstall.macLinuxCommand),
          _InstallMethod(label: loc.projectsOnboardingInstallMethodNpm, command: BridgeInstall.npmCommand),
          _InstallMethod(label: loc.projectsOnboardingInstallMethodBun, command: BridgeInstall.bunCommand),
        ],
      ),
      (
        label: loc.projectsOnboardingInstallWindowsLabel,
        methods: [
          _InstallMethod(label: loc.projectsOnboardingInstallWindowsMethod, command: BridgeInstall.windowsCommand),
          _InstallMethod(label: loc.projectsOnboardingInstallMethodNpm, command: BridgeInstall.npmCommand),
          _InstallMethod(label: loc.projectsOnboardingInstallMethodBun, command: BridgeInstall.bunCommand),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OsSegmentedControl(
          labels: [for (final group in osGroups) group.label],
          selectedIndex: _selectedOs,
          onChanged: (index) => setState(() => _selectedOs = index),
        ),
        const SizedBox(height: PregoSpacing.lg),
        // Keyed by platform so switching groups remounts the box and resets its
        // method tab to the group's first entry (curl / native).
        _InstallCommandBox(
          key: ValueKey(_selectedOs),
          methods: osGroups[_selectedOs].methods,
        ),
      ],
    );
  }
}

/// Flat, non-glass segmented control that switches the install command group.
/// Matches the Figma's pill-shaped iOS segmented control — a fully-rounded track
/// with a rounded thumb that slides under the selected segment. Flutter's
/// [CupertinoSlidingSegmentedControl] can't be used because its track (9px) and
/// thumb (7px) corner radii are hardcoded constants with no override, and the
/// design wants a full pill; this is a compact reimplementation that reuses the
/// same adaptive iOS fills (so it themes in light and dark) with the prego text
/// theme for the labels. Selection is tap-driven — the two-segment switch has no
/// need for Cupertino's drag-to-slide gesture — and the thumb still animates.
class _OsSegmentedControl extends StatelessWidget {
  const _OsSegmentedControl({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// iOS segmented-control thumb fill (white in light, grey in dark) and its
  /// subtle lift shadow, taken from Cupertino's own values so the thumb reads as
  /// native despite the rounder pill shape.
  static const CupertinoDynamicColor _thumbColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF636366),
  );
  static const List<BoxShadow> _thumbShadow = [
    BoxShadow(color: Color(0x1F000000), offset: Offset(0, 3), blurRadius: 8),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 3), blurRadius: 1),
  ];

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final count = labels.length;

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        shape: const StadiumBorder(),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / count;
          return Stack(
            fit: StackFit.expand,
            children: [
              // The sliding thumb: one segment wide, positioned under the
              // selected label and glided into place on selection change.
              AnimatedPositioned(
                duration: context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: selectedIndex * segmentWidth,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: _thumbColor.resolveFrom(context),
                      shape: const StadiumBorder(),
                      shadows: _thumbShadow,
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == selectedIndex,
                        label: labels[i],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: i == selectedIndex ? null : () => onChanged(i),
                          child: Center(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              // Selected segment is bolded to highlight it,
                              // matching the design.
                              style: (i == selectedIndex ? prego.textTheme.textSm.bold : prego.textTheme.textSm.regular)
                                  .copyWith(color: prego.colors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One selectable install method within an [_InstallCommandBox]: the tab
/// [label] (e.g. "curl", "npm") and the one-line [command] it installs with.
class _InstallMethod {
  const _InstallMethod({required this.label, required this.command});

  /// Tab label (literal tool name — not translated).
  final String label;

  /// The one-line install command shown and copied when this tab is selected.
  final String command;
}

/// One platform's install instruction box: a row of method tabs (e.g.
/// curl/npm/bun) and, below them, the monospace one-line command for the
/// selected method with copy and share actions. The platform group is chosen by
/// the [_OsSegmentedControl] above it; this box just renders the given
/// [methods]. Mirrors the Figma onboarding install box.
class _InstallCommandBox extends StatefulWidget {
  const _InstallCommandBox({super.key, required this.methods});

  /// Selectable install methods; the first is selected initially.
  final List<_InstallMethod> methods;

  @override
  State<_InstallCommandBox> createState() => _InstallCommandBoxState();
}

class _InstallCommandBoxState extends State<_InstallCommandBox> {
  int _selectedIndex = 0;

  _InstallMethod get _selected => widget.methods[_selectedIndex];

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;

    return _CommandBoxFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Method tabs (curl/npm/bun); the selected one is highlighted and
          // drives the command shown below.
          Container(
            width: double.infinity,
            color: colors.bgSurface3,
            child: Row(
              spacing: PregoSpacing.sm,
              children: [
                for (var i = 0; i < widget.methods.length; i++) _buildTab(index: i),
              ],
            ),
          ),
          _CommandActionRow(command: _selected.command, topDivider: true),
        ],
      ),
    );
  }

  Widget _buildTab({required int index}) {
    final prego = context.prego;
    final colors = prego.colors;
    final method = widget.methods[index];
    final selected = index == _selectedIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: method.label,
      // Transparent Material so the InkWell splash paints on top of the
      // bgSurface3 tab strip instead of behind it on the Scaffold's Material.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: selected ? null : () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(PregoRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: PregoSpacing.md),
            // The selected tab reads as the active method (brand color); the
            // rest stay quiet in the tertiary text color. Both are bold to match
            // the Figma tab strip.
            child: Text(
              method.label,
              style: prego.textTheme.textSm.bold.copyWith(
                color: selected ? colors.textPrimaryOnBrand : colors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rounded, bordered chrome shared by the install-command box and the
/// bridge-offline "Run the bridge" box, so both command boxes read as the same
/// component. Clips [child] to the radius and paints the border on top.
class _CommandBoxFrame extends StatelessWidget {
  const _CommandBoxFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PregoRadius.xl),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PregoRadius.xl),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: child,
    );
  }
}

/// The command display plus copy/share actions, shared by the install-command
/// box and the bridge-offline "Run the bridge" box. Shows [command] on a single
/// monospace line that fades out at the trailing edge — so an over-long command
/// reads as continuing off-screen rather than hard-clipping — with copy and
/// native-share buttons. [topDivider] draws the hairline separating this row
/// from the method tabs above it in the install box.
class _CommandActionRow extends StatefulWidget {
  const _CommandActionRow({required this.command, this.topDivider = false});

  final String command;
  final bool topDivider;

  @override
  State<_CommandActionRow> createState() => _CommandActionRowState();
}

class _CommandActionRowState extends State<_CommandActionRow> {
  Future<void> _copyCommand() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    // Clipboard can throw on restricted platforms/states; fail soft and skip
    // the success snackbar. Log so a broken copy button leaves a diagnostic
    // trail instead of failing silently.
    try {
      await Clipboard.setData(ClipboardData(text: widget.command));
    } on Object catch (error, stackTrace) {
      logw("Failed to copy command", error, stackTrace);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.projectsOnboardingCommandCopied),
        duration: kSnackBarDuration,
      ),
    );
  }

  Future<void> _shareCommand() async {
    // iPad presents the share sheet as a popover anchored to a source rect;
    // derive it from this row so the popover points at the command instead of
    // floating (an unanchored sheet throws on iPad).
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      await SharePlus.instance.share(ShareParams(text: widget.command, sharePositionOrigin: origin));
    } on Object catch (error, stackTrace) {
      // Dismissing the sheet is reported via ShareResultStatus, not a throw, so
      // reaching here is a real platform failure with nothing to recover — log
      // it and move on.
      logw("Failed to share command", error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final loc = context.loc;
    final mono = prego.textTheme.textXs.regular.copyWith(color: colors.textSecondary).monospace;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        border: widget.topDivider ? Border(top: BorderSide(color: colors.borderSecondary)) : null,
      ),
      padding: const EdgeInsetsDirectional.only(
        start: PregoSpacing.lg,
        top: PregoSpacing.sm,
        bottom: PregoSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              // Fade the trailing edge to transparent so a long command reads as
              // continuing off-screen instead of hard-clipping with an ellipsis.
              // The gradient only bites the rightmost sliver, so short commands
              // are unaffected.
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.black, Colors.black, Color(0x00000000)],
                stops: [0.0, 0.88, 1.0],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              // semanticsLabel carries the full command so screen readers read
              // it even though the visible text clamps to one line.
              child: Text(
                widget.command,
                semanticsLabel: widget.command,
                style: mono,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
              ),
            ),
          ),
          const SizedBox(width: PregoSpacing.md),
          _CommandIconButton(
            icon: TablerRegular.copy,
            label: loc.projectsOnboardingCopyCommand,
            onTap: _copyCommand,
          ),
          // Hands the command to the native share sheet so it can be sent to the
          // machine that will run it (AirDrop, etc.).
          _CommandIconButton(
            icon: TablerRegular.share_3,
            label: loc.projectsOnboardingShareCommand,
            onTap: _shareCommand,
          ),
        ],
      ),
    );
  }
}

/// A 40×40 tap target rendering [icon] over the command surface, used for the
/// copy and share actions. Transparent [Material] so the ripple paints on top
/// of the surface fill rather than behind it on the Scaffold's Material.
class _CommandIconButton extends StatelessWidget {
  const _CommandIconButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.prego.colors;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        type: MaterialType.transparency,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
