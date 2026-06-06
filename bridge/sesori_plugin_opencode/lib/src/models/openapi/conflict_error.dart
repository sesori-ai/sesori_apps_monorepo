// GENERATED FILE - DO NOT EDIT BY HAND


class ConflictError {
  const ConflictError({
    required this.tag,
    required this.message,
    this.resource,
  });

  factory ConflictError.fromJson(Map<String, dynamic> json) {
    return ConflictError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      resource: json["resource"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "resource": resource,
    };
  }

  final String tag;
  final String message;
  final String? resource;
}
