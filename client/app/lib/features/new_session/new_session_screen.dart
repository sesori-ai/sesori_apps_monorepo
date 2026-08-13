import "dart:math" as math;

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/extensions/remote_failure_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/agent_model_buttons.dart";
import "../../core/widgets/composer_surface_style.dart";
import "../../core/widgets/connection_banner.dart";
import "../../core/widgets/project_nav_subtitle.dart";
import "../session_detail/widgets/prompt_input.dart";
import "new_session_loading_overlay.dart";
import "new_session_no_harness_notice.dart";
import "new_session_options_skeleton.dart";
import "new_session_plugin_chooser.dart";

class const NewSessionScreen({
  super.key,
  required final String projectId,
  required final String? projectName,
  required final bool? initialSupportsDedicatedWorktrees,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewSessionCubit(
        connectionService: getIt<ConnectionService>(),
        sessionService: getIt<SessionService>(),
        newSessionPluginService: getIt<NewSessionPluginService>(),
        newSessionOptionsService: getIt<NewSessionOptionsService>(),
        projectRepository: getIt<ProjectRepository>(),
        selectionTracker: getIt<NewSessionSelectionTracker>(),
        composerDraftRepository: getIt<ComposerDraftRepository>(),
        productAnalyticsService: getIt<ProductAnalyticsService>(),
        projectId: projectId,
        initialSupportsDedicatedWorktrees: initialSupportsDedicatedWorktrees,
      ),
      child: _NewSessionBody(projectId: projectId, projectName: projectName),
    );
  }
}

