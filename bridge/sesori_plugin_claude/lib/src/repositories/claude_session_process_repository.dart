import "dart:async";
import "dart:collection";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/claude_launch_spec.dart";
import "../api/claude_process_factory.dart";
import "../api/claude_stream_client.dart";
import "../api/models/claude_stream_message.dart";
import "../models/claude_effort_level.dart";
import "../models/claude_permission_mode.dart";

sealed class const ClaudeTurnOutcome();

final class const ClaudeTurnCompleted() extends ClaudeTurnOutcome;

final class const ClaudeTurnFailed() extends ClaudeTurnOutcome;

final class const ClaudeTurnInterrupted() extends ClaudeTurnOutcome;

final class const ClaudeTurnDispatch({
  required final bool accepted,
  required final Future<ClaudeTurnOutcome> outcome,
});

sealed class const ClaudeSessionProcessEvent({required final String sessionId});

final class const ClaudeSessionProcessMessage({
  required super.sessionId,
  required final ClaudeStreamMessage message,
  required final bool interrupted,
  required final String? promptId,
}) extends ClaudeSessionProcessEvent {
  ClaudeControlRequestMessage? get controlRequest => switch (message) {
    final ClaudeControlRequestMessage request => request,
    _ => null,
  };
}

final class const ClaudeSessionProcessExited({required super.sessionId, required final bool interrupted})
    extends ClaudeSessionProcessEvent;

final class const ClaudeAppliedSelection({
  required final String? model,
  required final ClaudeEffortLevel? effort,
  required final ClaudePermissionMode? permissionMode,
});

final class _PendingTurn({
  required final String? promptId,
  required final List<Map<String, Object?>>? replayContent,
  required bool started,
}) {
  final Completer<ClaudeTurnOutcome> outcome = Completer<ClaudeTurnOutcome>();
  bool started = started;
  bool replayObserved = replayContent == null;
  bool settled = false;
}

final class _ResidentProcess({
  required final ClaudeStreamClient client,
  required final bool resumed,
  required var String? appliedModel,
  required var ClaudeEffortLevel? appliedEffort,
  required var ClaudePermissionMode? appliedPermissionMode,
}) {
  late final StreamSubscription<ClaudeStreamMessage> messages;
  final Queue<_PendingTurn> pendingTurns = Queue<_PendingTurn>();
  bool interrupted = false;
  bool turnActive = false;

  Future<void> cancelMessages() => messages.cancel();
}

