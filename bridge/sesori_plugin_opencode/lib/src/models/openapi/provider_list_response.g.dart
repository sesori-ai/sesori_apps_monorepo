// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'provider.g.dart';

@immutable
class ProviderListResponse {
  const ProviderListResponse({
    required this.all,
    required this.defaultValue,
    required this.connected,
  });

  factory ProviderListResponse.fromJson(Map<String, dynamic> json) {
    return ProviderListResponse(
      all: (json["all"] as List<dynamic>).map((e) => Provider.fromJson(e as Map<String, dynamic>)).toList(),
      defaultValue: (json["default"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      connected: (json["connected"] as List<dynamic>).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "all": all.map((e) => e.toJson()).toList(),
      "default": defaultValue,
      "connected": connected,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderListResponse copyWith({
    List<Provider>? all,
    Map<String, String>? defaultValue,
    List<String>? connected,
  }) {
    return ProviderListResponse(
      all: all ?? this.all,
      defaultValue: defaultValue ?? this.defaultValue,
      connected: connected ?? this.connected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderListResponse &&
          const DeepCollectionEquality().equals(other.all, all) &&
          const DeepCollectionEquality().equals(other.defaultValue, defaultValue) &&
          const DeepCollectionEquality().equals(other.connected, connected));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(all), const DeepCollectionEquality().hash(defaultValue), const DeepCollectionEquality().hash(connected));

  final List<Provider> all;
  final Map<String, String> defaultValue;
  final List<String> connected;
}
