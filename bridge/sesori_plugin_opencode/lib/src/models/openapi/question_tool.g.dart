// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';

@immutable
class QuestionTool {
  const QuestionTool({
    required this.messageID,
    required this.callID,
  });

  factory QuestionTool.fromJson(Map<String, dynamic> json) {
    return QuestionTool(
      messageID: json["messageID"] as String,
      callID: json["callID"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "messageID": messageID,
      "callID": callID,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  QuestionTool copyWith({
    String? messageID,
    String? callID,
  }) {
    return QuestionTool(
      messageID: messageID ?? this.messageID,
      callID: callID ?? this.callID,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuestionTool &&
          other.messageID == messageID &&
          other.callID == callID);

  @override
  int get hashCode => Object.hash(messageID, callID);

  final String messageID;
  final String callID;
}
