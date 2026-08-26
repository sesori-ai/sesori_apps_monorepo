import "package:flutter_webrtc/flutter_webrtc.dart" as webrtc;
import "package:injectable/injectable.dart";

@lazySingleton
class const FlutterWebRtcClient() {
  webrtc.RTCVideoRenderer createVideoRenderer() => webrtc.RTCVideoRenderer();

  Future<webrtc.RTCPeerConnection> createDeviceCanvasPeerConnection() => webrtc.createPeerConnection(
    const {
      "iceServers": <Never>[],
      "iceTransportPolicy": "all",
      "bundlePolicy": "max-bundle",
      "rtcpMuxPolicy": "require",
      "sdpSemantics": "unified-plan",
    },
    const {
      "mandatory": <String, Never>{},
      "optional": [
        {"DtlsSrtpKeyAgreement": true},
      ],
    },
  );
}
