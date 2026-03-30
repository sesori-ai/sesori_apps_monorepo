import 'package:freezed_annotation/freezed_annotation.dart';

part 'plugin_session_metadata.freezed.dart';

part 'plugin_session_metadata.g.dart';

@freezed
sealed class SessionMetadata with _$SessionMetadata {
  const factory SessionMetadata({
    required String title,
    required String branchName,
  }) = _SessionMetadata;
}
