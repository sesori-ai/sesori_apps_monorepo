import "package:flutter_webrtc/flutter_webrtc.dart" as webrtc;
import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

@lazySingleton
class const FlutterWebRtcClient() {
  webrtc.RTCVideoRenderer createVideoRenderer() => webrtc.RTCVideoRenderer();

  Future<webrtc.RTCPeerConnection> createDeviceCanvasPeerConnection({
    required DeviceCanvasTurnConfiguration? turn,
  }) => webrtc.createPeerConnection(
    buildDeviceCanvasPeerConnectionConfiguration(turn: turn, now: DateTime.now()),
    const {
      "mandatory": <String, Never>{},
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    },
  );

  Map<String, dynamic> buildDeviceCanvasPeerConnectionConfiguration({
    required DeviceCanvasTurnConfiguration? turn,
    required DateTime now,
  }) {
    if (turn == null) {
      return const {
        "iceServers": <Never>[],
        "iceTransportPolicy": "all",
        "bundlePolicy": "max-bundle",
        "rtcpMuxPolicy": "require",
        "sdpSemantics": "unified-plan",
      };
    }

    final urls = turn.canonicalUrls;
    if (!turn.isValid || urls == null || turn.expiresAt <= now.millisecondsSinceEpoch) {
      throw const FormatException("Device Canvas returned an invalid TURN configuration");
    }
    return {
      "iceServers": [
        {
          "urls": urls,
          "username": turn.username,
          "credential": turn.credential,
        },
      ],
      "iceTransportPolicy": "relay",
      "bundlePolicy": "max-bundle",
      "rtcpMuxPolicy": "require",
      "sdpSemantics": "unified-plan",
    };
  }
}
