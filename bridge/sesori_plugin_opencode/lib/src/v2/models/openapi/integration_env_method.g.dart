// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'integration_method.g.dart';

@immutable
class IntegrationEnvMethod implements IntegrationMethod {
  const IntegrationEnvMethod({
    required this.names,
  });

  factory IntegrationEnvMethod.fromJson(Map<String, dynamic> json) {
    return IntegrationEnvMethod(
      names: (json["names"] as List<dynamic>).cast<String>(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "env",
      "names": names,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationEnvMethod copyWith({
    List<String>? names,
  }) {
    return IntegrationEnvMethod(
      names: names ?? this.names,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationEnvMethod &&
          const DeepCollectionEquality().equals(other.names, names));

  @override
  int get hashCode => const DeepCollectionEquality().hash(names);

  final List<String> names;
}
