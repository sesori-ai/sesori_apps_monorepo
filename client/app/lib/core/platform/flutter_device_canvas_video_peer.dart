import "dart:async";

import "package:flutter_webrtc/flutter_webrtc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

import "flutter_webrtc_client.dart";

class FlutterDeviceCanvasVideoPeer({required FlutterWebRtcClient client}) implements DeviceCanvasVideoPeer {
  final FlutterWebRtcClient _client = client;
  final RTCVideoRenderer renderer = client.createVideoRenderer();
  final StreamController<DeviceCanvasVideoPeerConnectionState> _connectionStates =
      StreamController<DeviceCanvasVideoPeerConnectionState>.broadcast();
  final List<DeviceCanvasIceCandidate> _localCandidates = [];

  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  Completer<void>? _offerIceCompleter;
  Future<void>? _rendererInitialization;
  Future<void>? _closeFuture;
  bool _offerCreationStarted = false;
  bool _relayOnly = false;
  bool _invalidCandidate = false;
  bool _closed = false;

  static const _iceGatheringTimeout = Duration(seconds: 10);
  static final _candidateFoundationPattern = RegExp(r"^[A-Za-z0-9+/]{1,32}$");
  static final _candidateNumberPattern = RegExp(r"^[0-9]+$");
  static final _candidateExtensionNamePattern = RegExp(r"^[A-Za-z][A-Za-z0-9-]*$");
  static final _candidateExtensionValuePattern = RegExp(r"^[A-Za-z0-9+/_\-.]+$");
  static final _mdnsLabelPattern = RegExp(r"^[a-z0-9-]+$");
  static final _ipv6ZonePattern = RegExp(r"^[a-z0-9_.~-]{1,64}$");

  @override
  Stream<DeviceCanvasVideoPeerConnectionState> get connectionStateStream => _connectionStates.stream;

  @override
  Future<DeviceCanvasVideoOffer> createOffer({required DeviceCanvasTurnConfiguration? turn}) async {
    if (_offerCreationStarted) throw StateError("Device Canvas video offer already created");
    _ensureOpen();
    _offerCreationStarted = true;
    _relayOnly = turn != null;
    renderer.onFirstFrameRendered = _onFirstFrameRendered;
    _rendererInitialization ??= renderer.initialize();
    await _rendererInitialization;
    _ensureOpen();

    final peerConnection = await _client.createDeviceCanvasPeerConnection(turn: turn);
    if (_closed) {
      await _disposePeerConnection(peerConnection);
      throw StateError("Device Canvas video peer is closed");
    }
    _peerConnection = peerConnection;
    _configureCallbacks(peerConnection);
    _emit(DeviceCanvasVideoPeerConnectionState.connecting);

    await peerConnection.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    final offer = await peerConnection.createOffer(const {
      "mandatory": <String, dynamic>{
        "OfferToReceiveAudio": false,
        "OfferToReceiveVideo": true,
      },
      "optional": <Map<String, dynamic>>[],
    });
    final offerSdp = offer.sdp;
    if (offer.type != "offer" || offerSdp == null || offerSdp.isEmpty) {
      throw const FormatException("WebRTC did not create a valid video offer");
    }
    final offerIceCompleter = Completer<void>();
    _offerIceCompleter = offerIceCompleter;
    await peerConnection.setLocalDescription(offer);
    if (peerConnection.iceGatheringState != RTCIceGatheringState.RTCIceGatheringStateComplete) {
      await offerIceCompleter.future.timeout(_iceGatheringTimeout);
    }
    _ensureOpen();

    final localDescription = await peerConnection.getLocalDescription();
    final localSdp = localDescription?.sdp;
    if (localDescription?.type != "offer" || localSdp == null || localSdp.isEmpty) {
      throw const FormatException("WebRTC did not retain a valid local offer");
    }
    final filteredSdp = _retainAllowedCandidates(localSdp);
    if (_invalidCandidate ||
        _localCandidates.length > maxDeviceCanvasIceCandidates ||
        !_localCandidates.every((candidate) => candidate.isValid)) {
      throw const FormatException("WebRTC produced invalid ICE candidates");
    }
    if (!_containsIceCandidate(filteredSdp) && _localCandidates.isEmpty) {
      throw FormatException(
        _relayOnly
            ? "WebRTC did not produce a relay candidate"
            : "WebRTC did not produce a local-network host candidate",
      );
    }
    final fingerprint = _extractFingerprint(filteredSdp);
    final description = DeviceCanvasRtcDescription(
      type: DeviceCanvasRtcDescriptionType.offer,
      sdp: filteredSdp,
      fingerprint: fingerprint,
    );
    if (!description.isValid) throw const FormatException("WebRTC produced an invalid SDP fingerprint");
    return DeviceCanvasVideoOffer(description: description, iceCandidates: List.unmodifiable(_localCandidates));
  }

