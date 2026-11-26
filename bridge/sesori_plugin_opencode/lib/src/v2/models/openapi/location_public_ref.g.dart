// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.2 (fc31a485317970bcf6be7b431a9830aaef875731)

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
