import "dart:async";

import "package:sesori_bridge/src/bridge/services/session_event_service.dart";
import "package:sesori_bridge/src/listeners/plugin_event_listener.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("PluginEventListener", () {
    test("serializes source events and preserves multi-event normalization order", () async {
      final source = StreamController<BridgeSseEvent>.broadcast();
      final firstGate = Completer<void>();
      final service = _RecordingSessionEventService(firstGate: firstGate.future);
      final listener = PluginEventListener(
        pluginId: "plugin-a",
        source: source.stream,
        sessionEventService: service,
      );
      final outputFuture = listener.events.take(3).toList();

      source.add(const BridgeSseSessionDiff(sessionID: "first"));
      source.add(const BridgeSseProjectUpdated());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.sources, hasLength(1));

      firstGate.complete();
      final output = await outputFuture.timeout(const Duration(seconds: 1));

      expect(service.sources.map((source) => source.pluginId), ["plugin-a", "plugin-a"]);
      expect(
        output.map((event) => event.runtimeType),
        [BridgeSseSessionDiff, BridgeSseProjectUpdated, BridgeSseServerHeartbeat],
      );

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
        sessionEventService: _RecordingSessionEventService(firstGate: Future<void>.value()),
      );
      final firstSubscription = listener.events.listen((_) {});
      final secondSubscription = listener.events.listen((_) {});

      expect(sourceListenCount, 1);
      await listener.dispose();
      expect(sourceCancelCount, 1);

      await firstSubscription.cancel();
      await secondSubscription.cancel();
      await source.close();
    });
  });
}

class _RecordingSessionEventService implements SessionEventService {
  final Future<void> _firstGate;
  final List<SourcedBridgeEvent> sources = [];

  _RecordingSessionEventService({required Future<void> firstGate}) : _firstGate = firstGate;

  @override
  Future<List<BridgeSseEvent>> normalize({required SourcedBridgeEvent source}) async {
    sources.add(source);
    if (source.event case BridgeSseSessionDiff(sessionID: "first")) {
      await _firstGate;
    }
    if (source.event is BridgeSseProjectUpdated) {
      return [source.event, const BridgeSseServerHeartbeat()];
    }
    return [source.event];
  }
}
