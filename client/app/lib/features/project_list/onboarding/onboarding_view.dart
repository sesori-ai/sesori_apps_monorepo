part of "../project_list_screen.dart";

// ===========================================================================
// Bridge onboarding
//
// The two empty Projects states have their own bodies now that they diverge:
// * disconnected — the connect-your-computer onboarding (connection graphic in
//   its "off" state): install + start the bridge. See [_ConnectBridgeChecklist].
// * connected, no projects — the stacked-folders graphic over an add-project
//   call to action. See [_ConnectedEmptyView].
//
// Both are bodies, not pages: [ProjectListScreen] hosts them in its own page
// scroll — with the pull-to-refresh that comes with it — rather than each
// nesting a scroll view of its own.
// ===========================================================================

/// The "connected, no projects" empty state: the stacked-folders graphic, the
/// no-projects message and the call to action that opens the existing Add
/// Project sheet, as one block centred in the body.
///
/// The connection itself is not restated here — the design puts the machine
/// identity in the top navigation, and this screen only reports it when the
/// bridge is *not* connected ([_BridgeOfflineView]).
class _ConnectedEmptyView extends StatelessWidget {
  const _ConnectedEmptyView();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;

    // Centred in the body rather than at the design's exact screen centre: the
    // top bar takes the space above, so the group sits in the middle of what is
    // left of the page.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(child: _EmptyProjectsGraphic()),
          const SizedBox(height: PregoSpacing.x6l),
          SizedBox(
            // Figma caps the block at 224px so the message wraps into a compact
            // two-line paragraph and the button matches its width.
            width: 224,
            child: Column(
              children: [
                Text(
                  loc.projectsEmptyMessage,
                  textAlign: TextAlign.center,
                  style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
                ),
                const SizedBox(height: PregoSpacing.xl),
                PregoButtonsSolid(
                  fullWidth: true,
                  leadingIcon: TablerRegular.folder_plus,
                  label: loc.projectsEmptyAddProject,
                  hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                  size: PregoButtonsSolidSize.xl,
                  onPressed: () => showAddProjectDialog(context, context.read<ProjectListCubit>()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The stacked-folders illustration of the connected-but-empty Projects
/// screen, exported as PNGs from the Figma "Mask group" node (`3756:7644`):
/// two overlapping folder outlines carrying a "+" glyph, fading out towards
/// the bottom. Light and dark artwork (plus @2x/@3x variants) ship separately —
/// the folders are drawn near-white on the light surface and near-black on the
/// dark one, so both stay a subtle tone above the background.
///
/// Rendered at the 241×150 Figma frame size, pinned rather than taken from the
/// decoded asset: an unsized [Image] reports a *max intrinsic* height of
/// `crossAxisExtent / aspectRatio`, and the hosting
/// `SliverFillRemaining(hasScrollBody: false)` sizes itself from that — an
/// unsized graphic would inflate the page's scroll extent with empty space.
class _EmptyProjectsGraphic extends StatelessWidget {
  const _EmptyProjectsGraphic();

  static const double _width = 241;
  static const double _height = 150;

  static const String _dir = "assets/images/projects_onboarding/empty_projects_graphic";
  static const String _light = "$_dir/empty_projects-light.png";
  static const String _dark = "$_dir/empty_projects-dark.png";

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      context.isDarkMode ? _dark : _light,
      width: _width,
      height: _height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
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
        const SizedBox(height: PregoSpacing.x6l),
        const Center(
          child: ExcludeSemantics(child: ConnectionGraphic.connectionOff()),
        ),
        const SizedBox(height: PregoSpacing.sm),
        Text(
          loc.projectsOnboardingWaitingForBridge,
          textAlign: TextAlign.center,
          style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.x5l),
        Text(
          loc.projectsOnboardingRunOnComputer,
          textAlign: TextAlign.center,
          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
        ),
        const SizedBox(height: PregoSpacing.xl),
        // Step 1 — install: the OS segmented control drives the install-command
        // box; the numbered step label with its info popover sits between them.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
          child: _InstallCommandBoxes(
            surface: OnboardingSurface.connectSetup,
            stepHeader: _InfoLabel(
              title: "1. ${loc.projectsOnboardingInstallStepTitle}",
              info: loc.projectsOnboardingInstallStepInfo,
              centered: false,
            ),
          ),
        ),
        const SizedBox(height: PregoSpacing.xl),
        // Step 2 — start: a single, platform-independent command box.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoLabel(
                title: "2. ${loc.projectsOnboardingStartStepTitle}",
                info: loc.projectsOnboardingStartStepInfo,
                centered: false,
              ),
              const SizedBox(height: PregoSpacing.md),
              _CommandBoxFrame(
                child: _CommandActionRow(
                  command: BridgeInstall.runCommand,
                  reportCopied: (cubit) => cubit.reportRunCommandCopied(surface: OnboardingSurface.connectSetup),
                  reportShared: (cubit) => cubit.reportRunCommandShared(surface: OnboardingSurface.connectSetup),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PregoSpacing.xl),
        const _WhyBridgeButton(surface: OnboardingSurface.connectSetup),
        // Bottom breathing room so the last command box can be scrolled clear
        // of the "Need help?" button pinned centred at the bottom of the page.
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
          final presentation = showPregoBottomSheet<void>(
            context: context,
            title: loc.projectsOnboardingPcStatusWhy,
            builder: (_) => const _WhyBridgeInfoSheet(),
          );
          context.read<ProjectListCubit>().reportWhyBridgeOpened(surface: surface);
          unawaited(presentation);
        },
      ),
    );
  }
}

/// A command-box label with a trailing "ⓘ" info popover — e.g. "1. Install the
/// bridge ⓘ" on the connect onboarding or "Make sure the Bridge is running ⓘ"
/// on the bridge-offline view. Tapping the icon opens a [PregoInfoPopover]
/// (glass on iOS, flat/`cue` on Android) anchored to it, showing [info].
class _InfoLabel extends StatelessWidget {
  const _InfoLabel({required this.title, required this.info, required this.centered});

