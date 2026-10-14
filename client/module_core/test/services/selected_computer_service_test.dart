import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class _Locality({required final String? _localBridgeId}) implements ActiveBridgeLocality {
  @override
  String? get localBridgeId => _localBridgeId;

  @override
  bool isLocalBridge({required String bridgeId}) => bridgeId == _localBridgeId;
}

void main() {
  late MockConnectionService connection;

  setUp(() {
    connection = MockConnectionService();
    when(() => connection.retarget(bridgeId: any(named: "bridgeId"))).thenAnswer((_) async {});
  });

  SelectedComputerService build({required String? stored, required String? local}) {
    when(connection.readTargetBridgeId).thenAnswer((_) async => stored);
    return SelectedComputerService(
      connectionService: connection,
      activeBridgeLocality: _Locality(localBridgeId: local),
    );
  }

  test("a stored target wins over the local computer", () async {
    await build(stored: "remote", local: "local").ensureInitialTarget();

    verifyNever(() => connection.retarget(bridgeId: any(named: "bridgeId")));
  });

  test("without a stored target the local computer is pinned", () async {
    await build(stored: null, local: "local").ensureInitialTarget();

    verify(() => connection.retarget(bridgeId: "local")).called(1);
  });

  test("without a stored target or a local computer nothing is pinned", () async {
    await build(stored: null, local: null).ensureInitialTarget();

    verifyNever(() => connection.retarget(bridgeId: any(named: "bridgeId")));
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
