import "dart:async";
import "dart:collection";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart"
    show CommandOrigin, MessagePart, MessagePartType, MessageTime, MessageWithParts;

import "../repositories/command_invocation_repository.dart";
import "../repositories/command_invocation_tracker.dart";
import "../repositories/mappers/command_message_mapper.dart";
import "../repositories/models/accepted_command_invocation.dart";
import "../repositories/models/command_timeline.dart";
import "../repositories/session_repository.dart";
import "command_dispatch_outcome.dart";
import "command_timeline_mutation.dart";

typedef _LiveCommandKey = ({String sessionId, String messageId});

class CommandTimelineLiveResult {
  final bool handled;
  final List<CommandTimelineMutation> mutations;

  CommandTimelineLiveResult({required this.handled, required Iterable<CommandTimelineMutation> mutations})
    : mutations = List.unmodifiable(mutations);
}

class CommandTimelineService {
  static const CommandMessageMapper _commandMapper = CommandMessageMapper();

  final SessionRepository _sessionRepository;
  final CommandInvocationRepository _invocationRepository;
  final CommandInvocationTracker _tracker;
  final Map<String, MessageWithParts> _liveCards = <String, MessageWithParts>{};
  final Map<_LiveCommandKey, LinkedHashMap<String, MessagePart>> _liveTextResultParts = {};
  Future<void> _liveTail = Future<void>.value();
  Future<void>? _initialization;

  CommandTimelineService({
    required SessionRepository sessionRepository,
    required CommandInvocationRepository invocationRepository,
    required CommandInvocationTracker tracker,
  }) : _sessionRepository = sessionRepository,
       _invocationRepository = invocationRepository,
       _tracker = tracker;

  Future<void> initialize() {
    return _initialization ??= _loadPersistedInvocations();
  }

  void forgetSession({required String sessionId}) {
    _tracker.forgetSession(pluginId: _sessionRepository.pluginId, sessionId: sessionId);
    _liveCards.removeWhere((_, card) => card.info.sessionID == sessionId);
    _liveTextResultParts.removeWhere((key, _) => key.sessionId == sessionId);
  }

  Future<void> _loadPersistedInvocations() async {
    final invocations = await _invocationRepository.getForPlugin(pluginId: _sessionRepository.pluginId);
    _tracker.seed(invocations: invocations);
  }

  Future<List<MessageWithParts>> getSessionMessages({required String sessionId}) async {
    final stableSessionId = await _sessionRepository.resolveStableSessionId(backendSessionId: sessionId);
    final acceptedInvocations = await _invocationRepository.getForSession(
      pluginId: _sessionRepository.pluginId,
      sessionId: stableSessionId,
    );
    _tracker.seed(invocations: acceptedInvocations);
    final history = await _sessionRepository.getCommandHistory(
      sessionId: sessionId,
      acceptedInvocations: acceptedInvocations,
    );
    final entries = <String, _TimelineEntry>{};

    for (var index = 0; index < acceptedInvocations.length; index++) {
      final invocation = acceptedInvocations[index];
      final tracked = _tracker.accept(invocation: invocation);
      entries[tracked.snapshot.canonicalMessageId] = _TimelineEntry(
        message: _acceptedCard(invocation: invocation, snapshot: tracked.snapshot),
        sortTime: invocation.acceptedAt,
        sourceOrder: history.entries.length + index,
      );
    }

    for (final historyEntry in history.entries) {
      switch (historyEntry) {
        case StandardCommandHistoryEntry(:final message):
          entries["plugin:${message.info.id}:${historyEntry.sourceOrder}"] = _TimelineEntry(
            message: message,
            sortTime: historyEntry.sortTime,
            sourceOrder: historyEntry.sourceOrder,
          );
        case CandidateCommandHistoryEntry(:final candidate):
          final tracked = _tracker.track(candidate: candidate);
          if (tracked.disposition != CommandInvocationTrackingDisposition.ready) continue;
          final snapshot = await _persistLearnedCorrelation(
            snapshot: tracked.snapshot!,
            backendMessageId: candidate.backendMessageId,
          );
          _recordTextResultParts(snapshot: snapshot, parts: candidate.resultParts);
          final next = _candidateCard(candidate: candidate, snapshot: snapshot);
          entries[snapshot.canonicalMessageId] = _TimelineEntry(
            message: _mergeCards(previous: entries[snapshot.canonicalMessageId]?.message, next: next),
            sortTime: snapshot.acceptedInvocation?.acceptedAt ?? historyEntry.sortTime,
            sourceOrder: historyEntry.sourceOrder,
          );
      }
    }

    final ordered = entries.values.toList(growable: false)..sort(_compareEntries);
    return [for (final entry in ordered) entry.message];
  }

