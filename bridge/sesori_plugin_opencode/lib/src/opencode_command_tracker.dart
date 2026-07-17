import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "models/openapi/agent_part.g.dart";
import "models/openapi/assistant_message.g.dart";
import "models/openapi/compaction_part.g.dart";
import "models/openapi/file_part.g.dart";
import "models/openapi/message.g.dart";
import "models/openapi/part.g.dart";
import "models/openapi/patch_part.g.dart";
import "models/openapi/reasoning_part.g.dart";
import "models/openapi/retry_part.g.dart";
import "models/openapi/snapshot_part.g.dart";
import "models/openapi/step_finish_part.g.dart";
import "models/openapi/step_start_part.g.dart";
import "models/openapi/subtask_part.g.dart";
import "models/openapi/text_part.g.dart";
import "models/openapi/tool_part.g.dart";
import "models/openapi/user_message.g.dart";

/// Correlation state derived from OpenCode command dispatches and SSE events.
///
/// This class deliberately constructs no plugin messages or bridge events.
/// [OpenCodeCommandMapper] owns those pure transformations; the tracker only
/// records which backend messages belong to one command invocation.
class OpenCodeCommandTracker {
  final Map<String, List<OpenCodePendingCommand>> _pendingBySession = {};
  final Map<String, UserMessage> _heldUsers = {};
  final Set<String> _releasedUsers = {};
  final Set<String> _emittedTriggers = {};
  final Map<String, String> _suppressedGuidanceSessions = {};
  final Map<String, OpenCodeTrackedCommand> _commandsByTrigger = {};
  final Map<String, String> _resultToTrigger = {};
  final Map<String, Set<String>> _partIdsByResult = {};

  void registerDispatch({
    required String sessionId,
    required String invocationId,
    required String name,
    required String arguments,
    required String? backendMessageId,
  }) {
    if (!_isCompact(name)) {
      if (backendMessageId == null) {
        throw ArgumentError.notNull("backendMessageId");
      }
      _commandsByTrigger[backendMessageId] = OpenCodeTrackedCommand(
        triggerMessageId: backendMessageId,
        sessionId: sessionId,
        name: name,
        arguments: arguments,
        origin: PluginCommandOrigin.manual,
        invocationId: invocationId,
        time: null,
        isCompaction: false,
      );
      return;
    }
    (_pendingBySession[sessionId] ??= []).add(
      OpenCodePendingCommand(
        sessionId: sessionId,
        invocationId: invocationId,
        name: name,
        arguments: arguments,
      ),
    );
  }

  void cancelDispatch({required String sessionId, required String invocationId}) {
    final pending = _pendingBySession[sessionId];
    pending?.removeWhere((command) => command.invocationId == invocationId);
    if (pending?.isEmpty ?? false) _pendingBySession.remove(sessionId);
    final triggerIds = _commandsByTrigger.entries
        .where((entry) => entry.value.invocationId == invocationId && entry.value.sessionId == sessionId)
        .map((entry) => entry.key)
        .toSet();
    triggerIds.forEach(forgetMessage);
  }

  bool hasPendingDispatch({required String sessionId, required String invocationId}) {
    return _pendingBySession[sessionId]?.any((command) => command.invocationId == invocationId) ?? false;
  }

  /// Records a message envelope. User envelopes are held until their first
  /// part identifies them as an ordinary prompt, compaction guidance, or the
  /// compaction trigger itself.
  void observeMessage(Message message) {
    switch (message) {
      case UserMessage():
        _heldUsers[message.id] = message;
        final command = _commandsByTrigger[message.id];
        if (command != null) {
          _commandsByTrigger[message.id] = command.copyWith(
            time: PluginMessageTime(
              created: message.time.created.toInt(),
              completed: null,
            ),
          );
        }
      case AssistantMessage():
        final command = _commandsByTrigger[message.parentID];
        if (command == null) return;
        if (command.isCompaction &&
            message.error == null &&
            (message.summary != true || message.mode != "compaction")) {
          return;
        }
        _resultToTrigger[message.id] = command.triggerMessageId;
      default:
        return;
    }
  }

