import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "message_part_mapper.dart";
import "models/openapi/agent.g.dart";
import "models/openapi/assistant_message.g.dart";
import "models/openapi/message.g.dart";
import "models/openapi/permission_request.g.dart";
import "models/openapi/project.g.dart";
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
  }) : _messagePartMapper = messagePartMapper,
       _questionInfoMapper = questionInfoMapper;

  final MessagePartMapper _messagePartMapper;
  final QuestionInfoMapper _questionInfoMapper;

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

  PluginProject mapProject(Project project) {
    final time = project.time;
    return PluginProject(
      id: project.worktree,
      name: _effectiveProjectName(project),
      time: PluginProjectTime(
        created: time.created.toInt(),
        updated: time.updated.toInt(),
      ),
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
      AssistantMessage(:final id, :final sessionID, :final agent, :final modelID, :final providerID, :final error, :final time) =>
        _mapAssistantMessage(
          id: id,
          sessionID: sessionID,
          agent: agent,
          modelID: modelID,
          providerID: providerID,
          error: error,
          time: time,
        ),
      MessageUnknown(:final raw) => throw FormatException("Unknown message role: $raw"),
      _ => throw FormatException("Unknown message role: $info"),
    };
    return PluginMessageWithParts(
      info: pluginInfo,
      parts: raw.parts.map(_messagePartMapper.mapPart).where((part) => part.type.isVisible).toList(),
    );
  }

  PluginMessage _mapAssistantMessage({
    required String id,
    required String sessionID,
    required String agent,
    required String modelID,
    required String providerID,
    required Object? error,
    required AssistantMessageTime time,
  }) {
    final pluginTime = _mapAssistantMessageTime(time);
    final errorMap = error is Map<String, dynamic> ? error : null;
    if (errorMap == null) {
      return PluginMessage.assistant(
        id: id,
        sessionID: sessionID,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
        time: pluginTime,
      );
    }
    final data = errorMap["data"];
    final dataMap = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return PluginMessage.error(
      id: id,
      sessionID: sessionID,
      agent: agent,
      modelID: modelID,
      providerID: providerID,
      errorName: errorMap["name"]?.toString() ?? "UnknownError",
      errorMessage: dataMap["message"]?.toString() ?? "Unknown error",
      time: pluginTime,
    );
  }

  PluginMessageTime _mapUserMessageTime(UserMessageTime time) {
    return PluginMessageTime(created: time.created.toInt(), completed: null);
  }

  PluginMessageTime _mapAssistantMessageTime(AssistantMessageTime time) {
    return PluginMessageTime(created: time.created, completed: time.completed);
  }

  String? _effectiveProjectName(Project project) {
    final name = project.name;
    if (name != null && name.isNotEmpty) return name;
    if (project.worktree.isEmpty) return null;
    final normalized = project.worktree.replaceAll(r"\", "/");
    final segments = normalized.split("/").where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : segments.last;
  }
}
