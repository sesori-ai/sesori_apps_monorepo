// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.341465Z


class ModelV2Info1 {
  const ModelV2Info1({
    required this.id,
    required this.providerID,
    this.family,
    required this.name,
    required this.api,
    required this.capabilities,
    required this.request,
    required this.variants,
    required this.time,
    required this.cost,
    required this.status,
    required this.enabled,
    required this.limit,
  });

  factory ModelV2Info1.fromJson(Map<String, dynamic> json) {
    return ModelV2Info1(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      family: json["family"] as String?,
      name: json["name"] as String,
      api: json["api"] as Object,
      capabilities: json["capabilities"] as Map<String, dynamic>,
      request: json["request"] as Map<String, dynamic>,
      variants: (json["variants"] as List<dynamic>).cast<Map<String, dynamic>>(),
      time: json["time"] as Map<String, dynamic>,
      cost: (json["cost"] as List<dynamic>).cast<Map<String, dynamic>>(),
      status: json["status"] as String,
      enabled: json["enabled"] as bool,
      limit: json["limit"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "family": ?family,
      "name": name,
      "api": api,
      "capabilities": capabilities,
      "request": request,
      "variants": variants,
      "time": time,
      "cost": cost,
      "status": status,
      "enabled": enabled,
      "limit": limit,
    };
  }

  final String id;
  final String providerID;
  final String? family;
  final String name;
  final Object api;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> variants;
  final Map<String, dynamic> time;
  final List<Map<String, dynamic>> cost;
  final String status;
  final bool enabled;
  final Map<String, dynamic> limit;
}
