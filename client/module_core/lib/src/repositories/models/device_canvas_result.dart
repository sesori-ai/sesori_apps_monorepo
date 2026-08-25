import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

sealed class const DeviceCanvasStatusResult();

final class const DeviceCanvasStatusSupported({required final DeviceCanvasSessionStatusResponse status})
    extends DeviceCanvasStatusResult;

final class const DeviceCanvasStatusUnsupported() extends DeviceCanvasStatusResult;

final class const DeviceCanvasStatusFailure({required final ApiError error}) extends DeviceCanvasStatusResult;

sealed class const DeviceCanvasMutationResult();

final class const DeviceCanvasMutationCommitted({required final DeviceCanvasMutationResponse response})
    extends DeviceCanvasMutationResult;

final class const DeviceCanvasMutationUnsupported() extends DeviceCanvasMutationResult;

final class const DeviceCanvasMutationUncertain() extends DeviceCanvasMutationResult;

final class const DeviceCanvasMutationFailure({required final ApiError error}) extends DeviceCanvasMutationResult;
