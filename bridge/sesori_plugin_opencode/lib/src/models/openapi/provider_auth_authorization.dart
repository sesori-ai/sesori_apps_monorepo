// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.183065Z


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

  final String url;
  final String method;
  final String instructions;
}
