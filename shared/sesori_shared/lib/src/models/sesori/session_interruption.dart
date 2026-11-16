import "package:freezed_annotation/freezed_annotation.dart";

part "session_interruption.freezed.dart";
part "session_interruption.g.dart";

/// A turn the bridge was running for this session when it stopped, recorded
/// when the bridge next started. The bridge keeps only the latest one.
@Freezed(fromJson: true, toJson: true)
sealed class SessionInterruption with _$SessionInterruption {
  const factory({
    /// The newest stored message of the session when the bridge recorded the
    /// interruption: the cut-off turn ends after it.
    required String afterMessageId,

    /// True until the user opens the session or sends something to it.
    required bool unacknowledged,
  }) = _SessionInterruption;

  factory fromJson(Map<String, dynamic> json) => _$SessionInterruptionFromJson(json);
}
