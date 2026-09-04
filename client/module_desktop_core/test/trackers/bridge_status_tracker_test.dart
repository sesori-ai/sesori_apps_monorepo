import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../support/bridge_id_storage.dart";

void main() {
  late BridgeStatusTracker tracker;
  late MemoryBridgeIdStorage storage;

  setUp(() {
    storage = MemoryBridgeIdStorage();
    tracker = BridgeStatusTracker(bridgeIdStorage: storage);
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

  test("disconnect resets status to the baseline but retains bridgeId", () async {
    tracker.markHelperConnected();
    tracker.handleRegistered(bridgeId: "bridge-1", accountId: "account-a");
    await pumpEventQueue();
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

  test("a late registered frame is still recorded while offline", () async {
    final Future<BridgeRegistrationRecord> registrationEvent = tracker.registrationEvents.first;

    tracker.handleRegistered(bridgeId: "bridge-late", accountId: "account-a");
    await pumpEventQueue();

    expect(tracker.status.bridgeId, "bridge-late");
    expect(storage.bridgeId, "bridge-late");
    expect(
      await registrationEvent,
      const BridgeRegistrationRecord(bridgeId: "bridge-late", accountId: "account-a"),
    );
  });

  test("initializes its bridge id and owner from persisted storage", () async {
    const BridgeRegistrationRecord registration = BridgeRegistrationRecord(
      bridgeId: "bridge-persisted",
      accountId: "account-a",
    );
    storage.registration = registration;
    await tracker.initialize();

    expect(tracker.status.bridgeId, "bridge-persisted");
    expect(tracker.registeredBridge, registration);
  });

  test("clears only the bridge id it deleted", () async {
    tracker.handleRegistered(bridgeId: "bridge-current", accountId: "account-a");
    await pumpEventQueue();

    await tracker.clearBridgeId(
      registration: const BridgeRegistrationRecord(
        bridgeId: "bridge-other",
        accountId: "account-a",
      ),
    );
    expect(storage.bridgeId, "bridge-current");
    expect(tracker.status.bridgeId, "bridge-current");

    await tracker.clearBridgeId(
      registration: const BridgeRegistrationRecord(
        bridgeId: "bridge-current",
        accountId: "account-a",
      ),
    );
    expect(storage.bridgeId, isNull);
    expect(tracker.status.bridgeId, isNull);
  });

  test("does not clear a record with a different owning account", () async {
    tracker.handleRegistered(bridgeId: "bridge-owned", accountId: "account-a");
    await pumpEventQueue();

    await tracker.clearBridgeId(
      registration: const BridgeRegistrationRecord(
        bridgeId: "bridge-owned",
        accountId: "account-b",
      ),
    );

    expect(storage.registration?.bridgeId, "bridge-owned");
    expect(storage.registration?.accountId, "account-a");
    expect(tracker.registeredBridge?.accountId, "account-a");
  });

  test("writes after dispose are ignored instead of throwing", () async {
    final BridgeStatusTracker disposed = BridgeStatusTracker(
      bridgeIdStorage: MemoryBridgeIdStorage(),
    );
    await disposed.dispose();

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
    expect(
      () => disposed.handleRegistered(bridgeId: "x", accountId: "account-a"),
      returnsNormally,
    );
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
