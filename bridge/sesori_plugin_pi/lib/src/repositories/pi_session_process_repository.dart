import "dart:async";
import "dart:convert";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show decodedBase64Length, isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;

import "../api/models/pi_rpc_frame.dart";
import "../api/models/pi_session_history_dto.dart";
import "../api/pi_launch_spec.dart";
import "../api/pi_process_factory.dart";
import "../api/pi_rpc_client.dart";
import "../api/pi_session_storage_api.dart";
import "../models/pi_rpc_command.dart";
import "../trackers/pi_message_identity_tracker.dart";
import "mappers/pi_history_mapper.dart";
import "mappers/pi_persisted_user_text_codec.dart";

final class const PiSessionHistoryNotFoundException({required final String sessionId}) implements Exception {
  @override
  String toString() => "PiSessionHistoryNotFoundException";
}

final class const PiHistoryRpcStartupUnavailableException({required final Object cause}) implements Exception {
  @override
  String toString() => "PiHistoryRpcStartupUnavailableException";
}

final class const PiSessionHistoryLoadException({required final Object innerError}) implements Exception {
  @override
  String toString() => "PiSessionHistoryLoadException";
}

final class const PiSessionHistoryParseException({required final Object innerError}) implements Exception {
  @override
  String toString() => "PiSessionHistoryParseException";
}

final class const PiSessionHistoryCommandDiagnostic({required final String detail}) implements Exception {
  @override
  String toString() => "Pi session history command failed: $detail";
}

final class const PiSessionProcessFrame({
  required final String sessionId,
  required final int generation,
  required final PiRpcFrame frame,
});

final class const PiSessionProcessExit({
  required final String sessionId,
  required final int generation,
  required final int exitCode,
  required final bool authUnavailable,
});

final class const PiSessionConnection({
  required final String sessionId,
  required final int generation,
});

final class const PiPromptPayload({required final String message, required final List<Map<String, Object?>> images});

final class const PiAgentState({required final bool streaming, required final int pendingMessageCount});

final class const PiUnsupportedPromptAttachmentException({required final String variant}) implements Exception {
  @override
  String toString() => "Unsupported Pi prompt attachment variant: $variant";
}

final class const PiInvalidPromptImageException({required final String reason}) implements Exception {
  @override
  String toString() => "Invalid Pi prompt image: $reason";
}

final class const PiSessionAuthenticationException({required final Object innerError}) implements Exception {
  @override
  String toString() => "Pi session authentication is unavailable";
}

final class const PiSessionCommandDiagnostic({
  required final PiRpcCommand command,
  required final String detail,
}) implements Exception {
  @override
  String toString() => "Pi session command ${command.wireValue} failed: $detail";
}

