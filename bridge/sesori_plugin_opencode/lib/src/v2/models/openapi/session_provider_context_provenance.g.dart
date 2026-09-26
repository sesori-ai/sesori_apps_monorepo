// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class SessionProviderContextProvenance {
  const SessionProviderContextProvenance({
    required this.providerID,
    required this.provider,
    required this.modelID,
    required this.route,
    required this.protocol,
    required this.endpoint,
  });

  factory SessionProviderContextProvenance.fromJson(Map<String, dynamic> json) {
    return SessionProviderContextProvenance(
      providerID: json["providerID"] as String,
      provider: json["provider"] as String,
      modelID: json["modelID"] as String,
      route: json["route"] as String,
      protocol: json["protocol"] as String,
      endpoint: json["endpoint"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providerID": providerID,
      "provider": provider,
      "modelID": modelID,
      "route": route,
      "protocol": protocol,
      "endpoint": endpoint,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionProviderContextProvenance copyWith({
    String? providerID,
    String? provider,
    String? modelID,
    String? route,
    String? protocol,
    String? endpoint,
  }) {
    return SessionProviderContextProvenance(
      providerID: providerID ?? this.providerID,
      provider: provider ?? this.provider,
      modelID: modelID ?? this.modelID,
      route: route ?? this.route,
      protocol: protocol ?? this.protocol,
      endpoint: endpoint ?? this.endpoint,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionProviderContextProvenance &&
          other.providerID == providerID &&
          other.provider == provider &&
          other.modelID == modelID &&
          other.route == route &&
          other.protocol == protocol &&
          other.endpoint == endpoint);

  @override
  int get hashCode => Object.hash(providerID, provider, modelID, route, protocol, endpoint);

  final String providerID;
  final String provider;
  final String modelID;
  final String route;
  final String protocol;
  final String endpoint;
}
