// GENERATED FILE - DO NOT EDIT BY HAND


class HttpApiErrorInternalServerError {
  const HttpApiErrorInternalServerError({
    required this.tag,
  });

  factory HttpApiErrorInternalServerError.fromJson(Map<String, dynamic> json) {
    return HttpApiErrorInternalServerError(
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
