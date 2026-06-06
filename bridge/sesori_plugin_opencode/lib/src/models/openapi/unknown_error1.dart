// GENERATED FILE - DO NOT EDIT BY HAND


class UnknownError1 {
  const UnknownError1({
    required this.tag,
    required this.message,
    this.ref,
  });

  factory UnknownError1.fromJson(Map<String, dynamic> json) {
    return UnknownError1(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      ref: json["ref"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "ref": ref,
    };
  }

  final String tag;
  final String message;
  final String? ref;
}
