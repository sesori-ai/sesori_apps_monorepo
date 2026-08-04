import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/codex_image_bearing_item_dto.dart";
import "../api/models/codex_rollout_dto.dart";
import "../codex_app_server_client.dart";
import "mappers/codex_rollout_tool_mapper.dart";
import "models/codex_projected_tool.dart";

final RegExp _executorOutputBoundaryPattern = RegExp(
  r"(?:^|\r?\n)(?:Final )?Output:\r?\n",
  caseSensitive: false,
);

/// Reduces Codex's rollout and app-server evidence into canonical tool state.
///
/// Codex persists a `call_*` rollout id but emits a separate `exec-*`
/// app-server id. Commands execute sequentially within a turn, making the
/// pending same-turn FIFO the narrow common identity between those streams.
class CodexToolLifecycleTracker {
  CodexToolLifecycleTracker({
    required CodexRolloutToolMapper rolloutToolMapper,
  }) : _rolloutToolMapper = rolloutToolMapper;

  final CodexRolloutToolMapper _rolloutToolMapper;
  final Map<String, _ThreadToolLifecycle> _threads = {};
  final Map<String, Map<String, _TrackedTool>> _retainedCommandsByThread = {};

  /// Applies one typed rollout record and returns complete canonical upserts.
  List<CodexProjectedTool> observeRolloutLine({
    required String threadId,
    required CodexRolloutLineDto line,
  }) {
    final thread = _threads.putIfAbsent(threadId, _ThreadToolLifecycle.new);
    return switch (line) {
      CodexRolloutResponseItemLineDto(payload: final payload) => _observeRolloutPayload(
        thread: thread,
        payload: payload,
      ),
      CodexRolloutEventMessageLineDto(payload: final event) => _observeRolloutEvent(
        thread: thread,
        event: event,
      ),
      CodexRolloutSessionMetadataLineDto() ||
      CodexRolloutTurnContextLineDto() ||
      CodexRolloutCompactedLineDto() ||
      CodexRolloutUnknownLineDto() => const [],
    };
  }

