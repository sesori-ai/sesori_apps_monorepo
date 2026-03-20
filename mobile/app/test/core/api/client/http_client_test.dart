import "dart:convert";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:sesori_auth/sesori_auth.dart";

import "../../../helpers/test_helpers.dart";

// ignore_for_file: unused_import — test_helpers imported per project convention

void main() {
  group("HttpApiClient", () {
    late HttpApiClient client;

    setUp(() {
      client = HttpApiClient(http.Client());
    });

    test("successful GET returns SuccessResponse with parsed data", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.http("127.0.0.1:${server.port}", "/test");

      server.listen((request) {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({"id": "abc", "value": 42}));
        request.response.close();
      });

      try {
        final result = await client.get<Map<String, dynamic>>(
          uri,
          fromJson: (json) => json as Map<String, dynamic>,
        );

        expect(result, isA<SuccessResponse<Map<String, dynamic>>>());
        final success = result as SuccessResponse<Map<String, dynamic>>;
        expect(success.data, equals({"id": "abc", "value": 42}));
      } finally {
        await server.close(force: true);
      }
    });

    test("HTTP 404 response returns ErrorResponse with NonSuccessCodeError", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.http("127.0.0.1:${server.port}", "/test");

      server.listen((request) {
        request.response
          ..statusCode = 404
          ..write("Not Found");
        request.response.close();
      });

      try {
        final result = await client.get<Map<String, dynamic>>(
          uri,
          fromJson: (json) => json as Map<String, dynamic>,
        );

        expect(result, isA<ErrorResponse<Map<String, dynamic>>>());
        final error = result as ErrorResponse<Map<String, dynamic>>;
        expect(error.error, isA<NonSuccessCodeError>());
        final codeError = error.error as NonSuccessCodeError;
        expect(codeError.errorCode, equals(404));
        expect(codeError.rawErrorString, equals("Not Found"));
      } finally {
        await server.close(force: true);
      }
    });

    test("invalid JSON body returns ErrorResponse with JsonParsingError", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.http("127.0.0.1:${server.port}", "/test");

      server.listen((request) {
        request.response
          ..statusCode = 200
          ..write("{ this is not valid json {{{{");
        request.response.close();
      });

      try {
        final result = await client.get<Map<String, dynamic>>(
          uri,
          fromJson: (json) => json as Map<String, dynamic>,
        );

        expect(result, isA<ErrorResponse<Map<String, dynamic>>>());
        final error = result as ErrorResponse<Map<String, dynamic>>;
        expect(error.error, isA<JsonParsingError>());
        final parseError = error.error as JsonParsingError;
        expect(parseError.jsonString, equals("{ this is not valid json {{{{"));
      } finally {
        await server.close(force: true);
      }
    });

    test("network error returns ErrorResponse with DartHttpClientError", () async {
      // Bind then immediately close to obtain a port guaranteed to be closed.
      final closedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final closedPort = closedServer.port;
      await closedServer.close(force: true);

      final uri = Uri.http("127.0.0.1:$closedPort", "/test");

      final result = await client.get<Map<String, dynamic>>(
        uri,
        fromJson: (json) => json as Map<String, dynamic>,
      );

      expect(result, isA<ErrorResponse<Map<String, dynamic>>>());
      final error = result as ErrorResponse<Map<String, dynamic>>;
      expect(error.error, isA<DartHttpClientError>());
    });

    test("fromJson throwing returns ErrorResponse with JsonParsingError", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.http("127.0.0.1:${server.port}", "/test");

      server.listen((request) {
        // Return valid JSON, but a shape that fromJson cannot handle.
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode([1, 2, 3]));
        request.response.close();
      });

      try {
        final result = await client.get<Map<String, dynamic>>(
          uri,
          // Cast a List to Map — will throw a TypeError caught as JsonParsingError.
          fromJson: (json) => json as Map<String, dynamic>,
        );

        expect(result, isA<ErrorResponse<Map<String, dynamic>>>());
        final error = result as ErrorResponse<Map<String, dynamic>>;
        expect(error.error, isA<JsonParsingError>());
      } finally {
        await server.close(force: true);
      }
    });

    test("successful GET with empty body returns SuccessResponse", () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final uri = Uri.http("127.0.0.1:${server.port}", "/test");

      server.listen((request) {
        request.response.statusCode = 204;
        request.response.close();
      });

      try {
        // Use a nullable type so fromJson(null) succeeds.
        final result = await client.get<String?>(
          uri,
          fromJson: (json) => null,
        );

        expect(result, isA<SuccessResponse<String?>>());
      } finally {
        await server.close(force: true);
      }
    });
  });
}
