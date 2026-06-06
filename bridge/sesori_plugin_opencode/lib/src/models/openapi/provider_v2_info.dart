// GENERATED FILE - DO NOT EDIT BY HAND


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
      enabled: json["enabled"],
      env: (json["env"] as List<dynamic>).cast<String>(),
      api: json["api"],
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
  final dynamic enabled;
  final List<String> env;
  final dynamic api;
  final Map<String, dynamic> request;
}
