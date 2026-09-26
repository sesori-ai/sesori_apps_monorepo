// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:json_annotation/json_annotation.dart';

enum ProviderTransport {
  @JsonValue("http")
  http,
  @JsonValue("websocket")
  websocket,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static ProviderTransport fromJson(String value) {
    switch (value) {
      case "http":
        return ProviderTransport.http;
      case "websocket":
        return ProviderTransport.websocket;
      default:
        return ProviderTransport.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case ProviderTransport.http:
        return "http";
      case ProviderTransport.websocket:
        return "websocket";
      case ProviderTransport.unknown:
        return 'unknown';
    }
  }
}
