import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerCoreFallbackValues();
    registerFallbackValue(
      const RelayRequest(id: "fake-id", method: "GET", path: "/", headers: {}, body: null),
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
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '{"value":"relay-result"}',
          ),
        );

        // Act
        final result = await client.get<String>("/session", fromJson: (json) => json["value"] as String);

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        expect((result as SuccessResponse<String>).data, equals("relay-result"));
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("GET"));
        expect(request.path, contains("/session"));
      });

      test("POST sends request via relay and returns parsed response", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '{"value":"ok"}',
          ),
        );

        // Act
        final result = await client.post<String>(
          "/session",
          fromJson: (json) => json["value"] as String,
          body: {"key": "value"},
        );

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("POST"));
        expect(request.path, contains("/session"));
      });

      test("attachment POST uses its longer timeout", () async {
        const timeout = Duration(minutes: 2);
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '{"mime":"image/png","base64":"AQID","byteLength":3}',
          ),
        );

        final result = await client.postWithTimeout<SessionAttachmentResponse>(
          "/session/attachment",
          fromJson: SessionAttachmentResponse.fromJson,
          body: const SessionAttachmentRequest(
            sessionId: "session-1",
            attachmentId: "attachment-1",
            rendition: SessionAttachmentRendition.original,
          ),
          timeout: timeout,
        );

        expect(result, isA<SuccessResponse<SessionAttachmentResponse>>());
        final verification = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: timeout,
          ),
        )..called(1);
        final request = verification.captured.single as RelayRequest;
        expect(request.path, "/session/attachment");
        expect(
          SessionAttachmentRequest.fromJson(jsonDecodeMap(request.body!)),
          const SessionAttachmentRequest(
            sessionId: "session-1",
            attachmentId: "attachment-1",
            rendition: SessionAttachmentRendition.original,
          ),
        );
      });

      test("malformed attachment response redacts decrypted content", () async {
        const secret = "secret-attachment-base64";
        final logs = <String>[];
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '{"mime":"image/png","base64":"secret-attachment-base64","byteLength":"invalid"}',
          ),
        );

        final result = await runZoned(
          () => client.postWithTimeout<SessionAttachmentResponse>(
            "/session/attachment",
            fromJson: SessionAttachmentResponse.fromJson,
            body: const SessionAttachmentRequest(
              sessionId: "session-1",
              attachmentId: "attachment-1",
              rendition: SessionAttachmentRendition.thumbnail,
            ),
            timeout: const Duration(minutes: 2),
          ),
          zoneSpecification: ZoneSpecification(
            print: (_, _, _, line) => logs.add(line),
          ),
        );

        final error = (result as ErrorResponse<SessionAttachmentResponse>).error as JsonParsingError;
        expect(error.jsonString, "Sensitive response omitted");
        expect(error.jsonString, isNot(contains(secret)));
        expect(logs.join("\n"), isNot(contains(secret)));
        expect(error.toString(), isNot(contains(secret)));
      });

      test("attachment error response redacts decrypted content", () async {
        const secret = "secret-attachment-error";
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(id: "req-1", status: 404, headers: {}, body: secret),
        );

        final result = await client.postWithTimeout<SessionAttachmentResponse>(
          "/session/attachment",
          fromJson: SessionAttachmentResponse.fromJson,
          body: const SessionAttachmentRequest(
            sessionId: "session-1",
            attachmentId: "attachment-1",
            rendition: SessionAttachmentRendition.thumbnail,
          ),
          timeout: const Duration(minutes: 2),
        );

        final error = (result as ErrorResponse<SessionAttachmentResponse>).error as NonSuccessCodeError;
        expect(error.rawErrorString, isNull);
        expect(error.toString(), isNot(contains(secret)));
      });

      test("PATCH sends request via relay and returns parsed response", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: '{"value":"ok"}',
          ),
        );

        // Act
        final result = await client.patch<String>(
          "/session/1",
          fromJson: (json) => json["value"] as String,
          body: {"key": "value"},
        );

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("PATCH"));
        expect(request.path, contains("/session/1"));
      });

      test("DELETE sends request via relay and returns parsed response", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 200,
            headers: {},
            body: "{}",
          ),
        );

        // Act
        final result = await client.delete<String>(
          "/session/1",
          fromJson: (json) => json.toString(),
        );

        // Assert
        expect(result, isA<SuccessResponse<String>>());
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        expect(request.method, equals("DELETE"));
        expect(request.path, contains("/session/1"));
      });

      test("relay exception is mapped to GenericError", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenThrow(Exception("Relay transport failed"));

        // Act
        final result = await client.get<String>(
          "/session",
          fromJson: (json) => json.toString(),
        );

        // Assert
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<GenericError>());
      });

      test("appends query parameters to the relay request path", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(id: "req-3", status: 200, headers: {}, body: "{}"),
        );

        // Act
        await client.get<String>(
          "/search",
          fromJson: (json) => json.toString(),
          queryParameters: {"q": "flutter", "limit": "10"},
        );

        // Assert
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        final uri = Uri.parse(request.path);
        expect(uri.queryParameters["q"], equals("flutter"));
        expect(uri.queryParameters["limit"], equals("10"));
      });

      test("merges custom headers with request headers", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(id: "req-4", status: 200, headers: {}, body: "{}"),
        );

        // Act
        await client.get<String>(
          "/session",
          fromJson: (json) => json.toString(),
          headers: {"x-project-id": "/home/user/project"},
        );

        // Assert
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        expect(request.headers["x-project-id"], equals("/home/user/project"));
      });

      test("merges custom headers with content-type header for POST", () async {
        // Arrange
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(id: "req-5", status: 200, headers: {}, body: "{}"),
        );

        // Act
        await client.post<String>(
          "/session",
          fromJson: (json) => json.toString(),
          body: {"key": "value"},
          headers: {"x-project-id": "/home/user/project"},
        );

        // Assert
        final captured = verify(
          () => mockRelayClient.sendRequest(
            request: captureAny(named: "request"),
            timeout: const Duration(seconds: 30),
          ),
        ).captured;
        final request = captured.first as RelayRequest;
        expect(request.headers["x-project-id"], equals("/home/user/project"));
        expect(request.headers["content-type"], equals("application/json"));
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
          fromJson: (json) => json.toString(),
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
          fromJson: (json) => json.toString(),
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
          fromJson: (json) => json.toString(),
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
          fromJson: (json) => json.toString(),
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
          fromJson: (json) => json.toString(),
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
        when(
          () => mockRelayClient.sendRequest(
            request: any(named: "request"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => const RelayResponse(
            id: "req-1",
            status: 401,
            headers: {},
            body: "Unauthorized",
          ),
        );

        // Act
        final result = await client.get<String>("/protected", fromJson: (json) => json.toString());

        // Assert: 401 should be re-mapped to NotAuthenticatedError
        expect(result, isA<ErrorResponse<String>>());
        final error = (result as ErrorResponse<String>).error;
        expect(error, isA<NotAuthenticatedError>());
      });
    });
  });
}
