import "package:freezed_annotation/freezed_annotation.dart";

part "sse_toast_state.freezed.dart";

/// Severity of a backend toast, parsed at the boundary from the wire's raw
/// variant string. Unknown or absent variants degrade to [info].
enum SseToastVariant() {
  info,
  success,
  warning,
  error;

  static SseToastVariant parse(String? raw) => switch (raw) {
    "success" => SseToastVariant.success,
    "warning" => SseToastVariant.warning,
    "error" => SseToastVariant.error,
    _ => SseToastVariant.info,
  };
}

/// What the app-wide toast surface should present.
///
/// [SseToastShow.sequence] increases on every show so equal repeated guidance
/// (for example the same `/login` hint twice) is still a distinct effect for
/// listeners comparing states.
@Freezed()
sealed class SseToastState with _$SseToastState {
  const factory idle() = SseToastIdle;

  const factory show({
    required int sequence,
    required String? title,
    required String message,
    required SseToastVariant variant,
  }) = SseToastShow;
}
