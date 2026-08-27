import "dart:async";

import "package:flutter/semantics.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/platform/flutter_webrtc_client.dart";
import "package:sesori_mobile/features/session_detail/widgets/device_canvas_status_banner.dart";
import "package:sesori_mobile/features/session_detail/widgets/device_canvas_video_viewport.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockDeviceCanvasService() extends Mock implements DeviceCanvasService;

class _MockRtpTransceiver() extends Mock implements RTCRtpTransceiver;

class _MockPeerConnection() extends Mock implements RTCPeerConnection {
  @override
  void Function(RTCPeerConnectionState state)? onConnectionState;

  @override
  void Function(RTCIceGatheringState state)? onIceGatheringState;

  @override
  void Function(RTCIceCandidate candidate)? onIceCandidate;

  @override
  void Function(RTCTrackEvent event)? onTrack;

  @override
  RTCIceGatheringState? iceGatheringState = RTCIceGatheringState.RTCIceGatheringStateComplete;
}

class _FakeVideoRenderer() extends RTCVideoRenderer {
  int disposeCalls = 0;
  final Completer<void> disposed = Completer<void>();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {
    disposeCalls++;
    if (!disposed.isCompleted) disposed.complete();
    await super.dispose();
  }
}

class _FakeFlutterWebRtcClient({
  required final RTCVideoRenderer renderer,
  required final RTCPeerConnection connection,
}) extends FlutterWebRtcClient {
  @override
  RTCVideoRenderer createVideoRenderer() => renderer;

  @override
  Future<RTCPeerConnection> createDeviceCanvasPeerConnection({
    required DeviceCanvasTurnConfiguration? turn,
  }) async => connection;
}

class _FakeConnectionService() extends Mock implements ConnectionService {
  final BehaviorSubject<ConnectionStatus> states = BehaviorSubject.seeded(_connected);

  @override
  ConnectionStatus get currentStatus => states.value;

  @override
  ValueStream<ConnectionStatus> get status => states.stream;

  @override
  Future<void> dispose() => states.close();
}

class _VideoPeerHarness() {
  final _FakeVideoRenderer renderer = _FakeVideoRenderer();
  final _MockPeerConnection connection = _MockPeerConnection();
  final _MockRtpTransceiver transceiver = _MockRtpTransceiver();

  late final FlutterWebRtcClient client = _FakeFlutterWebRtcClient(renderer: renderer, connection: connection);

  void stub() {
    when(
      () => connection.addTransceiver(
        kind: any(named: "kind"),
        init: any(named: "init"),
      ),
    ).thenAnswer((_) async => transceiver);
    when(() => connection.createOffer(any())).thenAnswer((_) async => RTCSessionDescription(_videoSdp, "offer"));
    when(() => connection.setLocalDescription(any())).thenAnswer((_) async {});
    when(connection.getLocalDescription).thenAnswer((_) async => RTCSessionDescription(_videoSdp, "offer"));
    when(() => connection.setRemoteDescription(any())).thenAnswer((_) async {});
    when(connection.close).thenAnswer((_) async {});
    when(connection.dispose).thenAnswer((_) async {});
  }
}

const _connectionConfig = ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token");
const _health = HealthResponse(healthy: true, version: "1.0.0", filesystemAccessDegraded: false);
const _connected = ConnectionStatus.connected(config: _connectionConfig, health: _health);
const _fingerprint =
    "sha-256 00:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B:1C:1D:1E:1F";