  Future<CommandTimelineLiveResult> canonicalizeDispatchOutcome({required CommandDispatchOutcome outcome}) {
    return _serializedLive(() => _canonicalizeDispatchOutcome(outcome));
  }

  Future<CommandTimelineLiveResult> canonicalizePluginCandidate({required CommandTimelineCandidate candidate}) {
    return _serializedLive(() => _canonicalizePluginCandidate(candidate));
  }

  Future<CommandTimelineLiveResult> _canonicalizeDispatchOutcome(CommandDispatchOutcome outcome) async {
    switch (outcome) {
      case AcceptedCommandDispatchOutcome(:final invocation):
        final accepted = _tracker.accept(invocation: invocation);
        var card = _mergeCards(
          previous: _liveCards[accepted.snapshot.canonicalMessageId],
          next: _acceptedCard(invocation: invocation, snapshot: accepted.snapshot),
        );
        final trailingMutations = <CommandTimelineMutation>[];
        var commandRemoved = false;
        for (final candidate in accepted.heldCandidates) {
          final tracked = _tracker.track(candidate: candidate);
          if (tracked.disposition != CommandInvocationTrackingDisposition.ready) continue;
          final snapshot = candidate is CommandMessageRemovedTimelineCandidate
              ? tracked.snapshot!
              : await _snapshotWithPersistedCorrelation(candidate: candidate, tracked: tracked);
          switch (candidate) {
            case final CommandMessageTimelineCandidate message:
              _recordTextResultParts(snapshot: snapshot, parts: message.resultParts);
              card = _mergeCards(
                previous: card,
                next: _candidateCard(candidate: message, snapshot: snapshot),
              );
            case CommandMessageRemovedTimelineCandidate():
              commandRemoved = true;
              await _deleteAcceptedInvocation(snapshot);
              trailingMutations.add(_messageRemovedMutation(snapshot));
            case final CommandResultPartTimelineCandidate part:
              if (part.part != null) {
                final mapped = _mapLiveResultPart(candidate: part, snapshot: snapshot);
                card = _mergePart(
                  card: card,
                  part: mapped,
                );
              }
            case final CommandResultPartDeltaTimelineCandidate delta:
              final mutation = _liveDeltaMutation(candidate: delta, snapshot: snapshot);
              trailingMutations.add(mutation);
              if (mutation case CommandTimelinePartUpdated(:final part)) {
                card = _mergePart(card: card, part: part);
              }
            case final CommandResultPartRemovedTimelineCandidate removed:
              final mutation = _liveRemovalMutation(candidate: removed, snapshot: snapshot);
              switch (mutation) {
                case CommandTimelinePartUpdated(:final part):
                  card = _mergePart(card: card, part: part);
                case CommandTimelinePartRemoved(:final partId):
                  card = _removePart(card: card, partId: partId);
                case CommandTimelineEnvelopeUpdated() || CommandTimelineMessageRemoved() || CommandTimelinePartDelta():
                  throw StateError("Unexpected command removal mutation");
              }
          }
        }
        if (commandRemoved) {
          _forgetLiveCommand(accepted.snapshot);
        } else {
          _liveCards[accepted.snapshot.canonicalMessageId] = card;
        }
        return CommandTimelineLiveResult(
          handled: true,
          mutations: [..._cardMutations(card), ...trailingMutations],
        );
      case RejectedCommandDispatchOutcome():
        _tracker.reject(
          pluginId: outcome.pluginId,
          sessionId: outcome.sessionId,
          invocationId: outcome.invocationId,
        );
        return CommandTimelineLiveResult(handled: true, mutations: const []);
    }
  }

