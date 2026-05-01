import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../core/constants.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../core/widgets/agent_picker_sheet.dart";
import "../../../core/widgets/model_picker_sheet.dart";
import "../../../core/widgets/variant_picker_sheet.dart";
import "permission_modal.dart";
import "question_modal.dart";
import "session_detail_loaded_view.dart";
import "session_detail_scaffold_sections.dart";

class SessionDetailBody extends StatefulWidget {
  final String projectId;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const SessionDetailBody({
    super.key,
    required this.projectId,
    required this.sessionId,
    required this.sessionTitle,
    required this.readOnly,
  });

  @override
  State<SessionDetailBody> createState() => _SessionDetailBodyState();
}

class _SessionDetailBodyState extends State<SessionDetailBody> {
  StreamSubscription<SesoriQuestionAsked>? _questionSub;
  StreamSubscription<SesoriPermissionAsked>? _permissionSub;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SessionDetailCubit>();
    _questionSub = cubit.questionStream.listen((question) => mounted ? _showQuestionModal(question) : null);
    _permissionSub = cubit.permissionStream.listen((permission) => mounted ? _showPermissionModal(permission) : null);
    cubit.clearNotifications();
  }

  @override
  void dispose() {
    _questionSub?.cancel();
    _permissionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionDetailCubit>().state;
    final isBusy = switch (state) {
      SessionDetailLoaded(:final sessionStatus, :final childStatuses) => hasActiveWork(
        sessionStatus: sessionStatus,
        childStatuses: childStatuses,
      ),
      SessionDetailLoading() => true,
      SessionDetailFailed() => false,
    };

    return Scaffold(
      appBar: AppBar(
        title: SessionDetailTitle(
          state: state,
          fallbackTitle: widget.sessionTitle ?? loc.sessionDetailTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.difference_outlined),
            tooltip: "File changes",
            onPressed: () => context.pushRoute(
              AppRoute.sessionDiffs(
                projectId: widget.projectId,
                sessionId: widget.sessionId,
              ),
            ),
          ),
          if (isBusy)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: switch (state) {
        SessionDetailLoading() => const Center(child: CircularProgressIndicator()),
        final SessionDetailLoaded loaded =>
          widget.readOnly
              ? SessionDetailLoadedView.readOnly(
                  projectId: widget.projectId,
                  state: loaded,
                  onShowPendingQuestions: _showPendingQuestions,
                  onShowPendingPermissions: _showPendingPermissions,
                )
              : SessionDetailLoadedView.editable(
                  projectId: widget.projectId,
                  state: loaded,
                  onShowPendingQuestions: _showPendingQuestions,
                  onShowPendingPermissions: _showPendingPermissions,
                  onOpenAgentPicker: _openAgentPicker,
                  onOpenModelPicker: _openModelPicker,
                  onOpenVariantPicker: _openVariantPicker,
                ),
        SessionDetailFailed(:final error) => SessionDetailErrorView(
          error: error,
          onRetry: () => context.read<SessionDetailCubit>().reload(),
        ),
      },
    );
  }

  void _showPendingQuestions() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingQuestions) when pendingQuestions.isNotEmpty) {
      _showQuestionModal(pendingQuestions.first);
    }
  }

  void _showPendingPermissions() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingPermissions) when pendingPermissions.isNotEmpty) {
      _showPermissionModal(pendingPermissions.first);
    }
  }

  void _openAgentPicker() {
    final cubit = context.read<SessionDetailCubit>();
    final state = cubit.state;
    if (state is! SessionDetailLoaded) return;
    AgentPickerSheet.show(
      context,
      agents: state.availableAgents,
      selectedAgent: state.selectedAgent,
      onAgentChanged: cubit.selectAgent,
    );
  }

  void _openModelPicker() {
    final cubit = context.read<SessionDetailCubit>();
    final state = cubit.state;
    if (state is! SessionDetailLoaded) return;
    final agentModel = state.selectedAgentModel;
    ModelPickerSheet.show(
      context,
      providers: state.availableProviders,
      selectedProviderID: agentModel?.providerID ?? "",
      selectedModelID: agentModel?.modelID ?? "",
      onModelChanged: (providerID, modelID) {
        cubit.selectModel(providerID: providerID, modelID: modelID);
      },
    );
  }

  void _openVariantPicker() {
    final cubit = context.read<SessionDetailCubit>();
    final state = cubit.state;
    if (state is! SessionDetailLoaded) return;
    VariantPickerSheet.show(
      context,
      selectedVariantId: state.selectedAgentModel?.variant,
      availableVariants: state.availableVariants,
      onVariantChanged: cubit.selectVariant,
    );
  }

  void _showQuestionModal(SesoriQuestionAsked question) {
    context.read<SessionDetailCubit>().clearNotifications();
    QuestionModal.show(
      context,
      question: question,
      onReply: (requestId, answers) async {
        final success = await context.read<SessionDetailCubit>().replyToQuestion(
          requestId: requestId,
          sessionId: question.sessionID,
          answers: answers,
        );
        if (!mounted) return;
        if (!success) return _showFailureSnackBar(context.loc.questionReplyFailed);
        _scheduleNextQuestionModal();
      },
      onReject: (requestId) async {
        final success = await context.read<SessionDetailCubit>().rejectQuestion(requestId);
        if (!mounted) return;
        if (!success) return _showFailureSnackBar(context.loc.questionRejectFailed);
        _scheduleNextQuestionModal();
      },
    );
  }

  void _showPermissionModal(SesoriPermissionAsked permission) {
    context.read<SessionDetailCubit>().clearNotifications();
    PermissionModal.show(
      context,
      permission: permission,
      onReply:
          ({
            required String requestId,
            required String sessionId,
            required PermissionReply reply,
          }) async {
            final success = await context.read<SessionDetailCubit>().replyToPermission(
              requestId: requestId,
              sessionId: sessionId,
              reply: reply,
            );
            if (!mounted) return;
            if (!success) return _showFailureSnackBar(context.loc.permissionReplyFailed);
            _scheduleNextPermissionModal();
          },
    );
  }

  void _scheduleNextQuestionModal() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingQuestions) when pendingQuestions.isNotEmpty) {
      _scheduleModal(() => _showQuestionModal(pendingQuestions.first));
    }
  }

  void _scheduleNextPermissionModal() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingPermissions) when pendingPermissions.isNotEmpty) {
      _scheduleModal(() => _showPermissionModal(pendingPermissions.first));
    }
  }

  void _scheduleModal(VoidCallback action) =>
      Future.delayed(const Duration(milliseconds: 200), () => mounted ? action() : null);

  void _showFailureSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message), duration: kSnackBarDuration));
  }
}