class const _NewSessionBody({required final String projectId, required final String? projectName})
    extends StatefulWidget {
  @override
  State<_NewSessionBody> createState() => _NewSessionBodyState();
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

class _NewSessionBodyState() extends State<_NewSessionBody> {
  bool _dedicatedWorktree = true;
  bool _navigatingToCreatedSession = false;
  bool _isSending = false;
  late final ValueNotifier<PregoComposerSurfaceStyle> _composerSurfaceStyle;
  late PregoPopupAlertPresenter _popupAlertPresenter;
  late String _launchingInBackgroundMessage;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<NewSessionCubit>();
    _composerSurfaceStyle = ValueNotifier(
      resolveInitialComposerSurfaceStyle(
        inputMode: context.read<ChatInputModeCubit>().state,
        draft: cubit.composerDraft,
        stagedCommand: cubit.state.agentModelData?.stagedCommand,
      ),
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
    _composerSurfaceStyle.dispose();
    super.dispose();
  }

  void _dismissScreen() {
    context.pop();
  }

  Widget? _buildErrorBanner(NewSessionState state) {
    final prego = context.prego;
    final loc = context.loc;
    return switch (state) {
      NewSessionError(:final reason) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                reason.localizedMessage(loc),
                style: TextStyle(color: prego.colors.fgErrorPrimary),
              ),
            ),
          ],
        ),
      ),
      NewSessionIdle() => null,
      NewSessionSending() => null,
      NewSessionCreated() => null,
    };
  }

  Widget? _buildComposerHeader(NewSessionState state) {
    final data = state.agentModelData;
    final selectedAgent = data?.agent;
    if (data == null || (data.agents.isEmpty && data.providers.isEmpty)) return null;

    final cubit = context.read<NewSessionCubit>();
    return ValueListenableBuilder<PregoComposerSurfaceStyle>(
      valueListenable: _composerSurfaceStyle,
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
  /// Null while a load is still in flight or before a routable harness is
  /// known — there is nothing honest to say yet. The same answer gates the
  /// floating refresh action, so the explanation and the way to act on it
  /// appear and disappear together.
  ({String message, bool isFailure})? _resolveOptionsStatus({required AgentModelData? data}) {
    final plugin = data?.plugin;
    if (data == null || plugin == null || !plugin.isRoutable || data.isLoading) return null;

    final loc = context.loc;
    return switch (data.optionsState) {
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
      NewSessionOptionsAvailableState(source: NewSessionOptionsSource.legacy) => (
        message: loc.newSessionOptionsLegacyBridge,
        isFailure: false,
      ),
      NewSessionOptionsAvailableState(source: NewSessionOptionsSource.aggregate) => (
        message: loc.newSessionOptionsCached,
        isFailure: false,
      ),
      NewSessionOptionsLoadingState() || NewSessionOptionsRefreshingState() => null,
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
  /// When harness discovery itself failed before identifying a harness, it
  /// retries discovery instead and says so. A confirmed empty harness list has
  /// its own notice and no refresh action.
  Widget _buildOptionsRefresh({required NewSessionCubit cubit, required bool isHarnessDiscovery}) {
    return Positioned(
      bottom: _refreshBottomGap,
      left: 0,
      right: 0,
      child: Center(
        child: PregoButtonsSolid(
          key: const Key("new_session_options_refresh"),
          label: isHarnessDiscovery ? context.loc.newSessionHarnessesRefresh : context.loc.newSessionOptionsRefresh,
          hierarchy: PregoButtonsSolidHierarchy.tertiary,
          size: PregoButtonsSolidSize.sm,
          leadingIcon: TablerRegular.refresh,
          onPressed: cubit.canRefreshOptions ? cubit.refreshOptions : null,
        ),
      ),
    );
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
              onSettingsPressed: () => context.pushRoute(
                const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
              ),
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
          onSettingsPressed: () => context.pushRoute(
            const AppRoute.settingsHarnesses(presentation: HarnessSettingsPresentation.modal),
          ),
        ),
        if (status != null) _buildOptionsStatus(status: status),
        if (data.supportsDedicatedWorktrees) ...[
          if (hasPlugins) const SizedBox(height: _optionRowSpacing),
          _DedicatedWorkspaceRow(
            value: _dedicatedWorktree,
            onChanged: (value) => setState(() => _dedicatedWorktree = value),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<NewSessionCubit>();
    final state = cubit.state;
    final loc = context.loc;
    final isSending = state is NewSessionSending;
    final composerData = state.agentModelData;
    final needsHarnessDiscovery = cubit.needsHarnessDiscovery;
    final hasNoHarnesses = cubit.hasNoHarnesses;
    final optionsStatus = _resolveOptionsStatus(data: composerData);
    // A confirmed empty harness list is explained by the notice and has no
    // refresh action. Keep discovery retry available only when discovery failed
    // before the bridge could confirm what it runs.
    final showsRefresh = (needsHarnessDiscovery && !hasNoHarnesses) || optionsStatus != null;
    final optionsBottomPadding = showsRefresh
        ? _optionsBottomPadding + _refreshBandHeight(context)
        : _optionsBottomPadding;
    final isComposerEnabled = cubit.canCreateSession && !isSending;
    _isSending = isSending;
    // The listener can run while this route is being torn down. The route
    // object stays stable, so `isCurrent` remains safe to read at event time.
    final modalRoute = ModalRoute.of(context);

    return BlocListener<NewSessionCubit, NewSessionState>(
      listenWhen: (_, current) => current is NewSessionCreated,
      listener: (context, state) {
        if (state case NewSessionCreated(:final session)) {
          // The user may have navigated elsewhere (e.g. opened another
          // session from the split-view list) while creation was in flight.
          // Replacing the route then would hijack their navigation — the
          // leave-time snackbar already told them the session continues.
          if (modalRoute != null && !modalRoute.isCurrent) return;
          _navigatingToCreatedSession = true;
          context.replaceRoute(
            AppRoute.sessionDetail(
              projectId: widget.projectId,
              projectName: widget.projectName,
              sessionId: session.id,
              sessionTitle: session.title ?? "",
              readOnly: false,
            ),
          );
        }
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
        titleMode: PregoTopNavigationTitleMode.backLeading,
        subtitle: buildProjectNavSubtitle(context),
        reserveBarSpace: false,
        scrollable: false,
        banner: ConnectionBanner.maybeFor(context),
        // The loading scrim must dim the body while the glass back button
        // stays tappable (the user can abort while creation is in flight),
        // so it goes through the scaffold's bar-aware overlay slot rather
        // than an outer Stack that would also cover the bar.
        overlay: isSending
            ? NewSessionLoadingOverlay(
                semanticsLabel: loc.newSessionLoadingSemantics,
                messages: [
                  loc.newSessionLoadingMessage1,
                  loc.newSessionLoadingMessage2,
                  loc.newSessionLoadingMessage3,
                ],
              )
            : null,
        slivers: [
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
                        if (showsRefresh) _buildOptionsRefresh(cubit: cubit, isHarnessDiscovery: needsHarnessDiscovery),
                      ],
                    ),
                  ),
                  if (!hasNoHarnesses)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Semantics(
                        enabled: isComposerEnabled,
                        child: ExcludeFocus(
                          excluding: !isComposerEnabled,
                          child: IgnorePointer(
                            ignoring: !isComposerEnabled,
                            child: PromptInput(
                              draftIdentity: ComposerDraftRepository.newSessionIdentity(
                                projectId: widget.projectId,
                              ),
                              initialDraft: context.read<NewSessionCubit>().composerDraft,
                              hasMessages: false,
                              attachmentsSupported: composerData?.plugin?.supportsPromptAttachments,
                              isBusy: state is NewSessionSending,
                              onSend: ({required text, required command, required inputMode, required attachments}) {
                                context.read<NewSessionCubit>().createSession(
                                  text: text,
                                  command: command,
                                  inputMode: inputMode,
                                  attachments: attachments,
                                  dedicatedWorktree: _dedicatedWorktree,
                                );
                              },
                              onVoiceTranscriptionCompleted: context
                                  .read<NewSessionCubit>()
                                  .reportVoiceTranscriptionCompleted,
                              onDraftChanged: (draft) => context.read<NewSessionCubit>().saveComposerDraft(
                                draft: draft,
                              ),
                              onDraftCleared: context.read<NewSessionCubit>().clearComposerDraft,
                              onAbort: _dismissScreen,
                              surfaceStyleController: _composerSurfaceStyle,
                              header: _buildErrorBanner(state),
                              composerHeader: _buildComposerHeader(state),
                              availableCommands: composerData?.commands ?? const [],
                              stagedCommand: composerData?.stagedCommand,
                              onCommandSelected: context.read<NewSessionCubit>().stageCommand,
                              onCommandCleared: context.read<NewSessionCubit>().clearStagedCommand,
                            ),
                          ),
                        ),
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
