import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show PendingPermission, PendingQuestion;

import "../api/database/daos/session_dao.dart";
import "../api/database/tables/session_table.dart";
import "mappers/plugin_permission_mapper.dart";
import "mappers/plugin_question_mapper.dart";
import "models/session_operation.dart";

class PendingInteractionSupport({required final SessionDao _sessionDao}) {
  Future<SessionDto> requireBinding({
    required String sessionId,
    required SessionOperation operation,
  }) async {
    final binding = await _sessionDao.getSession(sessionId: sessionId);
    if (binding == null) {
      throw PluginOperationException.notFound(
        operation.name,
        message: "session $sessionId was not found",
      );
    }
    return binding;
  }

  Future<Set<String>?> tombstonesFor({
    required BridgePluginApi plugin,
    required String backendSessionId,
  }) async {
    if (plugin is! BridgeDerivedProjectsPluginApi) return null;
    final tombstones = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
    return tombstones.contains(backendSessionId) ? null : tombstones;
  }

  bool isVisible({
    required String sessionId,
    required String? displaySessionId,
    required Set<String> tombstones,
  }) => !tombstones.contains(sessionId) && (displaySessionId == null || !tombstones.contains(displaySessionId));

  Future<void> throwIfMutationTargetTombstoned({
    required String interactionId,
    required String backendSessionId,
    required SessionOperation operation,
    required BridgePluginApi plugin,
    required Future<List<({String id, String sessionID, String? displaySessionId})>> Function() readPending,
  }) async {
    if (plugin is! BridgeDerivedProjectsPluginApi) return;
    final tombstones = await _sessionDao.getTombstonedSessionIds(pluginId: plugin.id);
    if (tombstones.contains(backendSessionId)) {
      throw PluginOperationException.notFound(operation.name, message: "session $backendSessionId was deleted");
    }
    for (final pending in await readPending()) {
      if (pending.id != interactionId) continue;
      if (tombstones.contains(pending.sessionID)) {
        throw PluginOperationException.notFound(operation.name, message: "session ${pending.sessionID} was deleted");
      }
      if (pending.displaySessionId case final displaySessionId? when tombstones.contains(displaySessionId)) {
        throw PluginOperationException.notFound(
          operation.name,
          message: "display session $displaySessionId was deleted",
        );
      }
      break;
    }
  }

  Future<List<PendingQuestion>> mapQuestions({
    required String pluginId,
    required List<PluginPendingQuestion> questions,
  }) async {
    final bindings = await _bindings(
      pluginId: pluginId,
      interactions: [
        for (final question in questions) (sessionID: question.sessionID, displaySessionId: question.displaySessionId),
      ],
    );
    return [
      for (final question in questions)
        if (bindings[question.sessionID] case final session?)
          if (question.displaySessionId == null || bindings.containsKey(question.displaySessionId))
            question.toSharedPendingQuestion(
              sessionId: session.sessionId,
              displaySessionId: question.displaySessionId == null
                  ? null
                  : bindings[question.displaySessionId]!.sessionId,
            ),
    ];
  }

  Future<List<PendingPermission>> mapPermissions({
    required String pluginId,
    required List<PluginPendingPermission> permissions,
  }) async {
    final bindings = await _bindings(
      pluginId: pluginId,
      interactions: [
        for (final permission in permissions)
          (sessionID: permission.sessionID, displaySessionId: permission.displaySessionId),
      ],
    );
    return [
      for (final permission in permissions)
        if (bindings[permission.sessionID] case final session?)
          if (permission.displaySessionId == null || bindings.containsKey(permission.displaySessionId))
            permission.toSharedPendingPermission(
              sessionId: session.sessionId,
              displaySessionId: permission.displaySessionId == null
                  ? null
                  : bindings[permission.displaySessionId]!.sessionId,
            ),
    ];
  }

  Future<Map<String, SessionDto>> _bindings({
    required String pluginId,
    required Iterable<({String sessionID, String? displaySessionId})> interactions,
  }) {
    final backendSessionIds = <String>{
      for (final interaction in interactions) ...{
        interaction.sessionID,
        ?interaction.displaySessionId,
      },
    };
    return _sessionDao.getSessionsByBackendIds(
      pluginId: pluginId,
      backendSessionIds: backendSessionIds.toList(growable: false),
    );
  }
}
