// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';
import 'provider_compaction.g.dart';
import 'provider_encoding.g.dart';

@immutable
class ModelSettings {
  const ModelSettings({
    required this.compaction,
    required this.encoding,
  });

  factory ModelSettings.fromJson(Map<String, dynamic> json) {
    return ModelSettings(
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
  ModelSettings copyWith({
    ProviderCompaction? compaction,
    ProviderEncoding? encoding,
  }) {
    return ModelSettings(
      compaction: compaction ?? this.compaction,
      encoding: encoding ?? this.encoding,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelSettings &&
          other.compaction == compaction &&
          other.encoding == encoding);

  @override
  int get hashCode => Object.hash(compaction, encoding);

  final ProviderCompaction? compaction;
  final ProviderEncoding? encoding;
}
