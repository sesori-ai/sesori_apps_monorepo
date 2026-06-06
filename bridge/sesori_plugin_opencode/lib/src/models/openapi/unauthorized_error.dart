// GENERATED FILE - DO NOT EDIT BY HAND


class UnauthorizedError {
  const UnauthorizedError({
    required this.tag,
    required this.message,
  });

  factory UnauthorizedError.fromJson(Map<String, dynamic> json) {
    return UnauthorizedError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
    };
  }

  final String tag;
  final String message;
}
