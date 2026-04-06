import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../core/constants.dart";
import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/agent_model_buttons.dart";
import "../../core/widgets/agent_picker_sheet.dart";
import "../../core/widgets/model_picker_sheet.dart";
import "../../l10n/app_localizations.dart";
import "widgets/assistant_message_card.dart";
import "widgets/background_tasks_bar.dart";
import "widgets/prompt_input.dart";
import "widgets/permission_modal.dart";
import "widgets/question_modal.dart";
import "widgets/queued_message_bubble.dart";
import "widgets/user_message_card.dart";

class SessionDetailScreen extends StatelessWidget {
  final String? projectId;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const SessionDetailScreen({
    super.key,
    required this.projectId,
    required this.sessionId,
    this.sessionTitle,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SessionDetailCubit(
        getIt<SessionService>(),
        getIt<ConnectionService>(),
        permissionRepository: getIt<PermissionRepository>(),
        sessionId: sessionId,
        projectId: projectId,
        notificationCanceller: getIt<NotificationCanceller>(),
        failureReporter: getIt<FailureReporter>(),
      ),
      child: _SessionDetailBody(
        projectId: projectId,
        sessionId: sessionId,
        sessionTitle: sessionTitle,
        readOnly: readOnly,
      ),
    );
  }
}

class _SessionDetailBody extends StatefulWidget {
  final String? projectId;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const _SessionDetailBody({
    required this.projectId,
    required this.sessionId,
    required this.sessionTitle,
    this.readOnly = false,
  });

  @override
  State<_SessionDetailBody> createState() => _SessionDetailBodyState();
}