  Future<CommandTimelineLiveResult> _canonicalizePluginCandidate(CommandTimelineCandidate candidate) async {
    final tracked = _tracker.track(candidate: candidate);
    switch (tracked.disposition) {
      case CommandInvocationTrackingDisposition.unmatched:
        return CommandTimelineLiveResult(handled: false, mutations: const []);
      case CommandInvocationTrackingDisposition.held || CommandInvocationTrackingDisposition.ignored:
        return CommandTimelineLiveResult(handled: true, mutations: const []);
      case CommandInvocationTrackingDisposition.ready:
        final snapshot = candidate is CommandMessageRemovedTimelineCandidate
            ? tracked.snapshot!
            : await _snapshotWithPersistedCorrelation(candidate: candidate, tracked: tracked);
        switch (candidate) {
          case final CommandMessageTimelineCandidate message:
            _recordTextResultParts(snapshot: snapshot, parts: message.resultParts);
            final card = _mergeCards(
              previous: _liveCards[snapshot.canonicalMessageId],
              next: _candidateCard(candidate: message, snapshot: snapshot),
            );
            _liveCards[snapshot.canonicalMessageId] = card;
            return CommandTimelineLiveResult(handled: true, mutations: _cardMutations(card));
          case CommandMessageRemovedTimelineCandidate():
            await _deleteAcceptedInvocation(snapshot);
            _forgetLiveCommand(snapshot);
            return CommandTimelineLiveResult(
              handled: true,
              mutations: [_messageRemovedMutation(snapshot)],
            );
          case final CommandResultPartTimelineCandidate part:
            if (part.part == null) {
              return CommandTimelineLiveResult(handled: true, mutations: const []);
            }
            final mapped = _mapLiveResultPart(candidate: part, snapshot: snapshot);
            final existing = _liveCards[snapshot.canonicalMessageId];
            if (existing != null) _liveCards[snapshot.canonicalMessageId] = _mergePart(card: existing, part: mapped);
            return CommandTimelineLiveResult(
              handled: true,
              mutations: [CommandTimelinePartUpdated(part: mapped)],
            );
          case final CommandResultPartDeltaTimelineCandidate delta:
            final mutation = _liveDeltaMutation(candidate: delta, snapshot: snapshot);
            if (mutation case CommandTimelinePartUpdated(:final part)) {
              final existing = _liveCards[snapshot.canonicalMessageId];
              if (existing != null) _liveCards[snapshot.canonicalMessageId] = _mergePart(card: existing, part: part);
            }
            return CommandTimelineLiveResult(
              handled: true,
              mutations: [mutation],
            );
          case final CommandResultPartRemovedTimelineCandidate removed:
            final mutation = _liveRemovalMutation(candidate: removed, snapshot: snapshot);
            final existing = _liveCards[snapshot.canonicalMessageId];
            if (existing != null) {
              _liveCards[snapshot.canonicalMessageId] = switch (mutation) {
                CommandTimelinePartUpdated(:final part) => _mergePart(card: existing, part: part),
                CommandTimelinePartRemoved(:final partId) => _removePart(card: existing, partId: partId),
                CommandTimelineEnvelopeUpdated() ||
                CommandTimelineMessageRemoved() ||
                CommandTimelinePartDelta() => throw StateError(
                  "Unexpected command removal mutation",
                ),
              };
            }
            return CommandTimelineLiveResult(
              handled: true,
              mutations: [mutation],
            );
        }
    }
  }

  Future<CommandInvocationSnapshot> _snapshotWithPersistedCorrelation({
    required CommandTimelineCandidate candidate,
    required CommandCandidateTrackingResult tracked,
  }) {
    final snapshot = tracked.snapshot!;
    final backendMessageId = candidate.backendMessageId;
    return _persistLearnedCorrelation(snapshot: snapshot, backendMessageId: backendMessageId);
  }

  Future<CommandInvocationSnapshot> _persistLearnedCorrelation({
    required CommandInvocationSnapshot snapshot,
    required String backendMessageId,
  }) async {
    final accepted = snapshot.acceptedInvocation;
    if (accepted == null || accepted.backendMessageId != null) return snapshot;
    await _invocationRepository.updateBackendMessageId(
      invocationId: accepted.invocationId,
      backendMessageId: backendMessageId,
    );
    return _tracker.updateAcceptedInvocation(
      invocation: accepted.withBackendMessageId(backendMessageId: backendMessageId),
    );
  }

