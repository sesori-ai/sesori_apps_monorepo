// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'provider.g.dart';

@immutable
class ConfigProvidersResponse {
  const ConfigProvidersResponse({
    this.providers = const [],
    this.defaultValue = const {},
  });

  factory ConfigProvidersResponse.fromJson(Map<String, dynamic> json) {
    return ConfigProvidersResponse(
      providers: ((json["providers"] ?? const []) as List<dynamic>).map((e) => Provider.fromJson(e as Map<String, dynamic>)).toList(),
      defaultValue: ((json["default"] ?? const <String, dynamic>{}) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "providers": providers.map((e) => e.toJson()).toList(),
      "default": defaultValue,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ConfigProvidersResponse copyWith({
    List<Provider>? providers,
    Map<String, String>? defaultValue,
  }) {
    return ConfigProvidersResponse(
      providers: providers ?? this.providers,
      defaultValue: defaultValue ?? this.defaultValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigProvidersResponse &&
          const DeepCollectionEquality().equals(other.providers, providers) &&
          const DeepCollectionEquality().equals(other.defaultValue, defaultValue));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(providers), const DeepCollectionEquality().hash(defaultValue));

  final List<Provider> providers;
  final Map<String, String> defaultValue;
}
