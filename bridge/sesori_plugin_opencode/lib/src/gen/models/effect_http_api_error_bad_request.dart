// GENERATED FILE - DO NOT EDIT BY HAND


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
