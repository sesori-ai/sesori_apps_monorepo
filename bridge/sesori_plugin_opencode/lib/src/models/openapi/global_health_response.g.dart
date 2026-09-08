// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.7 (4ed4f749e644ffb5b279fb30b7b915e743d80142)

import 'package:meta/meta.dart';

@immutable
class GlobalHealthResponse {
  const GlobalHealthResponse({
    required this.healthy,
    required this.version,
  });

  factory GlobalHealthResponse.fromJson(Map<String, dynamic> json) {
    return GlobalHealthResponse(
      healthy: json["healthy"] as bool,
      version: json["version"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "healthy": healthy,
      "version": version,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  GlobalHealthResponse copyWith({
    bool? healthy,
    String? version,
  }) {
    return GlobalHealthResponse(
      healthy: healthy ?? this.healthy,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GlobalHealthResponse &&
          other.healthy == healthy &&
          other.version == version);

  @override
  int get hashCode => Object.hash(healthy, version);

  final bool healthy;
  final String? version;
}
