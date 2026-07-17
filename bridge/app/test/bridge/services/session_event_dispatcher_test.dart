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
    expect(output.single, isA<BridgeSseSessionDeleted>());
    await dispatcher.dispose();
  });
}

class _GatedSessionEventService implements SessionEventService {
  final Future<void> _normalizeGate;
  bool createdIsPublishable = true;

  _GatedSessionEventService({required Future<void> normalizeGate}) : _normalizeGate = normalizeGate;

  @override
  SourcedBridgeEvent captureSource({required String pluginId, required BridgeSseEvent event}) {
    return (pluginId: pluginId, projectionUpdatedAt: 1, event: event);
  }

  @override
  Future<List<BridgeSseEvent>> normalize({required SourcedBridgeEvent source}) async {
    await _normalizeGate;
    return [source.event];
  }

  @override
  Future<List<BridgeSseEvent>> handleBindingsCommitted({required SessionBindingsCommitted commit}) async {
    return const [];
  }

  @override
  Future<bool> canPublish({required BridgeSseEvent event}) async {
    return event is! BridgeSseSessionCreated || createdIsPublishable;
  }
}
