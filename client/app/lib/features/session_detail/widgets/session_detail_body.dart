import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/constants.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/routing/app_router.dart";
import "../../../core/routing/imperative_pane_route.dart";
import "../../../core/widgets/connection_banner.dart";
import "../../../core/widgets/isolated_activity_indicator.dart";
import "../../../core/widgets/session_split/session_split_scope.dart";
import "permission_modal.dart";
import "question_modal.dart";
import "session_detail_loaded_view.dart";
import "session_detail_scaffold_sections.dart";

class SessionDetailBody extends StatefulWidget {
  final String projectId;
  final String? projectName;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const SessionDetailBody({
    super.key,
    required this.projectId,
    required this.projectName,
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
    final isSplit = SessionSplitScope.maybeOf(context)?.isSplit ?? false;
    final showLeading = !isSplit || isImperativePaneRoute(context);
    final isBusy = switch (state) {
      SessionDetailLoaded(:final sessionStatus, :final childStatuses) => hasActiveWork(
        sessionStatus: sessionStatus,
        childStatuses: childStatuses,
      ),
      SessionDetailLoading() => false,
      SessionDetailFailed() => false,
    };
    final fallbackTitle = widget.sessionTitle ?? loc.sessionDetailTitle;
    final title = switch (state) {
      SessionDetailLoaded(:final sessionTitle) => sessionTitle ?? fallbackTitle,
      SessionDetailLoading() || SessionDetailFailed() => fallbackTitle,
    };
    final subtitle = switch (state) {
      // Both parts are null-aware: with a null agent/model the join must yield
      // an empty string (no subtitle), never a literal "null" under the title.
      SessionDetailLoaded(:final agent, :final assistantAgentModel) => [
        ?agent,
        ?assistantAgentModel?.modelID,
      ].join(" · "),
      SessionDetailLoading() || SessionDetailFailed() => "",
    };
    final isRootSession = state is SessionDetailLoaded && state.isRootSession == true;

    final actions = <Widget>[
      if (isRootSession)
        PregoButtonsIconGlass(
          icon: TablerRegular.git_compare,
          semanticLabel: loc.sessionDetailFileChangesTooltip,
          onPressed: () => context.pushRoute(
            AppRoute.sessionDiffs(
              projectId: widget.projectId,
              projectName: widget.projectName,
              sessionId: widget.sessionId,
            ),
          ),
        ),
      if (isBusy)
        // A status indicator, not a button — sized to the glass button's 40×40
        // footprint so the bar height stays stable as work starts and stops.
        SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: IsolatedActivityIndicator(
                strokeWidth: 2.5,
                color: context.prego.colors.bgBrandSolid,
              ),
            ),
          ),
        ),
    ];

    return PregoGlassScaffold(
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      banner: ConnectionBanner.maybeFor(context),
      // A chat owns its own (reversed) scroll, so there is no top-anchored
      // scroll for a large title to collapse against. Use the fixed, centred
      // inline title (Figma "Middle Title") instead.
      inlineTitle: true,
      // The chat owns its own scroll and insets itself, so the messages scroll
      // behind the transparent bar like every other screen. Skip the auto top
      // spacer that would otherwise confine the loaded view below the bar.
      reserveBarSpace: false,
      // The loaded view fills the viewport and the chat list owns its own
      // (reversed) scroll, so the outer page must not scroll — otherwise a drag
      // that starts on the pinned composer overscrolls/bounces the whole page.
      scrollable: false,
      automaticallyImplyLeading: showLeading,
      actions: actions.isEmpty ? null : actions,
      slivers: [
        switch (state) {
          SessionDetailLoading() => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          // The loaded view is a Column with an Expanded chat and a pinned
          // composer. With reserveBarSpace: false there is no top spacer, so
          // hasScrollBody: true gives it the full viewport height behind the
          // bar — the chat scrolls behind the transparent bar and insets its
          // own content below it (chat flexes, composer stays anchored at the
          // bottom and rides above the keyboard). The chat owns its own
          // reversed scroll controller, so the large title can't collapse with
          // it; the inline title is used instead, as on the new-session screen.
          final SessionDetailLoaded loaded => SliverFillRemaining(
            hasScrollBody: true,
            child: widget.readOnly
                ? SessionDetailLoadedView.readOnly(
                    projectId: widget.projectId,
                    state: loaded,
                    onShowPendingQuestions: _showPendingQuestions,
                    onShowPendingPermissions: _showPendingPermissions,
                  )
                : SessionDetailLoadedView.editable(
                    projectId: widget.projectId,
                    sessionId: widget.sessionId,
                    state: loaded,
                    onShowPendingQuestions: _showPendingQuestions,
                    onShowPendingPermissions: _showPendingPermissions,
                  ),
          ),
          SessionDetailFailed(:final reason) => SliverFillRemaining(
            hasScrollBody: false,
            child: SessionDetailErrorView(
              reason: reason,
              onRetry: () => context.read<SessionDetailCubit>().reload(),
            ),
          ),
        },
      ],
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
