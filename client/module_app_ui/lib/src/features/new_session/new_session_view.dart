import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../extensions/remote_failure_x.dart";
import "../session_detail/composer_presentation_scope.dart";
import "../session_detail/widgets/agent_model_buttons.dart";
import "../session_detail/widgets/composer_surface_style.dart";
import "../session_detail/widgets/prompt_input.dart";
import "new_session_no_harness_notice.dart";
import "new_session_options_skeleton.dart";
import "new_session_plugin_chooser.dart";

typedef NewSessionComposerScopeBuilder = Widget Function({required Widget child});
typedef NewSessionCreatedCallback = void Function({required Session session});

/// Shared new-session presentation below shell-owned routing, DI, and platform
/// composer capabilities.
class const NewSessionView({
  super.key,
  required final String projectId,
  required final VoidCallback onBack,
  required final VoidCallback onOpenHarnessSettings,
  required final NewSessionCreatedCallback onSessionCreated,
  required final NewSessionComposerScopeBuilder composerScopeBuilder,
  required final Widget? subtitle,
  required final Widget? banner,
}) extends StatefulWidget {
  @override
  State<NewSessionView> createState() => _NewSessionViewState();
}

/// Height of one options row, and the gap between rows — the rhythm the
/// loading skeleton stands in for (Figma node 4435:16803).
const double _optionRowHeight = 40;
const double _optionRowSpacing = PregoSpacing.xl;

/// Horizontal inset of the options block. Narrower than the composer's, so the
/// row content lands on the design's margin once each row's own padding is
/// added.
const double _optionsHorizontalPadding = 10;

/// Bottom padding of the options scroll view, so the last row can rest clear of
/// the composer.
const double _optionsBottomPadding = PregoSpacing.md;

/// The gap the floating refresh action keeps above the composer (Figma node
/// 4691:7507).
const double _refreshBottomGap = PregoSpacing.xl;