  @override
  Future<void> applyAnswer({
    required DeviceCanvasRtcDescription answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
  }) async {
    _ensureOpen();
    final peerConnection = _peerConnection;
    if (peerConnection == null) throw StateError("Device Canvas video offer was not created");
    if (answer.type != DeviceCanvasRtcDescriptionType.answer ||
        !answer.isValid ||
        iceCandidates.length > maxDeviceCanvasIceCandidates ||
        !iceCandidates.every((candidate) => candidate.isValid)) {
      throw const FormatException("Device Canvas returned invalid WebRTC signaling");
    }
    final filteredSdp = _retainAllowedCandidates(answer.sdp);
    final filteredCandidates = iceCandidates.where((candidate) => _isAllowedCandidate(candidate.candidate)).toList();
    if (!_containsIceCandidate(filteredSdp) && filteredCandidates.isEmpty) {
      throw FormatException(
        _relayOnly
            ? "Device Canvas did not return a relay candidate"
            : "Device Canvas did not return a local-network host candidate",
      );
    }
    final filteredAnswer = DeviceCanvasRtcDescription(
      type: DeviceCanvasRtcDescriptionType.answer,
      sdp: filteredSdp,
      fingerprint: answer.fingerprint,
    );
    if (!filteredAnswer.isValid) throw const FormatException("Device Canvas returned an invalid filtered answer");
    await peerConnection.setRemoteDescription(RTCSessionDescription(filteredAnswer.sdp, "answer"));
    for (final candidate in filteredCandidates) {
      await peerConnection.addCandidate(
        RTCIceCandidate(candidate.candidate, candidate.sdpMid, candidate.sdpMLineIndex),
      );
    }
  }

