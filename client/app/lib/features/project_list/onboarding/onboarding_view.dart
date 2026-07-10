part of "../project_list_screen.dart";

// ===========================================================================
// Bridge onboarding
//
// The two empty Projects states have their own bodies now that they diverge:
// * disconnected — the connect-your-computer onboarding (connection graphic in
//   its "off" state): install + start the bridge. See [_ConnectBridgeChecklist].
// * connected, no projects — the graphic in its "on" state with a "Connected"
//   caption and an add-project call to action. See [_ConnectedEmptyView].
//
// Both are bodies, not pages: [ProjectListScreen] hosts them in its own page
// scroll — with the pull-to-refresh and the collapsing large title that come
// with it — rather than each nesting a scroll view of its own.
// ===========================================================================

/// The "connected, no projects" empty state: the connection graphic in its
/// "on" state with a success-colored "Connected" caption sitting high in the
/// body, and — anchored to the bottom — the no-projects message with the
/// add-project call to action, which opens the existing Add Project sheet.
class _ConnectedEmptyView extends StatelessWidget {
  const _ConnectedEmptyView();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 64px gap from the title area keeps the graphic in the upper portion
        // of the screen (Figma gap-7xl), clear of the bottom CTA group.
        const SizedBox(height: PregoSpacing.x7l),
        const Center(
          child: ExcludeSemantics(child: ConnectionGraphic.connectionOn()),
        ),
        const SizedBox(height: PregoSpacing.lg),
        Text.rich(
          TextSpan(
            children: [
              // "Connected" + check icon read as a single success-colored unit
              // confirming the connection.
              TextSpan(text: loc.projectsEmptyConnected),
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
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSuccessPrimary),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        Center(
          child: ConstrainedBox(
            // Figma caps the message at 224px so it wraps into a compact
            // two-line block instead of a full-width single line.
            constraints: const BoxConstraints(maxWidth: 224),
            child: Text(
              loc.projectsEmptyMessage,
              textAlign: TextAlign.center,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: PregoSpacing.xl),
        Center(
          child: PregoButtonsSolid(
            fullWidth: false,
            leadingIcon: TablerRegular.folder_plus,
            label: loc.projectsEmptyAddProject,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.xl,
            onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
          ),
        ),
        // 24px above the home-indicator inset the hosting SafeArea applies.
        const SizedBox(height: PregoSpacing.x3l),
      ],
    );
  }
}

/// The not-yet-connected onboarding body ("Connect your computer"): the
/// connection graphic in its "off" state with a "Waiting for bridge" caption,
/// then two numbered command steps — install the bridge, then start it — each
/// introduced by a label carrying an "ⓘ" info popover, and a "Why is this
/// needed?" explainer button. The "Need help?" support menu ([_NeedHelpMenu])
/// is not part of this scroll flow — it rides the scaffold's floating-action
/// slot.
class _ConnectBridgeChecklist extends StatelessWidget {
  const _ConnectBridgeChecklist();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: PregoSpacing.x4l),
        const Center(
          child: ExcludeSemantics(child: ConnectionGraphic.connectionOff()),
        ),
        const SizedBox(height: PregoSpacing.lg),
        Text(
          loc.projectsOnboardingWaitingForBridge,
          textAlign: TextAlign.center,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.x4l),
        Text(
          loc.projectsOnboardingRunOnComputer,
          textAlign: TextAlign.center,
          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
        ),
        const SizedBox(height: PregoSpacing.lg),
        // Step 1 — install: the OS segmented control drives the install-command
        // box; the numbered step label with its info popover sits between them.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
          child: _InstallCommandBoxes(
            surface: OnboardingSurface.connectSetup,
            stepHeader: _InfoLabel(
              title: "1. ${loc.projectsOnboardingInstallStepTitle}",
              info: loc.projectsOnboardingInstallStepInfo,
            ),
          ),
        ),
        const SizedBox(height: PregoSpacing.x2l),
        // Step 2 — start: a single, platform-independent command box.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLabel(
                title: "2. ${loc.projectsOnboardingStartStepTitle}",
                info: loc.projectsOnboardingStartStepInfo,
              ),
              const SizedBox(height: PregoSpacing.md),
              const _CommandBoxFrame(
                child: _CommandActionRow(
                  command: BridgeInstall.runCommand,
                  copiedEvent: AnalyticsEvent.runCommandCopied(
                    surface: OnboardingSurface.connectSetup,
                  ),
                  sharedEvent: AnalyticsEvent.runCommandShared(
                    surface: OnboardingSurface.connectSetup,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PregoSpacing.x3l),
        const _WhyBridgeButton(surface: OnboardingSurface.connectSetup),
        // Bottom breathing room so the last command box can be scrolled clear of
        // the "Need help?" button pinned in the bottom-right corner.
        const SizedBox(height: PregoSpacing.x6l),
      ],
    );
  }
}

/// The "Why is this needed?" explainer button: a compact tertiary (ghost)
/// pill that opens the [_WhyBridgeInfoSheet] bottom sheet. Centred so the
/// stretch parent doesn't force it full-width. Shared by both empty Projects
/// states and the bridge-offline recovery view.
class _WhyBridgeButton extends StatelessWidget {
  const _WhyBridgeButton({required this.surface});

