import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockDeviceCanvasService() extends Mock implements DeviceCanvasService;

class _MockConnectionService() extends Mock implements ConnectionService;

class _FakeLifecycleSource() implements LifecycleSource {
  final BehaviorSubject<LifecycleState> states = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => states.stream;
}

class _FakeVideoPeer() implements DeviceCanvasVideoPeer {
  final StreamController<DeviceCanvasVideoPeerConnectionState> _states = StreamController.broadcast();
  DeviceCanvasVideoOffer offer = _offer;
  bool videoReadyDuringApply = false;
  Object? applyAnswerError;
  int createOfferCalls = 0;
  int closeCalls = 0;
  final List<({DeviceCanvasRtcDescription answer, List<DeviceCanvasIceCandidate> iceCandidates})> answers = [];

  @override
  Stream<DeviceCanvasVideoPeerConnectionState> get connectionStateStream => _states.stream;

  @override
  Future<DeviceCanvasVideoOffer> createOffer() async {
    createOfferCalls++;
    return offer;
  }

  @override
  Future<void> applyAnswer({
    required DeviceCanvasRtcDescription answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
  }) async {
    answers.add((answer: answer, iceCandidates: iceCandidates));
    final error = applyAnswerError;
    if (error != null) throw error;
    if (videoReadyDuringApply) emit(DeviceCanvasVideoPeerConnectionState.videoReady);
  }

  @override
  Future<void> close() async {
    closeCalls++;
    emit(DeviceCanvasVideoPeerConnectionState.closed);
  }

