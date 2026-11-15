import "package:sesori_shared/sesori_shared.dart";

/// A task request the bridge refuses, with the code the app explains.
final class const ScheduledTaskRequestException({required final ScheduledTaskErrorCode code}) implements Exception {
  @override
  String toString() => "ScheduledTaskRequestException(${code.name})";
}
