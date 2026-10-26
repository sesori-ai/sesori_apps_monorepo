import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/widgets/desktop_composer_presentation_scope.dart";
import "../../core/widgets/desktop_sidebar.dart";
import "../../core/widgets/desktop_sidebar_expansion.dart";
import "../../core/widgets/desktop_transcript_width.dart";
import "desktop_file_access_card.dart";

/// How long the home's own changes take: the body crossfade and the header
/// and the slow-start line fading in.
const Duration _homeMotionDuration = Duration(milliseconds: 220);

/// The desktop home: the cockpit's project list states, and otherwise a new
/// session in the sidebar list's default project from [AllSessionsCubit].
class const DesktopHomePane({
  super.key,

  /// Opens the session the home just started.
  required final SidebarSessionOpenedCallback onOpenSession,
  required final VoidCallback onOpenHarnessSettings,

  /// Opens the Computers page from the "Viewing:" menu.
  required final VoidCallback onManageComputers,
}) extends StatefulWidget {
  @override
  State<DesktopHomePane> createState() => _DesktopHomePaneState();
}

class _DesktopHomePaneState() extends State<DesktopHomePane> {
  /// Whether the ready home has started since the projects last loaded.
  bool _homeStarted = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Not lazy: besides naming the computer, it fetches the account's
        // computers whenever the relay is reachable. The header relies on that
        // eager fetch, as nothing else on the home loads the list.
        BlocProvider(
          lazy: false,
          create: (_) => BridgeIdentityCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
          ),
        ),
        BlocProvider(
          create: (_) => ComputerSwitcherCubit(
            registeredBridgesService: getIt<RegisteredBridgesService>(),
            connectionService: getIt<ConnectionService>(),
            selectedComputerService: getIt<SelectedComputerService>(),
            activeBridgeLocality: getIt<ActiveBridgeLocality>(),
          ),
        ),
      ],
      // The body fills the pane from launch, and the header floats over its
      // top band, so the header appearing never moves the body, and it stays
      // put while the body changes state. The pane paints the page's
      // background once, beneath every body.
      child: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            Positioned.fill(child: Builder(builder: _buildBody)),
            PositionedDirectional(
              top: 0,
              start: 0,
              end: 0,
              child: _DesktopComputerHeader(
                onSwitchComputer: _switchComputer,
                onManageComputers: widget.onManageComputers,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The ready home and each kind of status page cross-fade, as when a
  /// computer switch loads and then lands. Each fills the body and paints no
  /// background of its own, so neither moves or covers the other while they
  /// cross, and the one leaving takes no clicks, focus or announcements.
  Widget _buildBody(BuildContext context) => AnimatedSwitcher(
    duration: context.isReducedMotion ? Duration.zero : _homeMotionDuration,
    switchInCurve: Curves.easeOut,
    switchOutCurve: Curves.easeIn,
    // Unkeyed, unlike the default, so each switch gets an entry of its own: a
    // body back before its last one has faded out would otherwise replace that
    // one at once, which then vanishes mid-fade.
    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
    layoutBuilder: (current, previous) => Stack(
      fit: StackFit.expand,
      children: [
        for (final child in previous) _crossing(child: child, leaving: true),
        if (current != null) _crossing(child: current, leaving: false),
      ],
    ),
    child: _body(context),
  );

  /// Wraps a body under its entry's key, so a body that starts leaving keeps
  /// its state.
  static Widget _crossing({required Widget child, required bool leaving}) => IgnorePointer(
    key: child.key,
    ignoring: leaving,
    child: ExcludeFocus(
      excluding: leaving,
      child: ExcludeSemantics(excluding: leaving, child: child),
    ),
  );

  /// The ready home, or a status page keyed by its kind: another kind
  /// cross-fades in, while a page whose own content changes stays put.
  Widget _body(BuildContext context) {
    final state = context.watch<ProjectListCubit>().state;
    // Once the projects load, the loader holds until the list names the
    // project the home starts in, or loads without one, so it fades straight
    // into the composer. Once started, the home stays: a project added later
    // loads without taking it back to the loader.
    _homeStarted =
        state is ProjectListLoaded &&
        (_homeStarted ||
            context.select(
              (AllSessionsCubit cubit) => !cubit.state.isLoading || cubit.state.defaultProjectId != null,
            ));
    switch (state) {
      case ProjectListLoaded(:final projects) when _homeStarted:
        return DesktopHomeStart(
          key: const Key("desktop-home-ready"),
          projects: projects,
          createNewSessionCubit: ({required projectId, required projectName, required projectKind}) =>
              createNewSessionCubit(
                locator: getIt,
                projectId: projectId,
                projectName: projectName,
                projectKind: projectKind,
              ),
          onOpenSession: widget.onOpenSession,
          onOpenHarnessSettings: widget.onOpenHarnessSettings,
        );
      case ProjectListLoaded() || ProjectListLoading():
        // The relay can still be connecting as the launch begins, so the
        // line's wait starts with the launch, not with its offline report.
        return _loading(
          context: context,
          startingThisComputer: context.select(
            (LocalBridgeStartupCubit cubit) => cubit.state == LocalBridgeStartupState.starting,
          ),
        );
      case ProjectListFailed(:final reason):
        return _statusPage(
          key: const Key("desktop-home-failed"),
          status: RemoteFailureView(
            reason: reason,
            title: context.loc.projectListErrorTitle,
            retryLabel: context.loc.projectListRetry,
            onRetry: () => context.read<ProjectListCubit>().retryLoadProjects(),
          ),
        );
      case ProjectListBridgeDisconnected():
        return _disconnectedView(context: context);
    }
  }

  /// A status page under the file-access card, as the composer's page has it.
  static Widget _statusPage({required Key key, required Widget status}) => CustomScrollView(
    key: key,
    slivers: [
      const SliverToBoxAdapter(child: SafeArea(bottom: false, child: DesktopFileAccessCard())),
      SliverFillRemaining(hasScrollBody: false, child: SafeArea(child: status)),
    ],
  );

  /// The loader centred as for any load, with equal room above and below it.
  /// [_SlowStartLine] waits in the room below, so it fades in and out without
  /// moving the loader. Every load builds the same page, so a load turning
  /// into a launch, or back, keeps the running loader and the line.
  static Widget _loading({required BuildContext context, required bool startingThisComputer}) => _statusPage(
    key: const Key("desktop-home-loading"),
    status: Column(
      children: [
        const Spacer(),
        Semantics(
          label: context.loc.projectListLoadingSemantics,
          child: const PregoAiLoader(size: 32),
        ),
        Expanded(child: _SlowStartLine(starting: startingThisComputer)),
      ],
    ),
  );

  /// Another computer's bridge is out of this desktop's reach, so its
  /// recovery is switching away; only this computer's own offers supervised
  /// start, and while that start is under way it is still loading.
  static Widget _disconnectedView({required BuildContext context}) {
    final bridge = switch (context.watch<BridgeIdentityCubit>().state) {
      BridgeIdentityNamed(:final bridge) => bridge,
      BridgeIdentityPending() || BridgeIdentityUnnamed() => null,
    };
    if (context.select((ComputerSwitcherCubit cubit) => cubit.state.viewsAnotherComputer)) {
      return _statusPage(
        key: const Key("desktop-home-offline"),
        status: DesktopRemoteComputerOfflineView(bridge: bridge, onSwitchComputer: _switchComputer),
      );
    }
    if (context.select((LocalBridgeStartupCubit cubit) => cubit.state == LocalBridgeStartupState.starting)) {
      return _loading(context: context, startingThisComputer: true);
    }
    return _statusPage(
      key: const Key("desktop-home-recovery"),
      status: DesktopBridgeRecoveryView(
        bridge: bridge,
        onStartBridge: context.read<BridgeControlCubit>().recoverConnection,
      ),
    );
  }

  static void _switchComputer({required String bridgeId, required ComputerSwitchSource source}) =>
      unawaited(getIt<ComputerSwitchDispatcher>().switchTo(bridgeId: bridgeId, source: source));
}

/// Under the loader: once a launch of this computer's bridge has gone on for
/// [delay] without the app reaching it (a registration retry, say), a line
/// fades in to say it is still under way. A normal start connects well before
/// then, so it never shows. When the launch gives way to an ordinary load, the
/// line fades out and its wait is dropped; a later launch waits afresh.
class const _SlowStartLine({required final bool starting}) extends StatefulWidget {
  static const Duration delay = Duration(seconds: 10);

  @override
  State<_SlowStartLine> createState() => _SlowStartLineState();
}

class _SlowStartLineState() extends State<_SlowStartLine> {
  Timer? _timer;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _wait();
  }

  @override
  void didUpdateWidget(_SlowStartLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.starting != widget.starting) _wait();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Hides the line, and while [_SlowStartLine.starting] waits to show it.
  void _wait() {
    _timer?.cancel();
    _shown = false;
    _timer = widget.starting ? Timer(_SlowStartLine.delay, () => setState(() => _shown = true)) : null;
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.x2l, PregoSpacing.lg, PregoSpacing.x2l, 0),
        // Left out of semantics while hidden; once shown, a live region.
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: context.isReducedMotion ? Duration.zero : _homeMotionDuration,
          curve: Curves.easeOut,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              context.loc.projectsDesktopBridgeStillStarting,
              textAlign: TextAlign.center,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Viewing: …" over the home's top band: which computer's projects the
/// desktop shows, and the menu to switch. Hidden while the account's only
/// computer is this one, where there is nothing to tell apart or switch to; it
/// fades in when the list says otherwise, and out if the list goes back.
class const _DesktopComputerHeader({
  required final ComputerSwitchCallback onSwitchComputer,
  required final VoidCallback onManageComputers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<ComputerSwitcherCubit>().state;
    final current = state.computers.where((computer) => computer.id == state.currentId).firstOrNull;
    final remote = state.viewsAnotherComputer;
    return AnimatedSwitcher(
      duration: context.isReducedMotion ? Duration.zero : _homeMotionDuration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      // Unkeyed, as the body's, so a line back before its last one has faded
      // out gets an entry of its own.
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: current == null || !(remote || state.computers.length > 1)
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(PregoSpacing.lg, PregoSpacing.md, PregoSpacing.lg, 0),
              child: DesktopSidebarRestoreInset(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ComputerMenu(
                    onSelect: ({required bridgeId}) =>
                        onSwitchComputer(bridgeId: bridgeId, source: ComputerSwitchSource.menu),
                    onManageComputers: onManageComputers,
                    currentFirst: false,
                    triggerBuilder: (context, toggle) => _ViewingButton(
                      label: remote
                          ? context.loc.desktopViewingComputer(current.name)
                          : context.loc.desktopViewingThisComputer,
                      icon: ComputerMenu.platformIcon(platform: current.platform),
                      onPressed: toggle,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class const _ViewingButton({
  required final String label,
  required final IconData icon,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final color = prego.colors.textSecondary;
    return Semantics(
      hint: context.loc.computerMenuSwitchHint,
      child: InkWell(
        key: const Key("desktop-computer-header"),
        mouseCursor: WidgetStateMouseCursor.clickable,
        borderRadius: BorderRadius.circular(PregoRadius.sm),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.sm, vertical: PregoSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: PregoSpacing.xs,
            children: [
              Icon(icon, size: PregoIconSize.md, color: color),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textSm.medium.copyWith(color: color),
                ),
              ),
              Icon(TablerRegular.chevron_down, size: PregoIconSize.sm, color: prego.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The offline body for another computer, as the phone shows it: the computer
/// by name and when it was last seen, then the account's other online
/// computers to switch to. Its bridge runs elsewhere, so there is nothing to
/// start from here.
class const DesktopRemoteComputerOfflineView({
  super.key,

  /// Null while the account's list has not named it yet.
  required final BridgeSummary? bridge,
  required final ComputerSwitchCallback onSwitchComputer,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // An illustration, not a glyph: no icon token applies.
              Icon(TablerRegular.device_desktop_off, size: 48, color: prego.colors.textTertiary),
              const SizedBox(height: PregoSpacing.lg),
              ComputerOfflineHeading(bridge: bridge),
              const SizedBox(height: PregoSpacing.xl),
              Text(
                context.loc.projectsDesktopRemoteOfflineInfo,
                textAlign: TextAlign.center,
                style: prego.textTheme.textSm.regular,
              ),
              OtherComputersCard(onSwitchComputer: onSwitchComputer),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desktop-owned supervised recovery for this computer's own bridge, whether
/// it never registered or is offline.
class const DesktopBridgeRecoveryView({
  super.key,
  required final BridgeSummary? bridge,
  required final Future<void> Function() onStartBridge,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controlState = context.watch<BridgeControlCubit>().state;
    final bridge = this.bridge;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(PregoSpacing.x2l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // An illustration, not a glyph: no icon token applies.
              Icon(
                TablerRegular.device_laptop,
                size: 48,
                color: context.prego.colors.textTertiary,
              ),
              const SizedBox(height: PregoSpacing.lg),
              if (bridge != null) ...[
                Text(
                  bridge.name,
                  textAlign: TextAlign.center,
                  style: context.prego.textTheme.textLg.bold,
                ),
                const SizedBox(height: PregoSpacing.xs),
              ],
              Text(
                context.loc.projectsBridgeOfflineDisconnected,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular.copyWith(
                  color: context.prego.colors.textSecondary,
                ),
              ),
              const SizedBox(height: PregoSpacing.x2l),
              Text(
                context.loc.projectsDesktopStartBridgeInfo,
                textAlign: TextAlign.center,
                style: context.prego.textTheme.textSm.regular,
              ),
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                label: context.loc.projectsDesktopStartBridge,
                leadingIcon: TablerRegular.player_play,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.xl,
                fullWidth: true,
                isLoading: controlState.activity == BridgeControlActivity.toggling,
                onPressed: controlState.activity.locksCommands ? null : () => unawaited(onStartBridge()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The home that starts work: a new session in the list's default project
/// (D15), or, without a default, the project prompt with nothing selected.
/// With no projects at all, the prompt's picker offers only "Open another
/// folder…".
///
/// The project holds once a default lands, so a session elsewhere turning
/// newest never moves a draft; choosing another filter, or another project in
/// the header, moves it.
@visibleForTesting
class const DesktopHomeStart({
  super.key,
  required final List<ProjectSummary> projects,
  required final NewSessionCubit Function({
    required String projectId,
    required String? projectName,
    required ProjectKind projectKind,
  })
  createNewSessionCubit,
  required final SidebarSessionOpenedCallback onOpenSession,
  required final VoidCallback onOpenHarnessSettings,
}) extends StatefulWidget {
  @override
  State<DesktopHomeStart> createState() => _DesktopHomeStartState();
}

class _DesktopHomeStartState() extends State<DesktopHomeStart> {
  /// The draft's project, or null until a default lands or one is chosen.
  String? _projectId;

  @override
  void initState() {
    super.initState();
    _projectId = context.read<AllSessionsCubit>().state.defaultProjectId;
  }

  void _select({required String projectId}) => setState(() => _projectId = projectId);

  @override
  Widget build(BuildContext context) {
    final project = widget.projects.where((project) => project.id == _projectId).firstOrNull;
    final isLoading = context.select((AllSessionsCubit cubit) => cubit.state.isLoading);
    final Widget pane = switch (project) {
      final project? => _composer(project: project),
      // A list still loading may yet name a default, so the prompt waits.
      null when isLoading => const SizedBox.expand(key: Key("desktop-home-waiting")),
      null => NewSessionProjectPrompt(
        key: const Key("desktop-home-prompt"),
        onProjectSelected: ({required projectId, required projectName}) => _select(projectId: projectId),
        onBack: null,
        // The desktop root owns its single connection banner.
        banner: null,
        // Nobody asked for it yet, so the picker waits for a click.
        opensPicker: false,
        topBar: const SafeArea(bottom: false, child: DesktopFileAccessCard()),
      ),
    };
    return BlocListener<AllSessionsCubit, AllSessionsState>(
      // Another filter moves the draft to its default; until the draft has a
      // project, the first default to land is taken up.
      listenWhen: (previous, current) =>
          previous.projectId != current.projectId ||
          (_projectId == null && previous.defaultProjectId != current.defaultProjectId),
      listener: (_, state) => setState(() => _projectId = state.defaultProjectId),
      child: AnimatedSwitcher(
        duration: context.isReducedMotion ? Duration.zero : _homeMotionDuration,
        child: pane,
      ),
    );
  }

  Widget _composer({required ProjectSummary project}) {
    final displayName = projectDisplayName(loc: context.loc, project: project);
    // Keyed by project: a new pick gets its own cubit and draft, as the new
    // session page does when its route changes project.
    return BlocProvider(
      key: ValueKey("desktop-home-new-session-${project.id}"),
      create: (_) =>
          widget.createNewSessionCubit(projectId: project.id, projectName: displayName, projectKind: project.kind),
      child: NewSessionView(
        projectId: project.id,
        projectName: displayName,
        onProjectSelected: ({required projectId, required projectName}) => _select(projectId: projectId),
        // The home is where Back would lead; there is nothing to leave.
        onBack: null,
        onOpenHarnessSettings: widget.onOpenHarnessSettings,
        onSessionCreated: ({required session}) =>
            widget.onOpenSession(context: context, project: project, displayName: displayName, session: session),
        composerScopeBuilder: ({required child}) => DesktopComposerPresentationScope(
          child: DesktopVoiceInputScope(projectId: project.id, child: child),
        ),
        // The desktop root owns its single connection banner.
        banner: null,
        pageChrome: const NewSessionPageChrome(
          maxContentWidth: 760,
          transcriptWidth: desktopTranscriptWidth,
          topBar: SafeArea(bottom: false, child: DesktopFileAccessCard()),
          // The pane paints the background, beneath the bodies it cross-fades.
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}
