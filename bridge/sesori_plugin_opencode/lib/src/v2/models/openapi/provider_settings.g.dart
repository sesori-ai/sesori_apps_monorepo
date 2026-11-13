// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'provider_cache.g.dart';
import 'provider_compaction.g.dart';
import 'provider_encoding.g.dart';
import 'provider_transport.g.dart';

@immutable
class ProviderSettings {
  const ProviderSettings({
    required this.timeout,
    required this.headerTimeout,
    required this.chunkTimeout,
    required this.compaction,
    required this.cache,
    required this.transport,
    required this.encoding,
  });

  factory ProviderSettings.fromJson(Map<String, dynamic> json) {
    return ProviderSettings(
      timeout: json["timeout"] as Object?,
      headerTimeout: json["headerTimeout"] as Object?,
      chunkTimeout: json["chunkTimeout"] as Object?,
      compaction: json["compaction"] == null ? null : ProviderCompaction.fromJson(json["compaction"] as Object),
      cache: json["cache"] == null ? null : ProviderCache.fromJson(json["cache"] as Map<String, dynamic>),
      transport: json["transport"] == null ? null : ProviderTransport.fromJson(json["transport"] as String),
      encoding: json["encoding"] == null ? null : ProviderEncoding.fromJson(json["encoding"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timeout": ?timeout,
      "headerTimeout": ?headerTimeout,
      "chunkTimeout": ?chunkTimeout,
      "compaction": ?compaction?.toJson(),
      "cache": ?cache?.toJson(),
      "transport": ?transport?.toJson(),
      "encoding": ?encoding?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderSettings copyWith({
    Object? timeout,
    Object? headerTimeout,
    Object? chunkTimeout,
    ProviderCompaction? compaction,
    ProviderCache? cache,
    ProviderTransport? transport,
    ProviderEncoding? encoding,
  }) {
    return ProviderSettings(
      timeout: timeout ?? this.timeout,
      headerTimeout: headerTimeout ?? this.headerTimeout,
      chunkTimeout: chunkTimeout ?? this.chunkTimeout,
      compaction: compaction ?? this.compaction,
      cache: cache ?? this.cache,
      transport: transport ?? this.transport,
      encoding: encoding ?? this.encoding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderSettings &&
          const DeepCollectionEquality().equals(other.timeout, timeout) &&
          const DeepCollectionEquality().equals(other.headerTimeout, headerTimeout) &&
          const DeepCollectionEquality().equals(other.chunkTimeout, chunkTimeout) &&
          other.compaction == compaction &&
          other.cache == cache &&
          other.transport == transport &&
          other.encoding == encoding);

  @override
  int get hashCode => Object.hash(
    const DeepCollectionEquality().hash(timeout),
    const DeepCollectionEquality().hash(headerTimeout),
    const DeepCollectionEquality().hash(chunkTimeout),
    compaction,
    cache,
    transport,
    encoding,
  );

  final Object? timeout;
  final Object? headerTimeout;
  final Object? chunkTimeout;
  final ProviderCompaction? compaction;
  final ProviderCache? cache;
  final ProviderTransport? transport;
  final ProviderEncoding? encoding;
}
