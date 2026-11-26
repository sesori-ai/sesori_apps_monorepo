// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

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
