import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_device_canvas_video_peer.dart";
import "package:sesori_mobile/core/platform/flutter_webrtc_client.dart";
import "package:sesori_shared/sesori_shared.dart";

class _MockFlutterWebRtcClient() extends Mock implements FlutterWebRtcClient;

class _MockVideoRenderer() extends Mock implements RTCVideoRenderer {
  Function? _firstFrameCallback;

  @override
  Function? get onFirstFrameRendered => _firstFrameCallback;

  @override
  set onFirstFrameRendered(Function? callback) => _firstFrameCallback = callback;

  void renderFirstFrame() {
    final callback = _firstFrameCallback;
    if (callback == null) throw StateError("first-frame callback is not registered");
    (callback as void Function())();
  }
}

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

const _fingerprint =
    "sha-256 00:01:02:03:04:05:06:07:08:09:0A:0B:0C:0D:0E:0F:10:11:12:13:14:15:16:17:18:19:1A:1B:1C:1D:1E:1F";
const _localCandidate = "candidate:1 1 UDP 1 192.168.1.10 5000 typ host";
const _globalCandidate = "candidate:2 1 UDP 1 2001:db8::10 5001 typ host";
const _relayCandidate = "candidate:3 1 UDP 1 203.0.113.10 5002 typ relay";
const _publicIpv4Candidate = "candidate:4 1 UDP 1 8.8.8.8 5003 typ host";
const _serverReflexiveCandidate = "candidate:5 1 UDP 1 192.168.1.20 5004 typ srflx";
const _ipv4LinkLocalCandidate = "candidate:6 1 UDP 1 169.254.12.34 5005 typ host";
const _ulaCandidate = "candidate:7 1 UDP 1 fd12:3456:789a::1 5006 typ host";
const _ipv6LinkLocalCandidate = "candidate:8 1 UDP 1 fe80::1234 5007 typ host";
const _mappedPrivateCandidate = "candidate:9 1 UDP 1 ::ffff:192.168.1.30 5008 typ host";
const _mdnsCandidate = "candidate:10 1 UDP 1 peer-a.local 5009 typ host";
const _hostnameLookalikeCandidate = "candidate:11 1 UDP 1 february.example.com 5010 typ host";
const _zonedLinkLocalCandidate = "candidate:12 1 UDP 2122260223 fe80::1234%en0 5011 typ host generation 0 network-id 1";
const _tcpPrivateCandidate = "candidate:13 1 TCP 2122260222 10.0.0.8 5012 typ host tcptype passive";
const _mappedGlobalCandidate = "candidate:14 1 UDP 1 ::ffff:8.8.8.8 5013 typ host";
const _malformedPortCandidate = "candidate:15 1 UDP 1 192.168.1.8 not-a-port typ host";
const _malformedFoundationCandidate = "candidate:bad! 1 UDP 1 192.168.1.8 5014 typ host";
const _unsupportedTransportCandidate = "candidate:16 1 SCTP 1 192.168.1.8 5015 typ host";
const _malformedMdnsCandidate = "candidate:17 1 UDP 1 -peer.local 5016 typ host";
const _zonedUlaCandidate = "candidate:18 1 UDP 1 fd12::1%en0 5017 typ host";
const _duplicateExtensionCandidate = "candidate:19 1 UDP 1 192.168.1.8 5018 typ host generation 0 generation 1";
const _sdp = "v=0\r\na=fingerprint:$_fingerprint\r\na=$_localCandidate\r\n";
const _answer = DeviceCanvasRtcDescription(
  type: DeviceCanvasRtcDescriptionType.answer,
  sdp: _sdp,
  fingerprint: _fingerprint,
);

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(RTCRtpMediaType.RTCRtpMediaTypeVideo);
    registerFallbackValue(RTCRtpTransceiverInit());
    registerFallbackValue(RTCSessionDescription("", "offer"));
    registerFallbackValue(RTCIceCandidate("candidate", "0", 0));
  });

  late _MockFlutterWebRtcClient client;
  late _MockVideoRenderer renderer;
  late _MockPeerConnection connection;
  late _MockRtpTransceiver transceiver;
  FlutterDeviceCanvasVideoPeer? peer;

  setUp(() {
    client = _MockFlutterWebRtcClient();
    renderer = _MockVideoRenderer();
    connection = _MockPeerConnection();
    transceiver = _MockRtpTransceiver();
    when(client.createVideoRenderer).thenReturn(renderer);
    when(renderer.initialize).thenAnswer((_) async {});
    when(renderer.dispose).thenAnswer((_) async {});
    when(() => renderer.textureId).thenReturn(null);
    when(client.createDeviceCanvasPeerConnection).thenAnswer((_) async => connection);
    when(
      () => connection.addTransceiver(
        kind: any(named: "kind"),
        init: any(named: "init"),
      ),
    ).thenAnswer((_) async => transceiver);
    when(() => connection.createOffer(any())).thenAnswer((_) async => RTCSessionDescription(_sdp, "offer"));
    when(() => connection.setLocalDescription(any())).thenAnswer((_) async {});
    when(connection.getLocalDescription).thenAnswer((_) async => RTCSessionDescription(_sdp, "offer"));
    when(() => connection.setRemoteDescription(any())).thenAnswer((_) async {});
    when(() => connection.addCandidate(any())).thenAnswer((_) async {});
    when(connection.close).thenAnswer((_) async {});
    when(connection.dispose).thenAnswer((_) async {});
  });

  tearDown(() async {
    await peer?.close();
  });

  test("creates a recv-only host-candidate offer with a strict fingerprint", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    final states = <DeviceCanvasVideoPeerConnectionState>[];
    final subscription = peer!.connectionStateStream.listen(states.add);

    final offer = await peer!.createOffer();
    await _settle();

    expect(offer.description.type, DeviceCanvasRtcDescriptionType.offer);
    expect(offer.description.fingerprint, _fingerprint);
    expect(offer.description.isValid, isTrue);
    expect(offer.description.sdp, contains(_localCandidate));
    expect(offer.iceCandidates, isEmpty);
    expect(states, contains(DeviceCanvasVideoPeerConnectionState.connecting));

    verify(client.createDeviceCanvasPeerConnection).called(1);

    final init =
        verify(
              () => connection.addTransceiver(
                kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
                init: captureAny(named: "init"),
              ),
            ).captured.single
            as RTCRtpTransceiverInit;
    expect(init.direction, TransceiverDirection.RecvOnly);

    connection.onConnectionState!(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
    await _settle();
    expect(states, isNot(contains(DeviceCanvasVideoPeerConnectionState.videoReady)));
    renderer.renderFirstFrame();
    await _settle();
    expect(states, contains(DeviceCanvasVideoPeerConnectionState.videoReady));

    await subscription.cancel();
  });

  test("applies a validated answer and remote ICE candidates", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    await peer!.createOffer();
    const candidate = DeviceCanvasIceCandidate(
      candidate: "candidate:1 1 UDP 1 192.168.1.10 5000 typ host",
      sdpMid: "0",
      sdpMLineIndex: 0,
    );

    await peer!.applyAnswer(answer: _answer, iceCandidates: const [candidate]);

    final description =
        verify(() => connection.setRemoteDescription(captureAny())).captured.single as RTCSessionDescription;
    expect(description.type, "answer");
    expect(description.sdp, _sdp);
    final appliedCandidate = verify(() => connection.addCandidate(captureAny())).captured.single as RTCIceCandidate;
    expect(appliedCandidate.candidate, candidate.candidate);
    expect(appliedCandidate.sdpMid, "0");
    expect(appliedCandidate.sdpMLineIndex, 0);
  });

  test("removes globally routed candidates from the local offer", () async {
    const mixedSdp =
        "v=0\r\na=fingerprint:$_fingerprint\r\na=$_localCandidate\r\na=$_globalCandidate\r\na=$_relayCandidate\r\n";
    when(connection.getLocalDescription).thenAnswer((_) async => RTCSessionDescription(mixedSdp, "offer"));
    peer = FlutterDeviceCanvasVideoPeer(client: client);

    final offer = await peer!.createOffer();

    expect(offer.description.sdp, contains(_localCandidate));
    expect(offer.description.sdp, isNot(contains(_globalCandidate)));
    expect(offer.description.sdp, isNot(contains(_relayCandidate)));
  });

  test("retains private, link-local, ULA, mapped, and mDNS host candidates", () async {
    const mixedSdp =
        "v=0\r\na=fingerprint:$_fingerprint\r\na=$_localCandidate\r\na=$_ipv4LinkLocalCandidate\r\na=$_ulaCandidate\r\na=$_ipv6LinkLocalCandidate\r\na=$_mappedPrivateCandidate\r\na=$_mdnsCandidate\r\na=$_publicIpv4Candidate\r\na=$_serverReflexiveCandidate\r\n";
    when(connection.getLocalDescription).thenAnswer((_) async => RTCSessionDescription(mixedSdp, "offer"));
    peer = FlutterDeviceCanvasVideoPeer(client: client);

    final offer = await peer!.createOffer();

    expect(offer.description.sdp, contains(_localCandidate));
    expect(offer.description.sdp, contains(_ipv4LinkLocalCandidate));
    expect(offer.description.sdp, contains(_ulaCandidate));
    expect(offer.description.sdp, contains(_ipv6LinkLocalCandidate));
    expect(offer.description.sdp, contains(_mappedPrivateCandidate));
    expect(offer.description.sdp, contains(_mdnsCandidate));
    expect(offer.description.sdp, isNot(contains(_publicIpv4Candidate)));
    expect(offer.description.sdp, isNot(contains(_serverReflexiveCandidate)));
  });

  test("rejects a globally resolvable hostname that resembles an IPv6 prefix", () async {
    const hostnameSdp = "v=0\r\na=fingerprint:$_fingerprint\r\na=$_hostnameLookalikeCandidate\r\n";
    when(connection.getLocalDescription).thenAnswer((_) async => RTCSessionDescription(hostnameSdp, "offer"));
    peer = FlutterDeviceCanvasVideoPeer(client: client);

    await expectLater(peer!.createOffer(), throwsA(isA<FormatException>()));
  });

  test("validates complete ICE grammar before retaining LAN candidates", () async {
    const mixedSdp =
        "v=0\r\na=fingerprint:$_fingerprint\r\na=$_localCandidate\r\na=$_zonedLinkLocalCandidate\r\na=$_tcpPrivateCandidate\r\na=$_mappedGlobalCandidate\r\na=$_malformedPortCandidate\r\na=$_malformedFoundationCandidate\r\na=$_unsupportedTransportCandidate\r\na=$_malformedMdnsCandidate\r\na=$_zonedUlaCandidate\r\na=$_duplicateExtensionCandidate\r\n";
    when(connection.getLocalDescription).thenAnswer((_) async => RTCSessionDescription(mixedSdp, "offer"));
    peer = FlutterDeviceCanvasVideoPeer(client: client);

    final offer = await peer!.createOffer();

    expect(offer.description.sdp, contains(_localCandidate));
    expect(offer.description.sdp, contains(_zonedLinkLocalCandidate));
    expect(offer.description.sdp, contains(_tcpPrivateCandidate));
    expect(offer.description.sdp, isNot(contains(_mappedGlobalCandidate)));
    expect(offer.description.sdp, isNot(contains(_malformedPortCandidate)));
    expect(offer.description.sdp, isNot(contains(_malformedFoundationCandidate)));
    expect(offer.description.sdp, isNot(contains(_unsupportedTransportCandidate)));
    expect(offer.description.sdp, isNot(contains(_malformedMdnsCandidate)));
    expect(offer.description.sdp, isNot(contains(_zonedUlaCandidate)));
    expect(offer.description.sdp, isNot(contains(_duplicateExtensionCandidate)));
  });

  test("filters non-LAN explicit candidates from the local offer", () async {
    when(() => connection.setLocalDescription(any())).thenAnswer((_) async {
      connection.onIceCandidate!(RTCIceCandidate(_localCandidate, "0", 0));
      connection.onIceCandidate!(RTCIceCandidate(_publicIpv4Candidate, "0", 0));
      connection.onIceCandidate!(RTCIceCandidate(_serverReflexiveCandidate, "0", 0));
    });
    peer = FlutterDeviceCanvasVideoPeer(client: client);

    final offer = await peer!.createOffer();

    expect(offer.iceCandidates.map((candidate) => candidate.candidate), [_localCandidate]);
  });

  test("rejects malformed remote signaling before touching the peer connection", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    await peer!.createOffer();
    const invalidAnswer = DeviceCanvasRtcDescription(
      type: DeviceCanvasRtcDescriptionType.answer,
      sdp: "v=0\r\n",
      fingerprint: _fingerprint,
    );

    await expectLater(
      peer!.applyAnswer(answer: invalidAnswer, iceCandidates: const []),
      throwsA(isA<FormatException>()),
    );

    verifyNever(() => connection.setRemoteDescription(any()));
  });

  test("rejects a LAN-looking malformed candidate before native WebRTC", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    await peer!.createOffer();
    const invalidAnswer = DeviceCanvasRtcDescription(
      type: DeviceCanvasRtcDescriptionType.answer,
      sdp: "v=0\r\na=fingerprint:$_fingerprint\r\na=$_malformedPortCandidate\r\n",
      fingerprint: _fingerprint,
    );

    await expectLater(
      peer!.applyAnswer(answer: invalidAnswer, iceCandidates: const []),
      throwsA(isA<FormatException>()),
    );

    verifyNever(() => connection.setRemoteDescription(any()));
  });

  test("removes globally routed and relay candidates from remote signaling", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    await peer!.createOffer();
    const answer = DeviceCanvasRtcDescription(
      type: DeviceCanvasRtcDescriptionType.answer,
      sdp:
          "v=0\r\na=fingerprint:$_fingerprint\r\na=$_localCandidate\r\na=$_globalCandidate\r\na=$_relayCandidate\r\na=$_serverReflexiveCandidate\r\n",
      fingerprint: _fingerprint,
    );
    const local = DeviceCanvasIceCandidate(candidate: _localCandidate, sdpMid: "0", sdpMLineIndex: 0);
    const global = DeviceCanvasIceCandidate(candidate: _globalCandidate, sdpMid: "0", sdpMLineIndex: 0);
    const relay = DeviceCanvasIceCandidate(candidate: _relayCandidate, sdpMid: "0", sdpMLineIndex: 0);
    const serverReflexive = DeviceCanvasIceCandidate(
      candidate: _serverReflexiveCandidate,
      sdpMid: "0",
      sdpMLineIndex: 0,
    );

    await peer!.applyAnswer(answer: answer, iceCandidates: const [local, global, relay, serverReflexive]);

    final description =
        verify(() => connection.setRemoteDescription(captureAny())).captured.single as RTCSessionDescription;
    expect(description.sdp, contains(_localCandidate));
    expect(description.sdp, isNot(contains(_globalCandidate)));
    expect(description.sdp, isNot(contains(_relayCandidate)));
    expect(description.sdp, isNot(contains(_serverReflexiveCandidate)));
    final candidates = verify(() => connection.addCandidate(captureAny())).captured.cast<RTCIceCandidate>();
    expect(candidates, hasLength(1));
    expect(candidates.single.candidate, _localCandidate);
  });

  test("rejects signaling without any local host candidate", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    await peer!.createOffer();
    const answer = DeviceCanvasRtcDescription(
      type: DeviceCanvasRtcDescriptionType.answer,
      sdp: "v=0\r\na=fingerprint:$_fingerprint\r\na=$_globalCandidate\r\n",
      fingerprint: _fingerprint,
    );

    await expectLater(
      peer!.applyAnswer(
        answer: answer,
        iceCandidates: const [
          DeviceCanvasIceCandidate(candidate: _globalCandidate, sdpMid: "0", sdpMLineIndex: 0),
        ],
      ),
      throwsA(isA<FormatException>()),
    );

    verifyNever(() => connection.setRemoteDescription(any()));
  });

  test("can close from a delivered peer failure without reentrant stream disposal", () async {
    peer = FlutterDeviceCanvasVideoPeer(client: client);
    await peer!.createOffer();
    final closed = Completer<void>();
    peer!.connectionStateStream.listen((state) {
      if (state == DeviceCanvasVideoPeerConnectionState.failed) {
        peer!.close().then((_) => closed.complete());
      }
    });

    connection.onConnectionState!(RTCPeerConnectionState.RTCPeerConnectionStateFailed);
    await closed.future;

    verify(connection.close).called(1);
    verify(connection.dispose).called(1);
    verify(renderer.dispose).called(1);
    expect(connection.onConnectionState, isNull);
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
