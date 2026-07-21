import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin_session.freezed.dart';

part 'plugin_session.g.dart';

@freezed
sealed class PluginSession with _$PluginSession {
  const factory PluginSession({
    required String? branchName,
    required String id,
    required String projectID,
    required String directory,
    required String? parentID,
    required String? title,
    required PluginSessionTime? time,
  }) = _PluginSession;
}

@freezed
sealed class PluginSessionTime with _$PluginSessionTime {
  const factory PluginSessionTime({
    required int created,
    required int updated,
    required int? archived,
  }) = _PluginSessionTime;
}
