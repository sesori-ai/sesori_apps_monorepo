import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../session_detail_presentation_scope.dart";
import "permission_modal.dart";
import "question_modal.dart";
import "session_detail_loaded_view.dart";
import "session_detail_scaffold_sections.dart";
import "session_harness_unavailable_notice.dart";

String? _resolveModelName({required AgentModel? model, required List<ProviderInfo> providers}) {
  if (model == null) return null;
  for (final provider in providers) {
    if (provider.id == model.providerID) {
      return provider.models[model.modelID]?.name ?? model.modelID;
    }
  }
  return model.modelID;
}

/// The harness name the bridge reported, e.g. "Claude Code"; null until the
/// harness status loads or when an older bridge does not report it.
String? _harnessName({required SessionInteractionState interaction}) => switch (interaction) {
  SessionInteractionAvailable(:final displayName) => displayName,
  SessionInteractionBlocked(:final displayName) => displayName,
  SessionInteractionChecking() || SessionInteractionLegacyUnverified() => null,
};

/// "Claude Code · Haiku", or whichever part is known.
String? _subtitle({required String? harnessName, required String? modelName}) {
  final parts = [?harnessName, ?modelName];
  return parts.isEmpty ? null : parts.join(" · ");
}

typedef SessionDetailHeaderBuilder = Widget Function({
  required BuildContext context,
  required String title,
  required String? subtitle,
  required bool isBusy,

  /// Null while the session has no diff to show.
  required VoidCallback? onShowDiffs,

  /// The hydrated session, or null until the page has resolved it.
  required Session? session,
});

/// The session's own actions for the glass bar's menu, built when it opens.
typedef SessionDetailMenuEntriesBuilder = List<PregoMenuEntry> Function({
  required BuildContext context,
  required Session session,
});

/// A pointer surface's page frame: an opaque header above the transcript
/// instead of the floating glass bar over it, and a centred reading column.
class const SessionDetailPageChrome({
  required final SessionDetailHeaderBuilder headerBuilder,
  required final double maxContentWidth,
});

class const SessionDetailBody({
  super.key,
  required final String projectId,
  required final String sessionId,
  required final String? sessionTitle,
  required final bool readOnly,
  required final Widget? banner,
  required final VoidCallback? onBack,
  required final VoidCallback? onClose,
  required final VoidCallback? onShowDiffs,
  required final SessionDetailBottomControlsBuilder? bottomControlsBuilder,

  /// Null keeps the floating glass bar and a full-width transcript.
  required final SessionDetailPageChrome? pageChrome,

  /// The glass bar's session menu, for a root session; null shows none. A page frame brings its
  /// own header and menu instead.
  required final SessionDetailMenuEntriesBuilder? menuEntriesBuilder,
}) extends StatefulWidget {
  @override
  State<SessionDetailBody> createState() => _SessionDetailBodyState();
}