  void emit(DeviceCanvasVideoPeerConnectionState state) {
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() => _states.close();
}

const _config = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token");
const _health = HealthResponse(healthy: true, version: "1.0.0", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _config, health: _health);
const _fingerprint =
    "sha-256 00:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B:1C:1D:1E:1F";
const _otherFingerprint =
    "sha-256 FF:FE:FD:FC:FB:FA:F9:F8:F7:F6:F5:F4:F3:F2:F1:F0:EF:EE:ED:EC:EB:EA:E9:E8:E7:E6:E5:E4:E3:E2:E1:E0";
const _offerDescription = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.offer,
  sdp: "v=0\r\na=fingerprint:$_fingerprint\r\n",
  fingerprint: _fingerprint,
);
const _answerDescription = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.answer,
  sdp: "v=0\r\na=fingerprint:$_fingerprint\r\n",
  fingerprint: _fingerprint,
);
const _offer = DeviceCanvasVideoOffer(description: _offerDescription, iceCandidates: []);
const _stopResponse = DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.stopped);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const DeviceCanvasStreamStartRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "device-1",
        expectedClaimRevision: 1,
        operationId: "operation-1",
        control: false,
        offer: _offerDescription,
      ),
    );
    registerFallbackValue(
      const DeviceCanvasStreamStatusRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "device-1",
        expectedClaimRevision: 1,
        operationId: "operation-1",
      ),
    );
    registerFallbackValue(
      const DeviceCanvasStreamStopRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "device-1",
        expectedClaimRevision: 1,
        leaseId: "lease-1",
      ),
    );
  });

  late _MockDeviceCanvasService service;
  late _MockConnectionService connectionService;
  late BehaviorSubject<ConnectionStatus> relayStates;
  late _FakeLifecycleSource lifecycleSource;
  late _FakeVideoPeer peer;
  DeviceCanvasVideoCubit? cubit;

  setUp(() {
    service = _MockDeviceCanvasService();
    connectionService = _MockConnectionService();
    relayStates = BehaviorSubject.seeded(_connected);
    lifecycleSource = _FakeLifecycleSource();
    peer = _FakeVideoPeer();
    when(() => connectionService.currentStatus).thenReturn(_connected);
    when(() => connectionService.status).thenAnswer((_) => relayStates.stream);
    when(
      () => service.stopStream(request: any(named: "request")),
    ).thenAnswer((_) async => const DeviceCanvasStreamStopSupported(response: _stopResponse));
  });

  tearDown(() async {
    await cubit?.close();
    await peer.dispose();
    await lifecycleSource.states.close();
    await relayStates.close();
  });

  DeviceCanvasVideoCubit createCubit({
    DeviceCanvasSessionState? authorization,
    Duration connectionTimeout = const Duration(seconds: 15),
  }) {
    return DeviceCanvasVideoCubit(
      service: service,
      peer: peer,
      lifecycleSource: lifecycleSource,
      connectionService: connectionService,
      initialAuthorization: authorization ?? _authorization(),
      deviceKey: "device-1",
      connectionTimeout: connectionTimeout,
    );
  }

  test("starts video-only signaling with the exact authorized identity", () async {
    final response = _startedResponse();
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: response));
    cubit = createCubit();

    await cubit!.start();

    final request =
        verify(() => service.startStream(request: captureAny(named: "request"))).captured.single
            as DeviceCanvasStreamStartRequest;
    expect(request.expectedBridgeId, "bridge-1");
    expect(request.sessionId, "session-1");
    expect(request.deviceKey, "device-1");
    expect(request.expectedClaimRevision, 1);
    expect(request.operationId, matches(RegExp(r"^[A-Za-z0-9_-]{32}$")));
    expect(request.control, isFalse);
    expect(request.offer, _offerDescription);
    expect(peer.answers.single.answer, _answerDescription);

    peer.emit(DeviceCanvasVideoPeerConnectionState.videoReady);
    await _settle();

    expect(cubit!.state, isA<DeviceCanvasVideoLive>());
    expect((cubit!.state as DeviceCanvasVideoLive).expiresAt, response.expiresAt);

    await cubit!.stop();

    expect(cubit!.state, isA<DeviceCanvasVideoStopped>());
    expect(peer.closeCalls, 1);
    final stop =
        verify(() => service.stopStream(request: captureAny(named: "request"))).captured.single
            as DeviceCanvasStreamStopRequest;
    expect(stop.leaseId, "lease-1");
    expect(stop.expectedClaimRevision, 1);
  });

  test("fails closed and releases the lease when TURN is required", () async {
    final response = _startedResponse(
      turn: DeviceCanvasTurnConfiguration(
        urls: const ["turn:relay.example.com"],
        username: "user",
        credential: "credential",
        expiresAt: _expiresIn(const Duration(minutes: 5)),
      ),
    );
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: response));
    cubit = createCubit();

    await cubit!.start();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.lanOnly);
    expect(peer.answers, isEmpty);
    expect(peer.closeCalls, 1);
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("redacts native signaling errors from diagnostics", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
    peer.applyAnswerError = const _SensitiveWebRtcError();
    cubit = createCubit();
    final logs = <String>[];

    await runZoned(
      cubit!.start,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logs.add(line),
      ),
    );

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect(logs.join("\n"), contains("Failed to start Device Canvas LAN video"));
    expect(logs.join("\n"), isNot(contains(_sensitiveSignalingMarker)));
  });

  test("reconciles an uncertain start before applying the answer", () async {
    final response = _activeResponse();
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => const DeviceCanvasStreamStartUncertain());
    when(
      () => service.statusStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStatusSupported(response: response));
    cubit = createCubit();

    await cubit!.start();

    final startRequest =
        verify(() => service.startStream(request: captureAny(named: "request"))).captured.single
            as DeviceCanvasStreamStartRequest;
    final statusRequest =
        verify(() => service.statusStream(request: captureAny(named: "request"))).captured.single
            as DeviceCanvasStreamStatusRequest;
    expect(statusRequest.expectedBridgeId, "bridge-1");
    expect(statusRequest.expectedClaimRevision, 1);
    expect(statusRequest.operationId, startRequest.operationId);
    expect(peer.answers.single.answer, _answerDescription);
  });

  test("retries a failed uncertain-start status lookup", () async {
    var statusRequests = 0;
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => const DeviceCanvasStreamStartUncertain());
    when(() => service.statusStream(request: any(named: "request"))).thenAnswer((_) async {
      statusRequests++;
      return statusRequests == 1
          ? DeviceCanvasStreamStatusFailure(error: ApiError.generic())
          : DeviceCanvasStreamStatusSupported(response: _activeResponse());
    });
    cubit = createCubit();

    await cubit!.start();

    expect(statusRequests, 2);
    expect(peer.answers.single.answer, _answerDescription);
  });

  test("does not adopt an active lease created from another offer", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => const DeviceCanvasStreamStartUncertain());
    when(
      () => service.statusStream(request: any(named: "request")),
    ).thenAnswer(
      (_) async => DeviceCanvasStreamStatusSupported(
        response: _activeResponse(offerFingerprint: _otherFingerprint),
      ),
    );
    cubit = createCubit();

    await cubit!.start();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.signalingFailed);
    expect(peer.answers, isEmpty);
    verifyNever(() => service.stopStream(request: any(named: "request")));
  });

  test("fails closed when uncertain-start status requires TURN", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => const DeviceCanvasStreamStartUncertain());
    when(
      () => service.statusStream(request: any(named: "request")),
    ).thenAnswer(
      (_) async => DeviceCanvasStreamStatusSupported(
        response: _activeResponse(
          turn: DeviceCanvasTurnConfiguration(
            urls: const ["turn:relay.example.com"],
            username: "user",
            credential: "credential",
            expiresAt: _expiresIn(const Duration(minutes: 5)),
          ),
        ),
      ),
    );
    cubit = createCubit();

    await cubit!.start();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.lanOnly);
    expect(peer.answers, isEmpty);
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("authorization revision changes stop the active lease", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
    cubit = createCubit();
    await cubit!.start();
    peer.emit(DeviceCanvasVideoPeerConnectionState.videoReady);
    await _settle();

    cubit!.authorizationChanged(_authorization(claimRevision: 2));
    await _settle();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.unauthorized);
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("availability loss is not misreported as an ownership change", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
    cubit = createCubit();
    await cubit!.start();

    cubit!.authorizationChanged(const DeviceCanvasSessionDisconnected());
    await _settle();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.unavailable);
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("backgrounding stops and releases the active preview", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
    cubit = createCubit();
    await cubit!.start();
    peer.emit(DeviceCanvasVideoPeerConnectionState.videoReady);
    await _settle();

    lifecycleSource.states.add(LifecycleState.paused);
    await _settle();

    expect(cubit!.state, isA<DeviceCanvasVideoStopped>());
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("peer failure closes and releases the active preview", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
    cubit = createCubit();
    await cubit!.start();

    peer.emit(DeviceCanvasVideoPeerConnectionState.failed);
    await _settle();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.connectionFailed);
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("relay loss fails closed without attempting an unavailable stop request", () async {
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
    cubit = createCubit();
    await cubit!.start();
    peer.emit(DeviceCanvasVideoPeerConnectionState.videoReady);
    await _settle();

    relayStates.add(const ConnectionStatus.disconnected());
    await _settle();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.unavailable);
    expect(peer.closeCalls, 1);
    verifyNever(() => service.stopStream(request: any(named: "request")));
  });

  test("cleans up a successful start response that arrives after stop", () async {
    final result = Completer<DeviceCanvasStreamStartResult>();
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) => result.future);
    cubit = createCubit();
    final start = cubit!.start();
    await _settle();

    await cubit!.stop();
    result.complete(DeviceCanvasStreamStartSupported(response: _startedResponse()));
    await start;

    expect(cubit!.state, isA<DeviceCanvasVideoStopped>());
    expect(peer.answers, isEmpty);
    final stop =
        verify(() => service.stopStream(request: captureAny(named: "request"))).captured.single
            as DeviceCanvasStreamStopRequest;
    expect(stop.leaseId, "lease-1");
  });

  test("cleans up an active status response that arrives after stop", () async {
    final status = Completer<DeviceCanvasStreamStatusResult>();
    when(
      () => service.startStream(request: any(named: "request")),
    ).thenAnswer((_) async => const DeviceCanvasStreamStartUncertain());
    when(
      () => service.statusStream(request: any(named: "request")),
    ).thenAnswer((_) => status.future);
    cubit = createCubit();
    final start = cubit!.start();
    await _settle();

    await cubit!.stop();
    status.complete(DeviceCanvasStreamStatusSupported(response: _activeResponse()));
    await start;

    expect(peer.answers, isEmpty);
    verify(() => service.stopStream(request: any(named: "request"))).called(1);
  });

  test("a first-frame signal during answer application stays live", () {
    fakeAsync((async) {
      peer.videoReadyDuringApply = true;
      when(
        () => service.startStream(request: any(named: "request")),
      ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
      cubit = createCubit();

      unawaited(cubit!.start());
      async.flushMicrotasks();
      expect(cubit!.state, isA<DeviceCanvasVideoLive>());

      async.elapse(const Duration(seconds: 16));
      async.flushMicrotasks();
      expect(cubit!.state, isA<DeviceCanvasVideoLive>());

      unawaited(cubit!.close());
      async.flushMicrotasks();
      cubit = null;
    });
  });

  test("connection timeout closes the peer and releases the lease", () {
    fakeAsync((async) {
      when(
        () => service.startStream(request: any(named: "request")),
      ).thenAnswer((_) async => DeviceCanvasStreamStartSupported(response: _startedResponse()));
      cubit = createCubit(connectionTimeout: const Duration(milliseconds: 30));

      unawaited(cubit!.start());
      async.flushMicrotasks();
      expect(cubit!.state, isA<DeviceCanvasVideoConnecting>());

      async.elapse(const Duration(milliseconds: 31));
      async.flushMicrotasks();

      expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
      expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.connectionFailed);
      expect(peer.closeCalls, 1);
      verify(() => service.stopStream(request: any(named: "request"))).called(1);

      unawaited(cubit!.close());
      async.flushMicrotasks();
      cubit = null;
    });
  });

  test("lease expiry closes a live peer and sends an exact stop", () {
    fakeAsync((async) {
      when(
        () => service.startStream(request: any(named: "request")),
      ).thenAnswer(
        (_) async => DeviceCanvasStreamStartSupported(
          response: _startedResponse(expiresIn: const Duration(milliseconds: 30)),
        ),
      );
      cubit = createCubit(connectionTimeout: const Duration(hours: 1));

      unawaited(cubit!.start());
      async.flushMicrotasks();
      peer.emit(DeviceCanvasVideoPeerConnectionState.videoReady);
      async.flushMicrotasks();
      expect(cubit!.state, isA<DeviceCanvasVideoLive>());

      async.elapse(const Duration(milliseconds: 31));
      async.flushMicrotasks();

      expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
      expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.expired);
      expect(peer.closeCalls, 1);
      verify(() => service.stopStream(request: any(named: "request"))).called(1);

      unawaited(cubit!.close());
      async.flushMicrotasks();
      cubit = null;
    });
  });

  test("rejects a device without Android remote-video authorization", () async {
    cubit = createCubit(authorization: _authorization(platform: DeviceCanvasClientPlatform.ios));

    await cubit!.start();

    expect(cubit!.state, isA<DeviceCanvasVideoFailed>());
    expect((cubit!.state as DeviceCanvasVideoFailed).reason, DeviceCanvasVideoFailureReason.unsupported);
    expect(peer.createOfferCalls, 0);
    verifyNever(() => service.startStream(request: any(named: "request")));
  });
}

