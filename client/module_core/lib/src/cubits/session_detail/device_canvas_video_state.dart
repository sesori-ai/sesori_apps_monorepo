sealed class const DeviceCanvasVideoState();

final class const DeviceCanvasVideoConnecting() extends DeviceCanvasVideoState;

final class const DeviceCanvasVideoLive({required final int expiresAt}) extends DeviceCanvasVideoState;

final class const DeviceCanvasVideoFailed({required final DeviceCanvasVideoFailureReason reason})
    extends DeviceCanvasVideoState;

final class const DeviceCanvasVideoStopped() extends DeviceCanvasVideoState;

enum DeviceCanvasVideoFailureReason() {
  unavailable,
  unauthorized,
  unsupported,
  controllerConflict,
  connectionFailed,
  signalingFailed,
  lanOnly,
  expired,
}
