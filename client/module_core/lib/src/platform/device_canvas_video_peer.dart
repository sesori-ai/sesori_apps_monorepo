import "package:sesori_shared/sesori_shared.dart";

abstract interface class DeviceCanvasVideoPeer() {
  Stream<DeviceCanvasVideoPeerConnectionState> get connectionStateStream;

  Future<DeviceCanvasVideoOffer> createOffer({required DeviceCanvasTurnConfiguration? turn});

  Future<void> applyAnswer({
    required DeviceCanvasRtcDescription answer,
    required List<DeviceCanvasIceCandidate> iceCandidates,
  });

  Future<void> close();
}

final class const DeviceCanvasVideoOffer({
  required final DeviceCanvasRtcDescription description,
  required final List<DeviceCanvasIceCandidate> iceCandidates,
});

enum DeviceCanvasVideoPeerConnectionState() { connecting, videoReady, disconnected, failed, closed }
