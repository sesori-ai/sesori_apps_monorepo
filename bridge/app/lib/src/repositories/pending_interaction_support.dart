import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show PendingExternalAction, PendingForm, PendingPermission, PendingQuestion;

import "../api/database/daos/session_dao.dart";
import "../api/database/tables/session_table.dart";
import "mappers/plugin_external_action_mapper.dart";
import "mappers/plugin_form_mapper.dart";
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

  Future<Set<String>?> readPendingTombstones({
    required BridgePluginApi plugin,
    required String backendSessionId,
  }) async {
    if (plugin is! BridgeDerivedProjectsPluginApi) return const <String>{};
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
        if (bindings[question.sessionID] case final session? when session.archivedAt == null)
          if (_displayBinding(bindings: bindings, displaySessionId: question.displaySessionId) case final display?)
            question.toSharedPendingQuestion(sessionId: session.sessionId, displaySessionId: display.sessionId),
    ];
  }

  Future<List<PendingExternalAction>> mapExternalActions({
    required String pluginId,
    required List<PluginPendingExternalAction> actions,
  }) async {
    final bindings = await _bindings(
      pluginId: pluginId,
      interactions: [
        for (final action in actions) (sessionID: action.sessionID, displaySessionId: action.displaySessionId),
      ],
    );
    return [
      for (final action in actions)
        if (bindings[action.sessionID] case final session? when session.archivedAt == null)
          if (_displayBinding(bindings: bindings, displaySessionId: action.displaySessionId) case final display?)
            action.toShared(sessionId: session.sessionId, displaySessionId: display.sessionId),
    ];
  }

  Future<List<PendingForm>> mapForms({required String pluginId, required List<PluginPendingForm> forms}) async {
    final bindings = await _bindings(
      pluginId: pluginId,
      interactions: [
        for (final form in forms) (sessionID: form.sessionID, displaySessionId: form.displaySessionId),
      ],
    );
    return [
      for (final form in forms)
        if (bindings[form.sessionID] case final session? when session.archivedAt == null)
          if (_displayBinding(bindings: bindings, displaySessionId: form.displaySessionId) case final display?)
            form.toShared(sessionId: session.sessionId, displaySessionId: display.sessionId),
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
        if (bindings[permission.sessionID] case final session? when session.archivedAt == null)
          if (_displayBinding(bindings: bindings, displaySessionId: permission.displaySessionId) case final display?)
            permission.toSharedPendingPermission(sessionId: session.sessionId, displaySessionId: display.sessionId),
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

  /// Resolves an interaction's optional display session to its bound session
  /// ID. Returns `null` when the display session has no binding, so the caller
  /// drops the interaction; an absent display session resolves to no ID.
  ({String? sessionId})? _displayBinding({
    required Map<String, SessionDto> bindings,
    required String? displaySessionId,
  }) {
    if (displaySessionId == null) return (sessionId: null);
    final session = bindings[displaySessionId];
    if (session == null) return null;
    return (sessionId: session.sessionId);
  }
}