  /// Applies a stable app-server command item when it can be correlated.
  ///
  /// A null result means the notification must keep its native app-server id
  /// and continue through the existing native event mapping.
  CodexProjectedTool? observeAppServerTool({
    required CodexServerNotification notification,
    required CodexImageGenerationItemDto? imageGeneration,
  }) {
    if (notification.method != "item/started" && notification.method != "item/completed") {
      return null;
    }
    final params = notification.params;
    final item = params["item"];
    if (item is! Map) return null;
    final itemId = _usefulText(value: item["id"]);
    final threadId = _usefulText(value: params["threadId"]);
    if (itemId == null || threadId == null) return null;
    if (imageGeneration != null) {
      final thread = _threads.putIfAbsent(
        threadId,
        _ThreadToolLifecycle.new,
      );
      final generation = _rolloutToolMapper.mapAppServerImageGeneration(
        item: imageGeneration,
        completed: notification.method == "item/completed",
      );
      final generationId = generation.id;
      if (generationId == null) return null;
      final tool = thread.tools.putIfAbsent(
        generationId,
        () => _TrackedTool(
          id: generationId,
          tool: "image_generation",
          title: null,
          turnId: null,
          chronologySegment: thread.chronologySegment,
          isRolloutCall: false,
        ),
      );
      tool.status = _mergeStatus(
        previous: tool.status,
        current: generation.status,
      );
      if (tool.attachments.isEmpty) {
        _mergeAttachments(
          accumulated: tool.attachments,
          current: generation.attachments,
        );
      }
      return tool.snapshot();
    }

    if (item["type"] == "commandExecution" && notification.method == "item/completed") {
      final retainedCommands = _retainedCommandsByThread[threadId];
      final retainedTool = retainedCommands?.remove(itemId);
      if (retainedTool != null) {
        if (retainedCommands!.isEmpty) {
          _retainedCommandsByThread.remove(threadId);
        }
        return _applyAppServerCommand(
          tool: retainedTool,
          item: item,
          completed: true,
          mergeLateOutput: true,
        );
      }
    }

    final thread = _threads[threadId];
    if (thread == null) return null;

    if (item["type"] == "dynamicToolCall") {
      final tool = thread.tools[itemId];
      if (tool == null || !tool.hasRolloutResult) return null;
      tool.status = _mergeStatus(
        previous: tool.status,
        current: _appServerStatus(
          raw: item["status"],
          completed: notification.method == "item/completed",
        ),
      );
      return tool.snapshot();
    }
    if (item["type"] != "commandExecution") return null;

    var canonicalId = thread.appServerItemAliases[itemId];
    final turnId = _usefulText(value: params["turnId"]);
    if (canonicalId == null && turnId != null) {
      final pending = thread.pendingShellCallsByTurn[turnId];
      if (pending != null && pending.isNotEmpty) {
        canonicalId = pending.removeAt(0);
        thread.appServerItemAliases[itemId] = canonicalId;
        if (pending.isEmpty) thread.pendingShellCallsByTurn.remove(turnId);
      }
    }
    if (canonicalId == null && turnId != null) {
      final pending = thread.pendingCodeModeShellCallsByTurn[turnId];
      if (pending != null && pending.isNotEmpty) {
        canonicalId = pending.removeAt(0);
        thread.appServerItemAliases[itemId] = canonicalId;
        if (pending.isEmpty) {
          thread.pendingCodeModeShellCallsByTurn.remove(turnId);
        }
      }
    }
    if (canonicalId == null && thread.tools.containsKey(itemId)) {
      canonicalId = itemId;
      thread.appServerItemAliases[itemId] = canonicalId;
    }
    if (canonicalId == null) return null;
    final tool = thread.tools[canonicalId];
    if (tool == null || !tool.isRolloutCall) return null;
    final isLateCompletion = notification.method == "item/completed" && tool.status == PluginToolStatus.error;
    final snapshot = _applyAppServerCommand(
      tool: tool,
      item: item,
      completed: notification.method == "item/completed",
      mergeLateOutput: isLateCompletion,
    );
    if (notification.method == "item/completed") {
      thread.appServerItemAliases.remove(itemId);
    }
    return snapshot;
  }

  void prepareRolloutReplay({
    required String threadId,
    required Iterable<CodexRolloutLineDto> lines,
  }) {
    final thread = _threads.putIfAbsent(threadId, _ThreadToolLifecycle.new);
    thread.durableImageResults.addAll([
      for (final line in lines)
        if (line case CodexRolloutEventMessageLineDto(
          payload: CodexRolloutImageGenerationEndEventDto(:final result),
        ) when result.isNotEmpty)
          result,
    ]);
  }

  bool shouldReplayLegacyImage({
    required String threadId,
    required CodexRolloutImageGenerationDto image,
  }) {
    final id = image.id?.trim();
    return (id != null && id.isNotEmpty) || !(_threads[threadId]?.durableImageResults.contains(image.result) ?? false);
  }

  void clearThread({required String threadId}) {
    _threads.remove(threadId);
    _retainedCommandsByThread.remove(threadId);
  }

