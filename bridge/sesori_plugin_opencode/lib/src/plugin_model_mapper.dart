import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "message_part_mapper.dart";
import "models/openapi/agent.g.dart";
import "models/openapi/assistant_message.g.dart";
import "models/openapi/message.g.dart";
import "models/openapi/project.g.dart";
import "models/openapi/question_request.g.dart";
import "models/openapi/session.g.dart";
import "models/openapi/session_messages_response_item.g.dart";
import "models/openapi/session_status.g.dart";
import "models/openapi/user_message.g.dart";

class PluginModelMapper {
  const PluginModelMapper({required MessagePartMapper messagePartMapper}) : _messagePartMapper = messagePartMapper;

  final MessagePartMapper _messagePartMapper;

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
        "all" => PluginAgentMode.all,
        "primary" => PluginAgentMode.primary,
        "subagent" => PluginAgentMode.subagent,
        _ => PluginAgentMode.unknown,
      },
      hidden: agent.hidden ?? false,
    );
  }

  PluginPendingQuestion mapQuestion(QuestionRequest question) {
    return PluginPendingQuestion(
      id: question.id,
      sessionID: question.sessionID,
      questions: question.questions
          .map(
            (info) => PluginQuestionInfo(
              question: info.question,
              header: info.header,
              options: info.options
                  .map((option) => PluginQuestionOption(label: option.label, description: option.description))
                  .toList(),
              multiple: info.multiple ?? false,
              custom: info.custom ?? false,
            ),
          )
          .toList(),
    );
  }

  PluginMessageWithParts mapMessageWithParts(SessionMessagesResponseItem raw) {
    final info = raw.info;
    final pluginInfo = switch (info) {
      UserMessage(:final id, :final sessionID, :final agent) => PluginMessage.user(
        id: id,
        sessionID: sessionID,
        agent: agent,
      ),
      AssistantMessage(:final id, :final sessionID, :final agent, :final modelID, :final providerID, :final error) =>
        _mapAssistantMessage(
          id: id,
          sessionID: sessionID,
          agent: agent,
          modelID: modelID,
          providerID: providerID,
          error: error,
        ),
      MessageUnknown(:final raw) => throw ArgumentError("Unknown message role: $raw"),
      _ => throw ArgumentError("Unknown message role: $info"),
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
  }) {
    final errorMap = error is Map<String, dynamic> ? error : null;
    if (errorMap == null) {
      return PluginMessage.assistant(
        id: id,
        sessionID: sessionID,
        agent: agent,
        modelID: modelID,
        providerID: providerID,
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
    );
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
