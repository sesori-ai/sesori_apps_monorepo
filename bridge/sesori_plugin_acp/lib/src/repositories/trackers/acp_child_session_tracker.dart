import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

/// A harness-reported sub-agent start. A [prompt] the harness does not carry
/// is null and is filled from the child's own first user message; a harness
/// that exposes no launch mode records the child as foreground.
final class const AcpChildSpawn({
  required final String childSessionId,
  required final String? description,
  required final String? agent,
  required final String? prompt,
  required final bool isBackground,
});

/// One child that has not finished, as the plugin's stop policy sees it.
final class const AcpRunningChild({
  required final String childSessionId,
  required final bool isBackground,
});

/// The events one lifecycle fact produced, plus the envelope the mapper must
/// emit first when this is the tile's first render.
final class const AcpChildTileResult({
  required final String rootSessionId,
  required final String messageId,
  required final bool opensMessage,
  required final List<BridgeSseEvent> events,
});

/// A root whose child or autonomous-settlement activity changed.
final class const AcpChildSessionTrackerChange({required final String rootSessionId});

/// The single owner of ACP child-session lifecycle. It is constructed once at
/// the harness composition point and shared by the event mapper, which pushes
/// typed lifecycle facts through [spawn], [appendPrompt], [finish], and
/// [finishAndHoldRoot], and by the plugin, which reads child/root activity,
/// releases holds through [releaseRootHold], and clears state through
/// [forgetSession] and [clear].
///
/// Every tile is keyed by the child session id the harness reports, never by
/// a tool call, so one child is exactly one tile. Children are flattened under
/// the root that owns them, so a nested spawn reported under a child id files
/// under the same root. State survives turn boundaries because a background
/// child outlives the turn that launched it.
final class AcpChildSessionTracker() {
  /// Children per root, in spawn order.
  final Map<String, List<_Child>> _byRoot = {};
  final Map<String, _Child> _byChild = {};

  /// Opaque backend-neutral work holds that keep a root active after a child
  /// terminal event and until its autonomous settlement turn completes. Each
  /// hold retains its originating child so deleting that child clears the
  /// exact hold even when the backend's hold id differs from the session id.
  final Map<String, Map<String, String>> _rootHolds = {};

  /// Activity changes consumed by the plugin. The asynchronous controller
  /// guarantees mapper-returned child events enter the plugin stream before a
  /// last-child change can release the root idle transition.
  final StreamController<AcpChildSessionTrackerChange> _changes =
      StreamController<AcpChildSessionTrackerChange>.broadcast();
  Stream<AcpChildSessionTrackerChange> get changes => _changes.stream;

  void _notify({required String rootSessionId}) {
    if (!_changes.isClosed) {
      _changes.add(AcpChildSessionTrackerChange(rootSessionId: rootSessionId));
    }
  }

  /// Whether [sessionId] is a child this tracker announced.
  bool isChild({required String sessionId}) => _byChild.containsKey(sessionId);

  /// The root that owns [sessionId]: itself unless it is a known child.
  String rootOf({required String sessionId}) => _byChild[sessionId]?.rootSessionId ?? sessionId;

  /// Records that [spawn] started under [sessionId] (the parent as the harness
  /// reports it) and emits the child session, its busy status, and, when the
  /// prompt is already known, the tile. [directory] is the root's project
  /// directory; children never carry their own.
  AcpChildTileResult spawn({
    required String sessionId,
    required AcpChildSpawn spawn,
    required String directory,
  }) {
    final root = rootOf(sessionId: sessionId);
    final existing = _byChild[spawn.childSessionId];
    if (existing != null) {
      return AcpChildTileResult(
        rootSessionId: root,
        messageId: existing.messageId,
        opensMessage: false,
        events: const [],
      );
    }
    final messageId = "$root-subagent-${spawn.childSessionId}";
    final child = _Child(
      rootSessionId: root,
      childSessionId: spawn.childSessionId,
      messageId: messageId,
      partId: "$messageId-subtask",
      description: spawn.description,
      agent: spawn.agent,
      isBackground: spawn.isBackground,
    );
    if (spawn.prompt case final prompt?) child.prompt.write(prompt);
    (_byRoot[root] ??= []).add(child);
    _byChild[spawn.childSessionId] = child;
    _notify(rootSessionId: root);
    final part = child.partOrNull();
    return AcpChildTileResult(
      rootSessionId: root,
      messageId: messageId,
      opensMessage: part != null,
      events: [
        BridgeSseSessionCreated(
          info: PluginSession(
            id: spawn.childSessionId,
            projectID: directory,
            directory: directory,
            parentID: root,
            title: spawn.description,
            time: null,
          ).toJson(),
        ),
        _childStatus(childId: spawn.childSessionId, busy: true),
        if (part != null) BridgeSseMessagePartUpdated(part: part),
      ],
    );
  }

