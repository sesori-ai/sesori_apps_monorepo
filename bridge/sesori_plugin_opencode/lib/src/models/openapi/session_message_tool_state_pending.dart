// GENERATED FILE - DO NOT EDIT BY HAND


class SessionMessageToolStatePending {
  const SessionMessageToolStatePending({
    required this.status,
    required this.input,
  });

  factory SessionMessageToolStatePending.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStatePending(
      status: json["status"] as String,
      input: json["input"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
    };
  }

  final String status;
  final String input;
}
