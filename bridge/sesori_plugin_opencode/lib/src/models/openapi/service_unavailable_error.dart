// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.957808Z

import 'package:meta/meta.dart';

@immutable
class ServiceUnavailableError {
  const ServiceUnavailableError({
    required this.tag,
    required this.message,
    this.service,
  });

  factory ServiceUnavailableError.fromJson(Map<String, dynamic> json) {
    return ServiceUnavailableError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      service: json["service"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "service": ?service,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ServiceUnavailableError &&
          other.tag == tag &&
          other.message == message &&
          other.service == service);

  @override
  int get hashCode => Object.hash(tag, message, service);

  final String tag;
  final String message;
  final String? service;
}
