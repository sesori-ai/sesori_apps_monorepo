// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.208707Z


class HttpApiErrorBadRequest {
  const HttpApiErrorBadRequest({
    required this.tag,
  });

  factory HttpApiErrorBadRequest.fromJson(Map<String, dynamic> json) {
    return HttpApiErrorBadRequest(
      tag: json["_tag"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
    };
  }

  final String tag;
}
