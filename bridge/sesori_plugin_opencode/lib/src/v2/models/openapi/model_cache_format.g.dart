// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

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