  final String title;
  final String info;

  /// Centres the label + icon pair instead of aligning it to the start. The
  /// numbered onboarding steps sit above a full-width box and read as a list,
  /// so they stay start-aligned; the bridge-offline label heads a centred
  /// composition.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    return Row(
      mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        // The info icon's 40px tap target holds its 12px glyph against its
        // start, leaving 24px of dead space at the end. An equal gap in front
        // centres what the user actually sees rather than the hit box — and
        // keeps it centred once the title grows wide enough to claim the whole
        // row, where the spacer becomes the leading margin matching the glyph's
        // trailing one.
        if (centered) const SizedBox(width: 24),
        Flexible(
          child: Text(
            title,
            // A title too long for one line (long locale, large text scale)
            // wraps; centre those lines so the block still reads as centred
            // rather than ragged against the leading edge.
            textAlign: centered ? TextAlign.center : TextAlign.start,
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
              // 40×40 hit area keeps the tap target comfortably above the
              // touch-target minimum while the 12px glyph stays visually snug
              // against the step title via the small leading inset.
              child: SizedBox(
                width: 40,
                height: 40,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: PregoSpacing.xs),
                    child: Icon(TablerRegular.info_circle, size: 12, color: prego.colors.textSecondary),
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
  /// analytics only after the platform confirms the handoff.
  Future<void> _openSupportLink({
    required ProjectListCubit cubit,
    required String url,
    required SupportChannel channel,
  }) async {
    final launched = await openExternalLink(url: Uri.parse(url), mode: UrlLaunchMode.externalApp);
    if (launched) {
      cubit.reportSupportLinkOpened(channel: channel, surface: surface);
    }
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
          toggle();
          context.read<ProjectListCubit>().reportNeedHelpMenuOpened(surface: surface);
        },
      ),
      entriesBuilder: () => [
        PregoMenuItem(
          leadingIcon: TablerRegular.mail,
          title: loc.projectsOnboardingNeedHelpEmail,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(
            _openSupportLink(
              cubit: context.read<ProjectListCubit>(),
              url: SupportLinks.email,
              channel: SupportChannel.email,
            ),
          ),
        ),
        PregoMenuItem(
          leadingIcon: TablerRegular.brand_discord,
          title: loc.projectsOnboardingNeedHelpDiscord,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(
            _openSupportLink(
              cubit: context.read<ProjectListCubit>(),
              url: SupportLinks.discord,
              channel: SupportChannel.discord,
            ),
          ),
        ),
        PregoMenuItem(
          // Tabler's pinned set ships the legacy bird glyph, not the X mark.
          leadingIcon: TablerRegular.brand_twitter,
          title: loc.projectsOnboardingNeedHelpX,
          subtitle: null,
          isSelected: false,
          onTap: () => unawaited(
            _openSupportLink(
              cubit: context.read<ProjectListCubit>(),
              url: SupportLinks.x,
              channel: SupportChannel.x,
            ),
          ),
        ),
      ],
    );
  }
}

