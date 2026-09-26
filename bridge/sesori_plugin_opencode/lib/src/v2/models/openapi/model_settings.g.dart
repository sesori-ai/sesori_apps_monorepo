// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';
import 'provider_compaction.g.dart';

@immutable
class ModelSettings {
  const ModelSettings({
    required this.compaction,
  });

  factory ModelSettings.fromJson(Map<String, dynamic> json) {
    return ModelSettings(
      compaction: json["compaction"] == null ? null : ProviderCompaction.fromJson(json["compaction"] as Object),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "compaction": ?compaction?.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelSettings copyWith({
    ProviderCompaction? compaction,
  }) {
    return ModelSettings(
      compaction: compaction ?? this.compaction,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelSettings &&
          other.compaction == compaction);

  @override
  int get hashCode => compaction.hashCode;

  final ProviderCompaction? compaction;
}