final class PiSessionProcessRepository({
  required final PiSessionStorageApi _storageApi,
  required final PiSessionHistoryStorageApi _historyStorageApi,
  required final String _binaryPath,
  required Map<String, String> environment,
  required final PiProcessFactory _processFactory,
  required final PiHistoryMapper _historyMapper,
  required final PiMessageIdentityTracker _identityTracker,
  required final Duration _startupExitTimeout,
  required final Duration _historyRpcTimeout,
}) {
  final Map<String, String> _environment = Map.unmodifiable(environment);
  final Map<String, _ResidentClient> _residents = {};
  final Map<String, Future<PiSessionConnection>> _connecting = {};
  final Map<String, _ConnectingClient> _connectingClients = {};
  final Map<String, Future<void>> _sessionOperationTails = {};
  final Map<String, int> _generations = {};
  final StreamController<PiSessionProcessFrame> _frames = StreamController.broadcast();
  final StreamController<PiSessionProcessExit> _exits = StreamController.broadcast();
  var _nextConnectionGeneration = 0;
  bool _disposed = false;

  Stream<PiSessionProcessFrame> get frames => _frames.stream;
  Stream<PiSessionProcessExit> get exits => _exits.stream;
  Set<String> get residentSessionIds => Set.unmodifiable(_residents.keys);

  String generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
    return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-"
        "${hex.substring(16, 20)}-${hex.substring(20)}";
  }

  Future<void> markPendingNew({required String sessionId, required String directory}) =>
      _storageApi.writePendingNewSession(sessionId: sessionId, cwd: directory);

  Future<bool> clearPendingWhenPersisted({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    final resident = _residents[sessionId];
    if (resident == null || !resident.pendingPersistence) return false;
    final resolved = await _storageApi.resolveSession(
      sessionId: sessionId,
      knownDirectories: knownDirectories,
    );
    if (resolved == null) return false;
    await _storageApi.clearPendingNewSession(
      sessionId: sessionId,
      knownDirectories: {...knownDirectories, resolved.metadata.cwd},
    );
    if (identical(_residents[sessionId], resident)) resident.pendingPersistence = false;
    return true;
  }

  Future<PiSessionConnection> ensureResident({
    required String sessionId,
    required Set<String> knownDirectories,
  }) => _withSessionOperation(
    sessionId: sessionId,
    operation: () => _ensureResident(sessionId: sessionId, knownDirectories: knownDirectories),
  );

  Future<PiSessionConnection> _ensureResident({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    if (_disposed) throw const PiRpcDisposedException();
    final resident = _residents[sessionId];
    if (resident != null) {
      return PiSessionConnection(sessionId: sessionId, generation: resident.generation);
    }
    final connecting = _connecting[sessionId];
    if (connecting != null) return await connecting;
    final future = _connect(sessionId: sessionId, knownDirectories: knownDirectories);
    _connecting[sessionId] = future;
    try {
      return await future;
    } finally {
      if (identical(_connecting[sessionId], future)) unawaited(_connecting.remove(sessionId));
    }
  }

  Future<PiSessionConnection> _connect({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    final generation = ++_nextConnectionGeneration;
    _generations[sessionId] = generation;
    final resolved = await _storageApi.resolveSession(
      sessionId: sessionId,
      knownDirectories: knownDirectories,
    );
    final pending = resolved == null
        ? await _storageApi.readPendingNewSession(
            sessionId: sessionId,
            knownDirectories: knownDirectories,
          )
        : null;
    if (resolved == null && pending == null) {
      throw PluginOperationException.notFound(
        "connect Pi session",
        message: "Pi session was not found.",
        cause: PiSessionHistoryNotFoundException(sessionId: sessionId),
      );
    }
    if (resolved != null) {
      try {
        await _storageApi.clearPendingNewSession(
          sessionId: sessionId,
          knownDirectories: {...knownDirectories, resolved.metadata.cwd},
        );
      } on Object catch (error, stack) {
        Log.w("[pi] failed to clear stale pending marker for resolved session id=$sessionId; continuing", error, stack);
      }
    }
    final launch = resolved == null ? PiNewSession(sessionId: sessionId) : PiResumedSession(sessionPath: resolved.path);
    final cwd = resolved?.metadata.cwd ?? pending!.cwd;
    final client = PiRpcClient(
      launchSpec: PiLaunchSpec(
        binaryPath: _binaryPath,
        workingDirectory: cwd,
        launch: launch,
        environment: _environment,
      ),
      processFactory: _processFactory,
    );
    final connecting = _ConnectingClient(client: client, generation: generation);
    _connectingClients[sessionId] = connecting;
    try {
      await client.start();
      if (_disposed || _generations[sessionId] != generation) {
        await client.dispose();
        throw StateError("Pi session connection was invalidated during startup");
      }
      final history = await _getEntries(client: client);
      final hydration = _identityTracker.beginHydration(sessionId: sessionId);
      hydration.complete(
        map: (identities) => _historyMapper.map(
          sessionId: sessionId,
          entries: history.entries,
          leafId: history.leafId,
          identities: identities,
        ),
      );
      if (_disposed || _generations[sessionId] != generation) {
        await client.dispose();
        throw StateError("Pi session connection was invalidated during startup");
      }
      final resident = _ResidentClient(
        client: client,
        generation: generation,
        initialPendingPersistence: pending != null,
      );
      _residents[sessionId] = resident;
      resident.frameSubscription = client.frames.listen((frame) {
        if (identical(_residents[sessionId], resident) && !_frames.isClosed) {
          _frames.add(PiSessionProcessFrame(sessionId: sessionId, generation: generation, frame: frame));
        }
      });
      unawaited(
        client.processExit.then((exitCode) {
          if (!identical(_residents[sessionId], resident)) return;
          _residents.remove(sessionId);
          unawaited(resident.cancelFrames());
          if (!_exits.isClosed) {
            _exits.add(
              PiSessionProcessExit(
                sessionId: sessionId,
                generation: generation,
                exitCode: exitCode,
                authUnavailable: client.stderrDiagnostics.contains(PiRpcClient.noModelsDiagnosticPrefix),
              ),
            );
          }
        }),
      );
      return PiSessionConnection(sessionId: sessionId, generation: generation);
    } on Object catch (error, stack) {
      final authUnavailable = client.stderrDiagnostics.contains(PiRpcClient.noModelsDiagnosticPrefix);
      if (!_residents.containsKey(sessionId)) await client.dispose();
      if (authUnavailable) {
        Error.throwWithStackTrace(PiSessionAuthenticationException(innerError: error), stack);
      }
      rethrow;
    } finally {
      if (identical(_connectingClients[sessionId], connecting)) {
        _connectingClients.remove(sessionId);
      }
    }
  }

  Future<PiSessionEntriesDto> _getEntries({required PiRpcClient client}) async {
    final response = await client.send(
      command: PiRpcCommand.getEntries,
      arguments: const {},
      timeout: _historyRpcTimeout,
    );
    try {
      return PiSessionEntriesDto.fromJson(response.data.cast<String, dynamic>());
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(PiSessionHistoryParseException(innerError: error), stack);
    }
  }

  Future<void> applySelection({
    required String sessionId,
    required PiSessionConnection connection,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    final resident = _requiredResident(connection);
    if (model != null && resident.model != model) {
      await resident.client.send(
        command: PiRpcCommand.setModel,
        arguments: {"provider": model.providerID, "modelId": model.modelID},
        timeout: _historyRpcTimeout,
      );
      resident.model = model;
      resident.variant = null;
    }
    final variantId = variant?.id;
    if (variantId != null && resident.variant != variantId) {
      await resident.client.send(
        command: PiRpcCommand.setThinkingLevel,
        arguments: {"level": variantId},
        timeout: _historyRpcTimeout,
      );
      resident.variant = variantId;
    }
  }

  Future<void> dispatchPrompt({
    required PiSessionConnection connection,
    required PiPromptPayload payload,
  }) async {
    final resident = _requiredResident(connection);
    await resident.client.send(
      command: PiRpcCommand.prompt,
      arguments: {"message": payload.message, "images": payload.images},
      timeout: _historyRpcTimeout,
    );
  }

  Future<PiAgentState> getState({required PiSessionConnection connection}) async {
    final data = (await _requiredResident(connection).client.send(
      command: PiRpcCommand.getState,
      arguments: const {},
      timeout: _historyRpcTimeout,
    )).data;
    return PiAgentState(
      streaming: data["isStreaming"] == true,
      pendingMessageCount: switch (data["pendingMessageCount"]) {
        final int value when value >= 0 => value,
        _ => 0,
      },
    );
  }

  Future<void> abort({required PiSessionConnection connection}) async {
    await _requiredResident(connection).client.send(
      command: PiRpcCommand.abort,
      arguments: const {},
      timeout: _historyRpcTimeout,
    );
  }

  bool sendExtensionUiResponse({
    required String ownerSessionId,
    required int generation,
    required String requestId,
    required PiExtensionUiReply reply,
  }) {
    final resident = _residents[ownerSessionId];
    return resident != null && resident.generation == generation
        ? resident.client.sendExtensionUiResponse(id: requestId, reply: reply)
        : false;
  }

  PiPromptPayload mapPrompt({required List<PluginPromptPart> parts, required String? userVisibleText}) {
    final executionText = parts.whereType<PluginPromptPartText>().map((part) => part.text).join();
    final message = executionText.isEmpty && (userVisibleText == null || userVisibleText.isEmpty)
        ? ""
        : executionText == userVisibleText
        ? executionText
        : const PiPersistedUserTextCodec().encode(
            executionText: executionText,
            userVisibleText: userVisibleText,
          );
    var totalImageBytes = 0;
    final images = <Map<String, Object?>>[];
    for (final part in parts) {
      switch (part) {
        case PluginPromptPartText():
          break;
        case PluginPromptPartFileData(:final mime, base64: final raw):
          if (!const {"image/gif", "image/jpeg", "image/png", "image/webp"}.contains(mime.toLowerCase())) {
            _throwAttachmentFailure(
              cause: const PiUnsupportedPromptAttachmentException(variant: "inline non-image data"),
            );
          }
          if (raw.isEmpty || !isInlineMessageAttachmentWithinSizeLimit(base64Length: raw.length)) {
            _throwAttachmentFailure(cause: const PiInvalidPromptImageException(reason: "image exceeds size limit"));
          }
          final String normalized;
          try {
            normalized = base64.normalize(raw);
          } on FormatException catch (error, stack) {
            Error.throwWithStackTrace(
              PluginOperationException(
                "send Pi prompt",
                statusCode: 400,
                message: "Pi supports valid inline image data only.",
                cause: PiInvalidPromptImageException(reason: error.message),
              ),
              stack,
            );
          }
          try {
            base64.decode(normalized);
          } on FormatException catch (error, stack) {
            Error.throwWithStackTrace(
              PluginOperationException(
                "send Pi prompt",
                statusCode: 400,
                message: "Pi supports valid inline image data only.",
                cause: PiInvalidPromptImageException(reason: error.message),
              ),
              stack,
            );
          }
          final decodedBytes = decodedBase64Length(base64Data: normalized);
          totalImageBytes += decodedBytes;
          if (decodedBytes == 0 ||
              decodedBytes > maxInlineMessageAttachmentBytes ||
              totalImageBytes > maxInlineMessageAttachmentBytes) {
            _throwAttachmentFailure(cause: const PiInvalidPromptImageException(reason: "image exceeds size limit"));
          }
          images.add({"type": "image", "data": normalized, "mimeType": mime.toLowerCase()});
        case PluginPromptPartFilePath():
          _throwAttachmentFailure(cause: const PiUnsupportedPromptAttachmentException(variant: "file path"));
        case PluginPromptPartFileUrl():
          _throwAttachmentFailure(cause: const PiUnsupportedPromptAttachmentException(variant: "file URL"));
      }
    }
    return PiPromptPayload(message: message, images: List.unmodifiable(images));
  }

  Never _throwAttachmentFailure({required Object cause}) => throw PluginOperationException(
    "send Pi prompt",
    statusCode: 400,
    message: "Pi supports inline image data only.",
    cause: cause,
  );

  PluginOperationException presentTurnFailure({required String sessionId, required Object error}) {
    final resident = _residents[sessionId];
    final authUnavailable =
        error is PiSessionAuthenticationException ||
        (resident?.client.stderrDiagnostics.contains(PiRpcClient.noModelsDiagnosticPrefix) ?? false);
    return PluginOperationException(
      "run Pi session turn",
      message: authUnavailable
          ? "Pi has no model available. Run Pi locally and use /login, then try again."
          : "Pi could not run this turn.",
      cause: authUnavailable
          ? PiSessionAuthenticationException(innerError: error)
          : switch (error) {
              PiRpcCommandFailureException(:final command, :final error) => PiSessionCommandDiagnostic(
                command: command,
                detail: error,
              ),
              _ => error,
            },
    );
  }

  _ResidentClient _requiredResident(PiSessionConnection connection) {
    final resident = _residents[connection.sessionId];
    if (resident == null || resident.generation != connection.generation) {
      throw const PiRpcDisposedException();
    }
    return resident;
  }

  Future<void> renameSession({
    required String sessionId,
    required String title,
    required Set<String> knownDirectories,
  }) => _withSessionOperation(
    sessionId: sessionId,
    operation: () => _renameSession(sessionId: sessionId, title: title, knownDirectories: knownDirectories),
  );

  Future<void> _renameSession({
    required String sessionId,
    required String title,
    required Set<String> knownDirectories,
  }) async {
    if (_disposed) throw const PiRpcDisposedException();
    final resident = _residents[sessionId];
    if (resident != null) {
      await resident.client.send(
        command: PiRpcCommand.setSessionName,
        arguments: {"name": title},
        timeout: _historyRpcTimeout,
      );
      return;
    }
    final lease = await _openTransient(sessionId: sessionId, knownDirectories: knownDirectories);
    try {
      await lease.client.send(
        command: PiRpcCommand.setSessionName,
        arguments: {"name": title},
        timeout: _historyRpcTimeout,
      );
    } finally {
      await lease.client.dispose();
    }
  }

  Future<_TransientClient> _openTransient({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    final resolved = await _storageApi.resolveSession(sessionId: sessionId, knownDirectories: knownDirectories);
    if (resolved == null) {
      throw PluginOperationException.notFound(
        "open Pi session",
        message: "Pi session was not found.",
        cause: PiSessionHistoryNotFoundException(sessionId: sessionId),
      );
    }
    final client = PiRpcClient(
      launchSpec: PiLaunchSpec(
        binaryPath: _binaryPath,
        workingDirectory: resolved.metadata.cwd,
        launch: PiResumedSession(sessionPath: resolved.path),
        environment: _environment,
      ),
      processFactory: _processFactory,
    );
    await client.start();
    return _TransientClient(client: client, resolved: resolved);
  }

  Future<void> teardown({required String sessionId}) async {
    _generations.remove(sessionId);
    final connecting = _connectingClients.remove(sessionId);
    if (connecting != null) {
      final wasRunning = connecting.client.isRunning;
      final disposal = connecting.client.dispose();
      if (wasRunning) {
        await disposal;
      } else {
        unawaited(
          disposal.catchError((Object error, StackTrace stack) {
            Log.w("[pi] connecting client teardown failed for session id=$sessionId", error, stack);
          }),
        );
      }
    }
    final resident = _residents.remove(sessionId);
    if (resident == null) return;
    await resident.cancelFrames();
    await resident.client.dispose();
  }

  Future<void> teardownConnection({required PiSessionConnection connection}) async {
    final resident = _residents[connection.sessionId];
    if (resident == null || resident.generation != connection.generation) return;
    await teardown(sessionId: connection.sessionId);
  }

  Future<void> forgetSession({required String sessionId, required Set<String> knownDirectories}) async {
    await teardown(sessionId: sessionId);
    await _storageApi.clearPendingNewSession(sessionId: sessionId, knownDirectories: knownDirectories);
    _generations.remove(sessionId);
    _identityTracker.forgetSession(sessionId: sessionId);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final sessionId in {..._residents.keys, ..._connecting.keys}) {
      _generations[sessionId] = ++_nextConnectionGeneration;
    }
    await Future.wait([
      for (final sessionId in {..._residents.keys, ..._connectingClients.keys}) teardown(sessionId: sessionId),
    ]);
    await Future.wait(
      _connecting.values.map((future) => future.then<void>((_) {}, onError: (Object _, StackTrace _) {})),
    );
    await Future.wait(_sessionOperationTails.values.toList());
    await _frames.close();
    await _exits.close();
  }

  Future<List<PluginMessageWithParts>> loadHistory({
    required String sessionId,
    required Set<String> knownDirectories,
  }) => _withSessionOperation(
    sessionId: sessionId,
    operation: () => _loadHistory(sessionId: sessionId, knownDirectories: knownDirectories),
  );

  Future<List<PluginMessageWithParts>> _loadHistory({
    required String sessionId,
    required Set<String> knownDirectories,
  }) async {
    if (_disposed) throw const PiRpcDisposedException();
    final PiResolvedSession? resolved;
    try {
      final resident = _residents[sessionId];
      if (resident != null) {
        final history = await _getEntries(client: resident.client);
        return _hydrateHistory(sessionId: sessionId, history: history);
      }
      resolved = await _storageApi.resolveSession(sessionId: sessionId, knownDirectories: knownDirectories);
    } on Object catch (error, stack) {
      _throwLoadFailure(path: "session storage", error: error, stack: stack);
    }
    if (resolved == null) {
      final cause = PiSessionHistoryNotFoundException(sessionId: sessionId);
      Error.throwWithStackTrace(
        PluginOperationException.notFound(
          "load Pi session history",
          message: "Pi session was not found.",
          cause: cause,
        ),
        StackTrace.current,
      );
    }

    try {
      return _hydrateHistory(
        sessionId: sessionId,
        history: await _readHistory(resolved: resolved),
      );
    } on Object catch (error, stack) {
      _throwLoadFailure(path: resolved.path, error: error, stack: stack);
    }
  }

  Future<T> _withSessionOperation<T>({
    required String sessionId,
    required Future<T> Function() operation,
  }) async {
    final previous = _sessionOperationTails[sessionId] ?? Future.value();
    final completed = Completer<void>();
    _sessionOperationTails[sessionId] = completed.future;
    await previous;
    try {
      return await operation();
    } finally {
      completed.complete();
      if (identical(_sessionOperationTails[sessionId], completed.future)) {
        unawaited(_sessionOperationTails.remove(sessionId));
      }
    }
  }

  List<PluginMessageWithParts> _hydrateHistory({required String sessionId, required PiSessionEntriesDto history}) =>
      _identityTracker
          .beginHydration(sessionId: sessionId)
          .complete(
            map: (identities) => _historyMapper.map(
              sessionId: sessionId,
              entries: history.entries,
              leafId: history.leafId,
              identities: identities,
            ),
          );

  Future<PiSessionEntriesDto> _readHistory({required PiResolvedSession resolved}) async {
    try {
      final resident = _residents[resolved.metadata.id];
      return resident == null
          ? await _readHistoryFromRpc(resolved: resolved)
          : await _getEntries(client: resident.client);
    } on PiHistoryRpcStartupUnavailableException catch (error, stack) {
      Log.w(
        "[pi] history RPC startup unavailable at '${resolved.path}'; reading persisted session history",
        error.cause,
        stack,
      );
      final fileHistory = await _historyStorageApi.readSessionHistory(path: resolved.path);
      return _normalizeFileHistory(history: fileHistory);
    }
  }

  Future<PiSessionEntriesDto> _readHistoryFromRpc({required PiResolvedSession resolved}) async {
    final client = PiRpcClient(
      launchSpec: PiLaunchSpec(
        binaryPath: _binaryPath,
        workingDirectory: resolved.metadata.cwd,
        launch: PiResumedSession(sessionPath: resolved.path),
        environment: _environment,
      ),
      processFactory: _processFactory,
    );
    try {
      await client.start();
      try {
        final response = await client.send(
          command: PiRpcCommand.getEntries,
          arguments: const {},
          timeout: _historyRpcTimeout,
        );
        try {
          return PiSessionEntriesDto.fromJson(response.data.cast<String, dynamic>());
        } on Object catch (error, stack) {
          Error.throwWithStackTrace(PiSessionHistoryParseException(innerError: error), stack);
        }
      } on PiRpcProcessExitException catch (error, stack) {
        if (!_isNoModelStartupFailure(client.stderrDiagnostics)) rethrow;
        Error.throwWithStackTrace(PiHistoryRpcStartupUnavailableException(cause: error), stack);
      } on PiRpcStdinException catch (error, stack) {
        try {
          await client.processExit.timeout(_startupExitTimeout);
        } on TimeoutException {
          Error.throwWithStackTrace(error, stack);
        }
        if (!_isNoModelStartupFailure(client.stderrDiagnostics)) rethrow;
        Error.throwWithStackTrace(PiHistoryRpcStartupUnavailableException(cause: error), stack);
      }
    } finally {
      await client.dispose();
    }
  }

  PiSessionEntriesDto _normalizeFileHistory({required PiSessionFileHistoryDto history}) {
    final isV1 = (history.header.version ?? 1) < 2;
    final entries = <PiSessionEntryDto>[];
    String? previousId;
    for (var index = 0; index < history.entries.length; index++) {
      final fileEntry = history.entries[index];
      final id = isV1 ? "sesori-v1-${index + 1}" : fileEntry.id;
      if (id == null) continue;
      final parentId = isV1 ? previousId : fileEntry.parentId;
      entries.add(_normalizeFileEntry(entry: fileEntry, id: id, parentId: parentId));
      previousId = id;
    }
    return PiSessionEntriesDto(entries: List.unmodifiable(entries), leafId: entries.lastOrNull?.id);
  }

  PiSessionEntryDto _normalizeFileEntry({
    required PiSessionFileEntryDto entry,
    required String id,
    required String? parentId,
  }) => switch (entry) {
    PiSessionFileMessageEntryDto(:final timestamp, :final message) => PiSessionEntryDto.message(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
      message: _normalizeFileMessage(message),
    ),
    PiSessionFileThinkingLevelChangeEntryDto(:final timestamp) => PiSessionEntryDto.thinkingLevelChange(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileModelChangeEntryDto(:final timestamp) => PiSessionEntryDto.modelChange(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileCompactionEntryDto(:final timestamp) => PiSessionEntryDto.compaction(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileBranchSummaryEntryDto(:final timestamp) => PiSessionEntryDto.branchSummary(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileCustomEntryDto(:final timestamp) => PiSessionEntryDto.custom(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileCustomMessageEntryDto(:final timestamp, :final content, :final display) =>
      PiSessionEntryDto.customMessage(
        id: id,
        parentId: parentId,
        timestamp: timestamp,
        content: content,
        display: display,
      ),
    PiSessionFileLabelEntryDto(:final timestamp) => PiSessionEntryDto.label(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileSessionInfoEntryDto(:final timestamp) => PiSessionEntryDto.sessionInfo(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
    PiSessionFileUnknownEntryDto(:final timestamp) => PiSessionEntryDto.unknown(
      id: id,
      parentId: parentId,
      timestamp: timestamp,
    ),
  };

  PiAgentMessageDto _normalizeFileMessage(PiSessionFileAgentMessageDto message) => switch (message) {
    PiSessionFileUserMessageDto(:final content, :final timestamp) => PiAgentMessageDto.user(
      content: content,
      timestamp: timestamp,
    ),
    PiSessionFileAssistantMessageDto(
      :final content,
      :final provider,
      :final model,
      :final stopReason,
      :final errorMessage,
      :final timestamp,
    ) =>
      PiAgentMessageDto.assistant(
        content: content,
        provider: provider,
        model: model,
        stopReason: stopReason,
        errorMessage: errorMessage,
        timestamp: timestamp,
      ),
    PiSessionFileToolResultMessageDto(
      :final toolCallId,
      :final toolName,
      :final content,
      :final isError,
      :final timestamp,
    ) =>
      PiAgentMessageDto.toolResult(
        toolCallId: toolCallId,
        toolName: toolName,
        content: content,
        isError: isError,
        timestamp: timestamp,
      ),
    PiSessionFileBashExecutionMessageDto(
      :final command,
      :final output,
      :final exitCode,
      :final cancelled,
      :final truncated,
      :final timestamp,
    ) =>
      PiAgentMessageDto.bashExecution(
        command: command,
        output: output,
        exitCode: exitCode,
        cancelled: cancelled,
        truncated: truncated,
        timestamp: timestamp,
      ),
    PiSessionFileCustomMessageDto(:final content, :final display, :final timestamp) ||
    PiSessionFileHookMessageDto(:final content, :final display, :final timestamp) => PiAgentMessageDto.custom(
      content: content,
      display: display,
      timestamp: timestamp,
    ),
    PiSessionFileBranchSummaryMessageDto(:final timestamp) => PiAgentMessageDto.branchSummary(timestamp: timestamp),
    PiSessionFileCompactionSummaryMessageDto(:final timestamp) => PiAgentMessageDto.compactionSummary(
      timestamp: timestamp,
    ),
    PiSessionFileUnknownMessageDto(:final timestamp) => PiAgentMessageDto.unknown(timestamp: timestamp),
  };

  bool _isNoModelStartupFailure(List<String> diagnostics) => diagnostics.any(
    (line) => line == PiRpcClient.noModelsDiagnosticPrefix,
  );

  Never _throwLoadFailure({required String path, required Object error, required StackTrace stack}) {
    final localError = switch (error) {
      PiInvalidSessionHistoryException(:final cause) => PiSessionHistoryParseException(innerError: cause),
      PiRpcCommandFailureException(:final error) => PiSessionHistoryCommandDiagnostic(detail: error),
      _ => error,
    };
    Log.w("[pi] failed to load session history at '$path'", localError, stack);
    Error.throwWithStackTrace(
      PluginOperationException(
        "load Pi session history",
        message: "Pi session history could not be loaded.",
        cause: PiSessionHistoryLoadException(innerError: error),
      ),
      stack,
    );
  }
}

final class const _ConnectingClient({required final PiRpcClient client, required final int generation});

final class _ResidentClient({
  required final PiRpcClient client,
  required final int generation,
  required bool initialPendingPersistence,
}) {
  StreamSubscription<PiRpcFrame>? frameSubscription;
  ({String providerID, String modelID})? model;
  String? variant;
  bool pendingPersistence = initialPendingPersistence;
  Future<void> cancelFrames() async {
    await frameSubscription?.cancel();
    frameSubscription = null;
  }
}

final class const _TransientClient({required final PiRpcClient client, required final PiResolvedSession resolved});
