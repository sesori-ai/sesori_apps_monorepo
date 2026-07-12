import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "assistant_message_mapper.dart";
import "message_part_mapper.dart";
import "models/openapi/agent.g.dart";
import "models/openapi/assistant_message.g.dart";
import "models/openapi/message.g.dart";
import "models/openapi/permission_request.g.dart";
import "models/openapi/question_request.g.dart";
import "models/openapi/session.g.dart";
import "models/openapi/session_messages_response_item.g.dart";
import "models/openapi/session_status.g.dart";
import "models/openapi/user_message.g.dart";
import "question_info_mapper.dart";

class PluginModelMapper {
  const PluginModelMapper({
    required MessagePartMapper messagePartMapper,
    QuestionInfoMapper questionInfoMapper = const QuestionInfoMapper(),
    AssistantMessageMapper assistantMessageMapper = const AssistantMessageMapper(),
  }) : _messagePartMapper = messagePartMapper,
       _questionInfoMapper = questionInfoMapper,
       _assistantMessageMapper = assistantMessageMapper;

  final MessagePartMapper _messagePartMapper;
  final QuestionInfoMapper _questionInfoMapper;
  final AssistantMessageMapper _assistantMessageMapper;

  PluginSession mapSession(Session session, {required String projectID}) {
    final summary = session.summary;
    final time = session.time;
    return PluginSession(
      id: session.id,
      projectID: projectID,
      directory: session.directory,
      parentID: session.parentID,
      title: session.title,
      summary: summary == null
          ? null
          : PluginSessionSummary(
              additions: summary.additions.toInt(),
              deletions: summary.deletions.toInt(),
              files: summary.files.toInt(),
            ),
      time: PluginSessionTime(
        created: time.created.toInt(),
        updated: time.updated.toInt(),
        archived: time.archived?.toInt(),
      ),
    );
  }

  PluginProject mapProject({
    required String worktree,
    required String directory,
    required String? name,
    required PluginProjectActivity? activity,
  }) {
    return PluginProject(
      id: worktree,
      directory: directory,
      name: _effectiveProjectName(worktree: worktree, name: name),
      activity: activity,
    );
  }

  PluginSessionStatus mapSessionStatus(SessionStatus status) {
    return switch (status) {
      SessionStatusIdle() => const PluginSessionStatus.idle(),
      SessionStatusBusy() => const PluginSessionStatus.busy(),
      SessionStatusRetry(:final attempt, :final message, :final next) => PluginSessionStatus.retry(
        attempt: attempt,
        message: message,
        next: next,
      ),
      SessionStatusUnknown() => const PluginSessionStatus.idle(),
      _ => const PluginSessionStatus.idle(),
    };
  }

  PluginAgent mapAgent(Agent agent) {
    return PluginAgent(
      name: agent.name,
      description: agent.description,
      model: switch (agent.model) {
        AgentModel(:final modelID, :final providerID) => PluginAgentModel(
          modelID: modelID,
          providerID: providerID,
          variant: agent.variant,
        ),
        null => null,
      },
      mode: switch (agent.mode) {
        AgentMode.all => PluginAgentMode.all,
        AgentMode.primary => PluginAgentMode.primary,
        AgentMode.subagent => PluginAgentMode.subagent,
        AgentMode.unknown => PluginAgentMode.unknown,
      },
      hidden: agent.hidden ?? false,
    );
  }

  PluginPendingQuestion mapQuestion(QuestionRequest question, {required String? displaySessionId}) {
    return PluginPendingQuestion(
      id: question.id,
      sessionID: question.sessionID,
      displaySessionId: displaySessionId,
      questions: _questionInfoMapper.mapQuestionInfos(question.questions),
    );
  }

  PluginPendingPermission mapPermission(PermissionRequest permission, {required String? displaySessionId}) {
    // OpenCode's permission payload carries `permission` (the tool/permission
    // identifier) and the requested `patterns`; there is no separate
    // `description`, so the requested patterns stand in for the human-readable
    // detail (mirrors the SSE mapper).
    return PluginPendingPermission(
      id: permission.id,
      sessionID: permission.sessionID,
      displaySessionId: displaySessionId,
      tool: permission.permission,
      description: permission.patterns.join(", "),
    );
  }

  PluginMessageWithParts mapMessageWithParts(SessionMessagesResponseItem raw) {
    final info = raw.info;
    final pluginInfo = switch (info) {
      UserMessage(:final id, :final sessionID, :final agent, :final time) => PluginMessage.user(
        id: id,
        sessionID: sessionID,
        agent: agent,
        time: _mapUserMessageTime(time),
      ),
      AssistantMessage() => _assistantMessageMapper.map(info),
      MessageUnknown(:final raw) => throw FormatException("Unknown message role: $raw"),
      _ => throw FormatException("Unknown message role: $info"),
    };
    return PluginMessageWithParts(
      info: pluginInfo,
      parts: raw.parts.map(_messagePartMapper.mapPart).where((part) => part.type.isVisible).toList(),
    );
  }

  PluginMessageTime _mapUserMessageTime(UserMessageTime time) {
    return PluginMessageTime(created: time.created.toInt(), completed: null);
  }

  String? _effectiveProjectName({required String worktree, required String? name}) {
    if (name != null && name.isNotEmpty) return name;
    if (worktree.isEmpty) return null;
    final normalized = worktree.replaceAll(r"\", "/");
    final segments = normalized.split("/").where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : segments.last;
  }
}
