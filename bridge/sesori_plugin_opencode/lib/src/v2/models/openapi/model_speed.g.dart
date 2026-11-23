// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:meta/meta.dart';

@immutable
class ModelSpeed {
  const ModelSpeed({
    required this.base,
    required this.id,
    required this.faster,
  });

  factory ModelSpeed.fromJson(Map<String, dynamic> json) {
    return ModelSpeed(
      base: json["base"] as String,
      id: json["id"] as String,
      faster: json["faster"] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "base": base,
      "id": id,
      "faster": faster,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ModelSpeed copyWith({
    String? base,
    String? id,
    bool? faster,
  }) {
    return ModelSpeed(
      base: base ?? this.base,
      id: id ?? this.id,
      faster: faster ?? this.faster,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModelSpeed &&
          other.base == base &&
          other.id == id &&
          other.faster == faster);

  @override
  int get hashCode => Object.hash(base, id, faster);

  final String base;
  final String id;
  final bool faster;
}