  /// Appends a chunk of [childSessionId]'s own prompt, as its first user
  /// message streams under the child id; renders the tile once a prompt exists.
  AcpChildTileResult? appendPrompt({required String childSessionId, required String delta}) {
    final child = _byChild[childSessionId];
    if (child == null || delta.isEmpty) return null;
    final firstRender = child.prompt.isEmpty;
    child.prompt.write(delta);
    final part = child.partOrNull();
    return AcpChildTileResult(
      rootSessionId: child.rootSessionId,
      messageId: child.messageId,
      opensMessage: firstRender && part != null,
      events: [if (part != null) BridgeSseMessagePartUpdated(part: part)],
    );
  }

  /// Finalizes [childSessionId] with the harness-reported terminal [status];
  /// [output] is kept for a completed child and [error] for a failed one, both
  /// bounded like tool output. Unknown or already-finished children yield
  /// nothing.
  List<BridgeSseEvent> finish({
    required String childSessionId,
    required PluginToolStatus status,
    required String? output,
    required String? error,
  }) {
    final child = _byChild[childSessionId];
    if (child == null || child.status.isTerminal) return const [];
    final events = _finish(child: child, status: status, output: output, error: error);
    _notify(rootSessionId: child.rootSessionId);
    return events;
  }

  /// Atomically finalizes a child and replaces its running state with an
  /// opaque root hold. This prevents an idle gap before a backend-driven root
  /// settlement turn whose lifecycle does not increment ACP prompt accounting.
  List<BridgeSseEvent> finishAndHoldRoot({
    required String childSessionId,
    required String holdId,
    required PluginToolStatus status,
    required String? output,
    required String? error,
  }) {
    final child = _byChild[childSessionId];
    if (child == null || child.status.isTerminal) return const [];
    (_rootHolds[child.rootSessionId] ??= {})[holdId] = childSessionId;
    final events = _finish(child: child, status: status, output: output, error: error);
    _notify(rootSessionId: child.rootSessionId);
    return events;
  }

  /// Releases one opaque settlement hold. Unknown and duplicate releases are
  /// no-ops, preserving one transition per observed backend lifecycle fact.
  bool releaseRootHold({required String rootSessionId, required String holdId}) {
    final holds = _rootHolds[rootSessionId];
    if (holds == null || holds.remove(holdId) == null) return false;
    if (holds.isEmpty) _rootHolds.remove(rootSessionId);
    _notify(rootSessionId: rootSessionId);
    return true;
  }

  List<BridgeSseEvent> _finish({
    required _Child child,
    required PluginToolStatus status,
    required String? output,
    required String? error,
  }) {
    child
      ..status = status
      ..output = status == PluginToolStatus.completed ? _bounded(output) : null
      ..error = status == PluginToolStatus.error ? _bounded(error) : null;
    final part = child.partOrNull();
    return [
      if (part != null) BridgeSseMessagePartUpdated(part: part),
      _childStatus(childId: child.childSessionId, busy: false),
    ];
  }

  /// Cancels every running child and clears every autonomous root hold: the
  /// agent process or global work episode is ending. Child records stay until
  /// [clear] or [forgetSession].
  List<BridgeSseEvent> cancelAll() {
    final affectedRoots = <String>{
      for (final entry in _rootHolds.entries)
        if (entry.value.isNotEmpty) entry.key,
    };
    final events = <BridgeSseEvent>[];
    for (final child in _byChild.values) {
      if (child.status.isTerminal) continue;
      affectedRoots.add(child.rootSessionId);
      events.addAll(_finish(child: child, status: PluginToolStatus.cancelled, output: null, error: null));
    }
    _rootHolds.clear();
    for (final rootSessionId in affectedRoots) {
      _notify(rootSessionId: rootSessionId);
    }
    return events;
  }

  /// Whether any announced child, under any root, is still running.
  bool get hasBusyChildren => _byChild.values.any((child) => !child.status.isTerminal);

  /// Whether [sessionId] has an autonomous settlement turn in progress.
  bool hasRootHold({required String sessionId}) => _rootHolds[sessionId]?.isNotEmpty ?? false;

  /// Whether children or autonomous settlement keep [sessionId] active.
  bool hasActiveWorkForRoot({required String sessionId}) =>
      busyChildIds(sessionId: sessionId).isNotEmpty || hasRootHold(sessionId: sessionId);

  /// Every root that has child or autonomous settlement work.
  Set<String> get activeRootSessionIds => {
    for (final entry in _byRoot.entries)
      if (entry.value.any((child) => !child.status.isTerminal)) entry.key,
    for (final entry in _rootHolds.entries)
      if (entry.value.isNotEmpty) entry.key,
  };

  /// Whether any root has child or autonomous settlement work.
  bool get hasActiveWork => hasBusyChildren || _rootHolds.values.any((holds) => holds.isNotEmpty);