/// Owns resident Claude processes and all transport-facing session state.
final class ClaudeSessionProcessRepository({
  required final ClaudeProcessFactory _processFactory,
  required final String _binaryPath,
  required Map<String, String> environment,
}) {
  final Map<String, String> _environment = Map.unmodifiable(environment);
  final Map<String, _ResidentProcess> _resident = {};
  final Map<String, Future<void>> _connecting = {};
  final Map<String, ClaudeStreamClient> _connectingClients = {};
  final Map<String, int> _sessionGenerations = {};
  final Set<String> _startedSessions = {};
  final StreamController<ClaudeSessionProcessEvent> _events = StreamController.broadcast();
  bool _disposed = false;

  Stream<ClaudeSessionProcessEvent> get events => _events.stream;

  bool isResident({required String sessionId}) => _resident.containsKey(sessionId);

  Map<String, Object?>? handshake({required String sessionId}) => _resident[sessionId]?.client.handshake;

  ClaudeAppliedSelection? appliedSelection({required String sessionId}) {
    final process = _resident[sessionId];
    if (process == null) return null;
    return ClaudeAppliedSelection(
      model: process.appliedModel,
      effort: process.appliedEffort,
      permissionMode: process.appliedPermissionMode,
    );
  }

  void recordAppliedSelection({
    required String sessionId,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
  }) {
    final process = _resident[sessionId];
    if (process == null) return;
    process
      ..appliedModel = model
      ..appliedEffort = effort
      ..appliedPermissionMode = permissionMode;
  }

  Future<void> ensureResident({
    required String sessionId,
    required String directory,
    required bool createNew,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
    required List<String> allowedTools,
  }) async {
    if (_disposed) throw StateError("Claude process repository is disposed");
    final resident = _resident[sessionId];
    if (resident != null) {
      if (resident.appliedEffort != effort) {
        await teardown(sessionId: sessionId);
      } else {
        await _applySelection(
          process: resident,
          model: model,
          permissionMode: permissionMode,
        );
        return;
      }
    }
    final existing = _connecting[sessionId];
    if (existing != null) {
      await existing;
      return;
    }

    final generation = _sessionGenerations[sessionId] ?? 0;
    final connection = _connect(
      sessionId: sessionId,
      directory: directory,
      createNew: createNew,
      model: model,
      effort: effort,
      permissionMode: permissionMode,
      allowedTools: allowedTools,
      generation: generation,
    );
    _connecting[sessionId] = connection;
    try {
      await connection;
    } finally {
      if (identical(_connecting[sessionId], connection)) unawaited(_connecting.remove(sessionId));
    }
  }

  Future<void> _applySelection({
    required _ResidentProcess process,
    required String? model,
    required ClaudePermissionMode? permissionMode,
  }) async {
    if (process.appliedModel != model) {
      await process.client.sendControlRequest(
        subtype: "set_model",
        params: {"model": model},
      );
      process.appliedModel = model;
    }
    if (process.appliedPermissionMode != permissionMode) {
      await process.client.sendControlRequest(
        subtype: "set_permission_mode",
        params: {"mode": permissionMode?.controlValue ?? ClaudePermissionMode.auto.controlValue},
      );
      process.appliedPermissionMode = permissionMode;
    }
  }

  ClaudeTurnDispatch sendTurn({
    required String sessionId,
    required List<PluginPromptPart> parts,
    required String? promptId,
  }) {
    final process = _resident[sessionId];
    if (process == null) throw StateError("Claude session is not resident: $sessionId");
    final content = _promptContent(parts);
    if (content.isEmpty) {
      Log.w("[claude] turn contains no supported prompt parts");
      return ClaudeTurnDispatch(
        accepted: false,
        outcome: Future.value(const ClaudeTurnFailed()),
      );
    }

    process.interrupted = false;
    // A resident process can absorb several stdin messages into one agent turn.
    // Replayed user frames mark which queued messages joined that turn, and its
    // result settles exactly that started prefix.
    final pending = _PendingTurn(
      promptId: promptId,
      replayContent: promptId == null ? null : content,
      started: !process.turnActive && process.pendingTurns.every((pending) => pending.settled),
    );
    process.pendingTurns.addLast(pending);
    if (pending.started) process.turnActive = true;
    try {
      process.client.sendUserMessage(content: content);
    } on Object {
      process.pendingTurns.remove(pending);
      rethrow;
    }
    _startedSessions.add(sessionId);
    return ClaudeTurnDispatch(
      accepted: true,
      outcome: pending.outcome.future,
    );
  }

  Future<Map<String, Object?>> sendControlRequest({
    required String sessionId,
    required String subtype,
    required Map<String, Object?> params,
  }) {
    final process = _resident[sessionId];
    if (process == null) throw StateError("Claude session is not resident: $sessionId");
    return process.client.sendControlRequest(subtype: subtype, params: params);
  }

  bool answerControlRequest({
    required String sessionId,
    required String requestId,
    required Map<String, Object?> payload,
  }) => _resident[sessionId]?.client.sendControlResponse(requestId: requestId, payload: payload) ?? false;

  Future<void> interrupt({required String sessionId}) async {
    final process = _resident[sessionId];
    if (process == null) return;
    process.interrupted = true;
    await process.client.sendControlRequest(subtype: "interrupt", params: const {"cancel_queued": true});
  }

  Future<void> teardown({required String sessionId}) async {
    _sessionGenerations[sessionId] = (_sessionGenerations[sessionId] ?? 0) + 1;
    final connection = _connecting[sessionId];
    final connectingClient = _connectingClients[sessionId];
    final process = _resident.remove(sessionId);
    if (process != null) {
      _settlePendingTurns(
        process: process,
        outcome: process.interrupted ? const ClaudeTurnInterrupted() : const ClaudeTurnFailed(),
      );
      try {
        await process.cancelMessages();
      } on Object catch (error, stack) {
        Log.w("[claude] failed to cancel process message subscription", error, stack);
      } finally {
        await process.client.dispose();
      }
    }
    if (connectingClient != null) await connectingClient.dispose();
    if (connection != null) {
      try {
        await connection;
      } on Object {
        // This teardown invalidated the connection generation. The connecting
        // caller receives the cancellation; teardown only waits for child reap.
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final sessionIds = {..._resident.keys, ..._connecting.keys}.toList(growable: false);
    for (final sessionId in sessionIds) {
      await teardown(sessionId: sessionId);
    }
    await _events.close();
  }

  void forgetSession({required String sessionId}) {
    _startedSessions.remove(sessionId);
  }

  Future<void> _connect({
    required String sessionId,
    required String directory,
    required bool createNew,
    required String? model,
    required ClaudeEffortLevel? effort,
    required ClaudePermissionMode? permissionMode,
    required List<String> allowedTools,
    required int generation,
  }) async {
    final launch = createNew && !_startedSessions.contains(sessionId)
        ? ClaudeNewSession(sessionId: sessionId)
        : ClaudeResumedSession(sessionId: sessionId);
    final client = ClaudeStreamClient(
      launchSpec: ClaudeLaunchSpec(
        binaryPath: _binaryPath,
        workingDirectory: directory,
        launch: launch,
        model: model,
        effort: effort,
        permissionMode: permissionMode,
        allowedTools: allowedTools,
        environment: _environment,
      ),
      processFactory: _processFactory,
    );
    _connectingClients[sessionId] = client;
    try {
      await client.connect();
    } finally {
      if (identical(_connectingClients[sessionId], client)) {
        _connectingClients.remove(sessionId);
      }
    }
    if (_disposed || (_sessionGenerations[sessionId] ?? 0) != generation) {
      await client.dispose();
      throw StateError("Claude session residency was cancelled");
    }

    final process = _ResidentProcess(
      client: client,
      resumed: launch is ClaudeResumedSession,
      appliedModel: model,
      appliedEffort: effort,
      appliedPermissionMode: permissionMode,
    );
    process.messages = client.messages.listen((message) {
      final current = _resident[sessionId];
      if ((current?.resumed ?? false) && current?.appliedModel == null && message is ClaudeAssistantMessage) {
        current?.appliedModel = message.model;
      }
      final promptId = _trackTurnMessage(process: process, message: message);
      if (!_events.isClosed) {
        _events.add(
          ClaudeSessionProcessMessage(
            sessionId: sessionId,
            message: message,
            interrupted: process.interrupted,
            promptId: promptId,
          ),
        );
      }
    });
    _resident[sessionId] = process;
    unawaited(client.processExit.then((_) => _handleExit(sessionId: sessionId, process: process)));
  }

  Future<void> _handleExit({required String sessionId, required _ResidentProcess process}) async {
    if (!identical(_resident[sessionId], process)) return;
    _resident.remove(sessionId);
    if (!_events.isClosed) {
      _events.add(ClaudeSessionProcessExited(sessionId: sessionId, interrupted: process.interrupted));
    }
    _settlePendingTurns(
      process: process,
      outcome: process.interrupted ? const ClaudeTurnInterrupted() : const ClaudeTurnFailed(),
    );
    try {
      await process.cancelMessages();
    } on Object catch (error, stack) {
      Log.w("[claude] failed to cancel exited process subscription", error, stack);
    } finally {
      await process.client.dispose();
    }
  }

  String? _trackTurnMessage({required _ResidentProcess process, required ClaudeStreamMessage message}) {
    switch (message) {
      case ClaudeUserMessage(parentToolUseId: null, raw: {"isReplay": true}):
        for (final pending in process.pendingTurns) {
          final replayContent = pending.replayContent;
          if (pending.replayObserved ||
              replayContent == null ||
              !_sameJsonValue(replayContent, message.message["content"])) {
            continue;
          }
          pending.replayObserved = true;
          if (!pending.settled) {
            pending.started = true;
            process.turnActive = true;
          }
          final promptId = pending.promptId;
          _removeSettledReplays(process: process);
          return promptId;
        }
      case ClaudeStreamEventMessage() || ClaudeAssistantMessage() || ClaudeControlRequestMessage():
        process.turnActive = true;
      case final ClaudeResultMessage message:
        final outcome = process.interrupted
            ? const ClaudeTurnInterrupted()
            : message.isError
            ? const ClaudeTurnFailed()
            : const ClaudeTurnCompleted();
        for (final pending in process.pendingTurns) {
          if (pending.settled) continue;
          if (!pending.started) break;
          pending.settled = true;
          if (!pending.outcome.isCompleted) pending.outcome.complete(outcome);
        }
        _removeSettledReplays(process: process);
        process.turnActive = false;
      case ClaudeStreamMessage():
        break;
    }
    return null;
  }

  void _removeSettledReplays({required _ResidentProcess process}) {
    while (process.pendingTurns.isNotEmpty) {
      final pending = process.pendingTurns.first;
      if (!pending.settled || !pending.replayObserved) return;
      process.pendingTurns.removeFirst();
    }
  }

  void _settlePendingTurns({required _ResidentProcess process, required ClaudeTurnOutcome outcome}) {
    for (final pending in process.pendingTurns) {
      pending.settled = true;
      if (!pending.outcome.isCompleted) pending.outcome.complete(outcome);
    }
    process.pendingTurns.clear();
    process.turnActive = false;
  }
}

bool _sameJsonValue(Object? left, Object? right) {
  if (left is List && right is List) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_sameJsonValue(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) || !_sameJsonValue(entry.value, right[entry.key])) return false;
    }
    return true;
  }
  return left == right;
}

List<Map<String, Object?>> _promptContent(List<PluginPromptPart> parts) => [
  for (final part in parts)
    ...switch (part) {
      PluginPromptPartText(:final text) => [
        {"type": "text", "text": text},
      ],
      PluginPromptPartFileData(:final mime, :final base64) when mime.toLowerCase().startsWith("image/") => [
        {
          "type": "image",
          "source": {"type": "base64", "media_type": mime, "data": base64},
        },
      ],
      PluginPromptPartFileData() => const <Map<String, Object?>>[],
      PluginPromptPartFilePath(:final path) => [
        {"type": "text", "text": path},
      ],
      PluginPromptPartFileUrl(:final url) => [
        {"type": "text", "text": url},
      ],
    },
];
