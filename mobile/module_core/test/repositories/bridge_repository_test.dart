import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_api.dart";
import "package:sesori_dart_core/src/repositories/bridge_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

class MockBridgeApi extends Mock implements BridgeApi {}

void main() {
  late MockBridgeApi mockApi;
  late BridgeRepository repository;

  setUp(() {
    mockApi = MockBridgeApi();
    repository = BridgeRepository(api: mockApi);
  });

  group("BridgeRepository", () {
    test("getRegisteredBridges maps the response to its bridges list", () async {
      final bridges = [testBridgeSummary(id: "br_1"), testBridgeSummary(id: "br_2")];
      when(() => mockApi.fetchRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success(BridgesListResponse(bridges: bridges)),
      );

      final response = await repository.getRegisteredBridges();

      expect(
        response,
        isA<SuccessResponse<List<BridgeSummary>>>().having((r) => r.data, "bridges", bridges),
      );
    });

    test("getRegisteredBridges returns an empty list for an account without bridges", () async {
      when(() => mockApi.fetchRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.success(const BridgesListResponse(bridges: [])),
      );

      final response = await repository.getRegisteredBridges();

      expect(
        response,
        isA<SuccessResponse<List<BridgeSummary>>>().having((r) => r.data, "bridges", isEmpty),
      );
    });

    test("getRegisteredBridges passes the API error through", () async {
      when(() => mockApi.fetchRegisteredBridges()).thenAnswer(
        (_) async => ApiResponse.error(ApiError.generic()),
      );

      final response = await repository.getRegisteredBridges();

      expect(
        response,
        isA<ErrorResponse<List<BridgeSummary>>>().having((r) => r.error, "error", isA<GenericError>()),
      );
    });
  });
}
