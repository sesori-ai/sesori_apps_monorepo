import "package:sesori_shared/sesori_shared.dart";

import "models/accepted_command_invocation.dart";
import "models/command_timeline.dart";

typedef _BackendCommandKey = ({String pluginId, String sessionId, String backendMessageId});

class _CommandInvocationState {
  final String pluginId;
  final String sessionId;
  final String? invocationId;
  final String canonicalMessageId;
  final Set<String> backendMessageIds = <String>{};
  final Map<String, MessagePartType> backendPartTypes = <String, MessagePartType>{};
  final List<CommandTimelineCandidate> heldCandidates = <CommandTimelineCandidate>[];
  AcceptedCommandInvocation? acceptedInvocation;
  bool rejected;

  _CommandInvocationState({
    required this.pluginId,
    required this.sessionId,
    required this.invocationId,
    required this.canonicalMessageId,
    required this.acceptedInvocation,
    required this.rejected,
  });
}

/// In-memory command identity and correlation facts.
///
/// All mutable state remains private; callers receive immutable snapshots.
class CommandInvocationTracker {
  final Map<String, _CommandInvocationState> _byInvocationId = <String, _CommandInvocationState>{};
  final Map<_BackendCommandKey, _CommandInvocationState> _byBackendMessageId =
      <_BackendCommandKey, _CommandInvocationState>{};

  void seed({required Iterable<AcceptedCommandInvocation> invocations}) {
    for (final invocation in invocations) {
      accept(invocation: invocation);
    }
  }

  CommandAcceptanceTrackingResult accept({required AcceptedCommandInvocation invocation}) {
    final existing = _byInvocationId[invocation.invocationId];
    if (existing != null && (existing.pluginId != invocation.pluginId || existing.sessionId != invocation.sessionId)) {
      throw StateError("Command invocation ${invocation.invocationId} was registered for a different session");
    }
    final state =
        existing ??
        _CommandInvocationState(
          pluginId: invocation.pluginId,
          sessionId: invocation.sessionId,
          invocationId: invocation.invocationId,
          canonicalMessageId: _invocationMessageId(invocation.invocationId),
          acceptedInvocation: null,
          rejected: false,
        );
    state.acceptedInvocation = invocation;
    state.rejected = false;
    _byInvocationId[invocation.invocationId] = state;
    final backendMessageId = invocation.backendMessageId;
    if (backendMessageId != null) {
      _attachBackendMessageId(state: state, backendMessageId: backendMessageId);
    }
    final held = List<CommandTimelineCandidate>.of(state.heldCandidates);
    state.heldCandidates.clear();
    return CommandAcceptanceTrackingResult(snapshot: _snapshot(state), heldCandidates: held);
  }

  void reject({required String pluginId, required String sessionId, required String invocationId}) {
    final existing = _byInvocationId[invocationId];
    if (existing != null && (existing.pluginId != pluginId || existing.sessionId != sessionId)) return;
    final state =
        existing ??
        _CommandInvocationState(
          pluginId: pluginId,
          sessionId: sessionId,
          invocationId: invocationId,
          canonicalMessageId: _invocationMessageId(invocationId),
          acceptedInvocation: null,
          rejected: true,
        );
    state.rejected = true;
    state.heldCandidates.clear();
    _byInvocationId[invocationId] = state;
  }

  CommandCandidateTrackingResult track({required CommandTimelineCandidate candidate}) {
    return switch (candidate) {
      final CommandMessageTimelineCandidate message => _trackMessage(message),
      final CommandResultPartTimelineCandidate part => _trackBackendCandidate(
        candidate: part,
        backendPartId: part.backendPartId,
        partType: part.part?.type,
      ),
      final CommandResultPartDeltaTimelineCandidate delta => _trackBackendCandidate(
        candidate: delta,
        backendPartId: null,
        partType: null,
      ),
      final CommandResultPartRemovedTimelineCandidate removed => _trackBackendCandidate(
        candidate: removed,
        backendPartId: null,
        partType: null,
      ),
    };
  }

  CommandInvocationSnapshot updateAcceptedInvocation({required AcceptedCommandInvocation invocation}) {
    return accept(invocation: invocation).snapshot;
  }