const _localCandidate = "candidate:1 1 UDP 1 192.168.1.10 5000 typ host";
const _videoSdp = "v=0\r\na=fingerprint:$_fingerprint\r\na=$_localCandidate\r\n";
const _videoOffer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.offer,
  sdp: _videoSdp,
  fingerprint: _fingerprint,
);
const _videoAnswer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.answer,
  sdp: _videoSdp,
  fingerprint: _fingerprint,
);

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(RTCRtpMediaType.RTCRtpMediaTypeVideo);
    registerFallbackValue(RTCRtpTransceiverInit());
    registerFallbackValue(RTCSessionDescription("", "offer"));
    registerFallbackValue(
      const DeviceCanvasStreamStartRequest(
        expectedBridgeId: "bridge-1",
        sessionId: "session-1",
        deviceKey: "device-1",
        expectedClaimRevision: 1,
        operationId: "operation-1",
        leaseId: null,
        control: false,
        offer: _videoOffer,
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

  testWidgets("shows connection and assignment summary", (tester) async {
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _status(claimSessionId: "session-1"),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);

    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    expect(find.text("Device Canvas"), findsOneWidget);
    expect(find.text("1 available, 1 assigned here"), findsOneWidget);
    final semantics = tester.getSemantics(
      find.bySemanticsLabel("Device Canvas. 1 available, 1 assigned here"),
    );
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
  });

  testWidgets("confirms reassignment before invoking the cubit", (tester) async {
    final semantics = tester.ensureSemantics();
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _status(claimSessionId: "other-session"),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();
    expect(find.textContaining("Assigned to Other session"), findsOneWidget);
    expect(find.bySemanticsLabel("Reassign iPhone"), findsOneWidget);
    await tester.tap(find.text("Reassign"));
    await tester.pumpAndSettle();
    expect(find.text("Reassign iPhone?"), findsOneWidget);
    await tester.tap(find.text("Reassign").last);
    await tester.pumpAndSettle();

    expect(cubit.claims, [(deviceKey: "device-1", reassign: true)]);
    semantics.dispose();
  });

  testWidgets("read-only sessions do not expose assignment actions", (tester) async {
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _status(claimSessionId: "session-1"),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas, readOnly: true));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();

    expect(find.text("Assign"), findsNothing);
    expect(find.text("Reassign"), findsNothing);
    expect(find.text("Release"), findsNothing);
    expect(find.text("Watch"), findsNothing);
    expect(find.text("Assignments are read-only in this session."), findsOneWidget);
  });

  testWidgets("hides the LAN video action while the preview flag is disabled", (tester) async {
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _videoStatus(),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();

    expect(find.text("Watch"), findsNothing);
  });

  testWidgets("offers LAN video only for an assigned Android remote-video device", (tester) async {
    final semantics = tester.ensureSemantics();
    final deviceCanvas = DeviceCanvasSessionReady(
      status: _videoStatus(),
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      _app(cubit: cubit, deviceCanvas: deviceCanvas, videoPreviewEnabled: true),
    );

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();

    expect(find.text("Watch"), findsOneWidget);
    expect(find.bySemanticsLabel("Watch Android Emulator"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("does not expose raw identifiers when display metadata is missing", (tester) async {
    final status = _status(claimSessionId: "sensitive-session").copyWith(
      devices: const [
        DeviceCanvasDeviceStatus(
          deviceKey: "sensitive-device-key",
          descriptor: null,
          claim: DeviceCanvasClaimStatus(
            projectId: "project-2",
            sessionId: "sensitive-session",
            revision: 1,
            claimedAt: 1,
            displayTitle: null,
          ),
        ),
      ],
    );
    final deviceCanvas = DeviceCanvasSessionReady(
      status: status,
      mutation: const DeviceCanvasSessionMutationIdle(),
    );
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pumpAndSettle();

    expect(find.text("Unnamed device"), findsOneWidget);
    expect(find.textContaining("Assigned to another session"), findsOneWidget);
    expect(find.textContaining("sensitive-device-key"), findsNothing);
    expect(find.textContaining("sensitive-session"), findsNothing);
  });

  testWidgets("failed status can be retried", (tester) async {
    final deviceCanvas = DeviceCanvasSessionFailure(error: ApiError.generic());
    final cubit = _FakeSessionDetailCubit(deviceCanvas);
    addTearDown(cubit.close);
    await tester.pumpWidget(_app(cubit: cubit, deviceCanvas: deviceCanvas));

    await tester.tap(find.text("Device Canvas"));
    await tester.pump();

    expect(cubit.refreshes, 1);
  });

  group("LAN video viewport owner", () {
    late _MockDeviceCanvasService service;
    late _FakeConnectionService connectionService;
    late FakeLifecycleSource lifecycleSource;
    late _VideoPeerHarness peerHarness;
    late _FakeSessionDetailCubit cubit;

    setUp(() async {
      await getIt.reset();
      service = _MockDeviceCanvasService();
      connectionService = _FakeConnectionService();
      lifecycleSource = FakeLifecycleSource();
      peerHarness = _VideoPeerHarness()..stub();
      cubit = _FakeSessionDetailCubit(_videoAuthorization());
      when(
        () => service.startStream(request: any(named: "request")),
      ).thenAnswer(
        (_) async => DeviceCanvasStreamStartSupported(
          response: DeviceCanvasStreamStartResponse(
            outcome: DeviceCanvasStreamStartOutcome.started,
            leaseId: "lease-1",
            expiresAt: DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
            answer: _videoAnswer,
            iceCandidates: const [],
            turn: null,
          ),
        ),
      );
      when(
        () => service.stopStream(request: any(named: "request")),
      ).thenAnswer(
        (_) async => const DeviceCanvasStreamStopSupported(
          response: DeviceCanvasStreamStopResponse(outcome: DeviceCanvasStreamStopOutcome.stopped),
        ),
      );
      getIt
        ..registerSingleton<DeviceCanvasService>(service)
        ..registerSingleton<LifecycleSource>(lifecycleSource)
        ..registerSingleton<ConnectionService>(connectionService)
        ..registerSingleton<FlutterWebRtcClient>(peerHarness.client);
    });

    tearDown(() async {
      if (!cubit.isClosed) await cubit.close();
      await getIt.reset();
      await lifecycleSource.close();
      await connectionService.dispose();
    });

    testWidgets("forwards claim revision changes and releases the original lease", (tester) async {
      await _openVideoViewport(tester: tester, cubit: cubit, peerHarness: peerHarness);
      expect(tester.widget<DeviceCanvasVideoViewportOwner>(find.byType(DeviceCanvasVideoViewportOwner)).key, isNull);

      cubit.emitDeviceCanvas(_videoAuthorization(claimRevision: 2));
      await _pumpFrames(tester);

      expect(find.text("This device is no longer assigned to this session."), findsOneWidget);
      expect(peerHarness.renderer.disposeCalls, 1);
      verify(peerHarness.connection.close).called(1);
      verify(peerHarness.connection.dispose).called(1);
      final stopRequest =
          verify(() => service.stopStream(request: captureAny(named: "request"))).captured.single
              as DeviceCanvasStreamStopRequest;
      expect(stopRequest.expectedClaimRevision, 1);
      expect(stopRequest.leaseId, "lease-1");

      await tester.tap(find.text("Close preview"));
      await _pumpFrames(tester);
      expect(find.text("LAN video preview"), findsNothing);
      verify(() => service.startStream(request: any(named: "request"))).called(1);
      verifyNoMoreInteractions(service);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets("dismisses the modal and closes video before the session cubit", (tester) async {
      await _openVideoViewport(tester: tester, cubit: cubit, peerHarness: peerHarness);

      Navigator.of(tester.element(find.text("LAN video preview"))).pop();
      await tester.pumpAndSettle();
      await _pumpFrames(tester, 16);

      expect(find.text("LAN video preview"), findsNothing);
      expect(peerHarness.renderer.disposed.isCompleted, isTrue);
      expect(peerHarness.renderer.disposeCalls, 1);
      verify(peerHarness.connection.close).called(1);
      verify(peerHarness.connection.dispose).called(1);
      verify(() => service.stopStream(request: any(named: "request"))).called(1);

      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
      expect(cubit.isClosed, isTrue);
    });
  });
}

Future<void> _openVideoViewport({
  required WidgetTester tester,
  required _FakeSessionDetailCubit cubit,
  required _VideoPeerHarness peerHarness,
}) async {
  await tester.pumpWidget(
    _app(cubit: cubit, deviceCanvas: _videoAuthorization(), videoPreviewEnabled: true),
  );
  await tester.tap(find.text("Device Canvas"));
  await tester.pumpAndSettle();
  await tester.tap(find.text("Watch"));
  await _pumpFrames(tester);

  expect(find.text("LAN video preview"), findsOneWidget);
  final onFirstFrameRendered = peerHarness.renderer.onFirstFrameRendered as void Function()?;
  expect(onFirstFrameRendered, isNotNull);
  onFirstFrameRendered!();
  await _pumpFrames(tester);
  expect(find.text("Live"), findsOneWidget);
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 8]) async {
  for (var index = 0; index < count; index++) {
    await tester.pump();
  }
}

Widget _app({
  required _FakeSessionDetailCubit cubit,
  required DeviceCanvasSessionState deviceCanvas,
  bool readOnly = false,
  bool videoPreviewEnabled = false,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (_, _) => Scaffold(
          body: DeviceCanvasStatusBanner(
            state: deviceCanvas,
            readOnly: readOnly,
            videoPreviewEnabled: videoPreviewEnabled,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return BlocProvider<SessionDetailCubit>.value(
    value: cubit,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class _FakeSessionDetailCubit(DeviceCanvasSessionState initialDeviceCanvas)
    extends Cubit<SessionDetailState>
    implements SessionDetailCubit {
  final List<({String deviceKey, bool reassign})> claims = [];
  final List<String> releases = [];
  int refreshes = 0;

  this : super(_loaded(initialDeviceCanvas));

  @override
  Future<void> claimDeviceCanvasDevice({required String deviceKey, required bool reassign}) async {
    claims.add((deviceKey: deviceKey, reassign: reassign));
  }

  @override
  Future<void> releaseDeviceCanvasDevice({required String deviceKey}) async {
    releases.add(deviceKey);
  }

  @override
  Future<void> refreshDeviceCanvas() async {
    refreshes++;
  }

  void emitDeviceCanvas(DeviceCanvasSessionState deviceCanvas) => emit(_loaded(deviceCanvas));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SessionDetailState _loaded(DeviceCanvasSessionState deviceCanvas) => SessionDetailState.loaded(
  messages: const [],
  olderMessagesCursor: null,
  streamingText: const {},
  sessionStatus: const SessionStatus.idle(),
  pendingQuestions: const [],
  pendingPermissions: const [],
  sessionTitle: "Session",
  pluginId: "opencode",
  supportsPromptAttachments: false,
  agent: null,
  assistantAgentModel: null,
  children: const [],
  childStatuses: const {},
  isRootSession: true,
  isArchived: false,
  queuedMessages: const [],
  sendingSubmission: null,
  availableAgents: const [],
  availableProviders: const [],
  availableCommands: const [],
  selectedAgent: "build",
  selectedAgentModel: null,
  stagedCommand: null,
  isRefreshing: false,
  deviceCanvas: deviceCanvas,
);

DeviceCanvasSessionStatusResponse _status({required String? claimSessionId}) {
  return DeviceCanvasSessionStatusResponse(
    bridgeId: "bridge-1",
    sessionId: "session-1",
    sessionAvailable: true,
    projectId: "project-1",
    connection: DeviceCanvasClientConnectionStatus.connected,
    devices: [
      DeviceCanvasDeviceStatus(
        deviceKey: "device-1",
        descriptor: const DeviceCanvasClientDescriptor(
          platform: DeviceCanvasClientPlatform.ios,
          displayName: "iPhone",
          runtimeDescription: "iOS 26",
          modelDescription: "iPhone",
          dimensions: DeviceCanvasClientDimensions(width: 1179, height: 2556),
          orientation: DeviceCanvasClientOrientation.portrait,
          capabilities: DeviceCanvasClientCapabilities(localView: true),
        ),
        claim: claimSessionId == null
            ? null
            : DeviceCanvasClaimStatus(
                projectId: "project-2",
                sessionId: claimSessionId,
                revision: 1,
                claimedAt: 1,
                displayTitle: "Other session",
              ),
      ),
    ],
    supportsReassignment: true,
  );
}

DeviceCanvasSessionStatusResponse _videoStatus({int claimRevision = 1}) {
  return DeviceCanvasSessionStatusResponse(
    bridgeId: "bridge-1",
    sessionId: "session-1",
    sessionAvailable: true,
    projectId: "project-1",
    connection: DeviceCanvasClientConnectionStatus.connected,
    devices: [
      DeviceCanvasDeviceStatus(
        deviceKey: "device-1",
        descriptor: const DeviceCanvasClientDescriptor(
          platform: DeviceCanvasClientPlatform.android,
          displayName: "Android Emulator",
          runtimeDescription: "Android 16",
          modelDescription: "Pixel",
          dimensions: DeviceCanvasClientDimensions(width: 1080, height: 2400),
          orientation: DeviceCanvasClientOrientation.portrait,
          capabilities: DeviceCanvasClientCapabilities(localView: true, remoteVideo: true),
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
  );
}

DeviceCanvasSessionReady _videoAuthorization({int claimRevision = 1}) {
  return DeviceCanvasSessionReady(
    status: _videoStatus(claimRevision: claimRevision),
    mutation: const DeviceCanvasSessionMutationIdle(),
  );
}