  /// Settles terminal tools and discards state unless a started item can finish.
  List<CodexProjectedTool> observeTerminalNotification({
    required CodexServerNotification notification,
  }) {
    final threadId = _usefulText(value: notification.params["threadId"]);
    if (threadId == null) return const [];
    final terminalStatus = switch (notification.method) {
      "turn/completed" => _turnCompletionStatus(
        params: notification.params,
      ),
      "error" || "thread/closed" || "thread/status/changed" => PluginToolStatus.error,
      _ => throw ArgumentError.value(
        notification.method,
        "notification.method",
        "Expected a terminal app-server notification",
      ),
    };
    final thread = _threads.remove(threadId);
    final updates = <CodexProjectedTool>[];
    if (thread != null) {
      for (final tool in thread.tools.values) {
        if (!tool.isRolloutCall || tool.status != PluginToolStatus.running) {
          continue;
        }
        tool.status = terminalStatus;
        updates.add(tool.snapshot());
      }
      if (thread.appServerItemAliases.isNotEmpty) {
        final retainedCommands = _retainedCommandsByThread.putIfAbsent(
          threadId,
          () => {},
        );
        for (final MapEntry(key: itemId, value: canonicalId) in thread.appServerItemAliases.entries) {
          final tool = thread.tools[canonicalId];
          if (tool != null) retainedCommands[itemId] = tool;
        }
        if (retainedCommands.isEmpty) {
          _retainedCommandsByThread.remove(threadId);
        }
      }
    }
    return updates;
  }

  void clear() {
    _threads.clear();
    _retainedCommandsByThread.clear();
  }

  List<CodexProjectedTool> _observeRolloutPayload({
    required _ThreadToolLifecycle thread,
    required CodexRolloutResponseItemDto payload,
  }) {
    if (payload case final CodexRolloutImageGenerationDto item) {
      final generation = _rolloutToolMapper.mapImageGeneration(item: item);
      final id = generation.id;
      if (id == null) return const [];
      final tool = thread.tools.putIfAbsent(
        id,
        () => _TrackedTool(
          id: id,
          tool: "image_generation",
          title: null,
          turnId: null,
          chronologySegment: thread.chronologySegment,
          isRolloutCall: false,
        ),
      );
      tool.status = _mergeStatus(
        previous: tool.status,
        current: generation.status,
      );
      _mergeAttachments(
        accumulated: tool.attachments,
        current: generation.attachments,
      );
      return [tool.snapshot()];
    }

    final wait = _rolloutToolMapper.mapWaitCall(payload: payload);
    if (wait != null) {
      thread.internalCalls.add(wait.callId);
      final turnId = wait.turnId ?? thread.activeTurnId;
      final target =
          (turnId == null ? null : thread.visibleCallByCell[_cellKey(turnId: turnId, cellId: wait.cellId)]) ??
          thread.visibleCallByThreadCell[wait.cellId];
      if (target != null) thread.waitTargetByCall[wait.callId] = target;
      thread.waitCellByCall[wait.callId] = wait.cellId;
      return const [];
    }

    final internalCallId = _rolloutToolMapper.internalCallId(payload: payload);
    if (internalCallId != null) {
      thread.internalCalls.add(internalCallId);
      return const [];
    }

    final call = _rolloutToolMapper.mapCall(payload);
    if (call != null) {
      final effectiveTurnId = call.turnId ?? thread.activeTurnId;
      final tool = thread.tools.putIfAbsent(
        call.id,
        () => _TrackedTool(
          id: call.id,
          tool: call.tool,
          title: call.title,
          turnId: effectiveTurnId,
          chronologySegment: thread.chronologySegment,
          isRolloutCall: true,
        ),
      );
      tool.title ??= call.title;
      Map<String, List<String>>? pendingByTurn;
      if (_rolloutToolMapper.isCommandExecutionCall(payload: payload)) {
        pendingByTurn = thread.pendingShellCallsByTurn;
      } else if (_rolloutToolMapper.isSingleCodeModeCommandExecutionCall(
        payload: payload,
      )) {
        pendingByTurn = thread.pendingCodeModeShellCallsByTurn;
      }
      if (effectiveTurnId != null && pendingByTurn != null) {
        final pending = pendingByTurn.putIfAbsent(effectiveTurnId, () => []);
        if (!pending.contains(call.id) && !thread.appServerItemAliases.containsValue(call.id)) {
          pending.add(call.id);
        }
      }
      return [tool.snapshot()];
    }

    final result = _rolloutToolMapper.mapResult(payload);
    if (result == null) return const [];
    final waitTarget = thread.waitTargetByCall[result.callId];
    if (thread.internalCalls.contains(result.callId) && waitTarget == null) {
      return const [];
    }
    final canonicalId = waitTarget ?? result.callId;
    final tool = thread.tools[canonicalId];
    if (tool == null || !tool.isRolloutCall) return const [];

    final cellIds = switch (result) {
      CodexRolloutToolRunningResult(:final cellIds) => cellIds,
      CodexRolloutToolErrorWithRunningCellsResult(:final cellIds) => cellIds,
      CodexRolloutToolCompletedResult() || CodexRolloutToolErrorResult() => const <String>[],
    };
    tool.outstandingCellIds.addAll(cellIds);
    for (final cellId in cellIds) {
      thread.visibleCallByThreadCell[cellId] = canonicalId;
      final turnId = tool.turnId;
      if (turnId != null) {
        thread.visibleCallByCell[_cellKey(turnId: turnId, cellId: cellId)] = canonicalId;
      }
    }

    final waitedCell = thread.waitCellByCall[result.callId];
    if (waitTarget != null &&
        waitedCell != null &&
        (result.status != PluginToolStatus.running || !cellIds.contains(waitedCell))) {
      tool.outstandingCellIds.remove(waitedCell);
    }
    if (result.status != PluginToolStatus.running && waitTarget == null) {
      tool.outstandingCellIds.clear();
    }

    tool.rolloutOutput = _mergeOutput(
      previous: tool.rolloutOutput,
      current: result.output,
    );
    tool.hasRolloutResult = true;
    _mergeAttachments(
      accumulated: tool.attachments,
      current: result.attachments,
    );
    final resultStatus = result.status == PluginToolStatus.completed && tool.outstandingCellIds.isNotEmpty
        ? PluginToolStatus.running
        : result.status;
    tool.status = _mergeStatus(
      previous: tool.status,
      current: resultStatus,
    );
    return [tool.snapshot()];
  }

