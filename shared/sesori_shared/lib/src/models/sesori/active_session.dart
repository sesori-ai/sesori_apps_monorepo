import "package:freezed_annotation/freezed_annotation.dart";

part "active_session.freezed.dart";
part "active_session.g.dart";

/// A root session that is currently active, along with its direct child sessions
/// that are also active (busy or retrying).
///
/// A session is considered active when either the main agent or any of its
/// direct child tasks are running. Only direct descendants are tracked —
/// deeper nesting is ignored.
@Freezed(fromJson: true, toJson: true)
sealed class ActiveSession with _$ActiveSession {
  const factory({
    required String id,
    @Default(false) bool mainAgentRunning,
    @Default(false) bool awaitingInput,
    @Default([]) List<String> childSessionIds,
    @Default(false) bool isRetrying,
    // COMPATIBILITY 2026-08-13 (v1.8.0): Bridges before v1.8.0 omit active-root
    // ordering facts, which decode to null. Make both non-null once those
    // bridges are unsupported.
    required int? lastUserActivityAt,
    required int? updatedAt,
  }) = _ActiveSession;

  factory fromJson(Map<String, dynamic> json) => _$ActiveSessionFromJson(json);
}
