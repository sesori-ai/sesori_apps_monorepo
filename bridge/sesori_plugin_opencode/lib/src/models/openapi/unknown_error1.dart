// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.260988Z

import 'package:meta/meta.dart';

@immutable
class UnknownError1 {
  const UnknownError1({
    required this.tag,
    required this.message,
    this.ref,
  });

  factory UnknownError1.fromJson(Map<String, dynamic> json) {
    return UnknownError1(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      ref: json["ref"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "ref": ?ref,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnknownError1 &&
          other.tag == tag &&
          other.message == message &&
          other.ref == ref);

  @override
  int get hashCode => Object.hash(tag, message, ref);

  final String tag;
  final String message;
  final String? ref;
}
