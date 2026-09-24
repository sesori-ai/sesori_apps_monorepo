import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../extensions/remote_failure_x.dart";
import "../../widgets/harness_blocked_notice.dart";
import "../session_detail/composer_presentation_scope.dart";
import "../session_detail/widgets/agent_model_buttons.dart";
import "../session_detail/widgets/composer_surface_style.dart";
import "../session_detail/widgets/prompt_input.dart";
import "new_session_header.dart";
import "new_session_no_harness_notice.dart";
import "new_session_plugin_chooser.dart";

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

/// The gap between the header and the options below it.
const double _optionRowSpacing = PregoSpacing.xl;

/// Horizontal inset of the options block. Narrower than the composer's, so the
/// row content lands on the design's margin once each row's own padding is
/// added.
const double _optionsHorizontalPadding = 10;

/// Bottom padding of the options scroll view, so the last row can rest clear of
/// the composer.
const double _optionsBottomPadding = PregoSpacing.md;

class _NewSessionViewState() extends State<NewSessionView> {
  bool _dedicatedWorktree = true;
  bool _navigatingToCreatedSession = false;
  bool _isSending = false;
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

  /// The pills over the composer. They keep one height whatever they show, so
  /// the composer never moves as options arrive: shimmering placeholders while
  /// options load, the pickers once they are here, and a single action in
  /// their place when they could not be loaded.
  Widget? _buildComposerHeader({
    required NewSessionCubit cubit,
    required NewSessionState state,
    required ValueNotifier<PregoComposerSurfaceStyle> surfaceStyleController,
    required bool compact,
  }) {
    final loc = context.loc;
    // A plain button rather than a picker pill: it loads, it opens no menu.
    Widget action({required Key key, required String label}) => Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: PregoButtonsSolid(
          key: key,
          label: label,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.sm,
          leadingIcon: TablerRegular.refresh,
          onPressed: cubit.refreshOptions,
        ),
      ),
    );
    switch (cubit.composerPresentation) {
      case NewSessionComposerPending():
        return _OptionPillsPlaceholder(compact: compact);
      case NewSessionComposerRetry():
        return action(key: const Key("new_session_options_retry"), label: loc.newSessionOptionsRetry);
      case NewSessionComposerLoadOnDemand():
        return action(key: const Key("new_session_options_load"), label: loc.newSessionOptionsLoad);
      case NewSessionComposerNoHarnesses() ||
          NewSessionComposerLoginRequired() ||
          NewSessionComposerProjectUnavailable():
        return null;
      case NewSessionComposerReady():
        break;
    }
    final data = state.agentModelData;
    if (data == null || (data.agents.isEmpty && data.providers.isEmpty)) return null;
    return ValueListenableBuilder<PregoComposerSurfaceStyle>(
      valueListenable: surfaceStyleController,
      builder: (context, surfaceStyle, _) => AgentModelButtons(
        surfaceStyle: surfaceStyle,
        agents: data.agents,
        selectedAgent: data.agent,
        onAgentSelected: cubit.selectAgent,
        providers: data.providers,
        selectedAgentModel: data.agentModel,
        onModelSelected: cubit.selectModel,
        availableVariants: data.availableVariants,
        onVariantSelected: cubit.selectVariant,
        fastModeControl: data.fastModeControl,
        decideFastModeToggle: cubit.fastModeToggleDecision,
        onFastModeChanged: cubit.setFastMode,
        compact: compact,
      ),
    );
  }

  /// The option below the header: whether the session gets a worktree of its
  /// own. While the project is still being checked its row keeps its height,
  /// so the toggle appearing does not shift the page.
  ///
  /// With no harness there is nothing for the option to shape — no session
  /// can start. Say why when the bridge answered that itself; when discovery
  /// failed instead, the error banner already explains it and the retry sits
  /// over the composer.
  Widget? _buildOptions({required NewSessionCubit cubit, required AgentModelData? data}) {
    if (cubit.hasNoHarnesses) return NewSessionNoHarnessNotice(onSettingsPressed: widget.onOpenHarnessSettings);
    if (cubit.needsHarnessDiscovery) return null;
    return switch (data?.projectWorktreeCapability) {
      NewSessionProjectWorktreeCapability.supported => _DedicatedWorkspaceRow(
        value: _dedicatedWorktree,
        onChanged: (value) => setState(() => _dedicatedWorktree = value),
      ),
      NewSessionProjectWorktreeCapability.loading || null => const SizedBox(height: _DedicatedWorkspaceRow.height),
      NewSessionProjectWorktreeCapability.unsupported || NewSessionProjectWorktreeCapability.unavailable => null,
    };
  }

  /// The harness pill beside the project pill; a shimmering pill of the same
  /// size until the bridge has said which harnesses it runs.
  Widget? _buildHarnessPill({required NewSessionCubit cubit, required AgentModelData? data}) {
    if (data == null || (data.plugins.isEmpty && data.isPluginDiscoveryInFlight)) {
      return PregoShimmer(
        semanticLabel: context.loc.newSessionOptionsLoadingSemantics,
        child: PregoSkeletonBar(height: _optionPillHeight, width: 140, color: context.prego.colors.bgQuaternary),
      );
    }
    if (cubit.needsHarnessDiscovery) return null;
    return NewSessionPluginChooser(
      plugins: data.plugins,
      selectedPluginId: data.plugin?.id,
      isSelectionEnabled: data.backendScope.isVerified && !data.isPluginDiscoveryInFlight,
      onSelected: (pluginId) => cubit.selectPlugin(pluginId: pluginId),
      onSettingsPressed: widget.onOpenHarnessSettings,
    );
  }

  /// What stands in the composer's place when no session can start: the
  /// harness needs a login, or the project could not be checked.
  Widget? _buildBlockedNotice({required NewSessionCubit cubit}) {
    final loc = context.loc;
    return switch (cubit.composerPresentation) {
      NewSessionComposerLoginRequired(:final harnessName, :final actionHint) => HarnessBlockedNotice(
        key: const Key("new_session_login_required"),
        title: loc.newSessionAuthenticationRequiredTitle(harnessName),
        details: actionHint,
        onOpenHarnessSettings: widget.onOpenHarnessSettings,
        onRecheck: cubit.refreshOptions,
      ),
      NewSessionComposerProjectUnavailable() => HarnessBlockedNotice(
        key: const Key("new_session_project_unavailable"),
        title: loc.newSessionProjectUnavailable,
        details: null,
        onOpenHarnessSettings: null,
        onRecheck: cubit.refreshOptions,
      ),
      NewSessionComposerPending() ||
      NewSessionComposerReady() ||
      NewSessionComposerRetry() ||
      NewSessionComposerLoadOnDemand() ||
      NewSessionComposerNoHarnesses() => null,
    };
  }

  /// The page under [chrome]: one centred column that scrolls as a whole when
  /// the pane is too short for it.
  Widget _buildChromePage({
    required NewSessionPageChrome chrome,
    required NewSessionState state,
    required Widget launchStatus,
    required Widget header,
    required Widget? options,
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
                      padding: const EdgeInsets.all(PregoSpacing.xl),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chrome.maxContentWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: PregoSpacing.lg,
                          children: [
                            header,
                            ?options,
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
    required bool canSend,
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
        builder: ({required context, required surfaceStyleController}) => PromptInput(
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
          hasMessages: false,
          canSend: canSend,
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
            cubit: cubit,
            state: state,
            surfaceStyleController: surfaceStyleController,
            compact: ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer,
          ),
          composerTrailing: null,
          availableCommands: composerData?.commands ?? const [],
          stagedCommand: composerData?.stagedCommand,
          onCommandSelected: context.read<NewSessionCubit>().stageCommand,
          onCommandCleared: context.read<NewSessionCubit>().clearStagedCommand,
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
    final options = _buildOptions(cubit: cubit, data: composerData);
    // Typing never waits on options; only sending waits on what it needs.
    final notice = _buildBlockedNotice(cubit: cubit);
    // A notice hides the composer rather than replacing it, so staged images,
    // which live only in the composer, survive until the notice clears.
    final composer = cubit.hasNoHarnesses
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Plugin-provided guidance can outgrow a short phone at large text.
              if (notice != null)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 2),
                  child: SingleChildScrollView(primary: false, child: notice),
                ),
              Visibility(
                key: const ValueKey("new_session_prompt"),
                visible: notice == null,
                maintainState: true,
                child: ExcludeFocus(
                  excluding: notice != null,
                  child: _buildComposer(
                    canSend: cubit.canCreateSession && !isSending,
                    restoringSubmission: restoringSubmission,
                    restoredAttachments: restoredAttachments,
                    composerData: composerData,
                    state: state,
                  ),
                ),
              ),
            ],
          );
    final header = NewSessionHeader(
      projectId: widget.projectId,
      projectName: widget.projectName,
      projects: widget.projects,
      onProjectSelected: widget.onProjectSelected,
      harness: _buildHarnessPill(cubit: cubit, data: composerData),
    );
    final chromePage = switch (widget.pageChrome) {
      null => null,
      final chrome => _buildChromePage(
        chrome: chrome,
        state: state,
        launchStatus: launchStatus,
        header: header,
        options: options,
        composer: composer,
      ),
    };

    Widget listening({required Widget child}) => BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (previous, current) =>
          current is NewSessionCreated ||
          NewSessionCubit.newlyRequiredLogin(previous: previous, current: current) != null,
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
        // The harness logged out since it was last checked. The login card
        // takes the composer's place either way; the popup says why it did.
        if (modalRoute != null && !modalRoute.isCurrent) return;
        if (context.read<NewSessionCubit>().composerPresentation case NewSessionComposerLoginRequired(
          :final harnessName,
          :final actionHint,
        )) {
          _popupAlertPresenter.show(
            title: context.loc.newSessionAuthenticationRequiredTitle(harnessName),
            content: PregoPopupAlertContent(message: actionHint),
            variant: PregoPopupAlertsNotificationsVariant.warning,
            duration: const Duration(seconds: 8),
          );
        }
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
        // The header's project selector names the project, so the bar carries
        // no subtitle.
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
                            // pane must not become the route's primary scroll.
                            primary: false,
                            slivers: [
                              SliverPadding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                  _optionsHorizontalPadding,
                                  topInset + _optionRowSpacing,
                                  _optionsHorizontalPadding,
                                  _optionsBottomPadding,
                                ),
                                sliver: SliverToBoxAdapter(child: child),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: _optionRowSpacing,
                            children: [
                              // The keyboard leaves this pane a few rows tall;
                              // they belong to the options being typed against.
                              if (MediaQuery.viewInsetsOf(context).bottom == 0) header,
                              ?options,
                            ],
                          ),
                        ),
                      ),
                      if (composer != null)
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: composer),
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
class const _DedicatedWorkspaceRow({required final bool value, required final ValueChanged<bool> onChanged})
    extends StatelessWidget {
  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return SizedBox(
      height: height,
      // The label names what the switch does, so they must reach a screen
      // reader as one control rather than as stray text beside a bare toggle.
      child: MergeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerRegular.git_branch, size: PregoIconSize.sm, color: prego.colors.textTertiary),
            SizedBox(width: prego.spacing.xs),
            Flexible(
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: prego.spacing.sm),
                child: Text(
                  context.loc.newSessionDedicatedWorkspace,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.75,
              child: PregoSwitch(
                key: const Key("new_session_dedicated_workspace"),
                value: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Height of an option pill over the composer, and of the harness pill.
const double _optionPillHeight = 36;

/// Lays option pills out the way [AgentModelButtons] does, so a placeholder or
/// an action in their place takes exactly their room.
class const _OptionPillRow({required final bool compact, required final List<Widget> pills}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
      child: Row(
        spacing: 8,
        children: [
          for (final pill in pills)
            compact
                ? Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: IntrinsicWidth(child: pill),
                    ),
                  )
                : Expanded(child: pill),
        ],
      ),
    );
  }
}

/// The agent and model pills while options load.
class const _OptionPillsPlaceholder({required final bool compact}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoShimmer(
      semanticLabel: context.loc.newSessionOptionsLoadingSemantics,
      child: _OptionPillRow(
        compact: compact,
        pills: [
          for (final width in const [112.0, 160.0])
            SizedBox(
              width: compact ? width : null,
              child: PregoSkeletonBar(height: _optionPillHeight, color: context.prego.colors.bgQuaternary),
            ),
        ],
      ),
    );
  }
}
