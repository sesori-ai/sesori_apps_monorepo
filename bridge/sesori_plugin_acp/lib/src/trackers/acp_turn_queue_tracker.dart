import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

class AcpSessionTurnState {
  Future<void> tail = Future<void>.value();
  int pending = 0;
  int generation = 0;
}

class AcpTurnQueueTracker {
  AcpTurnQueueTracker({required this.pluginId});

  final String pluginId;
  final Map<String, AcpSessionTurnState> _states = {};
  final Map<String, PluginSessionStatus> _statuses = {};
  final List<String> _inFlightSessions = [];
  String? _lastTurnSessionId;

  Map<String, PluginSessionStatus> get statuses => Map.unmodifiable(_statuses);

  Iterable<AcpSessionTurnState> get states => _states.values;

  AcpSessionTurnState stateForEnqueue(String sessionId) => _states.putIfAbsent(
    sessionId,
    AcpSessionTurnState.new,
  );

  bool ownsState({required String sessionId, required AcpSessionTurnState state}) =>
      identical(_states[sessionId], state);

  int pendingTurnCount(String sessionId) => _states[sessionId]?.pending ?? 0;

  bool isRunning(String sessionId) => pendingTurnCount(sessionId) > 0;

  void setStatus({required String sessionId, required PluginSessionStatus status}) {
    _statuses[sessionId] = status;
  }

  void beginInFlight(String sessionId) {
    _inFlightSessions.add(sessionId);
    _lastTurnSessionId = sessionId;
  }

  void endInFlight(String sessionId) => _inFlightSessions.remove(sessionId);

  String? resolveActiveSession() {
    if (_inFlightSessions.length == 1) return _inFlightSessions.single;
    if (_inFlightSessions.isNotEmpty) {
      Log.w(
        "[$pluginId] ${_inFlightSessions.length} turns in flight; "
        "attributing sessionId-less server request to the most recent dispatch",
      );
      return _inFlightSessions.last;
    }
    return _lastTurnSessionId;
  }

  void abortSession(String sessionId) => _states[sessionId]?.generation++;

  void forgetSession(String sessionId) {
    _states.remove(sessionId);
    _inFlightSessions.remove(sessionId);
    if (_lastTurnSessionId == sessionId) _lastTurnSessionId = null;
    _statuses.remove(sessionId);
  }
}
