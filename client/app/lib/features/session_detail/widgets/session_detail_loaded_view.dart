import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/agent_model_buttons.dart";
import "background_tasks_bar.dart";
import "prompt_input.dart";
import "session_detail_message_list.dart";
import "session_detail_scaffold_sections.dart";

class SessionDetailLoadedView extends StatefulWidget {
  final String? projectId;
  // Session id, used as the composer draft key. Null in the read-only
  // variant, which renders no prompt input.
  final String? sessionId;
  final SessionDetailLoaded state;
  final bool readOnly;
  final VoidCallback onShowPendingQuestions;
  final VoidCallback onShowPendingPermissions;

  const SessionDetailLoadedView.readOnly({
    super.key,
    required this.projectId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
  }) : readOnly = true,
       sessionId = null;

  const SessionDetailLoadedView.editable({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.state,
    required this.onShowPendingQuestions,
    required this.onShowPendingPermissions,
  }) : readOnly = false;

  @override
  State<SessionDetailLoadedView> createState() => _SessionDetailLoadedViewState();
}

class _SessionDetailLoadedViewState extends State<SessionDetailLoadedView> {
  /// Measured height of the floating bottom controls overlaying the bottom of
  /// the chat — the background-tasks bar, queued messages and the composer. Fed
  /// to the message list so the newest message rests just above them (and the
  /// "jump to latest" pill clears them) while older content scrolls up behind
  /// the composer's fade. Stays 0 in the read-only variant, which renders none
  /// of these controls.
  double _bottomControlsHeight = 0;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = widget.state;
    final questionCount = state.pendingQuestions.fold<int>(0, (sum, q) => sum + q.questions.length);

    // The scaffold lets this view fill the full height behind the transparent
    // bar (reserveBarSpace: false), so the message list scrolls behind it like
    // every other screen. Inset the chat's content — and pin the refresh
    // indicator / banners — by this much so they clear the bar at rest.
    final topInset = MediaQuery.paddingOf(context).top + PregoTopNavigation.barHeight;

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: state.messages.isEmpty && state.retryErrorMessage == null
                  ? Center(child: Text(loc.sessionDetailEmpty))
                  : SessionDetailMessageList(
                      projectId: widget.projectId,
                      messages: state.messages,
                      streamingText: state.streamingText,
                      children: state.children,
                      childStatuses: state.childStatuses,
                      retryErrorMessage: state.retryErrorMessage,
                      // Pad the oldest-message edge clear of the bar it scrolls
                      // behind, and the newest-message edge clear of the floating
                      // bottom controls overlaid below (background-tasks bar,
                      // queued messages and composer); content in between scrolls
                      // up behind the bar's fade and the composer's fade.
                      topInset: topInset,
                      // The read-only variant renders no floating controls, so
                      // force the inset to 0 there — guarding against a stale
                      // measured height lingering if a state object is reused
                      // across an editable -> read-only transition.
                      bottomInset: widget.readOnly ? 0 : _bottomControlsHeight,
                    ),
            ),
          ],
        ),
        // The refresh indicator and pending banners pin just below the
        // transparent bar, floating over the chat that scrolls behind them —
        // rather than pushing the chat down out of the behind-bar region.
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isRefreshing) const LinearProgressIndicator(),
              if (state.pendingQuestions.isNotEmpty)
                SessionDetailPendingBanner(
                  icon: Icons.help_outline,
                  backgroundColor: context.prego.colors.bgBrandPrimary,
                  foregroundColor: context.prego.colors.textBrandPrimary,
                  label: questionCount == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(questionCount),
                  onTap: widget.onShowPendingQuestions,
                ),
              if (state.pendingPermissions.isNotEmpty)
                SessionDetailPendingBanner(
                  icon: Icons.shield_outlined,
                  backgroundColor: context.prego.colors.bgSuccessPrimary,
                  foregroundColor: context.prego.colors.textSuccessPrimary,
                  label: state.pendingPermissions.length == 1
                      ? loc.permissionBannerSingle
                      : loc.permissionBannerMultiple(state.pendingPermissions.length),
                  onTap: widget.onShowPendingPermissions,
                ),
            ],
          ),
        ),
        // Floating bottom controls — the background-tasks bar, queued messages
        // and the composer, stacked in that order above the composer at the
        // bottom edge. They sit over the chat (which scrolls behind them) and
        // are measured as one cluster so the chat insets its newest message
        // clear of the whole stack — and so the tasks bar/queued stay tappable
        // above the composer instead of hidden behind it.
        if (!widget.readOnly)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _MeasureSize(
              onChange: (size) {
                if (!mounted || size.height == _bottomControlsHeight) return;
                setState(() => _bottomControlsHeight = size.height);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.children.isNotEmpty)
                    BackgroundTasksBar(
                      projectId: widget.projectId,
                      children: state.children,
                      childStatuses: state.childStatuses,
                    ),
                  if (state.queuedMessages.isNotEmpty)
                    SessionDetailQueuedMessagesSection(messages: state.queuedMessages),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PromptInput(
                      draftKey: widget.sessionId,
                      isBusy: hasActiveWork(
                        sessionStatus: state.sessionStatus,
                        childStatuses: state.childStatuses,
                      ),
                      onSend: (text, command) => context.read<SessionDetailCubit>().sendMessage(
                        text: text,
                        command: command,
                      ),
                      onAbort: () => context.read<SessionDetailCubit>().abort(),
                      header: null,
                      composerHeader: AgentModelButtons(
                        agents: state.availableAgents,
                        selectedAgent: state.selectedAgent,
                        onAgentSelected: context.read<SessionDetailCubit>().selectAgent,
                        providers: state.availableProviders,
                        selectedAgentModel: state.selectedAgentModel,
                        onModelSelected: context.read<SessionDetailCubit>().selectModel,
                        availableVariants: state.availableVariants,
                        onVariantSelected: context.read<SessionDetailCubit>().selectVariant,
                      ),
                      availableCommands: state.availableCommands,
                      stagedCommand: state.stagedCommand,
                      onCommandSelected: context.read<SessionDetailCubit>().stageCommand,
                      onCommandCleared: context.read<SessionDetailCubit>().clearStagedCommand,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

bool hasActiveWork({
  required SessionStatus sessionStatus,
  required Map<String, SessionStatus> childStatuses,
}) {
  return sessionStatus is! SessionStatusIdle ||
      childStatuses.values.any((s) => s is SessionStatusBusy || s is SessionStatusRetry);
}

/// Reports its child's measured size via [onChange] after each layout pass.
/// Used to feed the floating composer's height to the message list so the
/// newest message and the "jump to latest" pill rest clear of it. [onChange]
/// is invoked post-frame so listeners may safely call `setState`.
class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) => _MeasureSizeRenderBox(onChange);

  @override
  void updateRenderObject(BuildContext context, _MeasureSizeRenderBox renderObject) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderBox extends RenderProxyBox {
  _MeasureSizeRenderBox(this.onChange);

  ValueChanged<Size> onChange;
  Size? _lastReported;

  @override
  void performLayout() {
    super.performLayout();
    final size = child?.size ?? Size.zero;
    if (size == _lastReported) return;
    _lastReported = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(size));
  }
}