  List<CodexProjectedTool> _observeRolloutEvent({
    required _ThreadToolLifecycle thread,
    required CodexRolloutEventDto event,
  }) {
    return switch (event) {
      CodexRolloutUserMessageEventDto() =>
        thread.activeTurnId == null ? _advanceChronologySegment(thread: thread) : const [],
      CodexRolloutTaskStartedEventDto(:final turnId) => _startTurn(
        thread: thread,
        turnId: turnId,
      ),
      CodexRolloutTaskCompleteEventDto(:final turnId) => _finishTurn(
        thread: thread,
        turnId: turnId,
        status: PluginToolStatus.completed,
      ),
      CodexRolloutTurnAbortedEventDto(:final turnId) => _finishTurn(
        thread: thread,
        turnId: turnId,
        status: PluginToolStatus.error,
      ),
      CodexRolloutImageGenerationEndEventDto() => _observeImageGenerationEnd(
        thread: thread,
        event: event,
      ),
      CodexRolloutUnknownEventDto() => const [],
    };
  }

  List<CodexProjectedTool> _observeImageGenerationEnd({
    required _ThreadToolLifecycle thread,
    required CodexRolloutImageGenerationEndEventDto event,
  }) {
    final generation = _rolloutToolMapper.mapImageGenerationEnd(event: event);
    final id = generation.id;
    if (id == null) return const [];
    final tool = thread.tools.putIfAbsent(
      id,
      () => _TrackedTool(
        id: id,
        tool: "image_generation",
        title: null,
        turnId: null,
        chronologySegment: thread.chronologySegment,
        isRolloutCall: false,
      ),
    );
    tool.status = _mergeStatus(
      previous: tool.status,
      current: generation.status,
    );
    tool.attachments.clear();
    _mergeAttachments(
      accumulated: tool.attachments,
      current: generation.attachments,
    );
    return [tool.snapshot()];
  }

  List<CodexProjectedTool> _startTurn({
    required _ThreadToolLifecycle thread,
    required String turnId,
  }) {
    final updates = _advanceChronologySegment(thread: thread);
    thread.activeTurnId = _usefulText(value: turnId);
    return updates;
  }