  /// The onboarding surface hosting the button, reported with the open event.
  final OnboardingSurface surface;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return Center(
      child: PregoButtonsSolid(
        fullWidth: false,
        leadingIcon: TablerRegular.info_circle,
        label: loc.projectsOnboardingPcStatusWhy,
        hierarchy: PregoButtonsSolidHierarchy.tertiary,
        size: PregoButtonsSolidSize.sm,
        onPressed: () {
          unawaited(
            getIt<AnalyticsReporter>().logEvent(
              event: AnalyticsEvent.whyBridgeOpened(surface: surface),
            ),
          );
          showPregoBottomSheet<void>(
            context: context,
            title: loc.projectsOnboardingPcStatusWhy,
            builder: (_) => const _WhyBridgeInfoSheet(),
          );
        },
      ),
    );
  }
}

/// A command-box label with a trailing "ⓘ" info popover — e.g. "1. Install the
/// bridge ⓘ" on the connect onboarding or "Start your bridge ⓘ" on the
/// bridge-offline view. Tapping the icon opens a [PregoInfoPopover] (glass on
/// iOS, flat/`cue` on Android) anchored to it, showing [info].
class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.title, required this.info});

  final String title;
  final String info;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
          ),
        ),
        PregoInfoPopover(
          message: info,
          triggerBuilder: (_, toggle) => Semantics(
            button: true,
            label: loc.projectsOnboardingStepInfoSemantics,
            // Put the tap action on the same node as the button role + label so
            // screen readers (VoiceOver/TalkBack) can activate the popover: a
            // child GestureDetector's tap action lands on a separate semantics
            // node the assistive-tech focus doesn't target.
            onTap: toggle,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: toggle,
              // 40×40 hit area (matching [_CommandIconButton]) keeps the tap
              // target comfortably above the touch-target minimum while the
              // 16px glyph stays visually snug against the step title via the
              // small leading inset.
              child: SizedBox(
                width: 40,
                height: 40,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                    child: Icon(TablerRegular.info_circle, size: 16, color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The onboarding support menu: a low-emphasis "Need help?" tertiary (ghost)
/// button that opens a flat anchored menu of support channels (email, Discord,
/// X), each launching an external link. Forced flat on every platform
/// ([PregoAnchorMenu.flat]) so the popup matches its flat trigger instead of
/// morphing in as glass.
class _NeedHelpMenu extends StatelessWidget {
  const _NeedHelpMenu({required this.surface});

  /// The onboarding surface hosting the pill, reported with every event so
  /// help-seeking is attributable to the funnel step the user was on.
  final OnboardingSurface surface;

  /// Opens one of the "Need help?" contact links ([SupportLinks]) through the
  /// shared [openExternalLink] helper. Reports the tapped [channel] to
  /// analytics before launching, so the tap is counted even when the launch
  /// itself fails.
  Future<void> _openSupportLink({required String url, required SupportChannel channel}) {
    unawaited(
      getIt<AnalyticsReporter>().logEvent(
        event: AnalyticsEvent.supportLinkOpened(channel: channel, surface: surface),
      ),
    );
    return openExternalLink(url: Uri.parse(url));
  }

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
        onPressed: () {
          // While the popup is up its barrier covers the trigger, so a pill
          // tap can only ever open the menu — safe to count as an open.
          unawaited(
            getIt<AnalyticsReporter>().logEvent(
              event: AnalyticsEvent.needHelpMenuOpened(surface: surface),
            ),
          );
          toggle();
        },
      ),
      entries: [
        PregoMenuItem(
          leadingIcon: TablerRegular.mail,
          title: loc.projectsOnboardingNeedHelpEmail,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(
            _openSupportLink(url: SupportLinks.email, channel: SupportChannel.email),
          ),
        ),
        PregoMenuItem(
          leadingIcon: TablerRegular.brand_discord,
          title: loc.projectsOnboardingNeedHelpDiscord,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(
            _openSupportLink(url: SupportLinks.discord, channel: SupportChannel.discord),
          ),
        ),
        PregoMenuItem(
          // Tabler's pinned set ships the legacy bird glyph, not the X mark.
          leadingIcon: TablerRegular.brand_twitter,
          title: loc.projectsOnboardingNeedHelpX,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(
            _openSupportLink(url: SupportLinks.x, channel: SupportChannel.x),
          ),
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
  const _InstallCommandBoxes({required this.surface, this.stepHeader});

  /// The surface hosting the boxes, stamped on the copy/share analytics of
  /// every install method built here.
  final OnboardingSurface surface;

  /// Optional widget rendered between the OS segmented control and the install
  /// command box. The connect onboarding slots its "1. Install the bridge" step
  /// label here; the bridge-offline disclosure passes none and shows the switch
  /// directly above the box.
  final Widget? stepHeader;

  @override
  State<_InstallCommandBoxes> createState() => _InstallCommandBoxesState();
}

class _InstallCommandBoxesState extends State<_InstallCommandBoxes> {
  /// Index of the selected platform group; 0 (Unix) initially.
  int _selectedOs = 0;

  /// One install method entry with its copy/share analytics stamped from the
  /// method identity, the OS group it sits under, and this widget's surface.
  _InstallMethod _method({
    required String label,
    required String command,
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
  }) {
    return _InstallMethod(
      label: label,
      command: command,
      copiedEvent: AnalyticsEvent.installCommandCopied(
        method: method,
        os: os,
        surface: widget.surface,
      ),
      sharedEvent: AnalyticsEvent.installCommandShared(
        method: method,
        os: os,
        surface: widget.surface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    // The two platform groups the segmented control switches between. Built
    // per-frame so the labels/commands follow the active locale.
    final osGroups = <({String label, List<_InstallMethod> methods})>[
      (
        label: loc.projectsOnboardingInstallUnixLabel,
        methods: [
          _method(
            label: loc.projectsOnboardingInstallUnixMethod,
            command: BridgeInstall.macLinuxCommand,
            method: BridgeInstallMethod.curl,
            os: BridgeInstallOs.unix,
          ),
          _method(
            label: loc.projectsOnboardingInstallMethodNpm,
            command: BridgeInstall.npmCommand,
            method: BridgeInstallMethod.npm,
            os: BridgeInstallOs.unix,
          ),
          _method(
            label: loc.projectsOnboardingInstallMethodBun,
            command: BridgeInstall.bunCommand,
            method: BridgeInstallMethod.bun,
            os: BridgeInstallOs.unix,
          ),
        ],
      ),
      (
        label: loc.projectsOnboardingInstallWindowsLabel,
        methods: [
          _method(
            label: loc.projectsOnboardingInstallWindowsMethod,
            command: BridgeInstall.windowsCommand,
            method: BridgeInstallMethod.powershell,
            os: BridgeInstallOs.windows,
          ),
          _method(
            label: loc.projectsOnboardingInstallMethodNpm,
            command: BridgeInstall.npmCommand,
            method: BridgeInstallMethod.npm,
            os: BridgeInstallOs.windows,
          ),
          _method(
            label: loc.projectsOnboardingInstallMethodBun,
            command: BridgeInstall.bunCommand,
            method: BridgeInstallMethod.bun,
            os: BridgeInstallOs.windows,
          ),
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
        if (widget.stepHeader case final stepHeader?) ...[
          stepHeader,
          const SizedBox(height: PregoSpacing.lg),
        ],
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
      height: 36,
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
/// [label] (e.g. "curl", "npm"), the one-line [command] it installs with, and
/// the pre-built analytics events its copy/share actions report.
class _InstallMethod {
  const _InstallMethod({
    required this.label,
    required this.command,
    required this.copiedEvent,
    required this.sharedEvent,
  });

  /// Tab label (literal tool name — not translated).
  final String label;

  /// The one-line install command shown and copied when this tab is selected.
  final String command;

  /// Logged when this method's command is copied, carrying the method/OS/
  /// surface identity stamped by [_InstallCommandBoxesState].
  final AnalyticsEvent copiedEvent;

  /// Logged when this method's command is shared.
  final AnalyticsEvent sharedEvent;
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
          _CommandActionRow(
            command: _selected.command,
            copiedEvent: _selected.copiedEvent,
            sharedEvent: _selected.sharedEvent,
            topDivider: true,
          ),
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
/// bridge-offline "Start your bridge" box, so both command boxes read as the
/// same component. Clips [child] to the radius and paints the border on top.
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
/// box and the bridge-offline "Start your bridge" box. Shows [command] on a single
/// monospace line that fades out at the trailing edge — so an over-long command
/// reads as continuing off-screen rather than hard-clipping — with copy and
/// native-share buttons. [topDivider] draws the hairline separating this row
/// from the method tabs above it in the install box.
class _CommandActionRow extends StatefulWidget {
  const _CommandActionRow({
    required this.command,
    required this.copiedEvent,
    required this.sharedEvent,
    this.topDivider = false,
  });

  final String command;

  /// Logged when the copy action is tapped. Pre-built by the host, which knows
  /// the command's identity (install method/OS or run) and surface.
  final AnalyticsEvent copiedEvent;

  /// Logged when the share action is tapped.
  final AnalyticsEvent sharedEvent;

  final bool topDivider;

  @override
  State<_CommandActionRow> createState() => _CommandActionRowState();
}

class _CommandActionRowState extends State<_CommandActionRow> {
  Future<void> _copyCommand() async {
    // Reported before attempting the write, so the tap is counted even when
    // the clipboard fails.
    unawaited(getIt<AnalyticsReporter>().logEvent(event: widget.copiedEvent));
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
    // Reported before raising the sheet, so the tap is counted even when the
    // share itself fails.
    unawaited(getIt<AnalyticsReporter>().logEvent(event: widget.sharedEvent));
    // iPad presents the share sheet as a popover anchored to a source rect;
    // derive it from this row so the popover points at the command instead of
    // floating (an unanchored sheet throws on iPad).
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.attached && renderObject.hasSize
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
