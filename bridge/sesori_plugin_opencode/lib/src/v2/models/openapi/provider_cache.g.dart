// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.0 (a6b15d33daf6ab7d35569f6d711fdb630b9f04e7)

import 'package:meta/meta.dart';
import 'provider_cache_warming.g.dart';

@immutable
class ProviderCache {
  const ProviderCache({
    required this.ttl,
    required this.warming,
  });

  factory ProviderCache.fromJson(Map<String, dynamic> json) {
    return ProviderCache(
      ttl: json["ttl"] as String?,
      warming: json["warming"] == null ? null : ProviderCacheWarming.fromJson(json["warming"] as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "ttl": ?ttl,
      "warming": ?warming?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderCache copyWith({
    String? ttl,
    ProviderCacheWarming? warming,
  }) {
    return ProviderCache(
      ttl: ttl ?? this.ttl,
      warming: warming ?? this.warming,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderCache &&
          other.ttl == ttl &&
          other.warming == warming);

  @override
  int get hashCode => Object.hash(ttl, warming);

  final String? ttl;
  final ProviderCacheWarming? warming;
}
