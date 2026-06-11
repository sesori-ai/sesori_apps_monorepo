// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:json_annotation/json_annotation.dart';

enum LogLevel {
  @JsonValue("DEBUG")
  dEBUG,
  @JsonValue("INFO")
  iNFO,
  @JsonValue("WARN")
  wARN,
  @JsonValue("ERROR")
  eRROR,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static LogLevel fromJson(String value) {
    switch (value) {
      case "DEBUG":
        return LogLevel.dEBUG;
      case "INFO":
        return LogLevel.iNFO;
      case "WARN":
        return LogLevel.wARN;
      case "ERROR":
        return LogLevel.eRROR;
      default:
        return LogLevel.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case LogLevel.dEBUG:
        return "DEBUG";
      case LogLevel.iNFO:
        return "INFO";
      case LogLevel.wARN:
        return "WARN";
      case LogLevel.eRROR:
        return "ERROR";
      case LogLevel.unknown:
        return 'unknown';
    }
  }
}
