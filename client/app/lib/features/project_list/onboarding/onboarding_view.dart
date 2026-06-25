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

/// The shared onboarding body: the phone/PC connection status lines, the
/// connection graphic, the "Why is this needed?" info button, and the
/// per-platform install command boxes.
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
        // TODO(daniil): add the button back
        /* Center(
          child: PregoButtonsSolid(
            fullWidth: false,
            leadingIcon: TablerRegular.info_circle,
            label: loc.projectsOnboardingPcStatusWhy,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.sm,
            onPressed: () {
              // TODO(daniil): show the new bottom sheet
            },
          ),
        ),*/
        // 40px gap from the header group to the install boxes (Figma gap-5xl).
        const SizedBox(height: PregoSpacing.x5l),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.xl, 0, PregoSpacing.xl, PregoSpacing.x3l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InstallCommandBox(
                osLabel: loc.projectsOnboardingInstallUnixLabel,
                methods: [
                  _InstallMethod(
                    label: loc.projectsOnboardingInstallUnixMethod,
                    command: BridgeInstall.macLinuxCommand,
                  ),
                  _InstallMethod(
                    label: loc.projectsOnboardingInstallMethodNpm,
                    command: BridgeInstall.npmCommand,
                  ),
                  _InstallMethod(
                    label: loc.projectsOnboardingInstallMethodBun,
                    command: BridgeInstall.bunCommand,
                  ),
                ],
              ),
              const SizedBox(height: PregoSpacing.xl),
              _InstallCommandBox(
                osLabel: loc.projectsOnboardingInstallWindowsLabel,
                methods: [
                  _InstallMethod(
                    label: loc.projectsOnboardingInstallWindowsMethod,
                    command: BridgeInstall.windowsCommand,
                  ),
                  _InstallMethod(
                    label: loc.projectsOnboardingInstallMethodNpm,
                    command: BridgeInstall.npmCommand,
                  ),
                  _InstallMethod(
                    label: loc.projectsOnboardingInstallMethodBun,
                    command: BridgeInstall.bunCommand,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
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

/// One platform's install instruction: a group label (e.g. "macOS, Linux,
/// WSL"), a row of method tabs (e.g. curl/npm/bun), and the monospace one-line
/// command for the selected method with a copy-to-clipboard button. Mirrors the
/// Figma onboarding install boxes.
class _InstallCommandBox extends StatefulWidget {
  const _InstallCommandBox({
    required this.osLabel,
    required this.methods,
  });

  /// Platform group label shown above the box.
  final String osLabel;

  /// Selectable install methods; the first is selected initially.
  final List<_InstallMethod> methods;

  @override
  State<_InstallCommandBox> createState() => _InstallCommandBoxState();
}

class _InstallCommandBoxState extends State<_InstallCommandBox> {
  int _selectedIndex = 0;

  _InstallMethod get _selected => widget.methods[_selectedIndex];

  Future<void> _copyCommand() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    // Clipboard can throw on restricted platforms/states; fail soft and skip
    // the success snackbar, matching _CommandBlock.
    try {
      await Clipboard.setData(ClipboardData(text: _selected.command));
    } on Object catch (_) {
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
    final command = _selected.command;
    // iPad presents the share sheet as a popover anchored to a source rect;
    // derive it from this box so the popover points at the command instead of
    // floating (an unanchored sheet throws on iPad).
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      await SharePlus.instance.share(ShareParams(text: command, sharePositionOrigin: origin));
    } on Object catch (error, stackTrace) {
      // Dismissing the sheet is reported via ShareResultStatus, not a throw, so
      // reaching here is a real platform failure with nothing to recover — log
      // it and move on.
      logw("Failed to share install command", error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final colors = prego.colors;
    final loc = context.loc;
    final mono = prego.textTheme.textXs.regular.copyWith(color: colors.textSecondary).monospace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.osLabel,
          style: prego.textTheme.textSm.regular.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: PregoSpacing.md),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PregoRadius.xl),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PregoRadius.xl),
            border: Border.all(color: colors.borderPrimary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Method tabs (curl/npm/bun); the selected one is highlighted and
              // drives the command shown below.
              Container(
                width: double.infinity,
                color: colors.bgSurface2,
                padding: const EdgeInsetsDirectional.only(
                  start: PregoSpacing.sm,
                  end: PregoSpacing.sm,
                  top: PregoSpacing.xs,
                  bottom: PregoSpacing.xs,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.methods.length; i++) _buildTab(index: i),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.bgSurface1,
                  border: Border(top: BorderSide(color: colors.borderSecondary)),
                ),
                padding: const EdgeInsetsDirectional.only(
                  start: PregoSpacing.lg,
                  top: PregoSpacing.sm,
                  bottom: PregoSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      // semanticsLabel carries the full command so screen readers
                      // read it even though the visible text clamps to one line.
                      child: Text(
                        _selected.command,
                        semanticsLabel: _selected.command,
                        style: mono,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Transparent Material so the InkResponse splash paints on
                    // top of the bgSurface1 fill — without it the ripple renders
                    // on the Scaffold's Material, hidden behind this Container.
                    Semantics(
                      button: true,
                      label: loc.projectsOnboardingCopyCommand,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkResponse(
                          onTap: _copyCommand,
                          radius: 22,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(TablerRegular.copy, size: 18, color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Hands the selected command to the native share sheet so it
                    // can be sent to the machine that will run it (AirDrop, etc.).
                    Semantics(
                      button: true,
                      label: loc.projectsOnboardingShareCommand,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkResponse(
                          onTap: _shareCommand,
                          radius: 22,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(TablerRegular.share_3, size: 18, color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ),
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
      // bgSurface2 tab strip instead of behind it on the Scaffold's Material.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: selected ? null : () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(PregoRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.xs),
            // The selected tab reads as the active method (brand color + bold);
            // the rest stay quiet in the secondary text color.
            child: Text(
              method.label,
              style: selected
                  ? prego.textTheme.textSm.bold.copyWith(color: colors.textPrimaryOnBrand)
                  : prego.textTheme.textSm.regular.copyWith(color: colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