  CommandCandidateTrackingResult _trackMessage(CommandMessageTimelineCandidate candidate) {
    _CommandInvocationState? state;
    final invocationId = candidate.invocationId;
    if (invocationId != null) {
      final byInvocation = _byInvocationId[invocationId];
      if (byInvocation != null &&
          byInvocation.pluginId == candidate.pluginId &&
          byInvocation.sessionId == candidate.sessionId) {
        state = byInvocation;
      }
    }
    state ??= _byBackendMessageId[_key(candidate)];
    state ??= _CommandInvocationState(
      pluginId: candidate.pluginId,
      sessionId: candidate.sessionId,
      invocationId: invocationId,
      canonicalMessageId: invocationId == null
          ? _backendMessageId(candidate.backendMessageId)
          : _invocationMessageId(invocationId),
      acceptedInvocation: null,
      rejected: false,
    );
    if (invocationId != null) _byInvocationId.putIfAbsent(invocationId, () => state!);
    _attachBackendMessageId(state: state, backendMessageId: candidate.backendMessageId);
    for (final part in candidate.resultParts) {
      state.backendPartTypes[part.id] = part.type;
    }
    if (state.rejected) {
      return CommandCandidateTrackingResult(
        disposition: CommandInvocationTrackingDisposition.ignored,
        snapshot: _snapshot(state),
      );
    }
    if (invocationId != null && state.acceptedInvocation == null) {
      state.heldCandidates.add(candidate);
      return CommandCandidateTrackingResult(
        disposition: CommandInvocationTrackingDisposition.held,
        snapshot: _snapshot(state),
      );
    }
    return CommandCandidateTrackingResult(
      disposition: CommandInvocationTrackingDisposition.ready,
      snapshot: _snapshot(state),
    );
  }

  CommandCandidateTrackingResult _trackBackendCandidate({
    required CommandTimelineCandidate candidate,
    required String? backendPartId,
    required MessagePartType? partType,
  }) {
    final state = _byBackendMessageId[_key(candidate)];
    if (state == null) {
      return const CommandCandidateTrackingResult(
        disposition: CommandInvocationTrackingDisposition.unmatched,
        snapshot: null,
      );
    }
    if (backendPartId != null && partType != null) state.backendPartTypes[backendPartId] = partType;
    if (state.rejected) {
      return CommandCandidateTrackingResult(
        disposition: CommandInvocationTrackingDisposition.ignored,
        snapshot: _snapshot(state),
      );
    }
    if (state.invocationId != null && state.acceptedInvocation == null) {
      state.heldCandidates.add(candidate);
      return CommandCandidateTrackingResult(
        disposition: CommandInvocationTrackingDisposition.held,
        snapshot: _snapshot(state),
      );
    }
    return CommandCandidateTrackingResult(
      disposition: CommandInvocationTrackingDisposition.ready,
      snapshot: _snapshot(state),
    );
  }

  void _attachBackendMessageId({required _CommandInvocationState state, required String backendMessageId}) {
    state.backendMessageIds.add(backendMessageId);
    _byBackendMessageId[(
          pluginId: state.pluginId,
          sessionId: state.sessionId,
          backendMessageId: backendMessageId,
        )] =
        state;
  }

  CommandInvocationSnapshot _snapshot(_CommandInvocationState state) {
    return CommandInvocationSnapshot(
      pluginId: state.pluginId,
      sessionId: state.sessionId,
      invocationId: state.invocationId,
      canonicalMessageId: state.canonicalMessageId,
      backendMessageId: state.acceptedInvocation?.backendMessageId ?? state.backendMessageIds.firstOrNull,
      acceptedInvocation: state.acceptedInvocation,
      backendPartTypes: state.backendPartTypes,
    );
  }

  _BackendCommandKey _key(CommandTimelineCandidate candidate) => (
    pluginId: candidate.pluginId,
    sessionId: candidate.sessionId,
    backendMessageId: candidate.backendMessageId,
  );

  static String _invocationMessageId(String invocationId) => "command-invocation:$invocationId";

  static String _backendMessageId(String backendMessageId) => "command-backend:$backendMessageId";
}
