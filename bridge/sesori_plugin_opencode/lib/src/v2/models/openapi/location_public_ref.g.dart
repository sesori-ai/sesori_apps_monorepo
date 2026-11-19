// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.3.2 (c0ad18b402eb2827fc1ee71c171b1177b3fc02d1)

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
