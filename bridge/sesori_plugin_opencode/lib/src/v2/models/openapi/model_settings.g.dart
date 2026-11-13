// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';

import 'provider_cache.g.dart';
import 'provider_compaction.g.dart';
import 'provider_encoding.g.dart';

@immutable
class ModelSettings {
  const ModelSettings({
    required this.compaction,
    required this.cache,
    required this.encoding,
  });

  factory ModelSettings.fromJson(Map<String, dynamic> json) {
    return ModelSettings(
      compaction: json["compaction"] == null ? null : ProviderCompaction.fromJson(json["compaction"] as Object),
      cache: json["cache"] == null ? null : ProviderCache.fromJson(json["cache"] as Map<String, dynamic>),
      encoding: json["encoding"] == null ? null : ProviderEncoding.fromJson(json["encoding"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "compaction": ?compaction?.toJson(),
      "cache": ?cache?.toJson(),
      "encoding": ?encoding?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelSettings copyWith({
    ProviderCompaction? compaction,
    ProviderCache? cache,
    ProviderEncoding? encoding,
  }) {
    return ModelSettings(
      compaction: compaction ?? this.compaction,
      cache: cache ?? this.cache,
      encoding: encoding ?? this.encoding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelSettings && other.compaction == compaction && other.cache == cache && other.encoding == encoding);

  @override
  int get hashCode => Object.hash(compaction, cache, encoding);

  final ProviderCompaction? compaction;
  final ProviderCache? cache;
  final ProviderEncoding? encoding;
}
