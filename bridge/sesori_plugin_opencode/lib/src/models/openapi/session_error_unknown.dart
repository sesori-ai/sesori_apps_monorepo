// GENERATED FILE - DO NOT EDIT BY HAND


class SessionErrorUnknown {
  const SessionErrorUnknown({
    required this.type,
    required this.message,
  });

  factory SessionErrorUnknown.fromJson(Map<String, dynamic> json) {
    return SessionErrorUnknown(
      type: json["type"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "message": message,
    };
  }

  final String type;
  final String message;
}
