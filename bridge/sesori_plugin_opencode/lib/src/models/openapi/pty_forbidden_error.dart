// GENERATED FILE - DO NOT EDIT BY HAND


class PtyForbiddenError {
  const PtyForbiddenError({
    required this.tag,
    required this.message,
  });

  factory PtyForbiddenError.fromJson(Map<String, dynamic> json) {
    return PtyForbiddenError(
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
