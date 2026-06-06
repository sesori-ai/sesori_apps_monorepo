// GENERATED FILE - DO NOT EDIT BY HAND


class QuestionRejected {
  const QuestionRejected({
    required this.sessionID,
    required this.requestID,
  });

  factory QuestionRejected.fromJson(Map<String, dynamic> json) {
    return QuestionRejected(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "sessionID": sessionID,
      "requestID": requestID,
    };
  }

  final String sessionID;
  final String requestID;
}
