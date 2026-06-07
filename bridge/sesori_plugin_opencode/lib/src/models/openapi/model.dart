// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-07T10:22:51.663401Z


class Model {
  const Model({
    required this.id,
    required this.providerID,
    required this.api,
    required this.name,
    this.family,
    required this.capabilities,
    required this.cost,
    required this.limit,
    required this.status,
    required this.options,
    required this.headers,
    required this.releaseDate,
    this.variants,
  });

  factory Model.fromJson(Map<String, dynamic> json) {
    return Model(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      api: json["api"] as Map<String, dynamic>,
      name: json["name"] as String,
      family: json["family"] as String?,
      capabilities: json["capabilities"] as Map<String, dynamic>,
      cost: json["cost"] as Map<String, dynamic>,
      limit: json["limit"] as Map<String, dynamic>,
      status: json["status"] as String,
      options: json["options"] as Map<String, dynamic>,
      headers: (json["headers"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      releaseDate: json["release_date"] as String,
      variants: (json["variants"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as Map<String, dynamic>)),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "api": api,
      "name": name,
      "family": family,
      "capabilities": capabilities,
      "cost": cost,
      "limit": limit,
      "status": status,
      "options": options,
      "headers": headers,
      "release_date": releaseDate,
      "variants": variants,
    };
  }

  final String id;
  final String providerID;
  final Map<String, dynamic> api;
  final String name;
  final String? family;
  final Map<String, dynamic> capabilities;
  final Map<String, dynamic> cost;
  final Map<String, dynamic> limit;
  final String status;
  final Map<String, dynamic> options;
  final Map<String, String> headers;
  final String releaseDate;
  final Map<String, Map<String, dynamic>>? variants;
}
