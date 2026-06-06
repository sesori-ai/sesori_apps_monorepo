// GENERATED FILE - DO NOT EDIT BY HAND


class QuestionV2Tool {
  const QuestionV2Tool({
    required this.messageID,
    required this.callID,
  });

  factory QuestionV2Tool.fromJson(Map<String, dynamic> json) {
    return QuestionV2Tool(
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
