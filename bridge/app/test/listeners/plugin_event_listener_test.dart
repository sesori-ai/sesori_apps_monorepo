import "dart:async";

import "package:sesori_bridge/src/listeners/plugin_event_listener.dart";
import "package:sesori_bridge/src/runtime/plugin_runtime.dart";
import "package:sesori_bridge/src/services/session_event_dispatcher.dart";
import "package:sesori_bridge/src/services/session_event_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PluginEventListener", () {
    test("captures every source event before serialized dispatch completes", () async {
      final source = StreamController<SourcedPluginRuntimeEvent>.broadcast();
      final firstGate = Completer<void>();
      final dispatcher = _RecordingSessionEventDispatcher(firstGate: firstGate.future);
      final listener = PluginEventListener(
        source: source.stream,
        dispatcher: dispatcher,
      );
      listener.start();
      final terminalHandoffConsumed = Completer<void>();

      source.add((
        pluginId: "plugin-a",
        generation: 1,
        event: const BridgeSseSessionDiff(sessionID: "first"),
        allowDuringStop: false,
        terminalHandoffConsumed: null,
      ));
      source.add((
        pluginId: "plugin-a",
        generation: 1,
        event: const BridgeSseProjectUpdated(),
        allowDuringStop: true,
        terminalHandoffConsumed: terminalHandoffConsumed,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(dispatcher.captured.map((source) => source.event.runtimeType), [
        BridgeSseSessionDiff,
        BridgeSseProjectUpdated,
      ]);
      expect(dispatcher.dispatched, hasLength(2));
      expect(dispatcher.allowDuringStopValues, [false, true]);
      expect(dispatcher.terminalHandoffConsumptions, [null, terminalHandoffConsumed]);

      firstGate.complete();
      await dispatcher.dispatched.last;
      await source.close();
      await listener.dispose();
    });

    test("subscribes to the source once and cancels it on dispose", () async {
      var sourceListenCount = 0;
      var sourceCancelCount = 0;
      final source = StreamController<SourcedPluginRuntimeEvent>.broadcast(
        onListen: () => sourceListenCount++,
        onCancel: () => sourceCancelCount++,
      );
      final listener = PluginEventListener(
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

class _RecordingSessionEventDispatcher({required final Future<void> _firstGate}) implements SessionEventDispatcher {
  final List<SourcedBridgeEvent> captured = [];
  final List<Future<void>> dispatched = [];
  final List<bool> allowDuringStopValues = [];
  final List<Completer<void>?> terminalHandoffConsumptions = [];

  @override
  SourcedBridgeEvent capturePluginEvent({
    required String pluginId,
    required int generation,
    required BridgeSseEvent event,
  }) {
    final source = (
      pluginId: pluginId,
      generation: generation,
      projectionUpdatedAt: captured.length + 1,
      event: event,
    );
    captured.add(source);
    return source;
  }

  @override
  Future<void> dispatchPluginEvent({
    required SourcedBridgeEvent source,
    required bool allowDuringStop,
    required Completer<void>? terminalHandoffConsumed,
  }) {
    final future = dispatched.isEmpty ? _firstGate : Future<void>.value();
    dispatched.add(future);
    allowDuringStopValues.add(allowDuringStop);
    terminalHandoffConsumptions.add(terminalHandoffConsumed);
    return future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
