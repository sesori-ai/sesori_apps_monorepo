// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.16 (3a103fe0aff726a4edc7492f03f7b88195d9e4c9)

import 'package:meta/meta.dart';

@immutable
class TokenUsageInfo {
  const TokenUsageInfo({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory TokenUsageInfo.fromJson(Map<String, dynamic> json) {
    return TokenUsageInfo(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: TokenUsageInfoCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "reasoning": reasoning,
      "cache": cache.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  TokenUsageInfo copyWith({
    double? input,
    double? output,
    double? reasoning,
    TokenUsageInfoCache? cache,
  }) {
    return TokenUsageInfo(
      input: input ?? this.input,
      output: output ?? this.output,
      reasoning: reasoning ?? this.reasoning,
      cache: cache ?? this.cache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TokenUsageInfo &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final TokenUsageInfoCache cache;
}

@immutable
class TokenUsageInfoCache {
  const TokenUsageInfoCache({
    required this.read,
    required this.write,
  });

  factory TokenUsageInfoCache.fromJson(Map<String, dynamic> json) {
    return TokenUsageInfoCache(
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
  TokenUsageInfoCache copyWith({
    double? read,
    double? write,
  }) {
    return TokenUsageInfoCache(
      read: read ?? this.read,
      write: write ?? this.write,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TokenUsageInfoCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
