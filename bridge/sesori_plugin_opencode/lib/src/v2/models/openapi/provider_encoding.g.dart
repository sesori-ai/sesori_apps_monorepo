// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

import 'package:json_annotation/json_annotation.dart';

enum ProviderEncoding {
  @JsonValue("zstd")
  zstd,
  @JsonValue("gzip")
  gzip,
  @JsonValue("none")
  none,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ProviderEncoding fromJson(String value) {
    switch (value) {
      case "zstd":
        return ProviderEncoding.zstd;
      case "gzip":
        return ProviderEncoding.gzip;
      case "none":
        return ProviderEncoding.none;
      default:
        return ProviderEncoding.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ProviderEncoding.zstd:
        return "zstd";
      case ProviderEncoding.gzip:
        return "gzip";
      case ProviderEncoding.none:
        return "none";
      case ProviderEncoding.unknown:
        return 'unknown';
    }
  }
}
