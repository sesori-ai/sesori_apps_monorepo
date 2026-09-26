import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../models/openapi/form_info.g.dart";
import "../models/openapi/permission_request.g.dart";
import "../models/v2_event.g.dart";
import "../sse/v2_event_mapper.dart";

/// Observed native activity only. I/O, projection and refresh belong to callers.
class OpenCodeV2ActivityTracker() {
  final Map<String, shared.Session> _sessions = {};
  final Map<String, PluginSessionStatus> _active = {};
  final Map<String, PermissionRequest> _permissions = {};
  final Map<String, FormInfo> _forms = {};
  bool _baselineTrusted = false;

  shared.Session? session({required String sessionId}) => _sessions[sessionId];
  PluginSessionStatus? status({required String sessionId}) => _active[sessionId];
  Iterable<PermissionRequest> get permissions => _permissions.values;
  Iterable<FormInfo> get forms => _forms.values;

  Set<String> get workingSessionIds => {
    ..._active.keys,
    for (final permission in permissions) permission.sessionID,
    for (final form in forms) form.sessionID,
  };

  PluginWorkState get workState {
    if (!_baselineTrusted) return PluginWorkState.unknown;
    return workingSessionIds.isEmpty ? PluginWorkState.idle : PluginWorkState.busy;
  }

  bool hasPendingInput({required String sessionId}) =>
      permissions.any((request) => request.sessionID == sessionId) || forms.any((form) => form.sessionID == sessionId);

  String? rootSessionId({required String sessionId}) {
    var current = _sessions[sessionId];
    while (current != null) {
      final parent = current.parentID;
      if (parent == null) return current.id;
      current = _sessions[parent];
    }
    return null;
  }

  bool rememberSession({required shared.Session session}) {
    final previous = _sessions[session.id];
    _sessions[session.id] = session;
    return previous != session;
  }

  void invalidateBaseline() => _baselineTrusted = false;

  void removeForm({required String formId}) => _forms.remove(formId);
  void removePermission({required String requestId}) => _permissions.remove(requestId);

  void seed({
    required List<shared.Session> sessions,
    required Set<String> activeSessionIds,
    required List<PermissionRequest> permissions,
    required List<FormInfo> forms,
  }) {
    _sessions
      ..clear()
      ..addEntries(sessions.map((session) => MapEntry(session.id, session)));
    _active
      ..clear()
      ..addEntries(activeSessionIds.map((id) => MapEntry(id, const PluginSessionStatus.busy())));
    _permissions
      ..clear()
      ..addEntries(permissions.map((request) => MapEntry(request.id, request)));
    _forms
      ..clear()
      ..addEntries(forms.map((form) => MapEntry(form.id, form)));
    _baselineTrusted = true;
  }

  bool apply({required V2EventData event}) {
    if (V2EventMapper.status(event: event) case final projected?) {
      if (projected.status is PluginSessionStatusIdle) return _active.remove(projected.sessionId) != null;
      final previous = _active[projected.sessionId];
      _active[projected.sessionId] = projected.status;
      return previous != projected.status;
    }
    switch (event) {
      case V2SessionRenamed():
        final previous = _sessions[event.sessionID];
        return previous != null && rememberSession(session: previous.copyWith(title: event.title));
      case V2SessionDeleted():
        _sessions.remove(event.sessionID);
        _active.remove(event.sessionID);
        _permissions.removeWhere((_, request) => request.sessionID == event.sessionID);
        _forms.removeWhere((_, form) => form.sessionID == event.sessionID);
        return true;
      case V2PermissionAsked():
        final request = PermissionRequest(
          id: event.id,
          sessionID: event.sessionID,
          action: event.action,
          resources: event.resources,
          save: event.save,
          metadata: event.metadata,
          source: event.source,
          message: event.message,
        );
        final previous = _permissions[request.id];
        _permissions[request.id] = request;
        return previous != request;
      case V2PermissionReplied():
        return _permissions.remove(event.requestID) != null;
      case V2FormCreated():
        final previous = _forms[event.form.id];
        _forms[event.form.id] = event.form;
        return previous != event.form;
      case V2FormReplied(:final id) || V2FormCancelled(:final id):
        return _forms.remove(id) != null;
      default:
        return false;
    }
  }

  void reset() {
    _sessions.clear();
    _active.clear();
    _permissions.clear();
    _forms.clear();
    _baselineTrusted = false;
  }
}
