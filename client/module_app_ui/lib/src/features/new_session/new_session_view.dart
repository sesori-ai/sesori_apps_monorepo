import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../extensions/remote_failure_x.dart";
import "../session_detail/composer_presentation_scope.dart";
import "../session_detail/widgets/agent_model_buttons.dart";
import "../session_detail/widgets/composer_surface_style.dart";
import "../session_detail/widgets/prompt_input.dart";
import "new_session_no_harness_notice.dart";
import "new_session_plugin_chooser.dart";
import "new_session_project_row.dart";

typedef NewSessionComposerScopeBuilder = Widget Function({required Widget child});
typedef NewSessionCreatedCallback = void Function({required Session session});

/// A pointer surface's frame for the page: [topBar] replaces the glass bar, and
/// the header, the options and the composer form one centred column no wider
/// than [maxContentWidth], instead of anchoring the composer to the bottom.
/// [footer] follows the composer in that column.
class const NewSessionPageChrome({
  required final Widget topBar,
  required final double maxContentWidth,
  required final Widget? footer,
});

/// Shared new-session presentation below shell-owned routing, DI, and platform
/// composer capabilities.
class const NewSessionView({
  super.key,
  required final String projectId,
  required final String? projectName,

  /// The projects the header's selector offers; empty shows the project only.
  required final List<ProjectSummary> projects,
  required final NewSessionProjectSelected onProjectSelected,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
  required final NewSessionComposerScopeBuilder composerScopeBuilder,
  required final Widget? banner,

  /// Null keeps the glass bar over options with a bottom-anchored composer.
  required final NewSessionPageChrome? pageChrome,
}) extends StatefulWidget {
  @override
  State<NewSessionView> createState() => _NewSessionViewState();
}

/// The page margin the options card and the composer share, so both start on
/// one edge.
const double _pageMargin = PregoSpacing.xl;

