// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T13:43:24.183888Z


class ProviderV2Info {
  const ProviderV2Info({
    required this.id,
    required this.name,
    required this.enabled,
    required this.env,
    required this.api,
    required this.request,
  });

  factory ProviderV2Info.fromJson(Map<String, dynamic> json) {
    return ProviderV2Info(
      id: json["id"] as String,
      name: json["name"] as String,
      enabled: json["enabled"] as Object,
      env: (json["env"] as List<dynamic>).cast<String>(),
      api: json["api"] as Object,
      request: json["request"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "enabled": enabled,
      "env": env,
      "api": api,
      "request": request,
    };
  }

  final String id;
  final String name;
  final Object enabled;
  final List<String> env;
  final Object api;
  final Map<String, dynamic> request;
}
