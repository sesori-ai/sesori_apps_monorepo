// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.984719Z

import 'package:meta/meta.dart';

@immutable
class ProviderNotFoundError {
  const ProviderNotFoundError({
    required this.tag,
    required this.providerID,
    required this.message,
  });

  factory ProviderNotFoundError.fromJson(Map<String, dynamic> json) {
    return ProviderNotFoundError(
      tag: json["_tag"] as String,
      providerID: json["providerID"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "providerID": providerID,
      "message": message,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderNotFoundError &&
          other.tag == tag &&
          other.providerID == providerID &&
          other.message == message);

  @override
  int get hashCode => Object.hash(tag, providerID, message);

  final String tag;
  final String providerID;
  final String message;
}
