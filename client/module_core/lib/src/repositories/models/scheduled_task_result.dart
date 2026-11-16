import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// The outcome of one scheduled-task request.
sealed class const ScheduledTaskResult<T>();

final class const ScheduledTaskSuccess<T>({required final T value}) extends ScheduledTaskResult<T>;

/// The bridge refused the request with a typed reason.
final class const ScheduledTaskRefused<T>({required final ScheduledTaskErrorCode code}) extends ScheduledTaskResult<T>;

/// The bridge predates scheduled tasks: it has none of their routes.
final class const ScheduledTaskBridgeOutdated<T>() extends ScheduledTaskResult<T>;

final class const ScheduledTaskFailure<T>({required final ApiError error}) extends ScheduledTaskResult<T>;