const _sensitiveSignalingMarker = "sensitive-sdp-marker";

class const _SensitiveWebRtcError() {
  @override
  String toString() => _sensitiveSignalingMarker;
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

int _expiresIn(Duration duration) => DateTime.now().add(duration).millisecondsSinceEpoch;

DeviceCanvasStreamStartResponse _startedResponse({
  DeviceCanvasTurnConfiguration? turn,
  Duration expiresIn = const Duration(hours: 1),
}) {
  return DeviceCanvasStreamStartResponse(
    outcome: DeviceCanvasStreamStartOutcome.started,
    leaseId: "lease-1",
    expiresAt: _expiresIn(expiresIn),
    answer: _answerDescription,
    iceCandidates: const [],
    turn: turn,
  );
}

DeviceCanvasStreamStatusResponse _activeResponse({
  String? offerFingerprint = _fingerprint,
  DeviceCanvasTurnConfiguration? turn,
}) {
  return DeviceCanvasStreamStatusResponse(
    outcome: DeviceCanvasStreamStatusOutcome.active,
    leaseId: "lease-1",
    expiresAt: _expiresIn(const Duration(hours: 1)),
    answer: _answerDescription,
    iceCandidates: const [],
    turn: turn,
    offerFingerprint: offerFingerprint,
  );
}

DeviceCanvasSessionState _authorization({
  int claimRevision = 1,
  DeviceCanvasClientPlatform platform = DeviceCanvasClientPlatform.android,
}) {
  return DeviceCanvasSessionReady(
    status: DeviceCanvasSessionStatusResponse(
      bridgeId: "bridge-1",
      sessionId: "session-1",
      sessionAvailable: true,
      projectId: "project-1",
      connection: DeviceCanvasClientConnectionStatus.connected,
      devices: [
        DeviceCanvasDeviceStatus(
          deviceKey: "device-1",
          descriptor: DeviceCanvasClientDescriptor(
            platform: platform,
            displayName: "Android Emulator",
            runtimeDescription: "Android 16",
            modelDescription: "Pixel",
            dimensions: const DeviceCanvasClientDimensions(width: 1080, height: 2400),
            orientation: DeviceCanvasClientOrientation.portrait,
            capabilities: const DeviceCanvasClientCapabilities(localView: true, remoteVideo: true),
          ),
          claim: DeviceCanvasClaimStatus(
            projectId: "project-1",
            sessionId: "session-1",
            revision: claimRevision,
            claimedAt: 1,
            displayTitle: "Session",
          ),
        ),
      ],
    ),
    mutation: const DeviceCanvasSessionMutationIdle(),
  );
}
