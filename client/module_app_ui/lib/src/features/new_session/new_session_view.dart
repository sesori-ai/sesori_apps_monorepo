import "dart:async";
import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../extensions/remote_failure_x.dart";
import "../../widgets/harness_blocked_notice.dart";
import "../project_picker/project_picker.dart";
import "../session_detail/composer_presentation_scope.dart";
import "../session_detail/widgets/agent_model_buttons.dart";
import "../session_detail/widgets/composer_surface_style.dart";
import "../session_detail/widgets/prompt_input.dart";
import "../session_detail/widgets/session_launch_submission_view.dart";
import "../session_detail/widgets/transcript_motion.dart";
import "new_session_header.dart";
import "new_session_no_harness_notice.dart";
import "new_session_plugin_chooser.dart";

typedef NewSessionComposerScopeBuilder = Widget Function({required Widget child});
typedef NewSessionCreatedCallback = void Function({required Session session});

/// A pointer surface's frame for the page: [topBar] replaces the glass bar, and
/// the header, the options and the composer form one centred column no wider
/// than [maxContentWidth], instead of anchoring the composer to the bottom.
/// While the first message is sending it rests in a column [transcriptWidth]
/// wide, the one the session's own transcript uses.
class const NewSessionPageChrome({
  required final Widget topBar,
  required final double maxContentWidth,
  required final double transcriptWidth,

  /// As [Scaffold.backgroundColor], null for the theme's. A pane painting its
  /// own beneath bodies it cross-fades passes a transparent one.
  required final Color? backgroundColor,
});

