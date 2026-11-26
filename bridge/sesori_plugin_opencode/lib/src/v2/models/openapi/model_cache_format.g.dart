// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

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
