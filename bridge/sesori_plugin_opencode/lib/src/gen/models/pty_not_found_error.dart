// GENERATED FILE - DO NOT EDIT BY HAND


class PtyNotFoundError {
  const PtyNotFoundError({
    required this.tag,
    required this.ptyID,
    required this.message,
  });

  factory PtyNotFoundError.fromJson(Map<String, dynamic> json) {
    return PtyNotFoundError(
      tag: json["_tag"] as String,
      ptyID: json["ptyID"] as String,
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "ptyID": ptyID,
      "message": message,
    };
  }

  final String tag;
  final String ptyID;
  final String message;
}
