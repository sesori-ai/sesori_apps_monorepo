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

sealed class const DeviceCanvasStreamStartResult();

final class const DeviceCanvasStreamStartSupported({required final DeviceCanvasStreamStartResponse response})
    extends DeviceCanvasStreamStartResult;

final class const DeviceCanvasStreamStartUnsupported() extends DeviceCanvasStreamStartResult;

final class const DeviceCanvasStreamStartUncertain() extends DeviceCanvasStreamStartResult;

final class const DeviceCanvasStreamStartFailure({required final ApiError error}) extends DeviceCanvasStreamStartResult;

sealed class const DeviceCanvasStreamPrepareResult();

final class const DeviceCanvasStreamPrepareSupported({required final DeviceCanvasStreamPrepareResponse response})
    extends DeviceCanvasStreamPrepareResult;

final class const DeviceCanvasStreamPrepareUnsupported() extends DeviceCanvasStreamPrepareResult;

final class const DeviceCanvasStreamPrepareUncertain() extends DeviceCanvasStreamPrepareResult;

final class const DeviceCanvasStreamPrepareFailure({required final ApiError error})
    extends DeviceCanvasStreamPrepareResult;

sealed class const DeviceCanvasStreamStatusResult();

final class const DeviceCanvasStreamStatusSupported({required final DeviceCanvasStreamStatusResponse response})
    extends DeviceCanvasStreamStatusResult;

final class const DeviceCanvasStreamStatusUnsupported() extends DeviceCanvasStreamStatusResult;

final class const DeviceCanvasStreamStatusFailure({required final ApiError error})
    extends DeviceCanvasStreamStatusResult;

sealed class const DeviceCanvasStreamStopResult();

final class const DeviceCanvasStreamStopSupported({required final DeviceCanvasStreamStopResponse response})
    extends DeviceCanvasStreamStopResult;

final class const DeviceCanvasStreamStopUnsupported() extends DeviceCanvasStreamStopResult;

final class const DeviceCanvasStreamStopUncertain() extends DeviceCanvasStreamStopResult;

final class const DeviceCanvasStreamStopFailure({required final ApiError error}) extends DeviceCanvasStreamStopResult;
