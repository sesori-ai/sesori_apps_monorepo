import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_command_identity_builder.dart";

enum AcpCommandInvocationPhase { pending, active }

class AcpCommandInvocationSnapshot {
  AcpCommandInvocationSnapshot({
    required this.invocationId,
    required this.sessionId,
    required this.name,
    required this.arguments,
    required this.turnId,
    required this.commandMessageId,
    required this.resultPartId,
    required this.phase,
    required this.resultPartCreated,
    required this.resultText,
    required Set<String> assistantMessageIds,
    required Map<String, PluginMessagePartType> assistantPartTypes,
  }) : assistantMessageIds = Set.unmodifiable(assistantMessageIds),
       assistantPartTypes = Map.unmodifiable(assistantPartTypes);

  final String invocationId;
  final String sessionId;
  final String name;
  final String? arguments;
  final String turnId;
  final String commandMessageId;
  final String resultPartId;
  final AcpCommandInvocationPhase phase;
  final bool resultPartCreated;
  final String resultText;
  final Set<String> assistantMessageIds;
  final Map<String, PluginMessagePartType> assistantPartTypes;

  AcpCommandInvocationSnapshot copyWith({
    AcpCommandInvocationPhase? phase,
    bool? resultPartCreated,
    String? resultText,
    Set<String>? assistantMessageIds,
    Map<String, PluginMessagePartType>? assistantPartTypes,
  }) => AcpCommandInvocationSnapshot(
    invocationId: invocationId,
    sessionId: sessionId,
    name: name,
    arguments: arguments,
    turnId: turnId,
    commandMessageId: commandMessageId,
    resultPartId: resultPartId,
    phase: phase ?? this.phase,
    resultPartCreated: resultPartCreated ?? this.resultPartCreated,
    resultText: resultText ?? this.resultText,
    assistantMessageIds: assistantMessageIds ?? this.assistantMessageIds,
    assistantPartTypes: assistantPartTypes ?? this.assistantPartTypes,
  );
}

class AcpCommandTurnRegistration {
  const AcpCommandTurnRegistration({
    required this.turnId,
    required this.accepted,
  });

  final String turnId;
  final Future<PluginCommandDispatch> accepted;
}

/// Owns the complete state invariant for queued and active ACP command turns.
class AcpCommandTurnTracker {
  final Map<String, _AcpCommandTurnState> _states = {};
  final Map<String, String> _turnIdByInvocation = {};
  final Map<String, String> _activeTurnBySession = {};
  int _nextTurn = 0;

  AcpCommandTurnRegistration register({
    required String sessionId,
    required String invocationId,
    required String name,
    required String arguments,
  }) {
    if (_turnIdByInvocation.containsKey(invocationId)) {
      throw StateError(
        "ACP command invocation is already registered: $invocationId",
      );
    }
    final normalizedName = name.startsWith("/") ? name.substring(1) : name;
    final turnId = "$sessionId-command-turn-${++_nextTurn}";
    final commandMessageId = AcpCommandIdentityBuilder.messageId(
      sessionId: sessionId,
      invocationId: invocationId,
    );
    final invocation = AcpCommandInvocationSnapshot(
      invocationId: invocationId,
      sessionId: sessionId,
      name: normalizedName,
      arguments: arguments.isEmpty ? null : arguments,
      turnId: turnId,
      commandMessageId: commandMessageId,
      resultPartId: AcpCommandIdentityBuilder.resultPartId(
        commandMessageId: commandMessageId,
      ),
      phase: AcpCommandInvocationPhase.pending,
      resultPartCreated: false,
      resultText: "",
      assistantMessageIds: const {},
      assistantPartTypes: const {},
    );
    final acceptance = Completer<PluginCommandDispatch>();
    _states[turnId] = _AcpCommandTurnState(
      invocation: invocation,
      acceptance: acceptance,
    );
    _turnIdByInvocation[invocationId] = turnId;
    return AcpCommandTurnRegistration(
      turnId: turnId,
      accepted: acceptance.future,
    );
  }

  AcpCommandInvocationSnapshot activate(String turnId) {
    final state = _require(turnId);
    final invocation = state.invocation;
    final activeTurn = _activeTurnBySession[invocation.sessionId];
    if (activeTurn != null && activeTurn != turnId) {
      throw StateError(
        "ACP session ${invocation.sessionId} already has an active command turn",
      );
    }
    final active = invocation.copyWith(phase: AcpCommandInvocationPhase.active);
    state.invocation = active;
    _activeTurnBySession[invocation.sessionId] = turnId;
    return active;
  }