class _SessionDetailBodyState extends State<_SessionDetailBody> {
  StreamSubscription<SesoriQuestionAsked>? _questionSub;
  StreamSubscription<SesoriPermissionAsked>? _permissionSub;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<SessionDetailCubit>();
    _questionSub = cubit.questionStream.listen(_onNewQuestion);
    _permissionSub = cubit.permissionStream.listen(_onNewPermission);
    cubit.clearNotifications();
  }

  @override
  void dispose() {
    _questionSub?.cancel();
    _permissionSub?.cancel();
    super.dispose();
  }

  void _onNewQuestion(SesoriQuestionAsked question) {
    if (!mounted) return;
    _showQuestionModal(question);
  }

  void _onNewPermission(SesoriPermissionAsked permission) {
    if (!mounted) return;
    _showPermissionModal(permission);
  }

  void _openAgentPicker(SessionDetailLoaded loaded) {
    final cubit = context.read<SessionDetailCubit>();
    AgentPickerSheet.show(
      context,
      agents: loaded.availableAgents,
      selectedAgent: loaded.selectedAgent,
      onAgentChanged: cubit.selectAgent,
    );
  }

  void _openModelPicker(SessionDetailLoaded loaded) {
    final cubit = context.read<SessionDetailCubit>();
    ModelPickerSheet.show(
      context,
      providers: loaded.availableProviders,
      selectedProviderID: loaded.selectedProviderID,
      selectedModelID: loaded.selectedModelID,
      onModelChanged: (providerID, modelID) {
        cubit.selectModel(providerID: providerID, modelID: modelID);
      },
    );
  }

  String _buildAgentModelSubtitle({required String? agent, required String? modelID}) {
    final parts = <String>[];
    if (agent != null) parts.add(agent);
    if (modelID != null) parts.add(modelID);
    return parts.join(" · ");
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

        if (!success) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(context.loc.questionReplyFailed),
                duration: kSnackBarDuration,
              ),
            );
          return;
        }

        // Auto-open the next pending question, if any.
        final current = context.read<SessionDetailCubit>().state;
        if (current case SessionDetailLoaded(:final pendingQuestions) when pendingQuestions.isNotEmpty) {
          // Schedule after the current modal finishes closing.
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            _showQuestionModal(pendingQuestions.first);
          });
        }
      },
      onReject: (requestId) async {
        final success = await context.read<SessionDetailCubit>().rejectQuestion(requestId);

        if (!mounted) return;

        if (!success) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(context.loc.questionRejectFailed),
                duration: kSnackBarDuration,
              ),
            );
          return;
        }

        final current = context.read<SessionDetailCubit>().state;
        if (current case SessionDetailLoaded(:final pendingQuestions) when pendingQuestions.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            _showQuestionModal(pendingQuestions.first);
          });
        }
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
            required String response,
          }) async {
            final success = await context.read<SessionDetailCubit>().replyToPermission(
              requestId: requestId,
              sessionId: sessionId,
              response: response,
            );

            if (!mounted) return;

            if (!success) {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(context.loc.permissionReplyFailed),
                    duration: kSnackBarDuration,
                  ),
                );
              return;
            }

            // Auto-open the next pending permission, if any.
            final current = context.read<SessionDetailCubit>().state;
            if (current case SessionDetailLoaded(:final pendingPermissions) when pendingPermissions.isNotEmpty) {
              Future.delayed(const Duration(milliseconds: 200), () {
                if (!mounted) return;
                _showPermissionModal(pendingPermissions.first);
              });
            }
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final state = context.watch<SessionDetailCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: .start,
          children: [
            Text(
              switch (state) {
                SessionDetailLoaded(:final sessionTitle) when sessionTitle != null => sessionTitle,
                SessionDetailLoaded() => widget.sessionTitle ?? loc.sessionDetailTitle,
                SessionDetailLoading() => widget.sessionTitle ?? loc.sessionDetailTitle,
                SessionDetailFailed() => widget.sessionTitle ?? loc.sessionDetailTitle,
              },
            ),
            if (state case SessionDetailLoaded(
              :final agent,
              :final modelID,
            ))
              Text(
                _buildAgentModelSubtitle(agent: agent, modelID: modelID),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.difference_outlined),
            tooltip: "File changes",
            onPressed: () {
              if (widget.projectId == null) return;
              context.pushRoute(
                AppRoute.sessionDiffs(
                  projectId: widget.projectId!,
                  sessionId: widget.sessionId,
                ),
              );
            },
          ),
          if (state case SessionDetailLoaded(
            :final sessionStatus,
            :final childStatuses,
          ) when _hasActiveWork(sessionStatus: sessionStatus, childStatuses: childStatuses))
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
        SessionDetailLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        SessionDetailLoaded(
          :final messages,
          :final streamingText,
          :final sessionStatus,
          :final pendingQuestions,
          :final pendingPermissions,
          :final children,
          :final childStatuses,
          :final queuedMessages,
          :final availableProviders,
          :final selectedAgent,
          :final selectedProviderID,
          :final selectedModelID,
          :final isRefreshing,
        ) =>
          Column(
            children: [
              if (isRefreshing) const LinearProgressIndicator(),
              // Pending-questions banner
              if (pendingQuestions.isNotEmpty)
                _PendingQuestionsBanner(
                  count: pendingQuestions.fold(0, (sum, q) => sum + q.questions.length),
                  onTap: () => _showQuestionModal(pendingQuestions.first),
                ),
              // Pending-permissions banner
              if (pendingPermissions.isNotEmpty)
                _PendingPermissionsBanner(
                  count: pendingPermissions.length,
                  onTap: () => _showPermissionModal(pendingPermissions.first),
                ),
              Expanded(
                child: messages.isEmpty
                    ? Center(child: Text(loc.sessionDetailEmpty))
                    : _MessageList(
                        messages: messages,
                        streamingText: streamingText,
                        children: children,
                        childStatuses: childStatuses,
                      ),
              ),
              if (children.isNotEmpty && !widget.readOnly)
                BackgroundTasksBar(
                  children: children,
                  childStatuses: childStatuses,
                ),
              if (!widget.readOnly) ...[
                if (queuedMessages.isNotEmpty)
                  _QueuedMessagesSection(
                    messages: queuedMessages,
                    onCancel: (index) => context.read<SessionDetailCubit>().cancelQueuedMessage(index),
                  ),
                PromptInput(
                  isBusy: _hasActiveWork(sessionStatus: sessionStatus, childStatuses: childStatuses),
                  onSend: (text) => context.read<SessionDetailCubit>().sendMessage(text),
                  onAbort: () => context.read<SessionDetailCubit>().abort(),
                  header: AgentModelButtons(
                    providers: availableProviders,
                    selectedAgent: selectedAgent,
                    selectedProviderID: selectedProviderID,
                    selectedModelID: selectedModelID,
                    onAgentTap: () => _openAgentPicker(state),
                    onModelTap: () => _openModelPicker(state),
                  ),
                ),
              ],
            ],
          ),
        SessionDetailFailed(:final error) => _ErrorView(
          error: error,
          onRetry: () => context.read<SessionDetailCubit>().reload(),
        ),
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Pending-permissions banner
// -----------------------------------------------------------------------------

