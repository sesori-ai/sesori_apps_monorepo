import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "api/models/grok_session_notification_dto.dart";
import "repositories/mappers/grok_subagent_status_mapping.dart";

/// Grok Build's ACP mapper: the base session/update handling plus the Grok
/// extension sub-agent lifecycle, pushed into the shared child-session tracker.
class GrokEventMapper({
  required super.launchDirectory,
  required super.pluginId,
  required super.configurationTracker,
  required super.childSessions,
}) extends AcpEventMapper {
  /// Grok extension lifecycle methods. Live sub-agent updates use the
  /// notification form; replay and autonomous settlement can use the update
  /// form with the same `params` shape.
  static const String sessionNotificationMethod = "_x.ai/session_notification";
  static const String sessionUpdateMethod = "_x.ai/session/update";

  /// The tool whose call launches a sub-agent, as named in `_meta["x.ai/tool"]`.
  static const String spawnSubagentToolName = "spawn_subagent";

  /// The agent Grok runs when a spawn names none.
  static const String defaultSubagentType = "general-purpose";

  /// Prefix used by Grok for the prompt-less root turn that reports a
  /// completed background child.
  static const String autonomousTurnPromptPrefix = "subagent-completed-";

  /// The `spawn_subagent` call and the `subagent_spawned` notification share
  /// no id, so the call renders nothing and the notification owns the tile.
  @override
  bool isSubagentSpawnToolCall({required Map<String, dynamic> update}) {
    final rawMeta = update["_meta"];
    if (rawMeta is! Map) return false;
    try {
      return GrokToolCallMetaDto.fromJson(rawMeta.cast<String, dynamic>()).tool?.name == spawnSubagentToolName;
    } on Object catch (error, stackTrace) {
      Log.w("[grok] tool call metadata could not be parsed; rendering a tool card", error, stackTrace);
      return false;
    }
  }

  @override
  List<BridgeSseEvent> mapExtension(AcpNotification notification) {
    if (notification.method != sessionNotificationMethod && notification.method != sessionUpdateMethod) {
      return super.mapExtension(notification);
    }
    final GrokSessionNotificationDto dto;
    try {
      dto = GrokSessionNotificationDto.fromJson(notification.params);
    } on Object catch (error, stackTrace) {
      Log.w("[grok] ignored malformed session notification", error, stackTrace);
      return const [];
    }
    return switch (dto.update) {
      GrokSubagentSpawned(:final childSessionId, :final subagentType, :final description, :final model) => _spawned(
        sessionId: dto.sessionId,
        childSessionId: childSessionId,
        model: model,
        spawn: AcpChildSpawn(
          childSessionId: childSessionId,
          description: description,
          agent: subagentType ?? defaultSubagentType,
          // The notification carries no prompt: the child's own first user
          // message supplies it. It carries no launch mode either, and a root
          // `session/cancel` stops background children too, so every child is
          // honestly a foreground one for the stop policy.
          prompt: null,
          isBackground: false,
        ),
      ),
      GrokSubagentFinished(
        :final childSessionId,
        :final status,
        :final output,
        :final error,
        willWake: true,
      ) =>
        mapChildFinishedAndHoldRoot(
          childSessionId: childSessionId,
          holdId: childSessionId,
          status: status.toPluginToolStatus(),
          output: output,
          error: error,
        ),
      GrokSubagentFinished(:final childSessionId, :final status, :final output, :final error) => mapChildFinished(
        childSessionId: childSessionId,
        status: status.toPluginToolStatus(),
        output: output,
        error: error,
      ),
      GrokTurnCompleted(:final promptId) => _releaseAutonomousRootTurn(
        rootSessionId: dto.sessionId,
        promptId: promptId,
      ),
      // One child is one tile; progress never redraws it.
      GrokSubagentProgress() || GrokSubagentUpdateUnknown() => const [],
    };
  }

  List<BridgeSseEvent> _releaseAutonomousRootTurn({
    required String rootSessionId,
    required String? promptId,
  }) {
    if (promptId == null || !promptId.startsWith(autonomousTurnPromptPrefix)) return const [];
    final holdId = promptId.substring(autonomousTurnPromptPrefix.length);
    if (holdId.isEmpty) return const [];
    childSessions.releaseRootHold(rootSessionId: rootSessionId, holdId: holdId);
    return const [];
  }

  List<BridgeSseEvent> _spawned({
    required String sessionId,
    required String childSessionId,
    required String? model,
    required AcpChildSpawn spawn,
  }) {
    final events = mapChildSpawned(sessionId: sessionId, spawn: spawn);
    // Only a child that was actually announced gets the reported model, so a
    // rejected spawn leaves no stray override behind.
    if (events.isNotEmpty) setChildModel(childSessionId: childSessionId, modelId: model);
    return events;
  }
}
