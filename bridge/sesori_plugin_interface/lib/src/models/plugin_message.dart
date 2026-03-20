import "package:freezed_annotation/freezed_annotation.dart";

part "plugin_message.freezed.dart";

part "plugin_message.g.dart";

@freezed
sealed class PluginMessageWithParts with _$PluginMessageWithParts {
  const factory PluginMessageWithParts({
    required PluginMessage info,
    required List<PluginMessagePart> parts,
  }) = _PluginMessageWithParts;
}

@freezed
sealed class PluginMessagePart with _$PluginMessagePart {
  const factory PluginMessagePart({
    required String id,
    required String sessionID,
    required String messageID,
    required String type,
    // text / reasoning
    required String? text,
    // tool
    required String? tool,
    required String? callID,
    required PluginToolState? state,
    // file
    required String? mime,
    required String? url,
    required String? filename,
    // step-finish
    required double? cost,
    required String? reason,
    // subtask
    required String? prompt,
    required String? description,
    required String? agent,
    // snapshot / step-start
    required String? snapshot,
    // time (for text, reasoning, tool)
    required PluginPartTime? time,
  }) = _PluginMessagePart;
}

@freezed
sealed class PluginToolState with _$PluginToolState {
  const factory PluginToolState({
    required String status,
    required String? title,
    required String? output,
    required String? error,
  }) = _PluginToolState;
}

@freezed
sealed class PluginPartTime with _$PluginPartTime {
  const factory PluginPartTime({
    required int? start,
    required int? end,
  }) = _PluginPartTime;
}

@freezed
sealed class PluginMessage with _$PluginMessage {
  const factory PluginMessage({
    required String role,
    required String id,
    required String sessionID,
    required String? parentID,
    required String? agent,
    required String? modelID,
    required String? providerID,
    required double? cost,
    required PluginMessageTime? time,
    required String? finish,
  }) = _PluginMessage;
}

@freezed
sealed class PluginMessageTime with _$PluginMessageTime {
  const factory PluginMessageTime({
    required int created,
    required int? completed,
  }) = _PluginMessageTime;
}
