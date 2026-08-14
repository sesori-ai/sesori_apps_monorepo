import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show VoiceApi, VoiceCapabilities, deriveProjectGlossaryKey;

class _FakeUri() extends Fake implements Uri;

class MockAuthenticatedHttpApiClient() extends Mock implements AuthenticatedHttpApiClient;

class MockHttpApiClient() extends Mock implements HttpApiClient;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
    registerFallbackValue(Duration.zero);
  });

  group("VoiceApi.transcribe", () {
    late MockAuthenticatedHttpApiClient mockAuthenticatedHttpApiClient;
    late MockHttpApiClient mockPublicHttpApiClient;
    late VoiceApi voiceApi;

    setUp(() {
      mockAuthenticatedHttpApiClient = MockAuthenticatedHttpApiClient();
      mockPublicHttpApiClient = MockHttpApiClient();
      voiceApi = VoiceApi(mockAuthenticatedHttpApiClient, mockPublicHttpApiClient);
    });

    Future<String> createAudioPath() async {
      final tempDir = await Directory.systemTemp.createTemp("voice_api_test");
      addTearDown(() async => await tempDir.delete(recursive: true));
      final audioFile = File("${tempDir.path}/clip.m4a");
      await audioFile.writeAsBytes([1, 2, 3, 4]);
      return audioFile.path;
    }

    test("success: sends multipart request and returns transcript", () async {
      final audioPath = await createAudioPath();

      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("transcribed text"));

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: null,
        capabilities: null,
      );

      expect(result, ApiResponse.success("transcribed text"));

      final captured = verify(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          captureAny(),
          fromJson: captureAny(named: "fromJson"),
          fields: captureAny(named: "fields"),
          createFiles: captureAny(named: "createFiles"),
          timeout: captureAny(named: "timeout"),
        ),
      ).captured;

      expect(captured[0], Uri.parse("$authBaseUrl/voice/transcribe"));
      expect(captured[1], isA<String Function(dynamic)>());
      expect(captured[2], isA<Future<List<http.MultipartFile>> Function()>());
      expect(captured[3], isNull);

      final createFiles = captured[2] as Future<List<http.MultipartFile>> Function();
      final files = await createFiles();
      expect(files, hasLength(1));
      expect(files.single, isA<http.MultipartFile>());

      final multipartFile = files.single;
      expect(multipartFile.field, "audio");
      expect(multipartFile.filename, "clip.m4a");

      expect(captured[4], const Duration(seconds: 120));
    });

    test("protocol 1 async context sends only opaque project key", () async {
      final audioPath = await createAudioPath();
      const capabilities = VoiceCapabilities(realtimeEnabled: false, protocolVersions: [1]);
      final opaqueKey = deriveProjectGlossaryKey("project-123");

      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("transcribed text"));

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: opaqueKey,
        capabilities: capabilities,
      );

      expect(result, ApiResponse.success("transcribed text"));

      final captured = verify(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          captureAny(),
          fromJson: captureAny(named: "fromJson"),
          fields: captureAny(named: "fields"),
          createFiles: captureAny(named: "createFiles"),
          timeout: captureAny(named: "timeout"),
        ),
      ).captured;

      expect(captured[3], {"projectKey": opaqueKey});
      expect(captured[3].toString(), isNot(contains("project-123")));
      expect(captured[4], const Duration(seconds: 120));
    });

    test("API error: propagates error returned by postMultipart", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.nonSuccessCode(errorCode: 502, rawErrorString: "bad gateway"),
        ),
      );

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: null,
        capabilities: null,
      );

      expect(
        result,
        ApiResponse<String>.error(
          ApiError.nonSuccessCode(errorCode: 502, rawErrorString: "bad gateway"),
        ),
      );
    });

    test("timeout: maps TimeoutException to dartHttpClient error", () async {
      final audioPath = await createAudioPath();
      // Use thenAnswer with Future.error to simulate an async failure from the
      // underlying HTTP client — matches how `.timeout()` surfaces
      // TimeoutException in production and protects against the try/catch
      // regression where the returned Future isn't awaited.
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) => Future<ApiResponse<String>>.error(TimeoutException("Request timed out")),
      );

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: null,
        capabilities: null,
      );

      expect(result.toString(), contains("dartHttpClient"));
      expect(result.toString(), contains("TimeoutException"));
    });

    test("socket error: maps SocketException to dartHttpClient error", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) => Future<ApiResponse<String>>.error(const SocketException("Network unreachable")),
      );

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: null,
        capabilities: null,
      );

      expect(result.toString(), contains("dartHttpClient"));
      expect(result.toString(), contains("SocketException"));
    });

    test("parse error: propagates jsonParsing error from client", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.jsonParsing("not json")));

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: null,
        capabilities: null,
      );

      expect(result, ApiResponse<String>.error(ApiError.jsonParsing("not json")));
    });

    test("handshake error: maps HandshakeException to dartHttpClient error", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          fields: any(named: "fields"),
          createFiles: any(named: "createFiles"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) => Future<ApiResponse<String>>.error(const HandshakeException("TLS failed")),
      );

      final result = await voiceApi.transcribe(
        audioPath,
        mimeType: "audio/mp4",
        projectKey: null,
        capabilities: null,
      );

      expect(result.toString(), contains("dartHttpClient"));
      expect(result.toString(), contains("HandshakeException"));
    });
  });
}