  void _configureCallbacks(RTCPeerConnection peerConnection) {
    peerConnection.onConnectionState = (state) {
      _emit(
        switch (state) {
          RTCPeerConnectionState.RTCPeerConnectionStateNew ||
          RTCPeerConnectionState.RTCPeerConnectionStateConnecting ||
          RTCPeerConnectionState.RTCPeerConnectionStateConnected => DeviceCanvasVideoPeerConnectionState.connecting,
          RTCPeerConnectionState.RTCPeerConnectionStateDisconnected =>
            DeviceCanvasVideoPeerConnectionState.disconnected,
          RTCPeerConnectionState.RTCPeerConnectionStateFailed => DeviceCanvasVideoPeerConnectionState.failed,
          RTCPeerConnectionState.RTCPeerConnectionStateClosed => DeviceCanvasVideoPeerConnectionState.closed,
        },
      );
    };
    peerConnection.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        _completeOfferIceWait();
      }
    };
    peerConnection.onIceCandidate = (candidate) {
      final value = candidate.candidate;
      if (value == null || value.isEmpty) return;
      final sdpMid = candidate.sdpMid;
      final sdpMLineIndex = candidate.sdpMLineIndex;
      if (sdpMid == null || sdpMid.isEmpty || sdpMLineIndex == null || sdpMLineIndex < 0) {
        _invalidCandidate = true;
        return;
      }
      if (!_isAllowedCandidate(value)) return;
      _localCandidates.add(
        DeviceCanvasIceCandidate(candidate: value, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex),
      );
      if (_relayOnly) _completeOfferIceWait();
    };
    peerConnection.onTrack = (event) {
      if (event.track.kind != "video") return;
      unawaited(_attachRemoteTrack(event));
    };
  }

  Future<void> _attachRemoteTrack(RTCTrackEvent event) async {
    try {
      if (_closed) return;
      if (event.streams.isEmpty) {
        _emit(DeviceCanvasVideoPeerConnectionState.failed);
        return;
      }
      final stream = event.streams.first;
      _remoteStream = stream;
      await renderer.setSrcObject(stream: stream, trackId: event.track.id);
    } on Object catch (error, stackTrace) {
      logw("Failed to attach Device Canvas remote video track", error, stackTrace);
      _emit(DeviceCanvasVideoPeerConnectionState.failed);
    }
  }

  String _extractFingerprint(String sdp) {
    final lines = sdp.split(RegExp(r"\r?\n")).where((line) => line.startsWith("a=fingerprint:")).toList();
    if (lines.length != 1) throw const FormatException("WebRTC offer must contain one DTLS fingerprint");
    return lines.single.substring("a=fingerprint:".length);
  }

  String _retainAllowedCandidates(String sdp) {
    final lineEnding = sdp.contains("\r\n") ? "\r\n" : "\n";
    return sdp
        .split(RegExp(r"\r?\n"))
        .where((line) => !line.startsWith("a=candidate:") || _isAllowedCandidate(line.substring(2)))
        .join(lineEnding);
  }

  bool _containsIceCandidate(String sdp) {
    return sdp.split(RegExp(r"\r?\n")).any((line) => line.startsWith("a=candidate:"));
  }

  bool _isAllowedCandidate(String candidate) =>
      _relayOnly ? _isCandidate(candidate, type: "relay") : _isCandidate(candidate, type: "host");

  bool _isCandidate(String candidate, {required String type}) {
    final fields = candidate.trim().split(RegExp(r"\s+"));
    if (fields.length < 8 || (fields.length - 8).isOdd) return false;
    if (!fields[0].startsWith("candidate:") ||
        !_candidateFoundationPattern.hasMatch(fields[0].substring("candidate:".length)) ||
        !_isCandidateNumberInRange(fields[1], minimum: 1, maximum: 256) ||
        !_isCandidateNumberInRange(fields[3], minimum: 1, maximum: 0xffffffff) ||
        !_isCandidateNumberInRange(fields[5], minimum: 1, maximum: 65535) ||
        fields[6].toLowerCase() != "typ" ||
        fields[7].toLowerCase() != type) {
      return false;
    }
    final transport = fields[2].toLowerCase();
    if (transport != "udp" && transport != "tcp") return false;

    final extensionNames = <String>{"typ"};
    String? tcpType;
    String? relatedAddress;
    String? relatedPort;
    for (var index = 8; index < fields.length; index += 2) {
      final name = fields[index].toLowerCase();
      final value = fields[index + 1].toLowerCase();
      if (!_candidateExtensionNamePattern.hasMatch(name) ||
          !extensionNames.add(name) ||
          (name != "raddr" && !_candidateExtensionValuePattern.hasMatch(value))) {
        return false;
      }
      if (name == "tcptype") tcpType = value;
      if (name == "raddr") relatedAddress = value;
      if (name == "rport") relatedPort = value;
    }
    if (transport == "tcp") {
      if (tcpType != "active" && tcpType != "passive" && tcpType != "so") return false;
    } else if (tcpType != null) {
      return false;
    }

    final address = fields[4].toLowerCase();
    if (type == "host") {
      if (relatedAddress != null || relatedPort != null) return false;
      return _isLanCandidateAddress(address);
    }
    if ((relatedAddress == null) != (relatedPort == null)) return false;
    if (relatedAddress != null) {
      final port = relatedPort;
      if (port == null ||
          !_isCandidateIpAddress(relatedAddress) ||
          !_isCandidateNumberInRange(port, minimum: 0, maximum: 65535)) {
        return false;
      }
    }
    return _isCandidateIpAddress(address);
  }

  bool _isCandidateNumberInRange(String value, {required int minimum, required int maximum}) {
    if (value.length > 10 || !_candidateNumberPattern.hasMatch(value)) return false;
    final parsed = int.tryParse(value);
    return parsed != null && parsed >= minimum && parsed <= maximum;
  }

  bool _isLanCandidateAddress(String address) {
    if (_isValidMdnsAddress(address)) return true;
    final zoneSeparator = address.indexOf("%");
    if (zoneSeparator < 0) return _isLanIpv4Address(address) || _isLanIpv6Address(address, hasZone: false);
    if (address.indexOf("%", zoneSeparator + 1) >= 0) return false;
    final zone = address.substring(zoneSeparator + 1);
    if (!_ipv6ZonePattern.hasMatch(zone)) return false;
    return _isLanIpv6Address(address.substring(0, zoneSeparator), hasZone: true);
  }

  bool _isValidMdnsAddress(String address) {
    final normalized = address.endsWith(".") ? address.substring(0, address.length - 1) : address;
    if (normalized.length > 253 || !normalized.endsWith(".local")) return false;
    final labels = normalized.split(".");
    return labels.length >= 2 &&
        labels.every(
          (label) =>
              label.isNotEmpty &&
              label.length <= 63 &&
              _mdnsLabelPattern.hasMatch(label) &&
              !label.startsWith("-") &&
              !label.endsWith("-"),
        );
  }

  bool _isLanIpv4Address(String address) {
    final octets = _parseCanonicalIpv4Address(address);
    if (octets == null) return false;
    final first = octets[0];
    final second = octets[1];
    return first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168) ||
        (first == 169 && second == 254);
  }

  List<int>? _parseCanonicalIpv4Address(String address) {
    final fields = address.split(".");
    if (fields.length != 4) return null;
    final octets = <int>[];
    for (final field in fields) {
      if (field.length > 3 || !_candidateNumberPattern.hasMatch(field) || (field.length > 1 && field.startsWith("0"))) {
        return null;
      }
      final octet = int.parse(field);
      if (octet > 255) return null;
      octets.add(octet);
    }
    return octets;
  }

  bool _isCandidateIpAddress(String address) {
    if (_parseCanonicalIpv4Address(address) != null) return true;
    if (!address.contains(":") || address.contains("%")) return false;
    try {
      return Uri.parseIPv6Address(address).length == 16;
    } on FormatException {
      return false;
    }
  }

  bool _isLanIpv6Address(String address, {required bool hasZone}) {
    final List<int> bytes;
    try {
      bytes = Uri.parseIPv6Address(address);
    } on FormatException {
      return false;
    }
    if (bytes.length != 16) return false;
    final isLinkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
    if (hasZone && !isLinkLocal) return false;
    final isIpv4Mapped = bytes.take(10).every((byte) => byte == 0) && bytes[10] == 0xff && bytes[11] == 0xff;
    if (isIpv4Mapped) return _isLanIpv4Address(bytes.sublist(12).join("."));
    return (bytes[0] & 0xfe) == 0xfc || isLinkLocal;
  }

  void _onFirstFrameRendered() => _emit(DeviceCanvasVideoPeerConnectionState.videoReady);

  void _completeOfferIceWait() {
    final completer = _offerIceCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void _emit(DeviceCanvasVideoPeerConnectionState state) {
    if (!_closed && !_connectionStates.isClosed) _connectionStates.add(state);
  }

  void _ensureOpen() {
    if (_closed) throw StateError("Device Canvas video peer is closed");
  }

  @override
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _completeOfferIceWait();

    final peerConnection = _peerConnection;
    if (peerConnection != null) {
      peerConnection
        ..onConnectionState = null
        ..onIceGatheringState = null
        ..onIceCandidate = null
        ..onTrack = null;
    }
    renderer.onFirstFrameRendered = null;
    if (!_connectionStates.isClosed) {
      _connectionStates.add(DeviceCanvasVideoPeerConnectionState.closed);
    }

    final initialization = _rendererInitialization;
    if (initialization != null) {
      try {
        await initialization;
      } on Object catch (error, stackTrace) {
        logw("Failed to initialize Device Canvas video renderer during cleanup", error, stackTrace);
      }
    }
    final remoteStream = _remoteStream;
    _remoteStream = null;
    if (renderer.textureId != null) {
      try {
        renderer.srcObject = null;
      } on Object catch (error, stackTrace) {
        logw("Failed to detach Device Canvas video renderer", error, stackTrace);
      }
    }
    if (peerConnection != null) await _disposePeerConnection(peerConnection);
    if (remoteStream != null) {
      try {
        await remoteStream.dispose();
      } on Object catch (error, stackTrace) {
        logw("Failed to dispose Device Canvas remote media stream", error, stackTrace);
      }
    }
    try {
      await renderer.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to dispose Device Canvas video renderer", error, stackTrace);
    }
    await _connectionStates.close();
  }

  Future<void> _disposePeerConnection(RTCPeerConnection peerConnection) async {
    try {
      await peerConnection.close();
    } on Object catch (error, stackTrace) {
      logw("Failed to close Device Canvas WebRTC connection", error, stackTrace);
    }
    try {
      await peerConnection.dispose();
    } on Object catch (error, stackTrace) {
      logw("Failed to dispose Device Canvas WebRTC connection", error, stackTrace);
    }
  }
}