  List<CodexProjectedTool> _advanceChronologySegment({
    required _ThreadToolLifecycle thread,
  }) {
    final updates = <CodexProjectedTool>[];
    for (final tool in thread.tools.values) {
      if (!tool.isRolloutCall ||
          tool.status != PluginToolStatus.running ||
          tool.chronologySegment != thread.chronologySegment) {
        continue;
      }
      tool.status = PluginToolStatus.error;
      updates.add(tool.snapshot());
    }
    thread
      ..chronologySegment += 1
      ..activeTurnId = null;
    _clearCorrelationState(thread: thread);
    return updates;
  }

  List<CodexProjectedTool> _finishTurn({
    required _ThreadToolLifecycle thread,
    required String turnId,
    required PluginToolStatus status,
  }) {
    final usefulTurnId = _usefulText(value: turnId);
    final updates = <CodexProjectedTool>[];
    for (final tool in thread.tools.values) {
      if (!tool.isRolloutCall || tool.status != PluginToolStatus.running) {
        continue;
      }
      final applies = tool.turnId == null
          ? (thread.activeTurnId == null || thread.activeTurnId == usefulTurnId) &&
                tool.chronologySegment == thread.chronologySegment
          : tool.turnId == usefulTurnId;
      if (!applies) continue;
      tool.status = status;
      updates.add(tool.snapshot());
    }
    if (thread.activeTurnId == null || thread.activeTurnId == usefulTurnId) {
      thread
        ..activeTurnId = null
        ..chronologySegment += 1;
      _clearCorrelationState(thread: thread);
    }
    return updates;
  }

  void _clearCorrelationState({required _ThreadToolLifecycle thread}) {
    // A command process can outlive an aborted turn. Its alias retires when the
    // app-server eventually emits `item/completed`.
    thread
      ..pendingShellCallsByTurn.clear()
      ..pendingCodeModeShellCallsByTurn.clear()
      ..visibleCallByCell.clear()
      ..visibleCallByThreadCell.clear()
      ..waitTargetByCall.clear()
      ..waitCellByCall.clear()
      ..internalCalls.clear();
    for (final tool in thread.tools.values) {
      tool.outstandingCellIds.clear();
    }
  }

  PluginToolStatus _appServerStatus({
    required Object? raw,
    required bool completed,
  }) {
    return switch (raw) {
      "failed" || "declined" => PluginToolStatus.error,
      "completed" => PluginToolStatus.completed,
      "inProgress" || "in_progress" => PluginToolStatus.running,
      _ => completed ? PluginToolStatus.completed : PluginToolStatus.running,
    };
  }

  PluginToolStatus _turnCompletionStatus({
    required Map<String, dynamic> params,
  }) {
    final turn = params["turn"];
    final rawStatus = turn is Map ? turn["status"] : null;
    return switch (rawStatus) {
      "failed" || "interrupted" => PluginToolStatus.error,
      _ => PluginToolStatus.completed,
    };
  }

  CodexProjectedTool _applyAppServerCommand({
    required _TrackedTool tool,
    required Map<Object?, Object?> item,
    required bool completed,
    required bool mergeLateOutput,
  }) {
    final command = item["command"];
    tool.title ??= _rolloutToolMapper.logicalCommandTitle(
      command is String ? command : null,
    );
    if (item["aggregatedOutput"] case final String output) {
      final clippedOutput = _rolloutToolMapper.clipOutput(output);
      tool.appServerOutput = clippedOutput;
      if (mergeLateOutput && clippedOutput != null && clippedOutput.isNotEmpty) {
        tool.rolloutOutput = _mergeLateOutput(
          previous: tool.rolloutOutput,
          current: clippedOutput,
        );
      }
    }
    final exitCode = item["exitCode"];
    final status = exitCode is num && exitCode.toInt() != 0
        ? PluginToolStatus.error
        : _appServerStatus(
            raw: item["status"],
            completed: completed,
          );
    tool.status = _mergeStatus(previous: tool.status, current: status);
    return tool.snapshot();
  }

