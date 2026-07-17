import "dart:collection";

enum CodexCommandInvocationPhase { pending, active }

/// State derived from Codex command dispatches and turn/item notifications.
///
/// The tracker deliberately creates no plugin messages or bridge events.
class CodexCommandInvocationTracker {
  final Map<String, _MutableInvocation> _pendingByThread = {};
  final Map<String, _MutableInvocation> _activeByThread = {};
  final Map<String, _MutableInvocation> _activeByTurn = {};
  var _nextSyntheticId = 0;

  CodexCommandInvocationSnapshot register({
    required String threadId,
    required String invocationId,
    required String command,
    required String arguments,
  }) {
    if (_pendingByThread.containsKey(threadId) || _activeByThread.containsKey(threadId)) {
      throw CodexCommandAlreadyOutstandingException(threadId: threadId);
    }
    final normalizedCommand = command.startsWith("/") ? command.substring(1) : command;
    final invocation = _MutableInvocation(
      threadId: threadId,
      invocationId: invocationId,
      command: normalizedCommand,
      arguments: arguments.isEmpty ? null : arguments,
      syntheticMessageId: "codex-command-${_nextSyntheticId++}",
    );
    _pendingByThread[threadId] = invocation;
    return invocation.snapshot(CodexCommandInvocationPhase.pending);
  }

