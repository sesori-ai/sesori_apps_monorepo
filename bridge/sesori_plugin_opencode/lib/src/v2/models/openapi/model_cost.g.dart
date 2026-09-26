// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class ModelCost {
  const ModelCost({
    required this.tier,
    required this.input,
    required this.output,
    required this.cache,
  });

  factory ModelCost.fromJson(Map<String, dynamic> json) {
    return ModelCost(
      tier: json["tier"] == null ? null : ModelCostTier.fromJson(json["tier"] as Map<String, dynamic>),
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      cache: ModelCostCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "tier": ?tier?.toJson(),
      "input": input,
      "output": output,
      "cache": cache.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCost copyWith({
    ModelCostTier? tier,
    double? input,
    double? output,
    ModelCostCache? cache,
  }) {
    return ModelCost(
      tier: tier ?? this.tier,
      input: input ?? this.input,
      output: output ?? this.output,
      cache: cache ?? this.cache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCost &&
          other.tier == tier &&
          other.input == input &&
          other.output == output &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(tier, input, output, cache);

  final ModelCostTier? tier;
  final double input;
  final double output;
  final ModelCostCache cache;
}

@immutable
class ModelCostTier {
  const ModelCostTier({
    required this.type,
    required this.size,
  });

  factory ModelCostTier.fromJson(Map<String, dynamic> json) {
    return ModelCostTier(
      type: json["type"] as String,
      size: (json["size"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "size": size,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostTier copyWith({
    String? type,
    int? size,
  }) {
    return ModelCostTier(
      type: type ?? this.type,
      size: size ?? this.size,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostTier &&
          other.type == type &&
          other.size == size);

  @override
  int get hashCode => Object.hash(type, size);

  final String type;
  final int size;
}

@immutable
class ModelCostCache {
  const ModelCostCache({
    required this.read,
    required this.write,
  });

  factory ModelCostCache.fromJson(Map<String, dynamic> json) {
    return ModelCostCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelCostCache copyWith({
    double? read,
    double? write,
  }) {
    return ModelCostCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelCostCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
