import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class const _Locality({@override required final String? localBridgeId}) implements ActiveBridgeLocality {
  @override
  Stream<String?> get localBridgeIdStream => const Stream.empty();

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == localBridgeId;
}

void main() {
  late MockRegisteredBridgesService registeredBridges;

  setUp(() => registeredBridges = MockRegisteredBridgesService());

  Future<List<LinkedComputerAlert?>> alertsAfter({
    required List<List<BridgeSummary>> lists,
    required String? localBridgeId,
  }) async {
    final cubit = LinkedComputerAlertCubit(
      registeredBridgesService: registeredBridges,
      activeBridgeLocality: _Locality(localBridgeId: localBridgeId),
    );
    final alerts = <LinkedComputerAlert?>[];
    final subscription = cubit.stream.listen(alerts.add);
    for (final bridges in lists) {
      registeredBridges.emitBridges(bridges: bridges);
      await Future<void>.delayed(Duration.zero);
    }
    await subscription.cancel();
    await cubit.close();
    return alerts;
  }

  final laptop = testBridgeSummary(id: "br_laptop", name: "dev-laptop");
  final workstation = testBridgeSummary(id: "br_workstation", name: "workstation");

  test("announces a computer the list gains", () async {
    final alerts = await alertsAfter(
      lists: [
        [laptop],
        [workstation, laptop],
      ],
      localBridgeId: null,
    );

    expect(alerts.map((alert) => (alert?.bridgeId, alert?.name)), [("br_workstation", "workstation")]);
  });

  test("announces nothing for the first list, which holds the account's computers", () async {
    final alerts = await alertsAfter(
      lists: [
        [laptop],
      ],
      localBridgeId: null,
    );

    expect(alerts, isEmpty);
  });

  test("announces nothing for the first list after sign-out", () async {
    final alerts = await alertsAfter(
      lists: [
        [laptop],
        [],
        [workstation],
      ],
      localBridgeId: null,
    );

    expect(alerts, isEmpty);
  });

  test("never announces this surface's own computer", () async {
    final alerts = await alertsAfter(
      lists: [
        [laptop],
        [workstation, laptop],
      ],
      localBridgeId: "br_workstation",
    );

    expect(alerts, isEmpty);
  });

  test("announces nothing when only a known computer's status changes", () async {
    final alerts = await alertsAfter(
      lists: [
        [laptop],
        [laptop.copyWith(status: BridgeRegistrationStatus.inactive)],
      ],
      localBridgeId: null,
    );

    expect(alerts, isEmpty);
  });
}