class _PendingPermissionsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingPermissionsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Material(
      elevation: 2,
      color: theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1 ? loc.permissionBannerSingle : loc.permissionBannerMultiple(count),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pending-questions banner
// -----------------------------------------------------------------------------

class _PendingQuestionsBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingQuestionsBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Material(
      elevation: 2,
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  count == 1 ? loc.questionBannerSingle : loc.questionBannerMultiple(count),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatefulWidget {
  final List<MessageWithParts> messages;
  final Map<String, String> streamingText;
  final List<Session> children;
  final Map<String, SessionStatus> childStatuses;

  const _MessageList({
    required this.messages,
    required this.streamingText,
    required this.children,
    required this.childStatuses,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  late final ScrollController _scrollController;
  bool _following = true;
  static const _kNearBottomThreshold = 20.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_following) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  void _jumpToLatest() {
    setState(() {
      _following = true;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollUpdateNotification && notification.dragDetails != null) {
              // reverse: true — offset 0 is the bottom (newest), offset > 0 is scrolled up
              final pixels = _scrollController.position.pixels;
              if (_following && pixels > _kNearBottomThreshold) {
                setState(() {
                  _following = false;
                });
              } else if (!_following && pixels <= _kNearBottomThreshold) {
                setState(() {
                  _following = true;
                });
              }
            } else if (notification is ScrollEndNotification) {
              // Re-check once the scroll settles (after fling/ballistic animation).
              // Without this, flinging to the bottom never reattaches because
              // dragDetails is null during momentum scrolling.
              final pixels = _scrollController.position.pixels;
              if (!_following && pixels <= _kNearBottomThreshold) {
                setState(() {
                  _following = true;
                });
              }
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            reverse: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final message = widget.messages[widget.messages.length - 1 - index];
              return _buildMessageWidget(message);
            },
          ),
        ),
        if (!_following)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(20),
                color: theme.colorScheme.primaryContainer,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _jumpToLatest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_downward,
                          size: 16,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          loc.sessionDetailJumpToLatest,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageWidget(MessageWithParts message) {
    if (message.info.role == "user") {
      return UserMessageCard(message: message);
    }

    return AssistantMessageCard(
      message: message,
      streamingText: widget.streamingText,
      children: widget.children,
      childStatuses: widget.childStatuses,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final ApiError error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              loc.sessionDetailErrorTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _describeError(loc: loc, error: error),
              textAlign: .center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc.sessionDetailRetry),
            ),
          ],
        ),
      ),
    );
  }

  String _describeError({required AppLocalizations loc, required ApiError error}) => switch (error) {
    NotAuthenticatedError() => loc.apiErrorNotAuthenticated,
    NonSuccessCodeError(:final errorCode, :final rawErrorString) =>
      rawErrorString != null
          ? loc.connectErrorNonSuccessCodeWithBody(errorCode, rawErrorString)
          : loc.connectErrorNonSuccessCode(errorCode),
    DartHttpClientError(:final innerError) => loc.connectErrorConnectionFailed(innerError.toString()),
    JsonParsingError() => loc.connectErrorUnexpectedFormat,
    EmptyResponseError() => loc.connectErrorUnexpectedFormat,
    GenericError() => loc.connectErrorUnknown,
  };
}

// -----------------------------------------------------------------------------
// Queued messages section
// -----------------------------------------------------------------------------

/// Whether the main session or any child session is actively running or retrying.
bool _hasActiveWork({
  required SessionStatus sessionStatus,
  required Map<String, SessionStatus> childStatuses,
}) =>
    sessionStatus is! SessionStatusIdle ||
    childStatuses.values.any(
      (s) => s is SessionStatusBusy || s is SessionStatusRetry,
    );

class _QueuedMessagesSection extends StatelessWidget {
  final List<String> messages;
  final ValueChanged<int> onCancel;

  const _QueuedMessagesSection({
    required this.messages,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        for (var i = 0; i < messages.length; i++)
          QueuedMessageBubble(
            text: messages[i],
            onCancel: () => onCancel(i),
          ),
      ],
    );
  }
}
