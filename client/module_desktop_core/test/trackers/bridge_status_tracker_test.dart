import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late BridgeStatusTracker tracker;

  setUp(() {
    tracker = BridgeStatusTracker();
    addTearDown(tracker.dispose);
  });

  test("defaults to the offline baseline before any helper connects", () {
    expect(tracker.status, BridgeControlStatus.offline);
    expect(tracker.status.helperOnline, isFalse);
    expect(tracker.statusStream.value, BridgeControlStatus.offline);
  });

  test("connect then status push lands in the snapshot and stream", () async {
    tracker.markHelperConnected();
    tracker.applyStatus(
      status: const ControlStatus(
        relay: ControlRelayConnectionState.connected,
        plugin: ControlPluginHealthState.healthy,
        activeSessionCount: 3,
      ),
    );

    expect(tracker.status.helperOnline, isTrue);
    expect(tracker.status.relay, ControlRelayConnectionState.connected);
    expect(tracker.status.plugin, ControlPluginHealthState.healthy);
    expect(tracker.status.activeSessionCount, 3);
  });

  test("disconnect resets status to the baseline but retains bridgeId", () {
    tracker.markHelperConnected();
    tracker.handleRegistered(bridgeId: "bridge-1");
    tracker.applyStatus(
      status: const ControlStatus(
        relay: ControlRelayConnectionState.connected,
        plugin: ControlPluginHealthState.healthy,
        activeSessionCount: 2,
      ),
    );

    tracker.markHelperDisconnected();

    expect(tracker.status.helperOnline, isFalse);
    expect(tracker.status.relay, ControlRelayConnectionState.disconnected);
    expect(tracker.status.plugin, ControlPluginHealthState.unknown);
    expect(tracker.status.activeSessionCount, 0);
    expect(tracker.status.bridgeId, "bridge-1");
  });

  test("unknown enum values from a newer helper are stored untouched", () {
    tracker.markHelperConnected();
    tracker.applyStatus(
      status: const ControlStatus(
        relay: ControlRelayConnectionState.unknown,
        plugin: ControlPluginHealthState.unknown,
        activeSessionCount: 0,
      ),
    );

    expect(tracker.status.relay, ControlRelayConnectionState.unknown);
    expect(tracker.status.plugin, ControlPluginHealthState.unknown);
  });

  test("a stale status frame processed after disconnect is ignored", () {
    tracker.markHelperConnected();
    tracker.markHelperDisconnected();

    tracker.applyStatus(
      status: const ControlStatus(
        relay: ControlRelayConnectionState.connected,
        plugin: ControlPluginHealthState.healthy,
        activeSessionCount: 5,
      ),
    );

    expect(tracker.status.helperOnline, isFalse);
    expect(tracker.status.relay, ControlRelayConnectionState.disconnected);
    expect(tracker.status.activeSessionCount, 0);
  });

  test("a late registered frame is still recorded while offline", () {
    tracker.handleRegistered(bridgeId: "bridge-late");

    expect(tracker.status.bridgeId, "bridge-late");
  });

  test("writes after dispose are ignored instead of throwing", () {
    final BridgeStatusTracker disposed = BridgeStatusTracker()..dispose();

    expect(disposed.markHelperConnected, returnsNormally);
    expect(disposed.markHelperDisconnected, returnsNormally);
    expect(
      () => disposed.applyStatus(
        status: const ControlStatus(
          relay: ControlRelayConnectionState.connected,
          plugin: ControlPluginHealthState.healthy,
          activeSessionCount: 1,
        ),
      ),
      returnsNormally,
    );
    expect(() => disposed.handleRegistered(bridgeId: "x"), returnsNormally);
  });

  test("the stream pushes every write to subscribers", () async {
    final List<bool> observedHelperOnline = <bool>[];
    final subscription = tracker.statusStream.listen((status) => observedHelperOnline.add(status.helperOnline));
    addTearDown(subscription.cancel);

    tracker.markHelperConnected();
    tracker.markHelperDisconnected();
    await pumpEventQueue();

    expect(observedHelperOnline, [false, true, false]);
  });
}
