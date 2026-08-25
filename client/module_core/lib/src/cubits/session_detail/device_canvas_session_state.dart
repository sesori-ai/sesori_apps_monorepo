import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const DeviceCanvasSessionState();

final class const DeviceCanvasSessionHidden() extends DeviceCanvasSessionState;

final class const DeviceCanvasSessionLoading() extends DeviceCanvasSessionState;

final class const DeviceCanvasSessionDisconnected() extends DeviceCanvasSessionState;

final class const DeviceCanvasSessionFailure({required final ApiError error}) extends DeviceCanvasSessionState;

final class const DeviceCanvasSessionReady({
  required final DeviceCanvasSessionStatusResponse status,
  required final DeviceCanvasSessionMutationState mutation,
}) extends DeviceCanvasSessionState;

sealed class const DeviceCanvasSessionMutationState();

final class const DeviceCanvasSessionMutationIdle() extends DeviceCanvasSessionMutationState;

final class const DeviceCanvasSessionMutationInProgress({
  required final String deviceKey,
  required final DeviceCanvasSessionMutationAction action,
}) extends DeviceCanvasSessionMutationState;

final class const DeviceCanvasSessionMutationFailed({
  required final String deviceKey,
  required final DeviceCanvasSessionMutationAction action,
  required final DeviceCanvasSessionMutationFailure reason,
}) extends DeviceCanvasSessionMutationState;

enum DeviceCanvasSessionMutationAction() { claim, reassign, release }

enum DeviceCanvasSessionMutationFailure() {
  conflict,
  deviceUnavailable,
  sessionUnavailable,
  uncertain,
  requestFailed,
}