class _NewSessionViewState() extends State<NewSessionView> {
  bool _dedicatedWorktree = true;
  bool _navigatingToCreatedSession = false;
  bool _isSending = false;
  Future<void>? _refreshPress;
  late PregoPopupAlertPresenter _popupAlertPresenter;
  late String _launchingInBackgroundMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _popupAlertPresenter = PregoPopupAlertPresenter.of(context);
    _launchingInBackgroundMessage = context.loc.newSessionLaunchingInBackground;
  }

  @override
  void dispose() {
    if (_isSending && !_navigatingToCreatedSession) {
      final popupAlertPresenter = _popupAlertPresenter;
      final message = _launchingInBackgroundMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        popupAlertPresenter.show(title: message);
      });
    }
    super.dispose();
  }

  void _dismissScreen() {
    widget.onBack();
  }

  /// Runs the harness menu's refresh and remembers the press while it is still
  /// working, so the harness row can shimmer for it: the menu closes on the
  /// tap, and without this nothing on screen would acknowledge the press.
  ///
  /// It shimmers while a press is running and the answers on screen are still
  /// unsettled, rather than for the whole life of the press. A press outlives
  /// its own subject — the harness chooser stays live during a refresh, and the
  /// harness left behind may take as long as it likes to answer.
  ///
  /// Only the newest press governs: a second press can begin while the first is
  /// still outstanding, and the first finishing must not end the second's.
  Future<void> _refreshOptions() async {
    final press = context.read<NewSessionCubit>().refreshOptions();
    // Block bodies: an arrow would hand setState the assigned Future, which it
    // rejects as asynchronous work.
    setState(() {
      _refreshPress = press;
    });
    try {
      await press;
    } finally {
      if (mounted && identical(_refreshPress, press)) {
        setState(() {
          _refreshPress = null;
        });
      }
    }
  }

  Widget? _buildErrorBanner(NewSessionState state) {
    final prego = context.prego;
    final loc = context.loc;
    return switch (state.phase) {
      NewSessionPhaseRestoringSubmission(:final reason) || NewSessionPhaseCreationError(:final reason) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason.localizedMessage(loc),
              style: TextStyle(color: prego.colors.fgErrorPrimary),
            ),
            Text(
              loc.newSessionCreationDuplicateWarning,
              style: TextStyle(color: prego.colors.fgErrorPrimary),
            ),
          ],
        ),
      ),
      NewSessionPhaseDiscoveryError(:final reason) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Text(
          reason.localizedMessage(loc),
          style: TextStyle(color: prego.colors.fgErrorPrimary),
        ),
      ),
      NewSessionPhaseIdle() || NewSessionPhaseSending() || null => null,
    };
  }

  Widget? _buildComposerHeader({
    required NewSessionState state,
    required ValueNotifier<PregoComposerSurfaceStyle> surfaceStyleController,
  }) {
    final data = state.agentModelData;
    final selectedAgent = data?.agent;
    if (data == null || (data.agents.isEmpty && data.providers.isEmpty)) return null;

    final cubit = context.read<NewSessionCubit>();
    return ValueListenableBuilder<PregoComposerSurfaceStyle>(
      valueListenable: surfaceStyleController,
      builder: (context, surfaceStyle, _) => AgentModelButtons(
        surfaceStyle: surfaceStyle,
        agents: data.agents,
        selectedAgent: selectedAgent,
        onAgentSelected: cubit.selectAgent,
        providers: data.providers,
        selectedAgentModel: data.agentModel,
        onModelSelected: cubit.selectModel,
        availableVariants: data.availableVariants,
        onVariantSelected: cubit.selectVariant,
        fastModeControl: data.fastModeControl,
        decideFastModeToggle: cubit.fastModeToggleDecision,
        onFastModeChanged: cubit.setFastMode,
        compact: ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer,
      ),
    );
  }

  /// Why the harness options are missing or limited.
  ///
  /// Null before a routable harness is known, while a first load has nothing
  /// to describe yet, and whenever the options are simply available — there is
  /// nothing the user needs to act on. A refresh over options already on
  /// screen keeps describing those, so the line does not blink out and shift
  /// the page for the length of the load.
  ({String message, bool isFailure})? _resolveOptionsStatus({required AgentModelData? data}) {
    final plugin = data?.plugin;
    if (data == null ||
        plugin == null ||
        !plugin.isRoutable ||
        data.projectWorktreeCapability == NewSessionProjectWorktreeCapability.loading) {
      return null;
    }

    final loc = context.loc;
    if (data.projectWorktreeCapability == NewSessionProjectWorktreeCapability.unavailable) {
      return (message: loc.newSessionProjectUnavailable, isFailure: true);
    }
    return switch (data.optionsState) {
      NewSessionOptionsAuthenticationRequiredUnavailableState(:final actionHint) ||
      NewSessionOptionsAuthenticationRequiredRetainedState(:final actionHint) => (
        message: actionHint,
        isFailure: true,
      ),
      NewSessionOptionsFailureState(:final reason) => (message: reason.localizedMessage(loc), isFailure: true),
      NewSessionOptionsFailureRetainedState() => (message: loc.newSessionOptionsUpdateFailedRetained, isFailure: true),
      NewSessionOptionsRefreshFailureUnavailableState() => (
        message: loc.newSessionOptionsRefreshFailedUnavailable,
        isFailure: true,
      ),
      NewSessionOptionsLoadFailureUnavailableState() => (
        message: loc.newSessionOptionsLoadFailedUnavailable,
        isFailure: true,
      ),
      NewSessionOptionsUnavailableState() => (message: loc.newSessionOptionsUnavailable, isFailure: false),
      NewSessionOptionsUnsupportedState() ||
      NewSessionOptionsAvailableState(source: NewSessionOptionsSource.legacy) ||
      NewSessionOptionsRefreshingState(source: NewSessionOptionsSource.legacy) => (
        message: loc.newSessionOptionsLegacyBridge,
        isFailure: false,
      ),
      NewSessionOptionsAvailableState(source: NewSessionOptionsSource.aggregate) ||
      NewSessionOptionsRefreshingState(source: NewSessionOptionsSource.aggregate) ||
      NewSessionOptionsLoadingState() => null,
    };
  }

  Widget _buildOptionsStatus({required ({String message, bool isFailure}) status}) {
    final prego = context.prego;
    // Inset like the card rows' content, so the line starts under their labels.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.xl),
      child: Text(
        status.message,
        style: prego.textTheme.textXs.regular.copyWith(
          color: status.isFailure ? prego.colors.fgErrorPrimary : prego.colors.textSecondary,
        ),
      ),
    );
  }

  ({String pluginId, String displayName, String actionHint})? _authenticationNotice(NewSessionState state) {
    final actionHint = switch (state.config?.options) {
      NewSessionOptionsAuthenticationRequiredUnavailableState(:final actionHint) ||
      NewSessionOptionsAuthenticationRequiredRetainedState(:final actionHint) => actionHint,
      NewSessionOptionsLoadingState() ||
      NewSessionOptionsRefreshingState() ||
      NewSessionOptionsAvailableState() ||
      NewSessionOptionsUnsupportedState() ||
      NewSessionOptionsUnavailableState() ||
      NewSessionOptionsLoadFailureUnavailableState() ||
      NewSessionOptionsFailureState() ||
      NewSessionOptionsFailureRetainedState() ||
      NewSessionOptionsRefreshFailureUnavailableState() ||
      null => null,
    };
    final plugin = state.agentModelData?.plugin;
    return actionHint == null || plugin == null
        ? null
        : (pluginId: plugin.id, displayName: plugin.displayName, actionHint: actionHint);
  }

  /// Whether the worktree option is on offer. With no harness to run the
  /// session there is nothing for it to shape.
  bool _offersWorktree({required NewSessionCubit cubit, required AgentModelData? data}) =>
      !cubit.needsHarnessDiscovery && data?.projectWorktreeCapability == NewSessionProjectWorktreeCapability.supported;

  /// The options above the composer as one card, read top to bottom: the
  /// project the session starts in, the harness that runs it, and whether it
  /// gets a git worktree of its own. Why the options are missing or limited
  /// follows the card.
  ///
  /// Until the bridge has answered what it can run, the harness row shimmers a
  /// placeholder. A later discovery (a reconnect) keeps the harness it already
  /// has, disabled — blanking a known harness back to a shimmer would lose more
  /// than it says. When the bridge answered that it runs no harness at all, a
  /// notice takes the harness row's place; when discovery failed instead, the
  /// error banner explains it and the harness menu keeps the refresh.
  Widget _buildOptions({
    required NewSessionCubit cubit,
    required AgentModelData? data,
    required ({String message, bool isFailure})? status,
  }) {
    final isDiscovering = data == null || (data.plugins.isEmpty && data.isPluginDiscoveryInFlight);
    final hasNoHarnesses = cubit.hasNoHarnesses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PregoSpacing.lg,
      children: [
        PregoGroupedRows(
          children: [
            NewSessionProjectRow(
              projectId: widget.projectId,
              projectName: widget.projectName,
              projects: widget.projects,
              onProjectSelected: widget.onProjectSelected,
            ),
            if (!hasNoHarnesses)
              NewSessionPluginChooser(
                plugins: data?.plugins ?? const [],
                selectedPluginId: data?.plugin?.id,
                isSelectionEnabled: data != null && data.backendScope.isVerified && !data.isPluginDiscoveryInFlight,
                isLoading: isDiscovering || (_refreshPress != null && data.isLoading),
                onSelected: (pluginId) => cubit.selectPlugin(pluginId: pluginId),
                onSettingsPressed: widget.onOpenHarnessSettings,
                onRefreshPressed: cubit.canRefreshOptions ? _refreshOptions : null,
              ),
            if (_offersWorktree(cubit: cubit, data: data))
              _NewWorktreeRow(
                value: _dedicatedWorktree,
                onChanged: (value) => setState(() => _dedicatedWorktree = value),
              ),
          ],
        ),
        if (hasNoHarnesses) NewSessionNoHarnessNotice(onSettingsPressed: widget.onOpenHarnessSettings),
        if (status != null) _buildOptionsStatus(status: status),
      ],
    );
  }

  /// One line naming what the card says — project, harness, and the worktree
  /// when one is picked — for while the keyboard leaves no room for the card.
  Widget _buildKeyboardSummary({required NewSessionCubit cubit, required AgentModelData? data}) {
    final prego = context.prego;
    final loc = context.loc;
    final harness = data?.plugin?.displayName;
    final parts = [
      newSessionProjectLabel(
        loc: loc,
        projectId: widget.projectId,
        projectName: widget.projectName,
        projects: widget.projects,
      ),
      ?harness,
      if (_dedicatedWorktree && _offersWorktree(cubit: cubit, data: data)) loc.newSessionSummaryWorktree,
    ];
    return Padding(
      key: const Key("new_session_keyboard_summary"),
      padding: const EdgeInsetsDirectional.fromSTEB(
        _pageMargin + PregoSpacing.xl,
        0,
        _pageMargin + PregoSpacing.xl,
        PregoSpacing.sm,
      ),
      child: Text(
        parts.join(" · "),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
      ),
    );
  }

  /// The page under [chrome]: the options card over the composer, one centred
  /// column that scrolls as a whole when the pane is too short for it.
  Widget _buildChromePage({
    required NewSessionPageChrome chrome,
    required NewSessionState state,
    required Widget launchStatus,
    required Widget options,
    required Widget? composer,
  }) {
    return Scaffold(
      body: Column(
        children: [
          chrome.topBar,
          ?widget.banner,
          Expanded(
            child: state.phase is NewSessionPhaseSending
                ? launchStatus
                : Center(
                    child: SingleChildScrollView(
                      key: const Key("new_session_options_scroll"),
                      padding: const EdgeInsets.all(_pageMargin),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chrome.maxContentWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: PregoSpacing.x3l,
                          children: [
                            options,
                            ?composer,
                            ?chrome.footer,
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer({
    required bool isComposerEnabled,
    required NewSessionSubmissionSnapshot? restoringSubmission,
    required List<ComposerAttachment> restoredAttachments,
    required AgentModelData? composerData,
    required NewSessionState state,
  }) {
    final cubit = context.read<NewSessionCubit>();
    return widget.composerScopeBuilder(
      child: _ComposerSurfaceStyleOwner(
        initialDraft: cubit.composerDraft,
        stagedCommand: composerData?.stagedCommand,
        builder: ({required context, required surfaceStyleController}) => Semantics(
          enabled: isComposerEnabled,
          child: ExcludeFocus(
            excluding: !isComposerEnabled,
            child: IgnorePointer(
              ignoring: !isComposerEnabled,
              child: PromptInput(
                draftIdentity: ComposerDraftRepository.newSessionIdentity(projectId: widget.projectId),
                restorationKey: restoringSubmission == null ? null : ObjectKey(restoringSubmission),
                initialDraft: context.read<NewSessionCubit>().composerDraft,
                initialAttachments: restoredAttachments,
                onInitialAttachmentsConsumed: () {
                  final submission = restoringSubmission;
                  if (submission != null) {
                    context.read<NewSessionCubit>().acknowledgeRestoredSubmission(submission: submission);
                  }
                },
                // The page's question lives where it is answered.
                restingHint: context.loc.newSessionPromptHint,
                attachmentsSupported: composerData?.plugin?.supportsPromptAttachments,
                isBusy: false,
                onSend: ({required draft, required command, required attachments}) {
                  context.read<NewSessionCubit>().createSession(
                    draft: draft,
                    command: command,
                    attachments: attachments,
                    dedicatedWorktree: _dedicatedWorktree,
                  );
                },
                onVoiceTranscriptionCompleted: ComposerPresentationScope.of(context).voiceSupport.isSupported
                    ? context.read<NewSessionCubit>().reportVoiceTranscriptionCompleted
                    : null,
                onDraftChanged: (draft) => context.read<NewSessionCubit>().saveComposerDraft(draft: draft),
                onDraftCleared: context.read<NewSessionCubit>().clearComposerDraft,
                onAbort: _dismissScreen,
                surfaceStyleController: surfaceStyleController,
                header: _buildErrorBanner(state),
                composerHeader: _buildComposerHeader(
                  state: state,
                  surfaceStyleController: surfaceStyleController,
                ),
                composerTrailing: null,
                availableCommands: composerData?.commands ?? const [],
                stagedCommand: composerData?.stagedCommand,
                onCommandSelected: context.read<NewSessionCubit>().stageCommand,
                onCommandCleared: context.read<NewSessionCubit>().clearStagedCommand,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NewSessionCubit>();
    final state = cubit.state;
    final loc = context.loc;
    final isSending = state.phase is NewSessionPhaseSending;
    final composerData = state.agentModelData;
    final hasNoHarnesses = cubit.hasNoHarnesses;
    final optionsStatus = _resolveOptionsStatus(data: composerData);
    final restoringSubmission = switch (state.phase) {
      NewSessionPhaseRestoringSubmission(:final submission) => submission,
      NewSessionPhaseIdle() ||
      NewSessionPhaseSending() ||
      NewSessionPhaseCreationError() ||
      NewSessionPhaseDiscoveryError() ||
      null => null,
    };
    final restoredAttachments = switch (restoringSubmission) {
      NewSessionTextSubmissionSnapshot(:final attachments) => attachments,
      NewSessionCommandSubmissionSnapshot() || null => const <ComposerAttachment>[],
    };
    final isComposerEnabled = cubit.canCreateSession && !isSending;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    _isSending = isSending;
    // The listener can run while this route is being torn down. The route
    // object stays stable, so `isCurrent` remains safe to read at event time.
    final modalRoute = ModalRoute.of(context);
    final launchStatus = PregoLaunchStatus(
      semanticsLabel: loc.newSessionLoadingSemantics,
      messages: [
        loc.newSessionLoadingMessage1,
        loc.newSessionLoadingMessage2,
        loc.newSessionLoadingMessage3,
      ],
    );
    final options = _buildOptions(cubit: cubit, data: composerData, status: optionsStatus);
    final composer = hasNoHarnesses
        ? null
        : _buildComposer(
            isComposerEnabled: isComposerEnabled,
            restoringSubmission: restoringSubmission,
            restoredAttachments: restoredAttachments,
            composerData: composerData,
            state: state,
          );
    final chromePage = switch (widget.pageChrome) {
      null => null,
      final chrome => _buildChromePage(
        chrome: chrome,
        state: state,
        launchStatus: launchStatus,
        options: options,
        composer: composer,
      ),
    };

    Widget listening({required Widget child}) => BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (previous, current) {
        final currentAuthentication = _authenticationNotice(current);
        return current is NewSessionCreated ||
            (currentAuthentication != null && currentAuthentication != _authenticationNotice(previous));
      },
      listener: (context, state) {
        if (state case NewSessionCreated(:final session)) {
          // The user may have navigated elsewhere (e.g. opened another
          // session from the split-view list) while creation was in flight.
          // Replacing the route then would hijack their navigation — the
          // leave-time snackbar already told them the session continues.
          if (modalRoute != null && !modalRoute.isCurrent) return;
          _navigatingToCreatedSession = true;
          widget.onSessionCreated(session: session);
          return;
        }
        final authentication = _authenticationNotice(state);
        if (authentication == null || (modalRoute != null && !modalRoute.isCurrent)) return;
        _popupAlertPresenter.show(
          title: context.loc.newSessionAuthenticationRequiredTitle(authentication.displayName),
          content: PregoPopupAlertContent(message: authentication.actionHint),
          variant: PregoPopupAlertsNotificationsVariant.warning,
          duration: const Duration(seconds: 8),
        );
      },
      child: child,
    );
    if (chromePage != null) return listening(child: chromePage);

    return listening(
      child: PregoGlassScaffold(
        title: loc.sessionListNewSession,
        // Toolbar navigation is explicit: unlike Android system back, it must
        // not be vetoed by the composer's keyboard-dismissal PopScope.
        onBack: _dismissScreen,
        // The card's project row names the project, so the bar carries no
        // subtitle.
        titleMode: isSending ? PregoTopNavigationTitleMode.inline : PregoTopNavigationTitleMode.backLeading,
        subtitle: null,
        reserveBarSpace: false,
        scrollable: false,
        banner: widget.banner,
        slivers: isSending
            ? [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: launchStatus,
                ),
              ]
            : [
                // Fill the viewport behind the bar so the variable-height options can
                // shrink and scroll without pushing the pinned composer off-screen.
                // With the scaffold's keyboard resize (Scaffold default), the
                // composer rides above the keyboard when the field is focused.
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: Column(
                    children: [
                      Expanded(
                        child: PregoTopBarInsetBuilder(
                          builder: (context, topInset, child) => CustomScrollView(
                            key: const Key("new_session_options_scroll"),
                            // The composer owns keyboard focus. This supporting
                            // pane must not become the route's primary scroll and
                            // jump when the keyboard opens.
                            primary: false,
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  _pageMargin,
                                  topInset + _pageMargin,
                                  _pageMargin,
                                  _pageMargin,
                                ),
                                sliver: SliverToBoxAdapter(child: child),
                              ),
                            ],
                          ),
                          // The keyboard leaves this pane a few rows tall, so the
                          // card gives way to the summary line above the composer.
                          child: keyboardUp
                              ? (optionsStatus == null ? null : _buildOptionsStatus(status: optionsStatus))
                              : options,
                        ),
                      ),
                      if (composer != null) ...[
                        if (keyboardUp) _buildKeyboardSummary(cubit: cubit, data: composerData),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _pageMargin),
                          child: composer,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
      ),
    );
  }
}

/// Owns composer-only presentation state below the shell's capability scope.
///
/// Keeping this owner inside the scope makes the initial style follow the
/// effective platform input mode, while removing it with the composer still
/// closes mobile voice resources during session launch.
class const _ComposerSurfaceStyleOwner({
  required final ComposerDraft initialDraft,
  required final CommandInfo? stagedCommand,
  required final Widget Function({
    required BuildContext context,
    required ValueNotifier<PregoComposerSurfaceStyle> surfaceStyleController,
  })
  builder,
}) extends StatefulWidget {
  @override
  State<_ComposerSurfaceStyleOwner> createState() => _ComposerSurfaceStyleOwnerState();
}

class _ComposerSurfaceStyleOwnerState() extends State<_ComposerSurfaceStyleOwner> {
  late final ValueNotifier<PregoComposerSurfaceStyle> _controller;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _controller = ValueNotifier(
      resolveInitialComposerSurfaceStyle(
        inputMode: ComposerPresentationScope.of(context).inputMode,
        draft: widget.initialDraft,
        stagedCommand: widget.stagedCommand,
      ),
    );
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context: context, surfaceStyleController: _controller);
  }
}

/// Whether the session gets a git worktree of its own instead of working in
/// the project checkout everyone shares.
class const _NewWorktreeRow({required final bool value, required final ValueChanged<bool> onChanged})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    // The label names what the switch does, so they must reach a screen reader
    // as one control rather than as stray text beside a bare toggle.
    return MergeSemantics(
      child: PregoGroupedRow(
        title: Text(loc.newSessionNewWorktree),
        subtitle: Text(loc.newSessionNewWorktreeHint),
        trailing: PregoSwitch(
          key: const Key("new_session_new_worktree"),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
