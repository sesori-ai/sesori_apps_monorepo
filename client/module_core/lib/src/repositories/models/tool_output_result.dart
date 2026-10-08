import "package:sesori_auth/sesori_auth.dart";

/// The output and error a page withheld from a summary tool part.
sealed class const ToolOutputResult();

/// Each is null when the tool reported none.
final class const ToolOutputAvailable({
  required final String? output,
  required final String? error,
}) extends ToolOutputResult;

final class const ToolOutputFailure({required final ApiError error}) extends ToolOutputResult;
