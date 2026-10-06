// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'provider_compaction.g.dart';
import 'provider_transport.g.dart';

@immutable
class ProviderSettings {
  const ProviderSettings({
    required this.timeout,
    required this.headerTimeout,
    required this.chunkTimeout,
    required this.compaction,
    required this.transport,
  });

  factory ProviderSettings.fromJson(Map<String, dynamic> json) {
    return ProviderSettings(
      timeout: json["timeout"] as Object?,
      headerTimeout: json["headerTimeout"] as Object?,
      chunkTimeout: json["chunkTimeout"] as Object?,
      compaction: json["compaction"] == null ? null : ProviderCompaction.fromJson(json["compaction"] as Object),
      transport: json["transport"] == null ? null : ProviderTransport.fromJson(json["transport"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timeout": ?timeout,
      "headerTimeout": ?headerTimeout,
      "chunkTimeout": ?chunkTimeout,
      "compaction": ?compaction?.toJson(),
      "transport": ?transport?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderSettings copyWith({
    Object? timeout,
    Object? headerTimeout,
    Object? chunkTimeout,
    ProviderCompaction? compaction,
    ProviderTransport? transport,
  }) {
    return ProviderSettings(
      timeout: timeout ?? this.timeout,
      headerTimeout: headerTimeout ?? this.headerTimeout,
      chunkTimeout: chunkTimeout ?? this.chunkTimeout,
      compaction: compaction ?? this.compaction,
      transport: transport ?? this.transport,
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
          other.transport == transport);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(timeout), const DeepCollectionEquality().hash(headerTimeout), const DeepCollectionEquality().hash(chunkTimeout), compaction, transport);

  final Object? timeout;
  final Object? headerTimeout;
  final Object? chunkTimeout;
  final ProviderCompaction? compaction;
  final ProviderTransport? transport;
}
