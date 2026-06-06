// GENERATED FILE - DO NOT EDIT BY HAND


class QuestionNotFoundError {
  const QuestionNotFoundError({
    required this.tag,
    required this.requestID,
    required this.message,
  });

  factory QuestionNotFoundError.fromJson(Map<String, dynamic> json) {
    return QuestionNotFoundError(
      tag: json["_tag"] as String,
      requestID: json["requestID"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "requestID": requestID,
      "message": message,
    };
  }

  final String tag;
  final String requestID;
  final String message;
}
