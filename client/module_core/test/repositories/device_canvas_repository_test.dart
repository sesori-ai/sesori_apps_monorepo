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

  group("stream start", () {
    test("returns supported responses", () async {
      when(
        () => api.startStream(request: _startRequest),
      ).thenAnswer((_) async => ApiResponse.success(_startResponse));

      final result = await repository.startStream(request: _startRequest);

      expect(result, isA<DeviceCanvasStreamStartSupported>());
      expect((result as DeviceCanvasStreamStartSupported).response, _startResponse);
    });

    test("maps a missing route to unsupported", () async {
      when(
        () => api.startStream(request: _startRequest),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));

      expect(await repository.startStream(request: _startRequest), isA<DeviceCanvasStreamStartUnsupported>());
    });

    for (final error in _uncertainErrors) {
      test("treats ${error.runtimeType} as uncertain", () async {
        when(() => api.startStream(request: _startRequest)).thenAnswer((_) async => ApiResponse.error(error));

        expect(await repository.startStream(request: _startRequest), isA<DeviceCanvasStreamStartUncertain>());
      });
    }

    test("preserves definite failures", () async {
      when(
        () => api.startStream(request: _startRequest),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      expect(await repository.startStream(request: _startRequest), isA<DeviceCanvasStreamStartFailure>());
    });
  });

  group("stream status", () {
    test("returns supported responses", () async {
      when(
        () => api.statusStream(request: _statusRequest),
      ).thenAnswer((_) async => ApiResponse.success(_streamStatusResponse));

      expect(await repository.statusStream(request: _statusRequest), isA<DeviceCanvasStreamStatusSupported>());
    });

    test("maps a missing route to unsupported", () async {
      when(
        () => api.statusStream(request: _statusRequest),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));

      expect(await repository.statusStream(request: _statusRequest), isA<DeviceCanvasStreamStatusUnsupported>());
    });

    for (final error in _uncertainErrors) {
      test("maps ${error.runtimeType} to a definite read failure", () async {
        when(() => api.statusStream(request: _statusRequest)).thenAnswer((_) async => ApiResponse.error(error));

        expect(await repository.statusStream(request: _statusRequest), isA<DeviceCanvasStreamStatusFailure>());
      });
    }
  });

  group("stream stop", () {
    test("returns supported responses", () async {
      when(
        () => api.stopStream(request: _stopRequest),
      ).thenAnswer(
        (_) async => ApiResponse.success(
          const DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.stopped),
        ),
      );

      expect(await repository.stopStream(request: _stopRequest), isA<DeviceCanvasStreamStopSupported>());
    });

    test("maps a missing route to unsupported", () async {
      when(
        () => api.stopStream(request: _stopRequest),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: null)));

      expect(await repository.stopStream(request: _stopRequest), isA<DeviceCanvasStreamStopUnsupported>());
    });

    test("maps a lost relay response to uncertain", () async {
      when(
        () => api.stopStream(request: _stopRequest),
      ).thenAnswer(
        (_) async => ApiResponse.error(
          ApiError.dartHttpClient(const RelayResponseLostException(message: "relay disconnected")),
        ),
      );

      expect(await repository.stopStream(request: _stopRequest), isA<DeviceCanvasStreamStopUncertain>());
    });

    test("preserves definite failures", () async {
      when(
        () => api.stopStream(request: _stopRequest),
      ).thenAnswer((_) async => ApiResponse.error(ApiError.generic()));

      expect(await repository.stopStream(request: _stopRequest), isA<DeviceCanvasStreamStopFailure>());
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

const _fingerprint =
    "sha-256 00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:10:21:32:43:54:65:76:87:98:A9:BA:CB:DC:ED:FE:0F";

const _startRequest = DeviceCanvasStreamStartRequest(
  expectedBridgeId: "bridge-1",
  sessionId: "session-1",
  deviceKey: "device-1",
  expectedClaimRevision: 7,
  operationId: "operation-1",
  control: true,
  offer: DeviceCanvasRtcDescription(
    type: DeviceCanvasRtcDescriptionType.offer,
    sdp: "v=0\na=fingerprint:$_fingerprint\n",
    fingerprint: _fingerprint,
  ),
);

const _statusRequest = DeviceCanvasStreamStatusRequest(
  expectedBridgeId: "bridge-1",
  sessionId: "session-1",
  deviceKey: "device-1",
  expectedClaimRevision: 7,
  operationId: "operation-1",
);

const _stopRequest = DeviceCanvasStreamStopRequest(
  expectedBridgeId: "bridge-1",
  sessionId: "session-1",
  deviceKey: "device-1",
  expectedClaimRevision: 7,
  leaseId: "lease-1",
);

const _startResponse = DeviceCanvasStreamStartResponse(
  outcome: DeviceCanvasStreamStartOutcome.unavailable,
  leaseId: null,
  expiresAt: null,
  answer: null,
  turn: null,
);

const _streamStatusResponse = DeviceCanvasStreamStatusResponse(
  outcome: DeviceCanvasStreamStatusOutcome.inactive,
  leaseId: null,
  expiresAt: null,
  answer: null,
  turn: null,
  offerFingerprint: null,
);

final _uncertainErrors = <ApiError>[
  ApiError.emptyResponse(),
  ApiError.jsonParsing("invalid"),
  ApiError.dartHttpClient(TimeoutException("timed out")),
  ApiError.dartHttpClient(const RelayResponseLostException(message: "relay disconnected")),
  ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null),
  ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null),
  ApiError.nonSuccessCode(errorCode: 599, rawErrorString: null),
];