/// The per-platform install commands: a flat iOS-style segmented control that
/// switches between the Unix (macOS/Linux/WSL) and Windows install groups, and
/// a single [_InstallCommandBox] showing the selected group's methods. Shared
/// by the connect-setup onboarding ([_ConnectBridgeChecklist]) and the
/// bridge-offline reconnect disclosure ([_BridgeOfflineView]) so both stay in
/// sync; callers supply their own surrounding padding.
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
      method: method,
      os: os,
      surface: widget.surface,
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
        const SizedBox(height: PregoSpacing.xl),
        if (widget.stepHeader case final stepHeader?) ...[
          stepHeader,
          const SizedBox(height: PregoSpacing.xl),
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
/// the bounded dimensions its copy/share outcome intents report.
class _InstallMethod {
  const _InstallMethod({
    required this.label,
    required this.command,
    required this.method,
    required this.os,
    required this.surface,
  });

  /// Tab label (literal tool name — not translated).
  final String label;

  /// The one-line install command shown and copied when this tab is selected.
  final String command;

  final BridgeInstallMethod method;
  final BridgeInstallOs os;
  final OnboardingSurface surface;
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
    final selected = _selected;

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
            command: selected.command,
            reportCopied: (cubit) => cubit.reportInstallCommandCopied(
              method: selected.method,
              os: selected.os,
              surface: selected.surface,
            ),
            reportShared: (cubit) => cubit.reportInstallCommandShared(
              method: selected.method,
              os: selected.os,
              surface: selected.surface,
            ),
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
            // 40px-tall tab: the 20px label line with 10px above and below —
            // off the spacing scale, so it is written out.
            padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.lg, vertical: 10),
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
    required this.reportCopied,
    required this.reportShared,
    this.topDivider = false,
  });

  final String command;

  /// Dispatches the copy outcome through the owning Cubit after clipboard
  /// success. The host supplies the command's bounded identity.
  final void Function(ProjectListCubit cubit) reportCopied;

  /// Dispatches the share outcome after the native sheet confirms a handoff.
  final void Function(ProjectListCubit cubit) reportShared;

  final bool topDivider;

  @override
  State<_CommandActionRow> createState() => _CommandActionRowState();
}

class _CommandActionRowState extends State<_CommandActionRow> {
  Future<void> _copyCommand() async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = context.loc;
    final cubit = context.read<ProjectListCubit>();
    final command = widget.command;
    final reportCopied = widget.reportCopied;
    // Clipboard can throw on restricted platforms/states; fail soft and skip
    // the success snackbar. Log so a broken copy button leaves a diagnostic
    // trail instead of failing silently.
    try {
      await Clipboard.setData(ClipboardData(text: command));
    } on Object catch (error, stackTrace) {
      logw("Failed to copy command", error, stackTrace);
      return;
    }
    reportCopied(cubit);
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.projectsOnboardingCommandCopied),
        duration: kSnackBarDuration,
      ),
    );
  }

  Future<void> _shareCommand() async {
    final cubit = context.read<ProjectListCubit>();
    final command = widget.command;
    final reportShared = widget.reportShared;
    // iPad presents the share sheet as a popover anchored to a source rect;
    // derive it from this row so the popover points at the command instead of
    // floating (an unanchored sheet throws on iPad).
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox && renderObject.attached && renderObject.hasSize
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      final result = await SharePlus.instance.share(
        ShareParams(text: command, sharePositionOrigin: origin),
      );
      if (result.status == ShareResultStatus.success) {
        reportShared(cubit);
      }
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
      // Figma insets the command 20px from the box edge and lets the action
      // buttons set the row's 44px height, so the row adds no padding of its
      // own above or below.
      padding: const EdgeInsetsDirectional.only(start: PregoSpacing.x2l),
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

/// A 40×44 tap target rendering [icon] over the command surface, used for the
/// copy and share actions. Its height is what sets the command row's, so it
/// carries the box's full 44px inner height rather than the row padding it.
/// Transparent [Material] so the ripple paints on top of the surface fill
/// rather than behind it on the Scaffold's Material.
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
            height: 44,
            child: Center(
              child: Icon(icon, size: 18, color: colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
