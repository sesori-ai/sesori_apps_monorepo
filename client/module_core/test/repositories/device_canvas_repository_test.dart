import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/device_canvas_api.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/repositories/device_canvas_repository.dart";
import "package:sesori_dart_core/src/repositories/models/device_canvas_result.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockDeviceCanvasApi() extends Mock implements DeviceCanvasApi;

void main() {
  late _MockDeviceCanvasApi api;
  late DeviceCanvasRepository repository;

  setUp(() {
    api = _MockDeviceCanvasApi();
    repository = DeviceCanvasRepository(api: api);
  });

  group("status", () {
    test("returns supported status", () async {
      when(
        () => api.getSessionStatus(sessionId: "session-1"),
      ).thenAnswer((_) async => ApiResponse.success(_status()));

      final result = await repository.getSessionStatus(sessionId: "session-1");

      expect(result, isA<DeviceCanvasStatusSupported>());
      expect((result as DeviceCanvasStatusSupported).status.bridgeId, "bridge-1");
    });

    test("maps a missing route to unsupported", () async {
      when(
        () => api.getSessionStatus(sessionId: "session-1"),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));

      expect(
        await repository.getSessionStatus(sessionId: "session-1"),
        isA<DeviceCanvasStatusUnsupported>(),
      );
    });

    test("preserves non-compatibility failures", () async {
      when(
        () => api.getSessionStatus(sessionId: "session-1"),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null)));

      expect(
        await repository.getSessionStatus(sessionId: "session-1"),
        isA<DeviceCanvasStatusFailure>(),
      );
    });
  });

  group("mutation", () {
    test("returns committed responses", () async {
      when(
        () => api.claim(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "device-1",
          reassign: false,
          expectedOwnerSessionId: null,
          expectedClaimRevision: null,
        ),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          DeviceCanvasMutationResponse(outcome: DeviceCanvasMutationOutcome.claimed, status: _status()),
        ),
      );

      final result = await repository.claim(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "device-1",
        reassign: false,
        expectedOwnerSessionId: null,
        expectedClaimRevision: null,
      );

      expect(result, isA<DeviceCanvasMutationCommitted>());
    });

    test("maps a missing route to unsupported", () async {
      when(
        () => api.release(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "device-1",
          expectedClaimRevision: 7,
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));

      expect(
        await repository.release(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "device-1",
          expectedClaimRevision: 7,
        ),
        isA<DeviceCanvasMutationUnsupported>(),
      );
    });

    for (final error in <ApiError>[
      ApiError.emptyResponse(),
      ApiError.jsonParsing("invalid"),
      ApiError.dartHttpClient(TimeoutException("timed out")),
      ApiError.dartHttpClient(const RelayResponseLostException(message: "relay disconnected")),
      ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null),
      ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null),
      ApiError.nonSuccessCode(errorCode: 599, rawErrorString: null),
    ]) {
      test("treats ${error.runtimeType} as uncertain", () async {
        when(
          () => api.release(
            expectedBridgeId: "bridge-1",
            sessionId: "session-1",
            deviceKey: "device-1",
            expectedClaimRevision: 7,
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        expect(
          await repository.release(
            expectedBridgeId: "bridge-1",
            sessionId: "session-1",
            deviceKey: "device-1",
            expectedClaimRevision: 7,
          ),
          isA<DeviceCanvasMutationUncertain>(),
        );
      });
    }

    test("preserves definite failures", () async {
      when(
        () => api.release(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "device-1",
          expectedClaimRevision: 7,
        ),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      expect(
        await repository.release(
          expectedBridgeId: "bridge-1",
          sessionId: "session-1",
          deviceKey: "device-1",
          expectedClaimRevision: 7,
        ),
        isA<DeviceCanvasMutationFailure>(),
      );
    });
  });
}

DeviceCanvasSessionStatusResponse _status() => const DeviceCanvasSessionStatusResponse(
  bridgeId: "bridge-1",
  sessionId: "session-1",
  sessionAvailable: true,
  projectId: "project-1",
  connection: DeviceCanvasClientConnectionStatus.connected,
);
