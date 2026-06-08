// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.347911Z


class ProviderConfig {
  const ProviderConfig({
    this.api,
    this.name,
    this.env,
    this.id,
    this.npm,
    this.whitelist,
    this.blacklist,
    this.options,
    this.models,
  });

  factory ProviderConfig.fromJson(Map<String, dynamic> json) {
    return ProviderConfig(
      api: json["api"] as String?,
      name: json["name"] as String?,
      env: (json["env"] as List<dynamic>?)?.cast<String>(),
      id: json["id"] as String?,
      npm: json["npm"] as String?,
      whitelist: (json["whitelist"] as List<dynamic>?)?.cast<String>(),
      blacklist: (json["blacklist"] as List<dynamic>?)?.cast<String>(),
      options: (json["options"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Object)),
      models: (json["models"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "api": ?api,
      "name": ?name,
      "env": ?env,
      "id": ?id,
      "npm": ?npm,
      "whitelist": ?whitelist,
      "blacklist": ?blacklist,
      "options": ?options,
      "models": ?models,
    };
  }

  final String? api;
  final String? name;
  final List<String>? env;
  final String? id;
  final String? npm;
  final List<String>? whitelist;
  final List<String>? blacklist;
  final Map<String, Object>? options;
  final Map<String, Map<String, dynamic>>? models;
}