  /// Records a message part and completes any correlation that depends on its
  /// typed backend semantics.
  void observePart(Part part) {
    if (part case CompactionPart(:final auto)) {
      final trigger = _heldUsers[part.messageID];
      if (trigger == null) return;
      final pending = auto ? null : _firstPendingCompact(part.sessionID);
      final command = OpenCodeTrackedCommand(
        triggerMessageId: trigger.id,
        sessionId: trigger.sessionID,
        name: "compact",
        arguments: pending?.arguments,
        origin: auto ? PluginCommandOrigin.automatic : PluginCommandOrigin.manual,
        invocationId: pending?.invocationId,
        time: PluginMessageTime(
          created: trigger.time.created.toInt(),
          completed: null,
        ),
        isCompaction: true,
      );
      _commandsByTrigger[trigger.id] = command;
      if (pending != null) _removePending(pending);
      return;
    }

    final messageId = _partMessageId(part);
    if (messageId == null) return;
    final partId = _partId(part);
    if (partId != null && _resultToTrigger.containsKey(messageId)) {
      (_partIdsByResult[messageId] ??= {}).add(partId);
    }
    final user = _heldUsers[messageId];
    if (user == null || _releasedUsers.contains(user.id)) return;
    final pending = _firstPendingCompact(user.sessionID);
    if (part case TextPart(
      :final text,
    ) when pending != null && pending.arguments.isNotEmpty && text == pending.arguments.trim()) {
      _heldUsers.remove(user.id);
      _releasedUsers.remove(user.id);
      _suppressedGuidanceSessions[user.id] = user.sessionID;
      return;
    }
    _releasedUsers.add(user.id);
  }

  OpenCodeTrackedCommand? takeCommandTrigger(String messageId) {
    final command = _commandsByTrigger[messageId];
    if (command == null || !_emittedTriggers.add(messageId)) return null;
    _heldUsers.remove(messageId);
    return command;
  }

  UserMessage? takeReleasedUser(String messageId) {
    if (!_releasedUsers.remove(messageId)) return null;
    return _heldUsers.remove(messageId);
  }

  bool isGuidanceSuppressed(String messageId) => _suppressedGuidanceSessions.containsKey(messageId);

  OpenCodeTrackedCommand? commandForTrigger(String messageId) => _commandsByTrigger[messageId];

  OpenCodeTrackedCommand? commandForResult(String messageId) {
    final triggerId = _resultToTrigger[messageId];
    return triggerId == null ? null : _commandsByTrigger[triggerId];
  }

  void observePartDelta({required String messageId, required String partId}) {
    if (_resultToTrigger.containsKey(messageId)) {
      (_partIdsByResult[messageId] ??= {}).add(partId);
    }
  }

  List<String> partIdsForResult({required String messageId}) {
    return List<String>.unmodifiable(
      _partIdsByResult[messageId] ?? const <String>{},
    );
  }

  void forgetMessage(String messageId) {
    _heldUsers.remove(messageId);
    _releasedUsers.remove(messageId);
    _emittedTriggers.remove(messageId);
    _suppressedGuidanceSessions.remove(messageId);
    final command = _commandsByTrigger.remove(messageId);
    if (command != null) {
      final resultIds = _resultToTrigger.entries
          .where((entry) => entry.value == messageId)
          .map((entry) => entry.key)
          .toList();
      _resultToTrigger.removeWhere((_, triggerId) => triggerId == messageId);
      resultIds.forEach(_partIdsByResult.remove);
    } else {
      _resultToTrigger.remove(messageId);
      _partIdsByResult.remove(messageId);
    }
  }

