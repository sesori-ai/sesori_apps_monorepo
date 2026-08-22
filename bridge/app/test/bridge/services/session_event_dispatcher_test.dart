import "dart:async";

import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/services/session_event_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("drops a delayed created event when its binding is deleted before publication", () async {
    final normalizeGate = Completer<void>();
    final service = _GatedSessionEventService(normalizeGate: normalizeGate.future);
    final dispatcher = SessionEventDispatcher(sessionEventService: service);
    final outputFuture = dispatcher.events.take(1).toList();
    final source = service.captureSource(
      pluginId: "plugin",
      generation: 1,
      event: const BridgeSseSessionCreated(
        info: {
          "id": "stable-root",
          "pluginId": "plugin",
          "projectID": "project",
          "directory": "/repo",
          "parentID": null,
          "title": "stale",
          "time": null,
          "pullRequest": null,
          "promptDefaults": null,
        },
      ),
    );

    final createdDispatch = dispatcher.dispatchPluginEvent(
      source: source,
      allowDuringStop: false,
      terminalHandoffConsumed: null,
    );
    service.createdIsPublishable = false;
    const deletedSession = Session(
      id: "stable-root",
      pluginId: "plugin",
      projectID: "project",
      directory: "/repo",
      parentID: null,
      title: "stale",
      time: null,
      pullRequest: null,
      promptDefaults: null,
      lastUserActivityAt: null,
      branchName: null,
    );
    final deletedDispatch = dispatcher.dispatchLocalEvent(
      source: (
        pluginId: deletedSession.pluginId,
        event: BridgeSseSessionDeleted(info: deletedSession.toJson()),
      ),
    );
    normalizeGate.complete();

    await Future.wait([createdDispatch, deletedDispatch]);
    final output = await outputFuture;
    expect(output.single.pluginId, "plugin");
    expect(output.single.event, isA<BridgeSseSessionDeleted>());
    await dispatcher.dispose();
  });

  test("maps a local title update to session.updated with titleChanged", () async {
    final service = _GatedSessionEventService(normalizeGate: Future<void>.value());
    final dispatcher = SessionEventDispatcher(sessionEventService: service);
    final outputFuture = dispatcher.events.first;
    const session = Session(
      id: "stable-root",
      pluginId: "plugin",
      projectID: "project",
      directory: "/repo",
      parentID: null,
      title: "Generated title",
      time: null,
      pullRequest: null,
      promptDefaults: null,
      lastUserActivityAt: null,
      branchName: null,
    );

    await dispatcher.dispatchLocalEvent(
      source: (
        pluginId: session.pluginId,
        event: BridgeSseSessionUpdated(info: session.toJson(), titleChanged: true),
      ),
    );

    final output = await outputFuture;
    expect(output.pluginId, "plugin");
    expect(
      output.event,
      isA<BridgeSseSessionUpdated>()
          .having((event) => event.titleChanged, "titleChanged", isTrue)
          .having((event) => event.info, "info", session.toJson()),
    );
    await dispatcher.dispose();
  });

  test("drops normalized output after its captured generation is replaced", () async {
    final normalizeGate = Completer<void>();
    final service = _GatedSessionEventService(normalizeGate: normalizeGate.future);
    final dispatcher = SessionEventDispatcher(sessionEventService: service);
    final output = <NormalizedSourcedBridgeEvent>[];
    final subscription = dispatcher.events.listen(output.add);
    final source = service.captureSource(
      pluginId: "plugin",
      generation: 1,
      event: const BridgeSsePermissionAsked(
        requestID: "permission",
        sessionID: "session",
        displaySessionId: "session",
        tool: "read",
        description: "read a file",
        allowAlways: true,
      ),
    );

    final dispatch = dispatcher.dispatchPluginEvent(
      source: source,
      allowDuringStop: false,
      terminalHandoffConsumed: null,
    );
    service.generationCurrent = false;
    normalizeGate.complete();
    await dispatch;

    expect(output, isEmpty);
    await subscription.cancel();
    await dispatcher.dispose();
  });

  test("forwards stop authorization and handoff consumption with the final normalized event", () async {
    final service = _GatedSessionEventService(normalizeGate: Future<void>.value())..generationCurrent = false;
    final dispatcher = SessionEventDispatcher(sessionEventService: service);
    final outputFuture = dispatcher.events.first;
    final consumed = Completer<void>();
    final source = service.captureSource(
      pluginId: "plugin",
      generation: 1,
      event: const BridgeSseTerminalHandoff(
        event: BridgeSseProjectUpdated(),
      ),
    );

    await dispatcher.dispatchPluginEvent(
      source: source,
      allowDuringStop: true,
      terminalHandoffConsumed: consumed,
    );

    final output = await outputFuture;
    expect(output.allowDuringStop, isTrue);
    expect(output.terminalHandoffConsumed, same(consumed));
    await dispatcher.dispose();
  });

  test("skips a stale replay without dropping later current output", () async {
    final service = _GatedSessionEventService(normalizeGate: Future<void>.value())
      ..currentGeneration = 2
      ..bindingOutputs = const [
        (
          generation: 1,
          event: BridgeSsePermissionAsked(
            requestID: "stale",
            sessionID: "session",
            displaySessionId: "session",
            tool: "read",
            description: "stale",
            allowAlways: true,
          ),
        ),
        (
          generation: 2,
          event: BridgeSsePermissionAsked(
            requestID: "current",
            sessionID: "session",
            displaySessionId: "session",
            tool: "read",
            description: "current",
            allowAlways: true,
          ),
        ),
      ];
    final dispatcher = SessionEventDispatcher(sessionEventService: service);
    final outputFuture = dispatcher.events.take(1).toList();

    await dispatcher.dispatchBindingsCommitted(
      commit: (
        pluginId: "plugin",
        projectId: "project",
        generation: 2,
        kind: SessionBindingCommitKind.catalogSync,
        backendSessionIds: const ["session"],
      ),
    );

    final output = await outputFuture;
    expect((output.single.event as BridgeSsePermissionAsked).requestID, "current");
    expect(output.single.generation, 2);
    await dispatcher.dispose();
  });
}

class _GatedSessionEventService({required final Future<void> _normalizeGate}) implements SessionEventService {
  bool createdIsPublishable = true;
  bool generationCurrent = true;
  bool eventGenerationCurrent = true;
  int currentGeneration = 1;
  List<NormalizedRuntimeEvent> bindingOutputs = const [];

  @override
  SourcedBridgeEvent captureSource({
    required String pluginId,
    required int generation,
    required BridgeSseEvent event,
  }) {
    return (pluginId: pluginId, generation: generation, projectionUpdatedAt: 1, event: event);
  }

  @override
  Future<List<BridgeSseEvent>> normalize({
    required SourcedBridgeEvent source,
    required bool allowDuringStop,
  }) async {
    await _normalizeGate;
    return [source.event];
  }

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return generationCurrent && generation == currentGeneration;
  }

  @override
  bool isCurrentEvent({
    required String pluginId,
    required int generation,
    required bool allowDuringStop,
  }) {
    return generation == currentGeneration && (generationCurrent || (allowDuringStop && eventGenerationCurrent));
  }

  @override
  Future<List<NormalizedRuntimeEvent>> handleBindingsCommitted({required SessionBindingsCommitted commit}) async {
    return bindingOutputs;
  }

  @override
  Future<bool> canPublish({required BridgeSseEvent event}) async {
    return event is! BridgeSseSessionCreated || createdIsPublishable;
  }
}