/// The band the floating refresh action occupies above the composer, reserved
/// as extra scroll padding so a long options block can still be scrolled out
/// from under it.
///
/// [PregoButtonsSolidSize.sm] is padding around its content rather than a fixed
/// box, so the pill grows with the reader's text scale. A constant would leave
/// the last option row stranded underneath it at accessibility sizes.
double _refreshBandHeight(BuildContext context) {
  // The sm button's vertical padding around its tallest content: a 20px icon,
  // or the text-sm line height — also 20 — once the text scale is applied.
  const contentHeight = 20.0;
  final scaledContent = MediaQuery.textScalerOf(context).scale(contentHeight);
  return PregoSpacing.md * 2 + math.max(contentHeight, scaledContent) + _refreshBottomGap;
}

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

  /// Runs the refresh action and keeps it on screen while the press is still
  /// working. Every load it can start also clears the condition that put the
  /// action there, so without this the only feedback for the press would be
  /// the action vanishing — at the one moment the user is watching it.
  ///
  /// Only the newest press governs: the harness chooser stays live during a
  /// refresh, so a second press can begin while the first is still outstanding,
  /// and the first finishing must not retire the action the second is running.
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
      ),
    );
  }

  /// Where the harness options came from, or why they are missing.
  ///
  /// Null before a routable harness is known, or while a first load has
  /// nothing to describe yet — there is nothing honest to say. A refresh over
  /// options already on screen keeps describing those, so the line does not
  /// blink out and shift the rows under it for the length of the load.
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
      NewSessionOptionsRefreshingState(source: NewSessionOptionsSource.aggregate) => (
        message: loc.newSessionOptionsCached,
        isFailure: false,
      ),
      NewSessionOptionsLoadingState() => null,
    };
  }

  Widget _buildOptionsStatus({required ({String message, bool isFailure}) status}) {
    final prego = context.prego;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        top: prego.spacing.sm,
        start: prego.spacing.lg,
        end: prego.spacing.lg,
      ),
      child: Text(
        status.message,
        style: prego.textTheme.textXs.regular.copyWith(
          color: status.isFailure ? prego.colors.fgErrorPrimary : prego.colors.textSecondary,
        ),
      ),
    );
  }

  /// The refresh action, floating centred just above the composer (Figma node
  /// 4691:7507). It reloads the whole options block rather than any one row,
  /// so it stays with the composer instead of scrolling away inside the block
  /// it acts on. Floating rather than in flow: a cramped viewport — landscape
  /// with a multiline draft — must still spend its height on the composer.
  ///
  /// It is one action with one name in every state. Which load it actually
  /// repeats — harness discovery, the project check, or the options themselves
  /// — is the cubit's to decide; naming that split here would ask the user to
  /// track a distinction they cannot act on. The line above the composer
  /// already says what is missing. A confirmed empty harness list has its own
  /// notice and no refresh action.
  /// It spins while a press is running and the answers on screen are still
  /// unsettled, rather than for the whole life of the press. A press outlives
  /// its own subject — the harness chooser stays live during a refresh, and the
  /// harness left behind may take as long as it likes to answer — so a spinner
  /// tied to the press alone would sit over another harness's settled options,
  /// on an action the user then cannot press.
  Widget _buildOptionsRefresh({required NewSessionCubit cubit, required bool isLoading}) {
    return Positioned(
      bottom: _refreshBottomGap,
      left: 0,
      right: 0,
      child: Center(
        child: PregoButtonsSolid(
          key: const Key("new_session_options_refresh"),
          label: context.loc.newSessionOptionsRefresh,
          hierarchy: PregoButtonsSolidHierarchy.tertiary,
          size: PregoButtonsSolidSize.sm,
          leadingIcon: TablerRegular.refresh,
          isLoading: isLoading,
          onPressed: cubit.canRefreshOptions ? _refreshOptions : null,
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

  /// The options above the composer: which harness runs the session, and
  /// whether it gets a workspace of its own.
  ///
  /// Until the bridge has answered what it can run, neither question has an
  /// answer to show, so the block shimmers placeholders on the rows' own
  /// rhythm rather than popping controls in one at a time. A later discovery
  /// (a reconnect) keeps the controls it already has, disabled — blanking a
  /// known harness back to a shimmer would lose more than it says.
  Widget _buildOptions({
    required AgentModelData? data,
    required ({String message, bool isFailure})? status,
    required bool needsHarnessDiscovery,
    required bool hasNoHarnesses,
  }) {
    if (data == null || (data.plugins.isEmpty && data.isPluginDiscoveryInFlight)) {
      return const NewSessionOptionsSkeleton(
        rowHeight: _optionRowHeight,
        rowSpacing: _optionRowSpacing,
      );
    }

    // With no harness there is nothing to choose between, and nothing for the
    // workspace option to shape — no session can start. Say why in the
    // chooser's place when the bridge answered that itself; when discovery
    // failed instead, the error banner already explains it and only the retry
    // above the composer is left standing.
    if (needsHarnessDiscovery) {
      return hasNoHarnesses
          ? NewSessionNoHarnessNotice(
              onSettingsPressed: widget.onOpenHarnessSettings,
            )
          : const SizedBox.shrink();
    }

    final hasPlugins = data.plugins.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NewSessionPluginChooser(
          plugins: data.plugins,
          selectedPluginId: data.plugin?.id,
          isSelectionEnabled: data.backendScope.isVerified && !data.isPluginDiscoveryInFlight,
          onSelected: (pluginId) => context.read<NewSessionCubit>().selectPlugin(pluginId: pluginId),
          onSettingsPressed: widget.onOpenHarnessSettings,
        ),
        if (status != null) _buildOptionsStatus(status: status),
        if (data.projectWorktreeCapability == NewSessionProjectWorktreeCapability.supported) ...[
          if (hasPlugins) const SizedBox(height: _optionRowSpacing),
          _DedicatedWorkspaceRow(
            value: _dedicatedWorktree,
            onChanged: (value) => setState(() => _dedicatedWorktree = value),
          ),
        ],
      ],
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
                hasMessages: false,
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
    final needsHarnessDiscovery = cubit.needsHarnessDiscovery;
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
    // A confirmed empty harness list is explained by the notice and has no
    // refresh action. Keep discovery retry available only when discovery failed
    // before the bridge could confirm what it runs. A press of its own keeps it
    // on screen: the load it started is exactly what the user wants to watch.
    final showsRefresh = (needsHarnessDiscovery && !hasNoHarnesses) || optionsStatus != null || _refreshPress != null;
    final optionsBottomPadding = showsRefresh
        ? _optionsBottomPadding + _refreshBandHeight(context)
        : _optionsBottomPadding;
    final isComposerEnabled = cubit.canCreateSession && !isSending;
    _isSending = isSending;
    // The listener can run while this route is being torn down. The route
    // object stays stable, so `isCurrent` remains safe to read at event time.
    final modalRoute = ModalRoute.of(context);

    return BlocListener<NewSessionCubit, NewSessionState>(
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
      child: PregoGlassScaffold(
        title: loc.sessionListNewSession,
        // Toolbar navigation is explicit: unlike Android system back, it must
        // not be vetoed by the composer's keyboard-dismissal PopScope.
        onBack: _dismissScreen,
        // The same back-leading block the sessions list wears, so stepping into
        // the composer keeps the project's repository in view. Only the title
        // line changes — this screen is about the session being started, not
        // the project it belongs to.
        titleMode: isSending ? PregoTopNavigationTitleMode.inline : PregoTopNavigationTitleMode.backLeading,
        subtitle: isSending ? null : widget.subtitle,
        reserveBarSpace: false,
        scrollable: false,
        banner: widget.banner,
        slivers: isSending
            ? [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PregoLaunchStatus(
                    semanticsLabel: loc.newSessionLoadingSemantics,
                    messages: [
                      loc.newSessionLoadingMessage1,
                      loc.newSessionLoadingMessage2,
                      loc.newSessionLoadingMessage3,
                    ],
                  ),
                ),
              ]
            : [
                // Fill the viewport behind the bar so the variable-height options can
                // shrink and scroll without pushing the pinned composer off-screen.
                // With the scaffold's keyboard resize (Scaffold default), the
                // composer rides above the keyboard when the field is focused.
                SliverFillRemaining(
                  hasScrollBody: true,
                  child: AbsorbPointer(
                    absorbing: isSending,
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            // The scroll view owns the whole area, as it did before
                            // the refresh action floated over it — a loose fit would
                            // let it shrink to its content and strand the last rows
                            // above a viewport that no longer reaches them.
                            fit: StackFit.expand,
                            children: [
                              PregoTopBarInsetBuilder(
                                builder: (context, topInset, child) => SingleChildScrollView(
                                  key: const Key("new_session_options_scroll"),
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                    _optionsHorizontalPadding,
                                    topInset + _optionRowSpacing,
                                    _optionsHorizontalPadding,
                                    optionsBottomPadding,
                                  ),
                                  child: child,
                                ),
                                child: _buildOptions(
                                  data: composerData,
                                  status: optionsStatus,
                                  needsHarnessDiscovery: needsHarnessDiscovery,
                                  hasNoHarnesses: hasNoHarnesses,
                                ),
                              ),
                              if (showsRefresh)
                                _buildOptionsRefresh(
                                  cubit: cubit,
                                  isLoading: _refreshPress != null && (composerData?.isLoading ?? false),
                                ),
                            ],
                          ),
                        ),
                        if (!hasNoHarnesses)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildComposer(
                              isComposerEnabled: isComposerEnabled,
                              restoringSubmission: restoringSubmission,
                              restoredAttachments: restoredAttachments,
                              composerData: composerData,
                              state: state,
                            ),
                          ),
                      ],
                    ),
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
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return SizedBox(
      height: _optionRowHeight,
      // The label names what the switch does, so they must reach a screen
      // reader as one control rather than as stray text beside a bare toggle.
      child: MergeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Padding(
                padding: EdgeInsetsDirectional.only(start: prego.spacing.lg, end: prego.spacing.md),
                child: Text(
                  context.loc.newSessionDedicatedWorkspace,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
                ),
              ),
            ),
            PregoSwitch(
              key: const Key("new_session_dedicated_workspace"),
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
