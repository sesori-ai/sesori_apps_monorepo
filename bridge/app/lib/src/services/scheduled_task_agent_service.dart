import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/history_window.dart";
import "../repositories/models/sesori_mcp_caller.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "scheduled_task_request_exception.dart";
import "scheduled_task_service.dart";

/// What agents may do with scheduled tasks, through the same services the
/// app's task routes call. Reads cover every task on this computer.
class ScheduledTaskAgentService({
  required final ScheduledTaskService _tasks,
  required final ScheduledTaskRepository _taskRepository,
  required final SessionRepository _sessions,
  required final ChatHistoryService _history,
}) {
  /// Messages read to find a run's final reply. The reply closes the turn,
  /// so it is among the newest few.
  static const int _finalReplyWindow = 6;

  /// Every task not yet done, or those of [projectId].
  Future<AgentTaskList> listTasks({required SesoriMcpCaller caller, required String? projectId}) async {
    final tasks = (await _tasks.list()).items;
    return AgentTaskList(
      tasks: [
        for (final task in tasks)
          if (projectId == null || task.definition.projectId == projectId) task,
      ],
      callerProjectId: (await _sessions.getStoredSession(sessionId: caller.sessionId))?.projectId,
    );
  }

  /// [taskId], or the caller's own task when the caller is a scheduled run.
  Future<AgentTaskLookup> getTask({required SesoriMcpCaller caller, required String? taskId}) async {
    final ownTaskId = await _ownTaskId(caller: caller);
    final targetId = taskId ?? ownTaskId;
    if (targetId == null) return const AgentTaskNotScheduledRun();
    final task = (await _tasks.list()).items.where((task) => task.id == targetId).firstOrNull;
    if (task == null) return AgentTaskNotFound(taskId: targetId);
    return AgentTaskFound(task: task, isCallersOwn: task.id == ownTaskId);
  }

  /// The task's runs, newest first, each started run with its final reply.
  ///
  /// Same-session runs share one session, so only the newest run of a session
  /// carries its reply.
  Future<AgentTaskRunsLookup> listTaskRuns({required String taskId}) async {
    final runs = await _runs(taskId: taskId);
    if (runs == null) return AgentTaskRunsTaskNotFound(taskId: taskId);
    final repliedSessions = <String>{};
    final entries = <AgentTaskRun>[];
    for (final run in runs) {
      String? finalReply;
      if (run.outcome case ScheduledTaskRunStarted(session: ScheduledTaskRunSession(:final id))) {
        final isNewestRunOfSession = repliedSessions.add(id);
        if (isNewestRunOfSession) finalReply = await _finalReply(sessionId: id);
      }
      entries.add(AgentTaskRun(run: run, finalReply: finalReply));
    }
    return AgentTaskRuns(runs: entries);
  }

  /// Up to [limit] messages of [runId]'s session, the newest ones older than
  /// [before] (or the newest of all when null), oldest first.
  Future<AgentRunTranscriptLookup> runTranscript({
    required String taskId,
    required String runId,
    required int? before,
    required int limit,
  }) async {
    final runs = await _runs(taskId: taskId);
    if (runs == null) return AgentRunTranscriptTaskNotFound(taskId: taskId);
    final run = runs.where((run) => run.id == runId).firstOrNull;
    if (run == null) return AgentRunTranscriptRunNotFound(runId: runId);
    if (run.outcome case ScheduledTaskRunStarted(session: ScheduledTaskRunSession(:final id))) {
      final page = await _storedPage(
        sessionId: id,
        window: HistoryWindowNewest(limit: limit, before: before),
      );
      return AgentRunTranscript(sessionId: id, messages: page.messages, nextCursor: page.nextCursor);
    }
    return AgentRunTranscriptNoSession(run: run);
  }

  Future<String?> _ownTaskId({required SesoriMcpCaller caller}) async {
    final marks = await _taskRepository.marksOfSessions(sessionIds: {caller.sessionId});
    return marks[caller.sessionId]?.taskId;
  }

  /// Null when the task does not exist.
  Future<List<ScheduledTaskRun>?> _runs({required String taskId}) async {
    try {
      return (await _tasks.listRuns(taskId: taskId)).items;
    } on ScheduledTaskRequestException catch (error) {
      if (error.code != ScheduledTaskErrorCode.taskNotFound) rethrow;
      return null;
    }
  }

  Future<String?> _finalReply({required String sessionId}) async {
    final page = await _storedPage(
      sessionId: sessionId,
      window: const HistoryWindowNewest(limit: _finalReplyWindow, before: null),
    );
    for (final message in page.messages.reversed) {
      if (message.info is! MessageAssistant) continue;
      final text = [
        for (final part in message.parts)
          if (part case MessagePartText(:final text) when text.trim().isNotEmpty) text.trim(),
      ].join("\n\n");
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  /// Reads only what the bridge stored, archived sessions included, so a read
  /// never starts a harness.
  Future<SessionMessagesPage> _storedPage({required String sessionId, required HistoryWindow window}) {
    return _history.getSessionMessages(
      sessionId: sessionId,
      window: window,
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      toolOutputDelivery: ToolOutputDelivery.inline,
      storedOnly: true,
      backgroundRefresh: false,
    );
  }
}

final class const AgentTaskList({
  required final List<ScheduledTask> tasks,

  /// Null when the caller's session row is gone.
  required final String? callerProjectId,
});

sealed class const AgentTaskLookup();

final class const AgentTaskFound({required final ScheduledTask task, required final bool isCallersOwn})
    extends AgentTaskLookup;

/// No task id was given and the caller is not a scheduled run.
final class const AgentTaskNotScheduledRun() extends AgentTaskLookup;

final class const AgentTaskNotFound({required final String taskId}) extends AgentTaskLookup;

final class const AgentTaskRun({
  required final ScheduledTaskRun run,

  /// The run session's final assistant reply, when it has one.
  required final String? finalReply,
});

sealed class const AgentTaskRunsLookup();

final class const AgentTaskRuns({required final List<AgentTaskRun> runs}) extends AgentTaskRunsLookup;

final class const AgentTaskRunsTaskNotFound({required final String taskId}) extends AgentTaskRunsLookup;

sealed class const AgentRunTranscriptLookup();

final class const AgentRunTranscript({
  required final String sessionId,
  required final List<MessageWithParts> messages,

  /// Pass back as `before` for the next older page; null when none is left.
  required final int? nextCursor,
}) extends AgentRunTranscriptLookup;

final class const AgentRunTranscriptTaskNotFound({required final String taskId}) extends AgentRunTranscriptLookup;

final class const AgentRunTranscriptRunNotFound({required final String runId}) extends AgentRunTranscriptLookup;

/// The run never started a session, or its session was deleted.
final class const AgentRunTranscriptNoSession({required final ScheduledTaskRun run}) extends AgentRunTranscriptLookup;
