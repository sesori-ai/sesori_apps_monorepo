import "dart:async";

import "package:sesori_bridge/src/bridge/repositories/session_repository.dart";
import "package:sesori_bridge/src/bridge/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
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

    final createdDispatch = dispatcher.dispatchPluginEvent(source: source);
    service.createdIsPublishable = false;
    final deletedDispatch = dispatcher.dispatchDeletedSession(
      session: const Session(
        id: "stable-root",
        pluginId: "plugin",
        projectID: "project",
        directory: "/repo",
        parentID: null,
        title: "stale",
        time: null,
        pullRequest: null,
        promptDefaults: null,
        branchName: null,
      ),
    );
    normalizeGate.complete();

    await Future.wait([createdDispatch, deletedDispatch]);
    final output = await outputFuture;
    expect(output.single.pluginId, "plugin");
    expect(output.single.event, isA<BridgeSseSessionDeleted>());
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
      ),
    );

    final dispatch = dispatcher.dispatchPluginEvent(source: source);
    service.generationCurrent = false;
    normalizeGate.complete();
    await dispatch;

    expect(output, isEmpty);
    await subscription.cancel();
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
          ),
        ),
      ];
    final dispatcher = SessionEventDispatcher(sessionEventService: service);
    final outputFuture = dispatcher.events.take(1).toList();

    await dispatcher.dispatchBindingsCommitted(
      commit: (pluginId: "plugin", backendSessionIds: const ["session"]),
    );

    final output = await outputFuture;
    expect((output.single.event as BridgeSsePermissionAsked).requestID, "current");
    expect(output.single.generation, 2);
    await dispatcher.dispose();
  });
}

class _GatedSessionEventService implements SessionEventService {
  final Future<void> _normalizeGate;
  bool createdIsPublishable = true;
  bool generationCurrent = true;
  int currentGeneration = 1;
  List<NormalizedRuntimeEvent> bindingOutputs = const [];

  _GatedSessionEventService({required Future<void> normalizeGate}) : _normalizeGate = normalizeGate;

  @override
  SourcedBridgeEvent captureSource({
    required String pluginId,
    required int generation,
    required BridgeSseEvent event,
  }) {
    return (pluginId: pluginId, generation: generation, projectionUpdatedAt: 1, event: event);
  }

  @override
  Future<List<BridgeSseEvent>> normalize({required SourcedBridgeEvent source}) async {
    await _normalizeGate;
    return [source.event];
  }

  @override
  bool isCurrentGeneration({required String pluginId, required int generation}) {
    return generationCurrent && generation == currentGeneration;
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