  CodexCommandInvocationSnapshot? bindReturnedTurn({
    required String threadId,
    required String invocationId,
    required String turnId,
  }) {
    final byTurn = _activeByTurn[turnId];
    if (byTurn != null) return byTurn.snapshot(CodexCommandInvocationPhase.active);

    final byThread = _activeByThread[threadId];
    if (byThread != null) {
      if (byThread.turnId == turnId) {
        return byThread.snapshot(CodexCommandInvocationPhase.active);
      }
      return null;
    }

    final pending = _pendingByThread[threadId];
    if (pending == null || pending.invocationId != invocationId) return null;
    final invocation = pending..turnId = turnId;
    _pendingByThread.remove(threadId);
    _activeByThread[threadId] = invocation;
    _activeByTurn[turnId] = invocation;
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? pendingForThread({required String threadId}) {
    final pending = _pendingByThread[threadId];
    return pending?.snapshot(CodexCommandInvocationPhase.pending);
  }

  CodexCommandInvocationSnapshot? activeFor({
    required String threadId,
    required String? turnId,
  }) {
    final invocation = turnId == null ? _activeByThread[threadId] : _activeByTurn[turnId];
    if (invocation == null || invocation.threadId != threadId) return null;
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot markCommandEmitted({required String turnId}) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) throw StateError("No active Codex command for turn $turnId");
    invocation.commandEmitted = true;
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? recordUserMessage({
    required String turnId,
    required String messageId,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    invocation.userMessageId = messageId;
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? recordResult({
    required String turnId,
    required String messageId,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    invocation.resultMessageId ??= messageId;
    invocation.resultPartIds.putIfAbsent(messageId, () => <String>{});
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? recordResultPart({
    required String turnId,
    required String messageId,
    required String partId,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    invocation.resultMessageId ??= messageId;
    (invocation.resultPartIds[messageId] ??= <String>{}).add(partId);
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? removeResultPart({
    required String turnId,
    required String messageId,
    required String partId,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    final partIds = invocation.resultPartIds[messageId];
    partIds?.remove(partId);
    if (partIds?.isEmpty ?? false) invocation.resultPartIds.remove(messageId);
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? appendResultText({
    required String turnId,
    required String messageId,
    required String delta,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    invocation.resultMessageId ??= messageId;
    invocation.resultTexts[messageId] = (invocation.resultTexts[messageId] ?? "") + delta;
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexCommandInvocationSnapshot? replaceResultText({
    required String turnId,
    required String messageId,
    required String text,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    invocation.resultMessageId ??= messageId;
    invocation.resultTexts[messageId] = text;
    return invocation.snapshot(CodexCommandInvocationPhase.active);
  }

  CodexRemovedCommandResult? removeResult({
    required String turnId,
    required String messageId,
  }) {
    final invocation = _activeByTurn[turnId];
    if (invocation == null) return null;
    final removedText = invocation.resultTexts.remove(messageId);
    final removedPartIds = invocation.resultPartIds.remove(messageId) ?? const <String>{};
    return CodexRemovedCommandResult(
      invocation: invocation.snapshot(CodexCommandInvocationPhase.active),
      hadDisplayText: removedText != null,
      partIds: Set.unmodifiable(removedPartIds),
    );
  }

  void reject({required String threadId, required String invocationId}) {
    final pending = _pendingByThread[threadId];
    if (pending?.invocationId == invocationId) _pendingByThread.remove(threadId);

    final active = _activeByThread[threadId];
    if (active?.invocationId == invocationId) _removeActive(active!);
  }

  CodexCommandInvocationSnapshot? complete({
    required String threadId,
    required String? turnId,
  }) {
    final invocation = turnId == null ? _activeByThread[threadId] : _activeByTurn[turnId];
    if (invocation == null || invocation.threadId != threadId) return null;
    final snapshot = invocation.snapshot(CodexCommandInvocationPhase.active);
    _removeActive(invocation);
    return snapshot;
  }

  void forgetThread({required String threadId}) {
    _pendingByThread.remove(threadId);
    final active = _activeByThread[threadId];
    if (active != null) _removeActive(active);
  }

  /// Drops connection-scoped invocations without reusing synthetic IDs.
  void reset() {
    _pendingByThread.clear();
    _activeByThread.clear();
    _activeByTurn.clear();
  }

  void _removeActive(_MutableInvocation invocation) {
    _activeByThread.remove(invocation.threadId);
    final turnId = invocation.turnId;
    if (turnId != null) _activeByTurn.remove(turnId);
  }
}

class CodexCommandAlreadyOutstandingException implements Exception {
  const CodexCommandAlreadyOutstandingException({required this.threadId});

  final String threadId;

  @override
  String toString() => "Codex thread $threadId already has an outstanding command";
}

class CodexCommandInvocationSnapshot {
  const CodexCommandInvocationSnapshot({
    required this.phase,
    required this.threadId,
    required this.turnId,
    required this.commandMessageId,
    required this.invocationId,
    required this.command,
    required this.arguments,
    required this.userMessageId,
    required this.resultMessageId,
    required this.resultText,
    required this.resultPartIds,
    required this.commandEmitted,
  });

  final CodexCommandInvocationPhase phase;
  final String threadId;
  final String? turnId;
  final String commandMessageId;
  final String invocationId;
  final String command;
  final String? arguments;
  final String? userMessageId;
  final String? resultMessageId;
  final String? resultText;
  final Map<String, Set<String>> resultPartIds;
  final bool commandEmitted;

  String get expectedUserText => arguments == null ? "/$command" : "/$command $arguments";
}

class CodexRemovedCommandResult {
  const CodexRemovedCommandResult({
    required this.invocation,
    required this.hadDisplayText,
    required this.partIds,
  });

  final CodexCommandInvocationSnapshot invocation;
  final bool hadDisplayText;
  final Set<String> partIds;
}

class _MutableInvocation {
  _MutableInvocation({
    required this.threadId,
    required this.invocationId,
    required this.command,
    required this.arguments,
    required this.syntheticMessageId,
  });

  final String threadId;
  final String invocationId;
  final String command;
  final String? arguments;
  final String syntheticMessageId;
  String? turnId;
  String? userMessageId;
  String? resultMessageId;
  bool commandEmitted = false;
  final LinkedHashMap<String, String> resultTexts = LinkedHashMap();
  final Map<String, Set<String>> resultPartIds = {};

  CodexCommandInvocationSnapshot snapshot(CodexCommandInvocationPhase phase) {
    final displayTexts = resultTexts.values.where((text) => text.isNotEmpty).toList(growable: false);
    return CodexCommandInvocationSnapshot(
      phase: phase,
      threadId: threadId,
      turnId: turnId,
      commandMessageId: turnId ?? syntheticMessageId,
      invocationId: invocationId,
      command: command,
      arguments: arguments,
      userMessageId: userMessageId,
      resultMessageId: resultMessageId,
      resultText: displayTexts.isEmpty ? null : displayTexts.join("\n\n"),
      resultPartIds: Map.unmodifiable({
        for (final entry in resultPartIds.entries) entry.key: Set.unmodifiable(entry.value),
      }),
      commandEmitted: commandEmitted,
    );
  }
}
