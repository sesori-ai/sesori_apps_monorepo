// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

import 'package:json_annotation/json_annotation.dart';

enum ModelCacheFormat {
  @JsonValue("anthropic")
  anthropic,
  @JsonValue("alibaba")
  alibaba,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ModelCacheFormat fromJson(String value) {
    switch (value) {
      case "anthropic":
        return ModelCacheFormat.anthropic;
      case "alibaba":
        return ModelCacheFormat.alibaba;
      default:
        return ModelCacheFormat.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ModelCacheFormat.anthropic:
        return "anthropic";
      case ModelCacheFormat.alibaba:
        return "alibaba";
      case ModelCacheFormat.unknown:
        return 'unknown';
    }
  }
}
