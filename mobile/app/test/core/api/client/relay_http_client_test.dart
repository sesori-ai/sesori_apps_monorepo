import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../../helpers/test_helpers.dart";

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      const RelayRequest(id: "fake-id", method: "GET", path: "/", headers: {}),
    );
  });

  group("RelayHttpApiClient", () {
    late MockConnectionService mockConnectionService;
    late MockRelayClient mockRelayClient;
    late RelayHttpApiClient client;

    setUp(() {
      mockConnectionService = MockConnectionService();
      mockRelayClient = MockRelayClient();
      client = RelayHttpApiClient(mockConnectionService);
    });

    // ---------------------------------------------------------------------------
    // relay connected
    // ---------------------------------------------------------------------------

    group("relay connected", () {
      setUp(() {
        when(() => mockConnectionService.relayClient).thenReturn(mockRelayClient);
        when(() => mockRelayClient.isConnected).thenReturn(true);
        when(() => mockConnectionService.activeDirectory).thenReturn(null);
      });

      test("GET sends request via relay and returns parsed response", () async {
        // Arrange
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '"relay-result"',
          ),
        );

        // Act
        final result = await client.get<String>("/session", fromJson: (json) => json as String);

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        expect((result as SuccessResponse<String>).data, equals("relay-result"));
        final captured = verify(() => mockRelayClient.sendRequest(captureAny())).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("GET"));
        expect(request.path, contains("/session"));
      });

      test("POST sends request via relay and returns parsed response", () async {
        // Arrange
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '"ok"',
          ),
        );

        // Act
        final result = await client.post<String>(
          "/session",
          fromJson: (json) => json as String,
          body: {"key": "value"},
        );

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        final captured = verify(() => mockRelayClient.sendRequest(captureAny())).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("POST"));
        expect(request.path, contains("/session"));
      });

      test("PATCH sends request via relay and returns parsed response", () async {
        // Arrange
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '"ok"',
          ),
        );

        // Act
        final result = await client.patch<String>(
          "/session/1",
          fromJson: (json) => json as String,
          body: {"key": "value"},
        );

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        final captured = verify(() => mockRelayClient.sendRequest(captureAny())).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("PATCH"));
        expect(request.path, contains("/session/1"));
      });

      test("DELETE sends request via relay and returns parsed response", () async {
        // Arrange
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: "null",
          ),
        );

        // Act
        final result = await client.delete<String>(
          "/session/1",
          fromJson: (json) => json?.toString() ?? "",
        );

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        final captured = verify(() => mockRelayClient.sendRequest(captureAny())).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("DELETE"));
        expect(request.path, contains("/session/1"));
      });

      test("relay exception is mapped to GenericError", () async {
        // Arrange
        when(() => mockRelayClient.sendRequest(any())).thenThrow(Exception("Relay transport failed"));

        // Act
        final result = await client.get<String>(
          "/session",
          fromJson: (json) => json?.toString() ?? "",
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<GenericError>());
      });

      test("injects x-opencode-directory header in RelayRequest when activeDirectory is set", () async {
        // Arrange
        const directory = "/home/user/relay-project";
        when(() => mockConnectionService.activeDirectory).thenReturn(directory);
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(id: "req-2", status: 200, headers: {}, body: "null"),
        );

        // Act
        await client.get<String>("/project", fromJson: (json) => json?.toString() ?? "");

        // Assert
        final captured = verify(() => mockRelayClient.sendRequest(captureAny())).captured;
        final request = captured.first as RelayRequest;
        expect(request.headers["x-opencode-directory"], equals(directory));
      });

      test("appends query parameters to the relay request path", () async {
        // Arrange
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(id: "req-3", status: 200, headers: {}, body: "null"),
        );

        // Act
        await client.get<String>(
          "/search",
          fromJson: (json) => json?.toString() ?? "",
          queryParameters: {"q": "flutter", "limit": "10"},
        );

        // Assert
        final captured = verify(() => mockRelayClient.sendRequest(captureAny())).captured;
        final request = captured.first as RelayRequest;
        final uri = Uri.parse(request.path);
        expect(uri.queryParameters["q"], equals("flutter"));
        expect(uri.queryParameters["limit"], equals("10"));
      });
    });

    // ---------------------------------------------------------------------------
    // relay disconnected
    // ---------------------------------------------------------------------------

    group("relay disconnected", () {
      test("GET returns DartHttpClientError when relayClient is null", () async {
        // Arrange
        when(() => mockConnectionService.relayClient).thenReturn(null);

        // Act
        final result = await client.get<String>(
          "/health",
          fromJson: (json) => json?.toString() ?? "",
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<DartHttpClientError>());
      });

      test("GET returns DartHttpClientError when relay isConnected is false", () async {
        // Arrange
        when(() => mockConnectionService.relayClient).thenReturn(mockRelayClient);
        when(() => mockRelayClient.isConnected).thenReturn(false);

        // Act
        final result = await client.get<String>(
          "/health",
          fromJson: (json) => json?.toString() ?? "",
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<DartHttpClientError>());
      });

      test("POST returns DartHttpClientError when relay is not connected", () async {
        // Arrange
        when(() => mockConnectionService.relayClient).thenReturn(null);

        // Act
        final result = await client.post<String>(
          "/session",
          fromJson: (json) => json?.toString() ?? "",
          body: null,
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<DartHttpClientError>());
      });

      test("PATCH returns DartHttpClientError when relay is not connected", () async {
        // Arrange
        when(() => mockConnectionService.relayClient).thenReturn(null);

        // Act
        final result = await client.patch<String>(
          "/session/1",
          fromJson: (json) => json?.toString() ?? "",
          body: null,
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<DartHttpClientError>());
      });

      test("DELETE returns DartHttpClientError when relay is not connected", () async {
        // Arrange
        when(() => mockConnectionService.relayClient).thenReturn(null);

        // Act
        final result = await client.delete<String>(
          "/session/1",
          fromJson: (json) => json?.toString() ?? "",
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<DartHttpClientError>());
      });
    });

    // ---------------------------------------------------------------------------
    // auth error mapping
    // ---------------------------------------------------------------------------

    group("auth error mapping", () {
      test("401 relay response is mapped to NotAuthenticatedError", () async {
        // Arrange
        when(() => mockConnectionService.relayClient).thenReturn(mockRelayClient);
        when(() => mockRelayClient.isConnected).thenReturn(true);
        when(() => mockConnectionService.activeDirectory).thenReturn(null);
        when(() => mockRelayClient.sendRequest(any())).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 401,
            headers: {},
            body: "Unauthorized",
          ),
        );

        // Act
        final result = await client.get<String>("/protected", fromJson: (json) => json?.toString() ?? "");

        // Assert: 401 should be re-mapped to NotAuthenticatedError
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<NotAuthenticatedError>());
      });
    });
  });
}
