// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:32:28.077990Z


class HttpApiErrorForbidden {
  const HttpApiErrorForbidden({
    required this.tag,
  });

  factory HttpApiErrorForbidden.fromJson(Map<String, dynamic> json) {
    return HttpApiErrorForbidden(
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
