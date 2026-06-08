// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.989504Z

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
        throw FormatException('Unknown LogLevel value: $value');
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
    }
  }
}
