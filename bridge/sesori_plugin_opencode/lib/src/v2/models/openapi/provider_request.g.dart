// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'provider_settings.g.dart';

@immutable
class ProviderRequest {
  const ProviderRequest({
    required this.settings,
    required this.headers,
    required this.body,
  });

  factory ProviderRequest.fromJson(Map<String, dynamic> json) {
    return ProviderRequest(
      settings: ProviderSettings.fromJson(json["settings"] as Map<String, dynamic>),
      headers: (json["headers"] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      body: json["body"] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "settings": settings.toJson(),
      "headers": headers,
      "body": body,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderRequest copyWith({
    ProviderSettings? settings,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
  }) {
    return ProviderRequest(
      settings: settings ?? this.settings,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderRequest &&
          other.settings == settings &&
          const DeepCollectionEquality().equals(other.headers, headers) &&
          const DeepCollectionEquality().equals(other.body, body));

  @override
  int get hashCode => Object.hash(settings, const DeepCollectionEquality().hash(headers), const DeepCollectionEquality().hash(body));

  final ProviderSettings settings;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
}
