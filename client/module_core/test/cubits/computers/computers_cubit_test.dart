import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_helpers.dart";

class _MockSelectedComputerService() extends Mock implements SelectedComputerService;

void main() {
  late MockRegisteredBridgesService registeredBridges;
  late _MockSelectedComputerService selectedComputer;

  setUp(() {
    registeredBridges = MockRegisteredBridgesService();
    selectedComputer = _MockSelectedComputerService();
    when(
      () => selectedComputer.replacementAfterRemoving(
        bridgeId: any(named: "bridgeId"),
        wasCurrent: any(named: "wasCurrent"),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => selectedComputer.replacementAfterRemoving(bridgeId: "current", wasCurrent: true),
    ).thenAnswer((_) async => "next");
  });

  ComputersCubit build() {
    final cubit = ComputersCubit(
      registeredBridgesService: registeredBridges,
      selectedComputerService: selectedComputer,
    );
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

  test("a rename that throws reports the failure for that computer", () async {
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: "Studio"),
    ).thenThrow(const FormatException("unexpected body"));
    final cubit = build();

    await cubit.rename(computer: unnamed, name: "Studio");

    expect(cubit.state, isA<ComputersRenameFailed>().having((state) => state.bridgeId, "bridgeId", "a"));
  });

  test("a refused rename reports the failure for that computer", () async {
    when(
      () => registeredBridges.rename(bridgeId: "a", nickname: "Studio"),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = build();

    await cubit.rename(computer: unnamed, name: "Studio");

    expect(cubit.state, isA<ComputersRenameFailed>().having((state) => state.bridgeId, "bridgeId", "a"));
  });

  test("a removal runs, then settles back to idle without a switch for another computer", () async {
    final response = Completer<ApiResponse<void>>();
    when(() => registeredBridges.remove(bridgeId: "a")).thenAnswer((_) => response.future);
    final cubit = build();

    final remove = cubit.remove(bridgeId: "a", isCurrent: false);
    expect(cubit.state, isA<ComputersRemoving>().having((state) => state.bridgeId, "bridgeId", "a"));

    response.complete(ApiResponse.success(null));
    expect(await remove, isNull);
    expect(cubit.state, isA<ComputersIdle>());
    verify(() => selectedComputer.replacementAfterRemoving(bridgeId: "a", wasCurrent: false)).called(1);
  });

  test("removing the computer the app works on returns its replacement", () async {
    when(() => registeredBridges.remove(bridgeId: "current")).thenAnswer((_) async => ApiResponse.success(null));
    final cubit = build();

    expect(await cubit.remove(bridgeId: "current", isCurrent: true), "next");
    expect(cubit.state, isA<ComputersIdle>());
  });

  test("a page closed during the removal still gets the replacement", () async {
    final response = Completer<ApiResponse<void>>();
    when(() => registeredBridges.remove(bridgeId: "current")).thenAnswer((_) => response.future);
    final cubit = build();

    final remove = cubit.remove(bridgeId: "current", isCurrent: true);
    await cubit.close();
    response.complete(ApiResponse.success(null));

    expect(await remove, "next");
  });

  test("a refused removal reports the failure for that computer and switches nowhere", () async {
    when(
      () => registeredBridges.remove(bridgeId: "current"),
    ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));
    final cubit = build();

    expect(await cubit.remove(bridgeId: "current", isCurrent: true), isNull);
    expect(cubit.state, isA<ComputersRemoveFailed>().having((state) => state.bridgeId, "bridgeId", "current"));
    verifyNever(
      () => selectedComputer.replacementAfterRemoving(
        bridgeId: any(named: "bridgeId"),
        wasCurrent: any(named: "wasCurrent"),
      ),
    );
  });

  test("a removal that throws reports the failure for that computer", () async {
    when(() => registeredBridges.remove(bridgeId: "current")).thenThrow(const FormatException("unexpected body"));
    final cubit = build();

    expect(await cubit.remove(bridgeId: "current", isCurrent: true), isNull);
    expect(cubit.state, isA<ComputersRemoveFailed>().having((state) => state.bridgeId, "bridgeId", "current"));
  });
}
