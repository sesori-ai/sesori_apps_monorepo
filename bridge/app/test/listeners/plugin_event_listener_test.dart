import "dart:async";

import "package:sesori_bridge/src/bridge/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
import "package:sesori_bridge/src/listeners/plugin_event_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PluginEventListener", () {
    test("captures every source event before serialized dispatch completes", () async {
      final source = StreamController<BridgeSseEvent>.broadcast();
      final firstGate = Completer<void>();
      final dispatcher = _RecordingSessionEventDispatcher(firstGate: firstGate.future);
      final listener = PluginEventListener(
        pluginId: "plugin-a",
        source: source.stream,
        dispatcher: dispatcher,
      );
      listener.start();

      source.add(const BridgeSseSessionDiff(sessionID: "first"));
      source.add(const BridgeSseProjectUpdated());
      await Future<void>.delayed(Duration.zero);

      expect(dispatcher.captured.map((source) => source.event.runtimeType), [
        BridgeSseSessionDiff,
        BridgeSseProjectUpdated,
      ]);
      expect(dispatcher.dispatched, hasLength(2));

      firstGate.complete();
      await dispatcher.dispatched.last;
      await source.close();
      await listener.dispose();
    });

    test("subscribes to the source once and cancels it on dispose", () async {
      var sourceListenCount = 0;
      var sourceCancelCount = 0;
      final source = StreamController<BridgeSseEvent>.broadcast(
        onListen: () => sourceListenCount++,
        onCancel: () => sourceCancelCount++,
      );
      final listener = PluginEventListener(
        pluginId: "plugin-a",
        source: source.stream,
        dispatcher: _RecordingSessionEventDispatcher(firstGate: Future<void>.value()),
      );

      listener.start();
      listener.start();
      expect(sourceListenCount, 1);
      await listener.dispose();
      expect(sourceCancelCount, 1);

      await source.close();
    });
  });
}

class _RecordingSessionEventDispatcher implements SessionEventDispatcher {
  final Future<void> _firstGate;
  final List<SourcedBridgeEvent> captured = [];
  final List<Future<void>> dispatched = [];

  _RecordingSessionEventDispatcher({required Future<void> firstGate}) : _firstGate = firstGate;

  @override
  SourcedBridgeEvent capturePluginEvent({required String pluginId, required BridgeSseEvent event}) {
    final source = (pluginId: pluginId, projectionUpdatedAt: captured.length + 1, event: event);
    captured.add(source);
    return source;
  }

  @override
  Future<void> dispatchPluginEvent({required SourcedBridgeEvent source}) {
    final future = dispatched.isEmpty ? _firstGate : Future<void>.value();
    dispatched.add(future);
    return future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