  /// The children of [sessionId] as sessions, for a harness whose listing
  /// carries no parent marker. [directory] is the root's project directory.
  List<PluginSession> childSessions({required String sessionId, required String directory}) => [
    for (final child in _byRoot[sessionId] ?? const <_Child>[])
      PluginSession(
        id: child.childSessionId,
        projectID: directory,
        directory: directory,
        parentID: sessionId,
        title: child.description,
        time: null,
      ),
  ];

  /// Statuses of every child this tracker announced, across roots.
  Map<String, PluginSessionStatus> get childStatuses => {
    for (final entry in _byChild.entries)
      entry.key: entry.value.status.isTerminal ? const PluginSessionStatus.idle() : const PluginSessionStatus.busy(),
  };

  /// Every child of [sessionId], running or finished.
  List<String> childSessionIds({required String sessionId}) => [
    for (final child in _byRoot[sessionId] ?? const <_Child>[]) child.childSessionId,
  ];

  /// The children of [sessionId] still running.
  Set<String> busyChildIds({required String sessionId}) => {
    for (final child in runningChildren(sessionId: sessionId)) child.childSessionId,
  };

  /// The children of [sessionId] still running, with their launch mode.
  List<AcpRunningChild> runningChildren({required String sessionId}) => [
    for (final child in _byRoot[sessionId] ?? const <_Child>[])
      if (!child.status.isTerminal)
        AcpRunningChild(childSessionId: child.childSessionId, isBackground: child.isBackground),
  ];

  /// Drops every record of a deleted root, or the single record of a deleted
  /// child. Emits nothing: the session is gone.
  void forgetSession({required String sessionId}) {
    final removedRootHolds = _rootHolds.remove(sessionId);
    final children = _byRoot.remove(sessionId);
    if (children != null) {
      final hadActiveWork =
          children.any((child) => !child.status.isTerminal) || (removedRootHolds?.isNotEmpty ?? false);
      for (final child in children) {
        _byChild.remove(child.childSessionId);
      }
      if (hadActiveWork) _notify(rootSessionId: sessionId);
      return;
    }
    final child = _byChild.remove(sessionId);
    if (child == null) {
      if (removedRootHolds?.isNotEmpty ?? false) _notify(rootSessionId: sessionId);
      return;
    }
    final siblings = _byRoot[child.rootSessionId];
    siblings?.remove(child);
    if (siblings?.isEmpty ?? false) _byRoot.remove(child.rootSessionId);
    final siblingHolds = _rootHolds[child.rootSessionId];
    final holdCount = siblingHolds?.length ?? 0;
    siblingHolds?.removeWhere((_, heldChildSessionId) => heldChildSessionId == sessionId);
    final removedChildHold = siblingHolds != null && siblingHolds.length != holdCount;
    if (siblingHolds?.isEmpty ?? false) _rootHolds.remove(child.rootSessionId);
    if (!child.status.isTerminal || removedChildHold) {
      _notify(rootSessionId: child.rootSessionId);
    }
  }

  /// Drops every record: the agent process that hosted the children is gone.
  void clear() {
    if (_byChild.isEmpty && _byRoot.isEmpty && _rootHolds.isEmpty) return;
    final affectedRoots = <String>{
      for (final entry in _byRoot.entries)
        if (entry.value.any((child) => !child.status.isTerminal)) entry.key,
      for (final entry in _rootHolds.entries)
        if (entry.value.isNotEmpty) entry.key,
    };
    _byRoot.clear();
    _byChild.clear();
    _rootHolds.clear();
    for (final rootSessionId in affectedRoots) {
      _notify(rootSessionId: rootSessionId);
    }
  }

  Future<void> dispose() => _changes.isClosed ? Future<void>.value() : _changes.close();

  BridgeSseSessionStatus _childStatus({required String childId, required bool busy}) => BridgeSseSessionStatus(
    sessionID: childId,
    status: (busy ? const shared.SessionStatus.busy() : const shared.SessionStatus.idle()).toJson(),
  );
}

final class _Child({
  required final String rootSessionId,
  required final String childSessionId,
  required final String messageId,
  required final String partId,
  required final String? description,
  required final String? agent,
  required final bool isBackground,
}) {
  final StringBuffer prompt = StringBuffer();
  PluginToolStatus status = PluginToolStatus.running;
  String? output;
  String? error;

  /// The tile, once every field the part requires is known.
  PluginMessagePart? partOrNull() {
    if (prompt.isEmpty) return null;
    final description = this.description;
    final agent = this.agent;
    if (description == null || agent == null) return null;
    return PluginMessagePart.subtask(
      id: partId,
      sessionID: rootSessionId,
      messageID: messageId,
      prompt: prompt.toString(),
      description: description,
      agent: agent,
      taskState: PluginToolState(status: status, title: null, output: output, error: error, attachments: const []),
      childSessionID: childSessionId,
    );
  }
}

String? _bounded(String? value) =>
    value == null || value.isEmpty ? null : String.fromCharCodes(value.runes.take(maxToolOutputLength));