  void forgetSession(String sessionId) {
    _pendingBySession.remove(sessionId);
    final userIds = _heldUsers.entries
        .where((entry) => entry.value.sessionID == sessionId)
        .map((entry) => entry.key)
        .toList();
    for (final userId in userIds) {
      _heldUsers.remove(userId);
      _releasedUsers.remove(userId);
      _emittedTriggers.remove(userId);
    }
    _suppressedGuidanceSessions.removeWhere((_, ownerSessionId) => ownerSessionId == sessionId);
    final triggerIds = _commandsByTrigger.entries
        .where((entry) => entry.value.sessionId == sessionId)
        .map((entry) => entry.key)
        .toSet();
    _commandsByTrigger.removeWhere((_, command) => command.sessionId == sessionId);
    _emittedTriggers.removeAll(triggerIds);
    final resultIds = _resultToTrigger.entries
        .where((entry) => triggerIds.contains(entry.value))
        .map((entry) => entry.key)
        .toList();
    _resultToTrigger.removeWhere((_, triggerId) => triggerIds.contains(triggerId));
    resultIds.forEach(_partIdsByResult.remove);
  }

  OpenCodePendingCommand? _firstPendingCompact(String sessionId) {
    final pending = _pendingBySession[sessionId];
    if (pending == null) return null;
    for (final command in pending) {
      if (_isCompact(command.name)) return command;
    }
    return null;
  }

  void _removePending(OpenCodePendingCommand command) {
    final pending = _pendingBySession[command.sessionId];
    pending?.remove(command);
    if (pending?.isEmpty ?? false) _pendingBySession.remove(command.sessionId);
  }

  static bool _isCompact(String name) => name == "compact" || name == "/compact";

  static String? _partMessageId(Part part) => switch (part) {
    AgentPart(:final messageID) ||
    CompactionPart(:final messageID) ||
    FilePart(:final messageID) ||
    PatchPart(:final messageID) ||
    ReasoningPart(:final messageID) ||
    RetryPart(:final messageID) ||
    SnapshotPart(:final messageID) ||
    StepFinishPart(:final messageID) ||
    StepStartPart(:final messageID) ||
    SubtaskPart(:final messageID) ||
    TextPart(:final messageID) ||
    ToolPart(:final messageID) => messageID,
    PartUnknown() => null,
    _ => null,
  };

  static String? _partId(Part part) => switch (part) {
    AgentPart(:final id) ||
    CompactionPart(:final id) ||
    FilePart(:final id) ||
    PatchPart(:final id) ||
    ReasoningPart(:final id) ||
    RetryPart(:final id) ||
    SnapshotPart(:final id) ||
    StepFinishPart(:final id) ||
    StepStartPart(:final id) ||
    SubtaskPart(:final id) ||
    TextPart(:final id) ||
    ToolPart(:final id) => id,
    PartUnknown() => null,
    _ => null,
  };
}

class OpenCodePendingCommand {
  const OpenCodePendingCommand({
    required this.sessionId,
    required this.invocationId,
    required this.name,
    required this.arguments,
  });

  final String sessionId;
  final String invocationId;
  final String name;
  final String arguments;
}

class OpenCodeTrackedCommand {
  const OpenCodeTrackedCommand({
    required this.triggerMessageId,
    required this.sessionId,
    required this.name,
    required this.arguments,
    required this.origin,
    required this.invocationId,
    required this.time,
    required this.isCompaction,
  });

  final String triggerMessageId;
  final String sessionId;
  final String name;
  final String? arguments;
  final PluginCommandOrigin origin;
  final String? invocationId;
  final PluginMessageTime? time;
  final bool isCompaction;

  OpenCodeTrackedCommand copyWith({required PluginMessageTime? time}) {
    return OpenCodeTrackedCommand(
      triggerMessageId: triggerMessageId,
      sessionId: sessionId,
      name: name,
      arguments: arguments,
      origin: origin,
      invocationId: invocationId,
      time: time,
      isCompaction: isCompaction,
    );
  }
}
