import "dart:collection";

import "package:sesori_shared/sesori_shared.dart"
    show CommandOrigin, MessagePart, MessagePartType, MessageTime, MessageWithParts;

import "accepted_command_invocation.dart";

sealed class CommandTimelineCandidate {
  final String pluginId;
  final String sessionId;

  const CommandTimelineCandidate({required this.pluginId, required this.sessionId});

  String get backendMessageId;
}

class CommandMessageTimelineCandidate extends CommandTimelineCandidate {
  @override
  final String backendMessageId;
  final String? invocationId;
  final String name;
  final String? arguments;
  final CommandOrigin origin;
  final MessageTime? time;
  final List<MessagePart> resultParts;

  CommandMessageTimelineCandidate({
    required super.pluginId,
    required super.sessionId,
    required this.backendMessageId,
    required this.invocationId,
    required this.name,
    required this.arguments,
    required this.origin,
    required this.time,
    required Iterable<MessagePart> resultParts,
  }) : resultParts = List.unmodifiable(resultParts);
}

class CommandResultPartTimelineCandidate extends CommandTimelineCandidate {
  @override
  final String backendMessageId;
  final String backendPartId;
  final MessagePart? part;

  const CommandResultPartTimelineCandidate({
    required super.pluginId,
    required super.sessionId,
    required this.backendMessageId,
    required this.backendPartId,
    required this.part,
  });
}

class CommandResultPartDeltaTimelineCandidate extends CommandTimelineCandidate {
  @override
  final String backendMessageId;
  final String backendPartId;
  final String field;
  final String delta;

  const CommandResultPartDeltaTimelineCandidate({
    required super.pluginId,
    required super.sessionId,
    required this.backendMessageId,
    required this.backendPartId,
    required this.field,
    required this.delta,
  });
}

class CommandResultPartRemovedTimelineCandidate extends CommandTimelineCandidate {
  @override
  final String backendMessageId;
  final String backendPartId;

  const CommandResultPartRemovedTimelineCandidate({
    required super.pluginId,
    required super.sessionId,
    required this.backendMessageId,
    required this.backendPartId,
  });
}

class CommandHistory {
  final String sessionId;
  final List<CommandHistoryEntry> entries;

  CommandHistory({required this.sessionId, required Iterable<CommandHistoryEntry> entries})
    : entries = List.unmodifiable(entries);
}

sealed class CommandHistoryEntry {
  final int sourceOrder;
  final int? sortTime;

  const CommandHistoryEntry({required this.sourceOrder, required this.sortTime});
}

class StandardCommandHistoryEntry extends CommandHistoryEntry {
  final MessageWithParts message;

  const StandardCommandHistoryEntry({
    required super.sourceOrder,
    required super.sortTime,
    required this.message,
  });
}

class CandidateCommandHistoryEntry extends CommandHistoryEntry {
  final CommandMessageTimelineCandidate candidate;

  const CandidateCommandHistoryEntry({
    required super.sourceOrder,
    required super.sortTime,
    required this.candidate,
  });
}

enum CommandInvocationTrackingDisposition { ready, held, ignored, unmatched }

class CommandInvocationSnapshot {
  final String pluginId;
  final String sessionId;
  final String? invocationId;
  final String canonicalMessageId;
  final String? backendMessageId;
  final AcceptedCommandInvocation? acceptedInvocation;
  final Map<String, MessagePartType> backendPartTypes;

  CommandInvocationSnapshot({
    required this.pluginId,
    required this.sessionId,
    required this.invocationId,
    required this.canonicalMessageId,
    required this.backendMessageId,
    required this.acceptedInvocation,
    required Map<String, MessagePartType> backendPartTypes,
  }) : backendPartTypes = UnmodifiableMapView(Map.of(backendPartTypes));
}

class CommandCandidateTrackingResult {
  final CommandInvocationTrackingDisposition disposition;
  final CommandInvocationSnapshot? snapshot;

  const CommandCandidateTrackingResult({required this.disposition, required this.snapshot});
}

class CommandAcceptanceTrackingResult {
  final CommandInvocationSnapshot snapshot;
  final List<CommandTimelineCandidate> heldCandidates;

  CommandAcceptanceTrackingResult({
    required this.snapshot,
    required Iterable<CommandTimelineCandidate> heldCandidates,
  }) : heldCandidates = List.unmodifiable(heldCandidates);
}
