// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.185425Z


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

  final String messageID;
  final String callID;
}