  AcpCommandInvocationSnapshot? byTurnId(String turnId) => _states[turnId]?.invocation;

  AcpCommandInvocationSnapshot? activeForSession(String sessionId) {
    final turnId = _activeTurnBySession[sessionId];
    return turnId == null ? null : _states[turnId]?.invocation;
  }

  List<AcpCommandInvocationSnapshot> pendingForSession(String sessionId) => List.unmodifiable(
    _states.values
        .map((state) => state.invocation)
        .where(
          (invocation) => invocation.sessionId == sessionId && invocation.phase == AcpCommandInvocationPhase.pending,
        ),
  );

  AcpCommandInvocationSnapshot recordAssistantMessage({
    required String turnId,
    required String messageId,
  }) {
    final state = _require(turnId);
    final updated = state.invocation.copyWith(
      assistantMessageIds: {
        ...state.invocation.assistantMessageIds,
        messageId,
      },
    );
    state.invocation = updated;
    return updated;
  }

  AcpCommandInvocationSnapshot recordAssistantPart({
    required String turnId,
    required String partId,
    required PluginMessagePartType type,
  }) {
    final state = _require(turnId);
    final updated = state.invocation.copyWith(
      assistantPartTypes: {
        ...state.invocation.assistantPartTypes,
        partId: type,
      },
    );
    state.invocation = updated;
    return updated;
  }

  AcpCommandInvocationSnapshot appendResultText({
    required String turnId,
    required String text,
  }) {
    final state = _require(turnId);
    final updated = state.invocation.copyWith(
      resultPartCreated: true,
      resultText: "${state.invocation.resultText}$text",
    );
    state.invocation = updated;
    return updated;
  }

  AcpCommandInvocationSnapshot clearResult({required String turnId}) {
    final state = _require(turnId);
    final updated = state.invocation.copyWith(
      resultPartCreated: false,
      resultText: "",
    );
    state.invocation = updated;
    return updated;
  }

  bool isAccepted(String turnId) => _states[turnId]?.accepted ?? false;

  bool containsState({required String turnId, required Object state}) => identical(_states[turnId], state);

  Object requireState(String turnId) => _require(turnId);

  void stage({
    required String turnId,
    required Iterable<BridgeSseEvent> events,
  }) {
    _require(turnId).stagedEvents.addAll(events);
  }

  List<BridgeSseEvent> accept(String turnId) {
    final state = _require(turnId);
    state.accepted = true;
    if (!state.acceptance.isCompleted) {
      state.acceptance.complete(
        const PluginCommandDispatch(backendMessageId: null),
      );
    }
    final staged = List<BridgeSseEvent>.of(state.stagedEvents);
    state.stagedEvents.clear();
    return staged;
  }

  void reject({
    required String turnId,
    required Object error,
    required StackTrace stackTrace,
  }) {
    final state = _states[turnId];
    if (state == null) return;
    _remove(turnId);
    if (!state.accepted && !state.acceptance.isCompleted) {
      state.acceptance.completeError(error, stackTrace);
    }
  }

  void complete(String turnId) => _remove(turnId);

  List<String> turnIdsForSession({
    required String sessionId,
    required bool onlyUnaccepted,
  }) => _states.values
      .where(
        (state) => state.invocation.sessionId == sessionId && (!onlyUnaccepted || !state.accepted),
      )
      .map((state) => state.invocation.turnId)
      .toList(growable: false);

  List<String> get turnIds => _states.keys.toList(growable: false);

  void forgetSession(String sessionId) {
    final turnIds = _states.values
        .where((state) => state.invocation.sessionId == sessionId)
        .map((state) => state.invocation.turnId)
        .toList(growable: false);
    turnIds.forEach(_remove);
  }

  _AcpCommandTurnState _require(String turnId) {
    final state = _states[turnId];
    if (state == null) throw StateError("Unknown ACP command turn: $turnId");
    return state;
  }

  void _remove(String turnId) {
    final state = _states.remove(turnId);
    if (state == null) return;
    final invocation = state.invocation;
    _turnIdByInvocation.remove(invocation.invocationId);
    if (_activeTurnBySession[invocation.sessionId] == turnId) {
      _activeTurnBySession.remove(invocation.sessionId);
    }
  }
}

class _AcpCommandTurnState {
  _AcpCommandTurnState({
    required this.invocation,
    required this.acceptance,
  });

  AcpCommandInvocationSnapshot invocation;
  final Completer<PluginCommandDispatch> acceptance;
  final List<BridgeSseEvent> stagedEvents = [];
  bool accepted = false;
}
