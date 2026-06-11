// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class GlobalHealthResponse {
  const GlobalHealthResponse({
    this.healthy = false,
    this.version = '',
  });

  factory GlobalHealthResponse.fromJson(Map<String, dynamic> json) {
    return GlobalHealthResponse(
      healthy: (json["healthy"] ?? false) as bool,
      version: (json["version"] ?? '') as String,
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
  final String version;
}
