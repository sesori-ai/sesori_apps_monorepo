// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.913669Z


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
