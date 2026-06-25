import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/bridge_api.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockAuthenticatedHttpApiClient extends Mock implements AuthenticatedHttpApiClient {}

/// A `GET /auth/bridges` payload with one registered bridge.
const _bridgesPayload = <String, dynamic>{
  "bridges": [
    {
      "id": "br_abc12345",
      "name": "alex-macbook",
      "platform": "macos",
      "addedAt": "2026-01-01T00:00:00.000Z",
      "lastSeenAt": null,
    },
  ],
};

void main() {
  late MockAuthenticatedHttpApiClient mockClient;
  late BridgeApi api;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockClient = MockAuthenticatedHttpApiClient();
    api = BridgeApi(client: mockClient);
  });

  group("BridgeApi", () {
    test("fetchRegisteredBridges GETs /auth/bridges and parses the payload", () async {
      when(
        () => mockClient.get<BridgesListResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((invocation) async {
        // Run the payload through the API's own fromJson so the parse path
        // is exercised, mirroring what the real client does.
        final fromJson = invocation.namedArguments[#fromJson]! as BridgesListResponse Function(dynamic);
        return ApiResponse.success(fromJson(_bridgesPayload));
      });

      final response = await api.fetchRegisteredBridges();

      expect(response, isA<SuccessResponse<BridgesListResponse>>());
      final data = (response as SuccessResponse<BridgesListResponse>).data;
      expect(data.bridges, hasLength(1));
      expect(data.bridges.first.id, "br_abc12345");

      verify(
        () => mockClient.get<BridgesListResponse>(
          Uri.parse("$authBaseUrl/auth/bridges"),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).called(1);
    });

    test("fetchRegisteredBridges passes the client error through", () async {
      when(
        () => mockClient.get<BridgesListResponse>(
          any(),
          fromJson: any(named: "fromJson"),
          headers: any(named: "headers"),
          contentType: any(named: "contentType"),
          logBody: any(named: "logBody"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "error")));

      final response = await api.fetchRegisteredBridges();

      expect(
        response,
        isA<ErrorResponse<BridgesListResponse>>().having((r) => r.error, "error", isA<NonSuccessCodeError>()),
      );
    });
  });
}
