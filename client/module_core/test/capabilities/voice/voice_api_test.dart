import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/capabilities/voice/voice_api.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;
import "package:test/test.dart";

void main() {
  setUpAll(registerCoreFallbackValues);

  group("VoiceApi.transcribe", () {
    late MockAuthenticatedHttpApiClient mockAuthenticatedHttpApiClient;
    late VoiceApi voiceApi;

    setUp(() {
      mockAuthenticatedHttpApiClient = MockAuthenticatedHttpApiClient();
      voiceApi = VoiceApi(mockAuthenticatedHttpApiClient);
    });

    Future<String> createAudioPath() async {
      final tempDir = await Directory.systemTemp.createTemp("voice_api_test");
      addTearDown(() async => await tempDir.delete(recursive: true));
      final audioFile = File("${tempDir.path}/clip.m4a");
      await audioFile.writeAsBytes([1, 2, 3, 4]);
      return audioFile.path;
    }

    test("success: sends multipart request with optional opaque context", () async {
      final audioPath = await createAudioPath();
      final glossaryKey = ProjectGlossaryKey.parse(
        value: "prj_v1_1yuLLmK3NKRJfpiX26q507WHb9ZxINRCpBKCBTgnGlQ",
      );

      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("transcribed text"));

      final result = await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: glossaryKey,
      );

      expect(
        result,
        isA<VoiceTranscriptionApiSuccess>().having(
          (success) => success.transcript,
          "transcript",
          "transcribed text",
        ),
      );

      final captured = verify(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          captureAny(),
          fromJson: captureAny(named: "fromJson"),
          createFiles: captureAny(named: "createFiles"),
          fields: captureAny(named: "fields"),
          timeout: captureAny(named: "timeout"),
        ),
      ).captured;

      expect(captured[0], Uri.parse("$authBaseUrl/voice/transcribe"));
      expect(captured[1], isA<String Function(dynamic)>());
      expect(captured[2], isA<Future<List<http.MultipartFile>> Function()>());

      final createFiles = captured[2] as Future<List<http.MultipartFile>> Function();
      final files = await createFiles();
      expect(files, hasLength(1));
      expect(files.single, isA<http.MultipartFile>());

      final multipartFile = files.single;
      expect(multipartFile.field, "audio");
      expect(multipartFile.filename, "clip.m4a");

      expect(captured[3], {"projectKey": glossaryKey.value});
      expect(captured[4], const Duration(seconds: 30));
    });

    test("omits multipart project context when no key is available", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.success("transcribed text"));

      await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      final fields = verify(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: captureAny(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).captured.single;
      expect(fields, isNull);
    });

    test("API error: parses authoritative retryability from the failure body", () async {
      final audioPath = await createAudioPath();
      final apiError = ApiError.nonSuccessCode(
        errorCode: 502,
        rawErrorString: '{"error":"transcription_provider_error","retryable":true}',
      );
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(apiError));

      final result = await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      expect(
        result,
        isA<VoiceTranscriptionApiFailure>()
            .having((failure) => failure.error, "error", apiError)
            .having((failure) => failure.retryable, "retryable", isTrue),
      );
    });

    test("API error: treats false, omitted, and malformed retryability as typed metadata", () async {
      final audioPath = await createAudioPath();
      final cases = <String, bool?>{
        '{"error":"bad_request","retryable":false}': false,
        '{"error":"internal_server_error"}': null,
        '{"error":"internal_server_error","retryable":"yes"}': null,
      };

      for (final MapEntry(key: body, value: expectedRetryable) in cases.entries) {
        reset(mockAuthenticatedHttpApiClient);
        when(
          () => mockAuthenticatedHttpApiClient.postMultipart<String>(
            any(),
            fromJson: any(named: "fromJson"),
            createFiles: any(named: "createFiles"),
            timeout: any(named: "timeout"),
          ),
        ).thenAnswer(
          (_) async => ApiResponse.error(
            ApiError.nonSuccessCode(errorCode: 500, rawErrorString: body),
          ),
        );

        final result = await voiceApi.transcribe(
          audioFilePath: audioPath,
          mimeType: "audio/mp4",
          projectGlossaryKey: null,
        );

        expect(
          result,
          isA<VoiceTranscriptionApiFailure>().having(
            (failure) => failure.retryable,
            "retryable",
            expectedRetryable,
          ),
        );
      }
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
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) => Future<ApiResponse<String>>.error(TimeoutException("Request timed out")),
      );

      final result = await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      expect(
        result,
        isA<VoiceTranscriptionApiFailure>().having(
          (failure) => failure.error,
          "error",
          isA<DartHttpClientError>(),
        ),
      );
    });

    test("socket error: maps SocketException to dartHttpClient error", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) => Future<ApiResponse<String>>.error(const SocketException("Network unreachable")),
      );

      final result = await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      expect(
        result,
        isA<VoiceTranscriptionApiFailure>().having(
          (failure) => failure.error,
          "error",
          isA<DartHttpClientError>(),
        ),
      );
    });

    test("parse error: propagates jsonParsing error from client", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.jsonParsing("not json")));

      final result = await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      expect(
        result,
        isA<VoiceTranscriptionApiFailure>()
            .having((failure) => failure.error, "error", ApiError.jsonParsing("not json"))
            .having((failure) => failure.retryable, "retryable", isNull),
      );
    });

    test("handshake error: maps HandshakeException to dartHttpClient error", () async {
      final audioPath = await createAudioPath();
      when(
        () => mockAuthenticatedHttpApiClient.postMultipart<String>(
          any(),
          fromJson: any(named: "fromJson"),
          createFiles: any(named: "createFiles"),
          fields: any(named: "fields"),
          timeout: any(named: "timeout"),
        ),
      ).thenAnswer(
        (_) => Future<ApiResponse<String>>.error(const HandshakeException("TLS failed")),
      );

      final result = await voiceApi.transcribe(
        audioFilePath: audioPath,
        mimeType: "audio/mp4",
        projectGlossaryKey: null,
      );

      expect(
        result,
        isA<VoiceTranscriptionApiFailure>().having(
          (failure) => failure.error,
          "error",
          isA<DartHttpClientError>(),
        ),
      );
    });
  });
}
