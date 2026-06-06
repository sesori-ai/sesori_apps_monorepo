// GENERATED FILE - DO NOT EDIT BY HAND


class InvalidRequestError {
  const InvalidRequestError({
    required this.tag,
    required this.message,
    this.kind,
    this.field,
  });

  factory InvalidRequestError.fromJson(Map<String, dynamic> json) {
    return InvalidRequestError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      kind: json["kind"] as String?,
      field: json["field"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "kind": kind,
      "field": field,
    };
  }

  final String tag;
  final String message;
  final String? kind;
  final String? field;
}
