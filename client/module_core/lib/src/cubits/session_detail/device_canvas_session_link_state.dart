import "package:sesori_shared/sesori_shared.dart";

sealed class const DeviceCanvasSessionLinkState();

final class const DeviceCanvasSessionLinkWaiting() extends DeviceCanvasSessionLinkState;

final class const DeviceCanvasSessionLinkVerified({required final DeviceCanvasSessionStatusResponse status})
    extends DeviceCanvasSessionLinkState;

final class const DeviceCanvasSessionLinkUnavailable() extends DeviceCanvasSessionLinkState;
