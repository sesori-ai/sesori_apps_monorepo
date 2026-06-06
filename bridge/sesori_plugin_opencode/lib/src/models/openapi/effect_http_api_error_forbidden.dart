// GENERATED FILE - DO NOT EDIT BY HAND


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
