// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.2.7 (fedc6f208aa2bd54c1019227214568083f6380ad)

import 'package:meta/meta.dart';
import 'provider_compaction.g.dart';
import 'provider_encoding.g.dart';

@immutable
class ModelVariantSettings {
  const ModelVariantSettings({
    required this.compaction,
    required this.encoding,
  });

  factory ModelVariantSettings.fromJson(Map<String, dynamic> json) {
    return ModelVariantSettings(
      compaction: json["compaction"] == null ? null : ProviderCompaction.fromJson(json["compaction"] as Object),
      encoding: json["encoding"] == null ? null : ProviderEncoding.fromJson(json["encoding"] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "compaction": ?compaction?.toJson(),
      "encoding": ?encoding?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelVariantSettings copyWith({
    ProviderCompaction? compaction,
    ProviderEncoding? encoding,
  }) {
    return ModelVariantSettings(
      compaction: compaction ?? this.compaction,
      encoding: encoding ?? this.encoding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelVariantSettings &&
          other.compaction == compaction &&
          other.encoding == encoding);

  @override
  int get hashCode => Object.hash(compaction, encoding);

  final ProviderCompaction? compaction;
  final ProviderEncoding? encoding;
}
