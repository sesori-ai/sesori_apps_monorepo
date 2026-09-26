// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class LocationPublicRef {
  const LocationPublicRef({
    required this.directory,
  });

  factory LocationPublicRef.fromJson(Map<String, dynamic> json) {
    return LocationPublicRef(
      directory: json["directory"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  LocationPublicRef copyWith({
    String? directory,
  }) {
    return LocationPublicRef(
      directory: directory ?? this.directory,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationPublicRef &&
          other.directory == directory);

  @override
  int get hashCode => directory.hashCode;

  final String directory;
}
