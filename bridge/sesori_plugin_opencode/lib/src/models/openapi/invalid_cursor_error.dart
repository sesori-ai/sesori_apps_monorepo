// GENERATED FILE - DO NOT EDIT BY HAND


class InvalidCursorError {
  const InvalidCursorError({
    required this.tag,
    required this.message,
  });

  factory InvalidCursorError.fromJson(Map<String, dynamic> json) {
    return InvalidCursorError(
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
