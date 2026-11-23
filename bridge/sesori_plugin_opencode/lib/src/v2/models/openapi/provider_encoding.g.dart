// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

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
