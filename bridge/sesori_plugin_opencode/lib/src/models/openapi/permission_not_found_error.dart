// GENERATED FILE - DO NOT EDIT BY HAND


class PermissionNotFoundError {
  const PermissionNotFoundError({
    required this.tag,
    required this.requestID,
    required this.message,
  });

  factory PermissionNotFoundError.fromJson(Map<String, dynamic> json) {
    return PermissionNotFoundError(
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
