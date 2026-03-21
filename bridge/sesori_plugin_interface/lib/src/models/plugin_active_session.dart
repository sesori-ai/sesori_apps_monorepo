import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_active_session.freezed.dart";
part "plugin_active_session.g.dart";

/// Plugin-side equivalent of [ActiveSession] from `sesori_shared`.
///
/// Represents a root session that is currently active, along with the IDs of
/// its direct child sessions that are also active (busy or retrying).
@freezed
sealed class PluginActiveSession with _$PluginActiveSession {
  const factory PluginActiveSession({
    required String id,
    @Default(false) bool mainAgentRunning,
    @Default([]) List<String> childSessionIds,
  }) = _PluginActiveSession;
}
