import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

void main() {
  late MockRegisteredBridgesService registeredBridges;

  setUp(() => registeredBridges = MockRegisteredBridgesService());

  ComputersCubit build() {
    final cubit = ComputersCubit(registeredBridgesService: registeredBridges);
    addTearDown(cubit.close);
    return cubit;
  }

  test("a rename runs, then settles back to idle", () async {
    final response = Completer<ApiResponse<BridgeSummary>>();
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: "Studio"),
    ).thenAnswer((_) => response.future);
    final cubit = build();
    expect(cubit.state, isA<ComputersIdle>());

    final rename = cubit.rename(bridgeId: "a", nickname: "Studio");
    expect(cubit.state, isA<ComputersRenaming>().having((state) => state.bridgeId, "bridgeId", "a"));

    response.complete(ApiResponse.success(testBridgeSummary(id: "a", name: "Studio")));
    await rename;
    expect(cubit.state, isA<ComputersIdle>());
  });

  test("a null nickname clears it on the server", () async {
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: null),
    ).thenAnswer((_) async => ApiResponse.success(testBridgeSummary(id: "a")));
    final cubit = build();

    await cubit.rename(bridgeId: "a", nickname: null);

    verify(() => registeredBridges.rename(bridgeId: "a", nickname: null)).called(1);
    expect(cubit.state, isA<ComputersIdle>());
  });

  test("a refused rename reports the failure for that computer", () async {
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: "Studio"),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = build();

    await cubit.rename(bridgeId: "a", nickname: "Studio");

    expect(cubit.state, isA<ComputersRenameFailed>().having((state) => state.bridgeId, "bridgeId", "a"));
  });
}
