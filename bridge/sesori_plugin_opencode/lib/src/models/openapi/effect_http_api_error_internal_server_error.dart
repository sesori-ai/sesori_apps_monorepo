// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HttpApiErrorInternalServerError &&
          other.tag == tag);

  @override
  int get hashCode => tag.hashCode;

  final String tag;
}
