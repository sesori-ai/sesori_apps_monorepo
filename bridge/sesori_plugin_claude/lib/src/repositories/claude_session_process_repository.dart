import "dart:async";

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

final class _ResidentProcess({
  required final ClaudeStreamClient client,
  required final bool resumed,
  required var String? appliedModel,
  required var ClaudeEffortLevel? appliedEffort,
  required var ClaudePermissionMode? appliedPermissionMode,
}) {
  late final StreamSubscription<ClaudeStreamMessage> messages;
  bool interrupted = false;

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
        params: {"model": model == "default" ? null : model},
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
    final result = process.client.messages
        .where((message) => message is ClaudeResultMessage)
        .cast<ClaudeResultMessage>()
        .first;
    final exit = process.client.processExit.then<ClaudeResultMessage?>((_) => null);
    process.client.sendUserMessage(content: content);
    _startedSessions.add(sessionId);
    return ClaudeTurnDispatch(
      accepted: true,
      outcome: Future.any<ClaudeResultMessage?>([result, exit]).then((message) {
        if (process.interrupted) return const ClaudeTurnInterrupted();
        if (message == null || message.isError) {
          return const ClaudeTurnFailed();
        }
        return const ClaudeTurnCompleted();
      }),
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
      if (!_events.isClosed) {
        _events.add(
          ClaudeSessionProcessMessage(
            sessionId: sessionId,
            message: message,
            interrupted: process.interrupted,
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
    try {
      await process.cancelMessages();
    } on Object catch (error, stack) {
      Log.w("[claude] failed to cancel exited process subscription", error, stack);
    } finally {
      await process.client.dispose();
    }
  }
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