/// Shared new-session presentation below shell-owned routing, DI, and platform
/// composer capabilities.
class const NewSessionView({
  super.key,
  required final String projectId,
  required final String? projectName,

  /// Null names the project without a picker, for a page that is the
  /// project's own.
  required final NewSessionProjectSelected? onProjectSelected,

  /// Null where nothing lies behind the page, such as the home's content pane.
  required final VoidCallback? onBack,
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

/// How long a pointer surface's page takes to become the session at Send: the
/// composer moves to the bottom while the page around it cross-fades (D8).
const _sendingMotionDuration = Duration(milliseconds: 240);

/// Where the page keeps whether its composer last showed options, for the
/// composer of the next project picked in its place.
const _optionsShownStorageId = "new_session_options_shown";

class _NewSessionViewState() extends State<NewSessionView> with SingleTickerProviderStateMixin {
  /// Null until the stored choice loads; the toggle stays hidden until then.
  bool? _chosenDedicatedWorktree;
  bool get _dedicatedWorktree => _chosenDedicatedWorktree ?? true;

  /// Whether the options showed when this composer last built; while the
  /// project is checked again they hold that place.
  late bool _optionsShown;
  bool _navigatingToCreatedSession = false;
  bool _isSending = false;
  late PregoPopupAlertPresenter _popupAlertPresenter;
  late String _launchingInBackgroundMessage;

  /// One composer through Send and a failure's restore: Flutter moves its
  /// state wherever the page puts it, so its text, images and focus stay.
  final _composerKey = GlobalKey();

  /// A pointer surface's page from composing (0) to sending (1).
  late final AnimationController _sendingMotion;

  /// The sending page as last built, so it can fade out after a failure.
  Widget? _lastSendingPane;

  @override
  void initState() {
    super.initState();
    _sendingMotion = AnimationController(
      vsync: this,
      duration: _sendingMotionDuration,
      value: context.read<NewSessionCubit>().state.phase is NewSessionPhaseSending ? 1 : 0,
    )..addStatusListener((_) => setState(() {}));
    // Picking another project builds a new composer in this one's place, so
    // it starts with the options where the last one left them. A page's
    // first composer holds the worktree row's room for a folder, which most
    // fill; "No project" never shows the row.
    final projectKind = context.read<NewSessionCubit>().projectKind;
    _optionsShown = switch (PageStorage.maybeOf(context)?.readState(context, identifier: _optionsShownStorageId)) {
      final bool shown => shown,
      _ => projectKind == ProjectKind.folder,
    };
    // "No project" is known up front, so room a folder left it folds from the
    // next frame instead of waiting for the bridge's check.
    if (projectKind == ProjectKind.scratch && _optionsShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _optionsShown = false);
      });
    }
    // The row stays hidden until the project's worktree support is known,
    // which comes from the bridge, so the stored choice lands before it shows.
    unawaited(
      context.read<NewSessionCubit>().readDedicatedWorktreePreference().then((value) {
        if (mounted) setState(() => _chosenDedicatedWorktree ??= value);
      }),
    );
  }

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
    _sendingMotion.dispose();
    super.dispose();
  }

  void _dismissScreen() {
    widget.onBack?.call();
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
    required bool readOnly,
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
      // With no harness the composer only folds away, and it keeps the
      // placeholders discovery showed rather than dropping them mid-fold.
      case NewSessionComposerPending() || NewSessionComposerNoHarnesses():
        return _OptionPillsPlaceholder(compact: compact);
      case NewSessionComposerRetry():
        return action(key: const Key("new_session_options_retry"), label: loc.newSessionOptionsRetry);
      case NewSessionComposerLoadOnDemand():
        return action(key: const Key("new_session_options_load"), label: loc.newSessionOptionsLoad);
      case NewSessionComposerLoginRequired() || NewSessionComposerProjectUnavailable():
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
        readOnly: readOnly,
        trailing: const [],
      ),
    );
  }

  /// The option below the header: whether the session gets a worktree of its
  /// own. While the project is still being checked the options hold the
  /// place they last had, so nothing shifts until the answer arrives.
  ///
  /// With no harness there is nothing for the option to shape — no session
  /// can start. Say why when the bridge answered that itself; when discovery
  /// failed instead, the error banner already explains it and the retry sits
  /// over the composer.
  Widget? _buildOptions({required NewSessionCubit cubit, required AgentModelData? data}) {
    if (cubit.hasNoHarnesses) return NewSessionNoHarnessNotice(onSettingsPressed: widget.onOpenHarnessSettings);
    if (cubit.needsHarnessDiscovery) return null;
    // "No project" never has the row. Room a folder left it stays empty for
    // the first frame only, so it folds rather than snaps.
    if (cubit.projectKind == ProjectKind.scratch) {
      return _optionsShown ? const SizedBox(height: _DedicatedWorkspaceRow.height) : null;
    }
    void choose(bool value) => setState(() => _chosenDedicatedWorktree = value);
    return switch (data?.projectWorktreeCapability) {
      // Until the stored choice loads the row shimmers in its room, so the
      // toggle never appears on and then flips off.
      NewSessionProjectWorktreeCapability.supported => _DedicatedWorkspaceRow(
        value: _chosenDedicatedWorktree,
        onChanged: choose,
      ),
      NewSessionProjectWorktreeCapability.loading ||
      null => _optionsShown ? _DedicatedWorkspaceRow(value: null, onChanged: choose) : null,
      NewSessionProjectWorktreeCapability.unsupported || NewSessionProjectWorktreeCapability.unavailable => null,
    };
  }

  /// The harness pill beside the project pill; a shimmering pill of the same
  /// size until the bridge has said which harnesses it runs.
  Widget? _buildHarnessPill({required NewSessionCubit cubit, required AgentModelData? data}) {
    if (data == null || (data.plugins.isEmpty && data.isPluginDiscoveryInFlight)) {
      return PregoShimmer(
        appearDelay: Duration.zero,
        semanticLabel: context.loc.newSessionOptionsLoadingSemantics,
        child: PregoSkeletonBar(
          height: _optionPillHeight,
          width: 140,
          color: _placeholderColor(colors: context.prego.colors),
        ),
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
        onShowBridgeUpdate: null,
        onRecheck: cubit.refreshOptions,
      ),
      NewSessionComposerProjectUnavailable() => HarnessBlockedNotice(
        key: const Key("new_session_project_unavailable"),
        title: loc.newSessionProjectUnavailable,
        details: null,
        onOpenHarnessSettings: null,
        onShowBridgeUpdate: null,
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
  /// the pane is too short for it. At Send the page becomes the session it is
  /// creating: the top bar, header and options fade out as the
  /// message fades in above the composer, which moves to the bottom edge where
  /// the session screen keeps it (D8). A failure plays it backwards.
  Widget _buildChromePage({
    required NewSessionPageChrome chrome,
    required Widget? sendingPane,
    required Widget header,
    required Widget? options,
    required Widget composer,
    required bool composerShown,
  }) {
    final isSending = sendingPane != null;
    if (sendingPane != null) _lastSendingPane = sendingPane;
    final lastSendingPane = _lastSendingPane;
    final idleOpacity = ReverseAnimation(_sendingMotion);
    Widget fadingIdle(Widget child) => FadeTransition(opacity: idleOpacity, child: child);
    // The composer's place in the column keeps its height while the column
    // fades, so nothing there shifts as it leaves.
    final composerHeight = switch (_composerKey.currentContext?.findRenderObject()) {
      final RenderBox box when box.hasSize => box.size.height,
      _ => 0.0,
    };
    final idle = IgnorePointer(
      ignoring: isSending,
      child: ExcludeFocus(
        excluding: isSending,
        child: Column(
          children: [
            fadingIdle(chrome.topBar),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  key: const Key("new_session_options_scroll"),
                  padding: const EdgeInsets.all(PregoSpacing.xl),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: chrome.maxContentWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        fadingIdle(
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              header,
                              _AnimatedOptions(
                                key: const Key("new_session_options"),
                                gap: PregoSpacing.lg,
                                options: options,
                              ),
                            ],
                          ),
                        ),
                        // The gap above the composer folds with it, so the
                        // centred column never snaps by the gap.
                        _AnimatedFold(
                          shown: composerShown,
                          gap: PregoSpacing.lg,
                          child: isSending ? SizedBox(height: composerHeight) : composer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final session = lastSendingPane == null
        ? null
        : LayoutBuilder(
            // The composer spans the column the session screen gives it.
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: IgnorePointer(
                    ignoring: !isSending,
                    child: FadeTransition(opacity: _sendingMotion, child: lastSendingPane),
                  ),
                ),
                if (isSending)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: math.max(0, (constraints.maxWidth - chrome.maxContentWidth) / 2) + 16,
                    ),
                    child: composer,
                  ),
              ],
            ),
          );
    return Scaffold(
      backgroundColor: chrome.backgroundColor,
      body: Column(
        children: [
          ?widget.banner,
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!isSending || !_sendingMotion.isCompleted) idle,
                if (isSending || !_sendingMotion.isDismissed) ?session,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plays the page's change at Send, or back after a failure; reduced motion
  /// makes it at once.
  void _onSendingChanged({required bool sending}) {
    if (context.isReducedMotion) {
      _sendingMotion.value = sending ? 1 : 0;
    } else if (sending) {
      _sendingMotion.forward();
    } else {
      _sendingMotion.reverse();
    }
  }

  /// Send turns the options into the session it is creating, showing the
  /// message as it will sit in the session's transcript above the composer,
  /// and a failed creation turns it back. Both directions cross-fade with the
  /// transcript's own motion rather than cutting; reduced motion swaps at once.
  Widget _crossFadeSending({required Widget? sending, required Widget composing}) {
    final child = sending == null
        ? KeyedSubtree(key: const ValueKey("new_session_composing"), child: composing)
        : KeyedSubtree(key: const ValueKey("new_session_sending"), child: sending);
    return ExcludeFocus(
      excluding: sending != null,
      child: context.isReducedMotion
          ? child
          : AnimatedSwitcher(
              duration: transcriptMotionDuration,
              switchInCurve: transcriptMotionCurve,
              switchOutCurve: transcriptMotionReverseCurve,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, ?current],
              ),
              child: child,
            ),
    );
  }

  Widget _buildComposer({
    required bool isSending,
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
        builder: ({required context, required surfaceStyleController}) => Focus(
          // Reports focus for the session screen that takes the composer over.
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => context.read<NewSessionCubit>().reportComposerFocus(focused: focused),
          child: PromptInput(
            draftIdentity: ComposerDraftRepository.newSessionIdentity(projectId: widget.projectId),
            restorationKey: restoringSubmission == null ? null : ObjectKey(restoringSubmission),
            initialDraft: context.read<NewSessionCubit>().composerDraft,
            initialSelection: null,
            initialAttachments: restoredAttachments,
            onInitialAttachmentsConsumed: () {
              final submission = restoringSubmission;
              if (submission != null) {
                context.read<NewSessionCubit>().acknowledgeRestoredSubmission(submission: submission);
              }
            },
            onAttachmentsChanged: (attachments) =>
                context.read<NewSessionCubit>().saveComposerAttachments(attachments: attachments),
            onSelectionChanged: (selection) =>
                context.read<NewSessionCubit>().reportComposerSelection(selection: selection),
            // A creation landing while this is true keeps this screen until
            // the work lands in what the session screen takes over.
            onBusyChanged: (busy) => context.read<NewSessionCubit>().setComposerBusy(busy: busy),
            autofocus: false,
            // The first message is in the transcript once it is sending.
            hasMessages: isSending,
            canSend: cubit.canSubmit,
            attachmentsSupported: composerData?.plugin?.supportsPromptAttachments,
            isBusy: false,
            onSend: ({required draft, required command, required attachments}) =>
                context.read<NewSessionCubit>().submit(
                  draft: draft,
                  command: command,
                  attachments: attachments,
                  dedicatedWorktree: _dedicatedWorktree,
                ),
            onVoiceTranscriptionCompleted: ComposerPresentationScope.of(context).voiceSupport.isSupported
                ? context.read<NewSessionCubit>().reportVoiceTranscriptionCompleted
                : null,
            onDraftChanged: (draft) => context.read<NewSessionCubit>().saveComposerDraft(draft: draft),
            onDraftCleared: context.read<NewSessionCubit>().clearComposerDraft,
            onAbort: _dismissScreen,
            surfaceStyleController: surfaceStyleController,
            header: _AnimatedBanner(banner: _buildErrorBanner(state)),
            composerHeader: _buildComposerHeader(
              cubit: cubit,
              state: state,
              surfaceStyleController: surfaceStyleController,
              compact: ComposerPresentationScope.of(context).presentation == ComposerPresentation.pointer,
              // D9: the options are committed at Send.
              readOnly: isSending,
            ),
            composerTrailing: null,
            availableCommands: composerData?.commands ?? const [],
            stagedCommand: composerData?.stagedCommand,
            onCommandSelected: context.read<NewSessionCubit>().stageCommand,
            onCommandCleared: context.read<NewSessionCubit>().clearStagedCommand,
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
    final sendingPhase = switch (state.phase) {
      final NewSessionPhaseSending phase => phase,
      NewSessionPhaseIdle() ||
      NewSessionPhaseRestoringSubmission() ||
      NewSessionPhaseCreationError() ||
      NewSessionPhaseDiscoveryError() ||
      null => null,
    };
    final isSending = sendingPhase != null;
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
    // Named from the plugin id, as the session screen names the launch's
    // bubble, so the handoff never changes the bubble's words.
    final harnessName = switch (composerData?.plugin) {
      final plugin? => PregoBrandLogo.displayNameFor(plugin.id),
      null => null,
    };
    final options = _buildOptions(cubit: cubit, data: composerData);
    _optionsShown = options != null;
    PageStorage.maybeOf(context)?.writeState(context, _optionsShown, identifier: _optionsShownStorageId);
    // Typing never waits on options; only sending waits on what it needs.
    final notice = _buildBlockedNotice(cubit: cubit);
    // With no harness the composer folds away as the notice opens in the
    // options, and opens again once a harness is back.
    final composerShown = !cubit.hasNoHarnesses;
    // A notice hides the composer rather than replacing it, so staged images,
    // which live only in the composer, survive until the notice clears.
    final composerColumn = Column(
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
              isSending: isSending,
              restoringSubmission: restoringSubmission,
              restoredAttachments: restoredAttachments,
              composerData: composerData,
              state: state,
            ),
          ),
        ),
      ],
    );
    final composer = KeyedSubtree(
      key: _composerKey,
      child: widget.pageChrome == null
          ? composerColumn
          // The composer's one move between the centred column and the
          // bottom edge (D8).
          : PregoSlideFromLastPosition(
              progress: _sendingMotion,
              forward: isSending,
              horizontalOnly: false,
              child: composerColumn,
            ),
    );
    Widget? sendingPane({required double? transcriptWidth}) => switch (sendingPhase) {
      null => null,
      final phase => SessionLaunchSubmissionView(
        submission: phase.submission,
        harnessName: harnessName,
        transcriptWidth: transcriptWidth,
        sendingSince: phase.startedAt,
        awaitingBridgeSubmissions: const [],
        launchFollowUps: phase.followUps,
        queuedMessages: const [],
        // Follow-ups only send once the session exists, on its own screen.
        onRetryLaunchFollowUp: null,
        onRemoveLaunchFollowUp: cubit.cancelFollowUp,
        onCancelQueuedMessage: null,
        // The composer sits below rather than over it.
        bottomInset: 0,
      ),
    };
    final header = NewSessionHeader(
      projectId: widget.projectId,
      projectName: widget.projectName,
      onProjectSelected: widget.onProjectSelected,
      harness: _buildHarnessPill(cubit: cubit, data: composerData),
    );
    final chromePage = switch (widget.pageChrome) {
      null => null,
      final chrome => _buildChromePage(
        chrome: chrome,
        // Nothing scrolls behind a pointer surface's bars, so the transcript
        // needs no top inset.
        sendingPane: switch (sendingPane(transcriptWidth: chrome.transcriptWidth)) {
          null => null,
          final pane => PregoTopBarInsetScope(
            baseInset: 0,
            bannerHeight: const AlwaysStoppedAnimation<double>(0),
            child: pane,
          ),
        },
        header: header,
        options: options,
        composer: composer,
        composerShown: composerShown,
      ),
    };

    Widget listening({required Widget child}) => BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (previous, current) =>
          (previous.phase is NewSessionPhaseSending) != (current.phase is NewSessionPhaseSending) ||
          current is NewSessionCreated ||
          NewSessionCubit.newlyRequiredLogin(previous: previous, current: current) != null,
      listener: (context, state) {
        if (widget.pageChrome != null) _onSendingChanged(sending: state.phase is NewSessionPhaseSending);
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
        onBack: widget.onBack == null ? null : _dismissScreen,
        // The header's project selector names the project, so the bar carries
        // no subtitle.
        titleMode: isSending ? PregoTopNavigationTitleMode.inline : PregoTopNavigationTitleMode.backLeading,
        subtitle: null,
        reserveBarSpace: false,
        scrollable: false,
        banner: widget.banner,
        slivers: [
          // Fill the viewport behind the bar so the variable-height options can
          // shrink and scroll without pushing the pinned composer off-screen.
          // With the scaffold's keyboard resize (Scaffold default), the
          // composer rides above the keyboard when the field is focused. The
          // sending transcript owns its scroll too.
          SliverFillRemaining(
            hasScrollBody: true,
            child: Column(
              children: [
                Expanded(
                  child: _crossFadeSending(
                    sending: sendingPane(transcriptWidth: null),
                    composing: PregoTopBarInsetBuilder(
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
                        children: [
                          header,
                          _AnimatedOptions(
                            key: const Key("new_session_options"),
                            gap: _optionRowSpacing,
                            options: options,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _AnimatedFold(
                  shown: composerShown,
                  gap: 0,
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: composer),
                ),
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

/// The options under the header, with the [gap] above them. They open as they
/// fade in and fold away as they fade out, so the composer below glides
/// rather than jumps as a project's answer adds or removes them. Options that
/// replace others open above them as they fold, so the two heights trade
/// evenly instead of the taller holding the room. A first build shows them as
/// they are, and reduced motion changes them at once.
class const _AnimatedOptions({super.key, required final double gap, required final Widget? options})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
      switchInCurve: transcriptMotionCurve,
      switchOutCurve: transcriptMotionReverseCurve,
      layoutBuilder: (current, previous) => Column(mainAxisSize: MainAxisSize.min, children: [?current, ...previous]),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: animation,
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: gap),
            // As wide as the column, as the options were before they moved.
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
      child: options,
    );
  }
}

/// The error banner over the composer, in the motion of [_AnimatedOptions]:
/// its room opens as it fades in and folds away as it fades out, so the pills
/// and a centred page glide rather than jump as an error comes or clears.
/// Another error while one shows takes its place without fading, its room
/// easing to the new text's height. Reduced motion changes it at once, with
/// no [AnimatedSize], which would re-dirty itself mid-layout at zero duration.
class const _AnimatedBanner({required final Widget? banner}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (context.isReducedMotion) return banner ?? const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: transcriptMotionDuration,
      switchInCurve: transcriptMotionCurve,
      switchOutCurve: transcriptMotionReverseCurve,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: Alignment.topCenter,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: switch (banner) {
        null => null,
        final banner => AnimatedSize(
          duration: transcriptMotionDuration,
          curve: transcriptMotionCurve,
          alignment: Alignment.topCenter,
          child: banner,
        ),
      },
    );
  }
}

/// [child] with the [gap] above it while [shown], in the motion of
/// [_AnimatedOptions]: it opens as it fades in and folds away as it fades out,
/// then stays mounted offstage, so the composer keeps its state, staged images
/// included, until it opens again. One child that comes and goes rather than a
/// switch between children, so a change mid-motion turns back from where it is
/// with the child's state intact; a switcher would hold the composer's global
/// key twice. Reduced motion changes it at once.
class const _AnimatedFold({required final bool shown, required final double gap, required final Widget child})
    extends StatefulWidget {
  @override
  State<_AnimatedFold> createState() => _AnimatedFoldState();
}

class _AnimatedFoldState() extends State<_AnimatedFold> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: transcriptMotionDuration, value: widget.shown ? 1 : 0)
      ..addStatusListener((_) => setState(() {}));
    _animation = CurvedAnimation(
      parent: _controller,
      curve: transcriptMotionCurve,
      reverseCurve: transcriptMotionReverseCurve,
    );
  }

  @override
  void didUpdateWidget(_AnimatedFold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shown == oldWidget.shown) return;
    if (context.isReducedMotion) {
      _controller.value = widget.shown ? 1 : 0;
    } else if (widget.shown) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = widget.shown;
    return Visibility(
      visible: !_controller.isDismissed,
      maintainState: true,
      // Clipped only while it moves: at rest a focus ring or glass may paint
      // past the child's box.
      child: ClipRect(
        clipBehavior: _controller.isCompleted ? Clip.none : Clip.hardEdge,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) =>
              Align(alignment: Alignment.topCenter, heightFactor: math.max(_animation.value, 0), child: child),
          child: FadeTransition(
            opacity: _animation,
            // Leaving, it takes no taps and gives its focus up at once.
            child: IgnorePointer(
              ignoring: !shown,
              child: ExcludeFocus(
                excluding: !shown,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(top: widget.gap),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether the session gets a git worktree of its own instead of working in
/// the project checkout everyone shares.
class const _DedicatedWorkspaceRow({
  /// Null shimmers in the row's place while the project is checked or the
  /// stored choice loads; the row fades in once both are known.
  required final bool? value,
  required final ValueChanged<bool> onChanged,
}) extends StatelessWidget {
  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
        switchInCurve: transcriptMotionCurve,
        switchOutCurve: transcriptMotionReverseCurve,
        child: switch (value) {
          null => PregoShimmer(
            appearDelay: Duration.zero,
            semanticLabel: context.loc.newSessionOptionsLoadingSemantics,
            child: PregoSkeletonBar(height: 20, width: 150, color: _placeholderColor(colors: prego.colors)),
          ),
          // The label names what the switch does, so they must reach a screen
          // reader as one control rather than as stray text beside a bare
          // toggle.
          final value => MergeSemantics(
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
        },
      ),
    );
  }
}

/// Height of an option pill over the composer, and of the harness pill.
const double _optionPillHeight = 36;

/// Colour of the bars that shimmer while the composer's options load: 30% of
/// the way from the quaternary background to the quaternary foreground, so the
/// bars read against the page itself and not only under the sweeping sheen.
Color _placeholderColor({required PregoColors colors}) =>
    Color.alphaBlend(colors.fgQuaternary.withValues(alpha: 0.3), colors.bgQuaternary);

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
      appearDelay: Duration.zero,
      semanticLabel: context.loc.newSessionOptionsLoadingSemantics,
      child: _OptionPillRow(
        compact: compact,
        pills: [
          for (final width in const [112.0, 160.0])
            SizedBox(
              width: compact ? width : null,
              child: PregoSkeletonBar(
                height: _optionPillHeight,
                color: _placeholderColor(colors: context.prego.colors),
              ),
            ),
        ],
      ),
    );
  }
}
