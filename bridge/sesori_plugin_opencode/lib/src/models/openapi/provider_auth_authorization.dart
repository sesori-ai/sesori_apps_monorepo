// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.983990Z

import 'package:meta/meta.dart';

@immutable
class ProviderAuthAuthorization {
  const ProviderAuthAuthorization({
    required this.url,
    required this.method,
    required this.instructions,
  });

  factory ProviderAuthAuthorization.fromJson(Map<String, dynamic> json) {
    return ProviderAuthAuthorization(
      url: json["url"] as String,
      method: json["method"] as String,
      instructions: json["instructions"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": url,
      "method": method,
      "instructions": instructions,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderAuthAuthorization &&
          other.url == url &&
          other.method == method &&
          other.instructions == instructions);

  @override
  int get hashCode => Object.hash(url, method, instructions);

  final String url;
  final String method;
  final String instructions;
}