  PluginToolStatus _mergeStatus({
    required PluginToolStatus previous,
    required PluginToolStatus current,
  }) {
    if (previous == PluginToolStatus.error || current == PluginToolStatus.error) {
      return PluginToolStatus.error;
    }
    if (previous == PluginToolStatus.completed || current == PluginToolStatus.completed) {
      return PluginToolStatus.completed;
    }
    return PluginToolStatus.running;
  }

  String? _mergeOutput({
    required String? previous,
    required String? current,
  }) {
    if (previous == null || previous.isEmpty) {
      return _rolloutToolMapper.clipOutput(current);
    }
    if (current == null || current.isEmpty) return previous;
    final currentRunes = current.runes.toList(growable: false);
    if (currentRunes.length >= maxToolOutputLength) {
      return String.fromCharCodes(currentRunes.take(maxToolOutputLength));
    }
    return String.fromCharCodes([
      ...previous.runes.take(maxToolOutputLength - currentRunes.length),
      ...currentRunes,
    ]);
  }

  String? _mergeLateOutput({
    required String? previous,
    required String current,
  }) {
    if (previous == null || previous.isEmpty) {
      return _rolloutToolMapper.clipOutput(current);
    }
    if (previous.endsWith(current)) return previous;
    if (current.contains(previous)) {
      return _rolloutToolMapper.clipOutput(current);
    }
    final outputBoundary = _executorOutputBoundaryPattern.firstMatch(previous);
    if (outputBoundary != null) {
      final previousProcessOutput = previous.substring(outputBoundary.end);
      if (previousProcessOutput.isNotEmpty && current.startsWith(previousProcessOutput)) {
        return _mergeOutput(
          previous: previous,
          current: current.substring(previousProcessOutput.length),
        );
      }
    }
    return _mergeOutput(previous: previous, current: current);
  }

  void _mergeAttachments({
    required List<PluginMessageAttachment> accumulated,
    required Iterable<PluginMessageAttachment> current,
  }) {
    final bounded = _rolloutToolMapper.boundAttachments(
      attachments: [...accumulated, ...current],
    );
    accumulated
      ..clear()
      ..addAll(bounded);
  }

  String _cellKey({required String turnId, required String cellId}) => "$turnId\u0000$cellId";

  String? _usefulText({required Object? value}) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ThreadToolLifecycle {
  final Map<String, _TrackedTool> tools = {};
  final Map<String, List<String>> pendingShellCallsByTurn = {};
  final Map<String, List<String>> pendingCodeModeShellCallsByTurn = {};
  final Map<String, String> visibleCallByCell = {};
  final Map<String, String> visibleCallByThreadCell = {};
  final Map<String, String> waitTargetByCall = {};
  final Map<String, String> waitCellByCall = {};
  final Set<String> internalCalls = {};
  final Map<String, String> appServerItemAliases = {};
  final Set<String> durableImageResults = {};

  String? activeTurnId;
  int chronologySegment = 0;
}

class _TrackedTool {
  _TrackedTool({
    required this.id,
    required this.tool,
    required this.title,
    required this.turnId,
    required this.chronologySegment,
    required this.isRolloutCall,
  });

  final String id;
  final String tool;
  String? title;
  final String? turnId;
  final int chronologySegment;
  final bool isRolloutCall;
  PluginToolStatus status = PluginToolStatus.running;
  String? rolloutOutput;
  String? appServerOutput;
  bool hasRolloutResult = false;
  final List<PluginMessageAttachment> attachments = [];
  final Set<String> outstandingCellIds = {};

  CodexProjectedTool snapshot() => CodexProjectedTool(
    canonicalId: id,
    tool: tool,
    title: title,
    status: status,
    output: rolloutOutput ?? appServerOutput,
    attachments: attachments,
  );
}
