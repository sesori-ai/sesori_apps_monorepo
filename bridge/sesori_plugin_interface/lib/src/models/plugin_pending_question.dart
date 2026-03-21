import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_pending_question.freezed.dart";

part "plugin_pending_question.g.dart";

@freezed
sealed class PluginQuestionOption with _$PluginQuestionOption {
  const factory PluginQuestionOption({
    required String label,
    required String description,
  }) = _PluginQuestionOption;
}

@freezed
sealed class PluginQuestionInfo with _$PluginQuestionInfo {
  const factory PluginQuestionInfo({
    required String question,
    required String header,
    required List<PluginQuestionOption> options,
    required bool multiple,
    required bool custom,
  }) = _PluginQuestionInfo;
}

@freezed
sealed class PluginPendingQuestion with _$PluginPendingQuestion {
  const factory PluginPendingQuestion({
    required String id,
    required String sessionID,
    required List<PluginQuestionInfo> questions,
  }) = _PluginPendingQuestion;
}