  Future<void> _deleteAcceptedInvocation(CommandInvocationSnapshot snapshot) async {
    final invocationId = snapshot.acceptedInvocation?.invocationId;
    if (invocationId == null) return;
    try {
      await _invocationRepository.deleteInvocation(invocationId: invocationId);
    } catch (error, stackTrace) {
      Log.w(
        "Failed to delete accepted command invocation $invocationId after its message was removed",
        error,
        stackTrace,
      );
    }
  }

  MessageWithParts _acceptedCard({
    required AcceptedCommandInvocation invocation,
    required CommandInvocationSnapshot snapshot,
  }) {
    return _commandMapper.map(
      messageId: snapshot.canonicalMessageId,
      sessionId: invocation.sessionId,
      name: invocation.name,
      arguments: invocation.arguments,
      origin: CommandOrigin.manual,
      time: MessageTime(created: invocation.acceptedAt, completed: null),
      resultParts: const [],
    );
  }

  MessageWithParts _candidateCard({
    required CommandMessageTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    final accepted = snapshot.acceptedInvocation;
    return _commandMapper.map(
      messageId: snapshot.canonicalMessageId,
      sessionId: snapshot.sessionId,
      name: accepted?.name ?? candidate.name,
      arguments: accepted?.arguments ?? candidate.arguments,
      origin: accepted == null ? candidate.origin : CommandOrigin.manual,
      time: accepted == null
          ? candidate.time
          : MessageTime(
              created: accepted.acceptedAt,
              completed: candidate.time?.completed,
            ),
      resultParts: [
        ...?_liveTextResultParts[_liveKey(snapshot)]?.values,
        for (final part in candidate.resultParts)
          if (part.type != MessagePartType.text) part,
      ],
    );
  }

  MessagePart _mapLiveResultPart({
    required CommandResultPartTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    final part = candidate.part!;
    if (part.type != MessagePartType.text) {
      return _mapResultPart(candidate: candidate, snapshot: snapshot);
    }
    _recordTextResultParts(snapshot: snapshot, parts: [part]);
    return _displayPart(snapshot);
  }

  MessagePart _mapResultPart({
    required CommandResultPartTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    return _commandMapper.mapResultPart(
      part: candidate.part!,
      messageId: snapshot.canonicalMessageId,
      sessionId: snapshot.sessionId,
    );
  }

  CommandTimelinePartDelta _deltaMutation({
    required CommandResultPartDeltaTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    return CommandTimelinePartDelta(
      sessionId: snapshot.sessionId,
      messageId: snapshot.canonicalMessageId,
      partId: _commandMapper.resultPartId(
        messageId: snapshot.canonicalMessageId,
        backendPartId: candidate.backendPartId,
        isText: candidate.field == "text" || snapshot.backendPartTypes[candidate.backendPartId] == MessagePartType.text,
      ),
      field: candidate.field,
      delta: candidate.delta,
    );
  }

  CommandTimelineMutation _liveDeltaMutation({
    required CommandResultPartDeltaTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    final isText =
        candidate.field == "text" || snapshot.backendPartTypes[candidate.backendPartId] == MessagePartType.text;
    if (!isText) return _deltaMutation(candidate: candidate, snapshot: snapshot);

    final parts = _textResultParts(snapshot);
    final existing = parts[candidate.backendPartId];
    parts[candidate.backendPartId] = (existing ?? _emptyBackendTextPart(candidate: candidate)).copyWith(
      text: "${existing?.text ?? ""}${candidate.delta}",
    );
    return CommandTimelinePartUpdated(part: _displayPart(snapshot));
  }

  CommandTimelineMutation _liveRemovalMutation({
    required CommandResultPartRemovedTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    final wasText = snapshot.backendPartTypes[candidate.backendPartId] == MessagePartType.text;
    if (!wasText) {
      return CommandTimelinePartRemoved(
        sessionId: snapshot.sessionId,
        messageId: snapshot.canonicalMessageId,
        partId: _resultPartId(candidate: candidate, snapshot: snapshot),
      );
    }
    _textResultParts(snapshot).remove(candidate.backendPartId);
    return CommandTimelinePartUpdated(part: _displayPart(snapshot));
  }

  CommandTimelineMessageRemoved _messageRemovedMutation(CommandInvocationSnapshot snapshot) {
    return CommandTimelineMessageRemoved(
      sessionId: snapshot.sessionId,
      messageId: snapshot.canonicalMessageId,
    );
  }

  void _forgetLiveCommand(CommandInvocationSnapshot snapshot) {
    _liveCards.remove(snapshot.canonicalMessageId);
    _liveTextResultParts.remove(_liveKey(snapshot));
  }

  void _recordTextResultParts({
    required CommandInvocationSnapshot snapshot,
    required Iterable<MessagePart> parts,
  }) {
    final textParts = _textResultParts(snapshot);
    for (final part in parts) {
      if (part.type == MessagePartType.text) textParts[part.id] = part;
    }
  }

  LinkedHashMap<String, MessagePart> _textResultParts(CommandInvocationSnapshot snapshot) {
    return _liveTextResultParts.putIfAbsent(_liveKey(snapshot), LinkedHashMap<String, MessagePart>.new);
  }

  MessagePart _displayPart(CommandInvocationSnapshot snapshot) {
    return _commandMapper.mapDisplayPart(
      messageId: snapshot.canonicalMessageId,
      sessionId: snapshot.sessionId,
      resultParts: _textResultParts(snapshot).values,
    );
  }

  MessagePart _emptyBackendTextPart({required CommandResultPartDeltaTimelineCandidate candidate}) {
    return MessagePart(
      id: candidate.backendPartId,
      sessionID: candidate.sessionId,
      messageID: candidate.backendMessageId,
      type: MessagePartType.text,
      text: "",
      tool: null,
      state: null,
      prompt: null,
      description: null,
      agent: null,
      agentName: null,
      attempt: null,
      retryError: null,
    );
  }

  _LiveCommandKey _liveKey(CommandInvocationSnapshot snapshot) => (
    sessionId: snapshot.sessionId,
    messageId: snapshot.canonicalMessageId,
  );

  String _resultPartId({
    required CommandResultPartRemovedTimelineCandidate candidate,
    required CommandInvocationSnapshot snapshot,
  }) {
    return _commandMapper.resultPartId(
      messageId: snapshot.canonicalMessageId,
      backendPartId: candidate.backendPartId,
      isText: snapshot.backendPartTypes[candidate.backendPartId] == MessagePartType.text,
    );
  }

  List<CommandTimelineMutation> _cardMutations(MessageWithParts card) => [
    CommandTimelineEnvelopeUpdated(info: card.info),
    for (final part in card.parts) CommandTimelinePartUpdated(part: part),
  ];

  MessageWithParts _mergeCards({required MessageWithParts? previous, required MessageWithParts next}) {
    if (previous == null) return next;
    final parts = LinkedHashMap<String, MessagePart>.fromEntries(
      previous.parts.map((part) => MapEntry(part.id, part)),
    );
    for (final part in next.parts) {
      final existing = parts[part.id];
      final preserveResultText =
          part.id.endsWith(":display") && (part.text?.isEmpty ?? false) && !(existing?.text?.isEmpty ?? true);
      if (!preserveResultText) parts[part.id] = part;
    }
    return next.copyWith(parts: parts.values.toList(growable: false));
  }

  MessageWithParts _mergePart({required MessageWithParts card, required MessagePart part}) {
    final parts = LinkedHashMap<String, MessagePart>.fromEntries(
      card.parts.map((existing) => MapEntry(existing.id, existing)),
    );
    parts[part.id] = part;
    return card.copyWith(parts: parts.values.toList(growable: false));
  }

  MessageWithParts _removePart({required MessageWithParts card, required String partId}) {
    return card.copyWith(
      parts: card.parts.where((part) => part.id != partId).toList(growable: false),
    );
  }

  Future<T> _serializedLive<T>(Future<T> Function() operation) {
    final previous = _liveTail;
    final release = Completer<void>();
    _liveTail = release.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }();
  }

  static int _compareEntries(_TimelineEntry left, _TimelineEntry right) {
    final leftTime = left.sortTime;
    final rightTime = right.sortTime;
    if (leftTime != null && rightTime != null) {
      final byTime = leftTime.compareTo(rightTime);
      if (byTime != 0) return byTime;
    }
    final bySource = left.sourceOrder.compareTo(right.sourceOrder);
    if (bySource != 0) return bySource;
    return left.message.info.id.compareTo(right.message.info.id);
  }
}

class _TimelineEntry {
  final MessageWithParts message;
  final int? sortTime;
  final int sourceOrder;

  const _TimelineEntry({
    required this.message,
    required this.sortTime,
    required this.sourceOrder,
  });
}
