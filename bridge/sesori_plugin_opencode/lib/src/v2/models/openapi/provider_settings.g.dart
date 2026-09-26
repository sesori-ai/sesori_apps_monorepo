// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'provider_compaction.g.dart';
import 'provider_transport.g.dart';

@immutable
class ProviderSettings {
  const ProviderSettings({
    required this.timeout,
    required this.chunkTimeout,
    required this.compaction,
    required this.transport,
  });

  factory ProviderSettings.fromJson(Map<String, dynamic> json) {
    return ProviderSettings(
      timeout: json["timeout"] as Object?,
      chunkTimeout: (json["chunkTimeout"] as num?)?.toDouble(),
      compaction: json["compaction"] == null ? null : ProviderCompaction.fromJson(json["compaction"] as Object),
      transport: json["transport"] == null ? null : ProviderTransport.fromJson(json["transport"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timeout": ?timeout,
      "chunkTimeout": ?chunkTimeout,
      "compaction": ?compaction?.toJson(),
      "transport": ?transport?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProviderSettings copyWith({
    Object? timeout,
    double? chunkTimeout,
    ProviderCompaction? compaction,
    ProviderTransport? transport,
  }) {
    return ProviderSettings(
      timeout: timeout ?? this.timeout,
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
          other.chunkTimeout == chunkTimeout &&
          other.compaction == compaction &&
          other.transport == transport);

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(timeout), chunkTimeout, compaction, transport);

  final Object? timeout;
  final double? chunkTimeout;
  final ProviderCompaction? compaction;
  final ProviderTransport? transport;
}
