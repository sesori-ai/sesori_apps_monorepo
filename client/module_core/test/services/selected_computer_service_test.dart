import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _Locality({required final String? _localBridgeId}) implements ActiveBridgeLocality {
  @override
  String? get localBridgeId => _localBridgeId;

  @override
  Stream<String?> get localBridgeIdStream => const Stream.empty();

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == _localBridgeId;
}

void main() {
  late MockConnectionService connection;
  late MockRegisteredBridgesService registeredBridges;
  late MockProductAnalyticsService analytics;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    connection = MockConnectionService();
    registeredBridges = MockRegisteredBridgesService();
    analytics = stubbedProductAnalyticsService();
    when(() => connection.retarget(bridgeId: any(named: "bridgeId"))).thenAnswer((_) async {});
  });

  SelectedComputerService build({required String? stored, required String? local}) {
    when(connection.readTargetBridgeId).thenAnswer((_) async => stored);
    return SelectedComputerService(
      connectionService: connection,
      activeBridgeLocality: _Locality(localBridgeId: local),
      registeredBridgesService: registeredBridges,
      productAnalyticsService: analytics,
    );
  }

  ProductAnalyticsEvent reportedEvent() =>
      verify(
            () => analytics.logEvent(
              event: captureAny(named: "event"),
              occurredAtUtc: any(named: "occurredAtUtc"),
            ),
          ).captured.single
          as ProductAnalyticsEvent;

  test("select reports the switch with its source and the target's state, then retargets", () async {
    registeredBridges.emitBridges(
      bridges: [
        testBridgeSummary(id: "online"),
        testBridgeSummary(id: "offline", status: BridgeRegistrationStatus.inactive),
      ],
    );
    final service = build(stored: null, local: null);

    await service.select(bridgeId: "offline", source: ComputerSwitchSource.menu);

    final event = reportedEvent();
    expect(event.wireName, "computer_switched");
    expect(event.parameters, {"source": "menu", "target_online": "false"});
    verify(() => connection.retarget(bridgeId: "offline")).called(1);

    await service.select(bridgeId: "online", source: ComputerSwitchSource.menu);
    expect(reportedEvent().parameters, {"source": "menu", "target_online": "true"});
  });

  test("select reports a computer missing from the list as offline", () async {
    await build(stored: null, local: null).select(bridgeId: "unknown", source: ComputerSwitchSource.notification);

    expect(reportedEvent().parameters, {"source": "notification", "target_online": "false"});
    verify(() => connection.retarget(bridgeId: "unknown")).called(1);
  });

  group("replacementAfterRemoving", () {
    Future<String?> replacement({
      required List<BridgeSummary> bridges,
      required String removed,
      required String? stored,
      required bool wasCurrent,
    }) {
      registeredBridges.emitBridges(bridges: bridges);
      when(() => connection.currentStatus).thenReturn(const ConnectionStatus.disconnected());
      return build(stored: stored, local: null).replacementAfterRemoving(bridgeId: removed, wasCurrent: wasCurrent);
    }

    final two = [testBridgeSummary(id: "removed"), testBridgeSummary(id: "other")];

    test("moves away from the stored target", () async {
      expect(await replacement(bridges: two, removed: "removed", stored: "removed", wasCurrent: false), "other");
    });

    test("moves away from a current computer without a stored target", () async {
      expect(await replacement(bridges: two, removed: "removed", stored: null, wasCurrent: true), "other");
    });

    test("keeps a switch elsewhere made while the removal ran", () async {
      expect(await replacement(bridges: two, removed: "removed", stored: "other", wasCurrent: true), isNull);
    });

    test("moves nowhere when the removed computer was not current", () async {
      expect(await replacement(bridges: two, removed: "removed", stored: null, wasCurrent: false), isNull);
    });

    test("prefers the first other online computer", () async {
      expect(
        await replacement(
          bridges: [
            testBridgeSummary(id: "removed"),
            testBridgeSummary(id: "offline", status: BridgeRegistrationStatus.inactive),
            testBridgeSummary(id: "online"),
            testBridgeSummary(id: "online-older"),
          ],
          removed: "removed",
          stored: null,
          wasCurrent: true,
        ),
        "online",
      );
    });

    test("falls back to the first other computer when none is online", () async {
      expect(
        await replacement(
          bridges: [
            testBridgeSummary(id: "offline", status: BridgeRegistrationStatus.inactive),
            testBridgeSummary(id: "removed"),
            testBridgeSummary(id: "offline-older", status: BridgeRegistrationStatus.inactive),
          ],
          removed: "removed",
          stored: null,
          wasCurrent: true,
        ),
        "offline",
      );
    });

    test("is null when no other computer remains", () async {
      expect(
        await replacement(
          bridges: [testBridgeSummary(id: "removed")],
          removed: "removed",
          stored: null,
          wasCurrent: true,
        ),
        isNull,
      );
      expect(await replacement(bridges: const [], removed: "removed", stored: null, wasCurrent: true), isNull);
    });
  });

  test("a stored target wins over the local computer", () async {
    await build(stored: "remote", local: null).ensureInitialTarget(localBridgeId: "local");

    verifyNever(() => connection.retarget(bridgeId: any(named: "bridgeId")));
  });

  test("without a stored target the local computer is pinned", () async {
    await build(stored: null, local: null).ensureInitialTarget(localBridgeId: "local");

    verify(() => connection.retarget(bridgeId: "local")).called(1);
  });

  test("without a stored target or a local computer nothing is pinned", () async {
    await build(stored: null, local: null).ensureInitialTarget(localBridgeId: null);

    verifyNever(() => connection.retarget(bridgeId: any(named: "bridgeId")));
  });

  test("a new local computer id becomes the target", () async {
    await build(stored: "relay-default", local: null).followLocalComputer(bridgeId: "local");

    verify(() => connection.retarget(bridgeId: "local")).called(1);
  });

  test("another computer picked in this sign-in is never replaced by the local one", () async {
    final service = build(stored: null, local: "local");
    await service.select(bridgeId: "remote", source: ComputerSwitchSource.menu);

    await service.followLocalComputer(bridgeId: "local-new");

    verifyNever(() => connection.retarget(bridgeId: "local-new"));
  });

  test("picking this computer keeps following it", () async {
    final service = build(stored: null, local: "local");
    await service.select(bridgeId: "remote", source: ComputerSwitchSource.menu);
    await service.select(bridgeId: "local", source: ComputerSwitchSource.menu);

    await service.followLocalComputer(bridgeId: "local-new");

    verify(() => connection.retarget(bridgeId: "local-new")).called(1);
  });

  test("a sign-out forgets the pick, so the next sign-in follows this computer", () async {
    final service = build(stored: null, local: "local");
    await service.select(bridgeId: "remote", source: ComputerSwitchSource.menu);

    service.forgetPick();
    await service.followLocalComputer(bridgeId: "local-new");

    verify(() => connection.retarget(bridgeId: "local-new")).called(1);
  });

  test("the target is the live connection's, else the stored one", () async {
    when(() => connection.currentStatus).thenReturn(const ConnectionStatus.disconnected());
    final service = build(stored: "stored", local: null);
    expect(await service.targetBridgeId(), "stored");

    when(() => connection.currentStatus).thenReturn(
      const ConnectionStatus.reconnecting(
        config: ServerConnectionConfig(relayHost: "relay", authToken: "t", bridgeId: "live"),
      ),
    );
    expect(await service.targetBridgeId(), "live");
  });
}