class _SessionDetailBodyState() extends State<SessionDetailBody> {
  StreamSubscription<SesoriQuestionAsked>? _questionSub;
  StreamSubscription<SesoriPermissionAsked>? _permissionSub;
  StreamSubscription<SessionDetailNotice>? _noticeSub;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SessionDetailCubit>();
    _questionSub = cubit.questionStream.listen((question) => mounted ? _showQuestionModal(question) : null);
    _permissionSub = cubit.permissionStream.listen((permission) => mounted ? _showPermissionModal(permission) : null);
    _noticeSub = cubit.noticeStream.listen((notice) => mounted ? _showNotice(notice) : null);
    cubit.clearNotifications();
  }

  @override
  void dispose() {
    _questionSub?.cancel();
    _permissionSub?.cancel();
    _noticeSub?.cancel();
    super.dispose();
  }

  void _showNotice(SessionDetailNotice notice) {
    if (!_isCurrentPage) return;
    final (title, message, variant, duration) = switch (notice) {
      SessionDetailQueueCancellationFailed() => (
        context.loc.sessionDetailQueueCancellationFailed,
        null,
        PregoPopupAlertsNotificationsVariant.warning,
        const Duration(seconds: 3),
      ),
      SessionDetailPromptOptionsUpdated() => (
        context.loc.sessionDetailPromptOptionsUpdated,
        null,
        PregoPopupAlertsNotificationsVariant.warning,
        const Duration(seconds: 3),
      ),
      SessionDetailPromptOptionsRecoveryFailed() => (
        context.loc.sessionDetailPromptOptionsRecoveryFailed,
        null,
        PregoPopupAlertsNotificationsVariant.error,
        const Duration(seconds: 3),
      ),
      SessionDetailAuthenticationRequired(:final actionHint) => (
        context.loc.sessionDetailAuthenticationRequired,
        actionHint,
        PregoPopupAlertsNotificationsVariant.warning,
        const Duration(seconds: 8),
      ),
      SessionDetailCommandUnavailable() => (
        context.loc.sessionDetailCommandUnavailable,
        null,
        PregoPopupAlertsNotificationsVariant.error,
        const Duration(seconds: 3),
      ),
    };
    PregoPopupAlertPresenter.of(context).show(
      title: title,
      content: PregoPopupAlertContent(message: message),
      variant: variant,
      duration: duration,
    );
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
      SessionDetailLoading() || SessionDetailHarnessUnavailable() || SessionDetailFailed() => false,
    };
    final fallbackTitle = widget.sessionTitle ?? loc.sessionDetailTitle;
    final title = switch (state) {
      SessionDetailLoaded(:final sessionTitle) => sessionTitle ?? fallbackTitle,
      SessionDetailHarnessUnavailable(:final session) => session.title ?? fallbackTitle,
      SessionDetailLoading() || SessionDetailFailed() => fallbackTitle,
    };
    final subtitle = switch (state) {
      SessionDetailLoaded(:final interaction, :final assistantAgentModel, :final availableProviders) => _subtitle(
        harnessName: _harnessName(interaction: interaction),
        modelName: _resolveModelName(model: assistantAgentModel, providers: availableProviders),
      ),
      SessionDetailLoading() || SessionDetailHarnessUnavailable() || SessionDetailFailed() => null,
    };
    final canShowDiffs = state is SessionDetailLoaded && (state.isRootSession ?? false) && !state.isArchived;
    final onShowDiffs = widget.onShowDiffs;
    final menuEntriesBuilder = widget.menuEntriesBuilder;
    final session = state.hydratedSession;

    final actions = <Widget>[
      if (widget.onClose != null)
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.archivedSessionsClose,
          onPressed: widget.onClose,
        ),
      if (canShowDiffs && onShowDiffs != null)
        PregoButtonsIconGlass(
          icon: TablerRegular.git_compare,
          semanticLabel: loc.sessionDetailFileChangesTooltip,
          onPressed: onShowDiffs,
        ),
      // Root sessions only: the actions run on the project's session list,
      // which holds no sub-agent sessions and must not gain one.
      if (menuEntriesBuilder != null && session != null && session.parentID == null)
        PregoAnchorMenu(
          flat: true,
          menuWidth: 240,
          acquireOpenLease: null,
          entriesBuilder: () => menuEntriesBuilder(context: context, session: session),
          triggerBuilder: (context, openMenu) => PregoButtonsIconGlass(
            key: const Key("session-detail-more"),
            icon: TablerRegular.dots,
            semanticLabel: loc.sessionDetailMoreActions,
            onPressed: openMenu,
          ),
        ),
      if (isBusy)
        // A status indicator, not a button — sized to the glass button's 40×40
        // footprint so the bar height stays stable as work starts and stops.
        const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: PregoActivityIndicator(color: null),
            ),
          ),
        ),
    ];

    final statusWarning = switch (state) {
      SessionDetailLoaded(isArchived: true) => null,
      SessionDetailLoaded(:final SessionInteractionLegacyUnverified interaction) => interaction,
      SessionDetailLoaded(:final SessionInteractionAvailable interaction) when interaction.refreshError != null =>
        interaction,
      SessionDetailLoaded() ||
      SessionDetailLoading() ||
      SessionDetailHarnessUnavailable() ||
      SessionDetailFailed() => null,
    };
    final banner = statusWarning == null
        ? widget.banner
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?widget.banner,
              _buildHarnessNotice(interaction: statusWarning, historyUnavailable: false),
            ],
          );
    final pageChrome = widget.pageChrome;
    final content = _buildContent(context: context, state: state, maxContentWidth: pageChrome?.maxContentWidth);
    if (pageChrome != null) {
      return Scaffold(
        body: Column(
          children: [
            pageChrome.headerBuilder(
              context: context,
              title: title,
              subtitle: subtitle,
              isBusy: isBusy,
              onShowDiffs: canShowDiffs ? onShowDiffs : null,
              session: state.hydratedSession,
            ),
            ?banner,
            // The header sits above the transcript, so nothing scrolls behind a
            // bar and the transcript needs no top inset for one.
            Expanded(
              child: PregoTopBarInsetScope(
                baseInset: 0,
                bannerHeight: const AlwaysStoppedAnimation<double>(0),
                child: content,
              ),
            ),
          ],
        ),
      );
    }
    return PregoGlassScaffold(
      title: title,
      subtitleText: subtitle,
      banner: banner,
      // A chat owns its own (reversed) scroll, so there is no top-anchored
      // scroll for a large title to collapse against. Use the fixed, centred
      // inline title (Figma "Middle Title") instead.
      titleMode: PregoTopNavigationTitleMode.inline,
      // The chat owns its own scroll and insets itself, so the messages scroll
      // behind the transparent bar like every other screen. Skip the auto top
      // spacer that would otherwise confine the loaded view below the bar.
      reserveBarSpace: false,
      // The loaded view fills the viewport and the chat list owns its own
      // (reversed) scroll, so the outer page must not scroll — otherwise a drag
      // that starts on the pinned composer overscrolls/bounces the whole page.
      scrollable: false,
      // Toolbar navigation is explicit: unlike Android system back, it must
      // not be vetoed by the composer's keyboard-dismissal PopScope. A pushed
      // child detail still pops to its parent. The base compact detail uses the
      // typed parent route rather than asking go_router to derive it from
      // decoded path parameters, which would turn path-like project IDs back
      // into literal slashes and make the parent URL unmatchable.
      onBack: widget.onBack,
      automaticallyImplyLeading: widget.onBack != null,
      actions: actions.isEmpty ? null : actions,
      slivers: [
        // The loaded view is a Column with an Expanded chat and a pinned
        // composer. With reserveBarSpace: false there is no top spacer, so
        // hasScrollBody: true gives it the full viewport height behind the
        // bar — the chat scrolls behind the transparent bar and insets its
        // own content below it (chat flexes, composer stays anchored at the
        // bottom and rides above the keyboard). The chat owns its own
        // reversed scroll controller, so the large title can't collapse with
        // it; the inline title is used instead, as on the new-session screen.
        SliverFillRemaining(hasScrollBody: state is SessionDetailLoaded, child: content),
      ],
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required SessionDetailState state,
    required double? maxContentWidth,
  }) {
    final loc = context.loc;
    return switch (state) {
      SessionDetailLoading() => PregoLaunchStatus(
        semanticsLabel: loc.sessionDetailLoadingSemantics,
        messages: [
          loc.newSessionLoadingMessage1,
          loc.newSessionLoadingMessage2,
          loc.newSessionLoadingMessage3,
        ],
      ),
      final SessionDetailLoaded loaded =>
        widget.readOnly || loaded.isArchived
            ? SessionDetailLoadedView.readOnly(
                projectId: widget.projectId,
                sessionId: widget.sessionId,
                state: loaded,
                onShowPendingQuestions: _showPendingQuestions,
                onShowPendingPermissions: _showPendingPermissions,
                bottomControls: loaded.isArchived || loaded.interaction.canInteract
                    ? null
                    : _buildHarnessNotice(interaction: loaded.interaction, historyUnavailable: false),
                maxContentWidth: maxContentWidth,
              )
            : SessionDetailLoadedView.interactive(
                projectId: widget.projectId,
                sessionId: widget.sessionId,
                state: loaded,
                onShowPendingQuestions: _showPendingQuestions,
                onShowPendingPermissions: _showPendingPermissions,
                bottomControls: !loaded.interaction.canInteract
                    ? _buildHarnessNotice(interaction: loaded.interaction, historyUnavailable: false)
                    : widget.bottomControlsBuilder?.call(
                        context: context,
                        projectId: widget.projectId,
                        sessionId: widget.sessionId,
                        state: loaded,
                      ),
                maxContentWidth: maxContentWidth,
              ),
      SessionDetailHarnessUnavailable(:final interaction) => Center(
        child: _buildHarnessNotice(interaction: interaction, historyUnavailable: true),
      ),
      SessionDetailFailed(:final reason) => SessionDetailErrorView(
        reason: reason,
        onRetry: () => context.read<SessionDetailCubit>().reload(),
      ),
    };
  }

  void _showPendingQuestions() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingQuestions, :final interaction)
        when interaction.canInteract && !widget.readOnly && pendingQuestions.isNotEmpty) {
      _showQuestionModal(pendingQuestions.first);
    }
  }

  void _showPendingPermissions() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingPermissions, :final interaction)
        when interaction.canInteract && !widget.readOnly && pendingPermissions.isNotEmpty) {
      _showPermissionModal(pendingPermissions.first);
    }
  }

  void _showQuestionModal(SesoriQuestionAsked question) {
    if (!_isCurrentPage) return;
    final cubit = context.read<SessionDetailCubit>();
    // An archived session is audit-only, so its requests are not answerable —
    // treating them as no longer pending both keeps the modal from opening and
    // dismisses one that was already open when the archive landed.
    bool isPending() {
      final state = cubit.state;
      return state is SessionDetailLoaded &&
          !widget.readOnly &&
          !state.isArchived &&
          state.interaction.canInteract &&
          state.pendingQuestions.any((q) => q.id == question.id);
    }

    if (!isPending()) return;
    cubit.clearNotifications();
    QuestionModal.show(
      context,
      question: question,
      isPendingStream: cubit.stream.map((_) => isPending()).distinct(),
      isPending: isPending,
      openExternalLink: SessionDetailPresentationScope.read(context).openExternalLink,
      onReply: (requestId, answers) async {
        final success = await context.read<SessionDetailCubit>().replyToQuestion(
          requestId: requestId,
          sessionId: question.sessionID,
          answers: answers,
        );
        if (!mounted) return;
        if (!success) return _showFailureAlert(context.loc.questionReplyFailed);
        _scheduleNextQuestionModal();
      },
      onReject: (requestId) async {
        final success = await context.read<SessionDetailCubit>().rejectQuestion(requestId);
        if (!mounted) return;
        if (!success) return _showFailureAlert(context.loc.questionRejectFailed);
        _scheduleNextQuestionModal();
      },
    );
  }

  void _showPermissionModal(SesoriPermissionAsked permission) {
    if (!_isCurrentPage) return;
    final cubit = context.read<SessionDetailCubit>();
    bool isPending() {
      final state = cubit.state;
      return state is SessionDetailLoaded &&
          !widget.readOnly &&
          !state.isArchived &&
          state.interaction.canInteract &&
          state.pendingPermissions.any((p) => p.requestID == permission.requestID);
    }

    if (!isPending()) return;
    cubit.clearNotifications();
    PermissionModal.show(
      context,
      permission: permission,
      isPendingStream: cubit.stream.map((_) => isPending()).distinct(),
      isPending: isPending,
      openExternalLink: SessionDetailPresentationScope.read(context).openExternalLink,
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
            if (!success) return _showFailureAlert(context.loc.permissionReplyFailed);
            _scheduleNextPermissionModal();
          },
    );
  }

  void _scheduleNextQuestionModal() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingQuestions, :final pendingPermissions)) {
      if (pendingQuestions.isNotEmpty) {
        _scheduleModal(() => _showQuestionModal(pendingQuestions.first));
        return;
      }
      if (pendingPermissions.isNotEmpty) {
        _scheduleModal(() => _showPermissionModal(pendingPermissions.first));
      }
    }
  }

  void _scheduleNextPermissionModal() {
    final state = context.read<SessionDetailCubit>().state;
    if (state case SessionDetailLoaded(:final pendingQuestions, :final pendingPermissions)) {
      if (pendingPermissions.isNotEmpty) {
        _scheduleModal(() => _showPermissionModal(pendingPermissions.first));
        return;
      }
      if (pendingQuestions.isNotEmpty) {
        _scheduleModal(() => _showQuestionModal(pendingQuestions.first));
      }
    }
  }

  void _scheduleModal(VoidCallback action) =>
      Future.delayed(const Duration(milliseconds: 200), () => mounted ? action() : null);

  bool get _isCurrentPage =>
      context.read<SessionDetailCubit>().isRouteVisible && (ModalRoute.of(context)?.isCurrent ?? false);

  Widget _buildHarnessNotice({required SessionInteractionState interaction, required bool historyUnavailable}) {
    return SessionHarnessUnavailableNotice(
      interaction: interaction,
      historyUnavailable: historyUnavailable,
      onOpenHarnessSettings: SessionDetailPresentationScope.read(context).openHarnessSettings,
      onRecheck: () => unawaited(context.read<SessionDetailCubit>().recheckHarnessAvailability()),
    );
  }

  void _showFailureAlert(String message) {
    PregoPopupAlertPresenter.of(context).show(
      title: message,
      variant: PregoPopupAlertsNotificationsVariant.error,
    );
  }
}
