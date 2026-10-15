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

  final named = testBridgeSummary(id: "a", name: "Studio", hostname: "studio-mac.local");
  final unnamed = testBridgeSummary(id: "a", name: "studio-mac.local", hostname: "studio-mac.local");

  test("a rename runs, then settles back to idle", () async {
    final response = Completer<ApiResponse<BridgeSummary>>();
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: "Studio"),
    ).thenAnswer((_) => response.future);
    final cubit = build();
    expect(cubit.state, isA<ComputersIdle>());

    final rename = cubit.rename(computer: unnamed, name: "  Studio  ");
    expect(cubit.state, isA<ComputersRenaming>().having((state) => state.bridgeId, "bridgeId", "a"));

    response.complete(ApiResponse.success(testBridgeSummary(id: "a", name: "Studio")));
    await rename;
    expect(cubit.state, isA<ComputersIdle>());
  });

  for (final (description, name) in [("a blank name", "   "), ("the hostname", "studio-mac.local")]) {
    test("$description clears the name of its own", () async {
      when(
        () => registeredBridges.rename(bridgeId: "a", nickname: null),
      ).thenAnswer((_) async => ApiResponse.success(unnamed));
      final cubit = build();

      await cubit.rename(computer: named, name: name);

      verify(() => registeredBridges.rename(bridgeId: "a", nickname: null)).called(1);
      expect(cubit.state, isA<ComputersIdle>());
    });
  }

  test("an unchanged name sends nothing", () async {
    final cubit = build();

    await cubit.rename(computer: named, name: " Studio ");
    await cubit.rename(computer: unnamed, name: "");

    verifyNever(
      () => registeredBridges.rename(
        bridgeId: any(named: "bridgeId"),
        nickname: any(named: "nickname"),
      ),
    );
    expect(cubit.state, isA<ComputersIdle>());
  });

  test("a refused rename reports the failure for that computer", () async {
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: "Studio"),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = build();

    await cubit.rename(computer: unnamed, name: "Studio");

    expect(cubit.state, isA<ComputersRenameFailed>().having((state) => state.bridgeId, "bridgeId", "a"));
  });
}
