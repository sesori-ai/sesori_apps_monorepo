// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.18 (cd9a14a6b688d4021bee381dfd39d2cef9c0f862)

import 'package:meta/meta.dart';

@immutable
class ProjectTime {
  const ProjectTime({
    required this.created,
    required this.updated,
    required this.active,
  });

  factory ProjectTime.fromJson(Map<String, dynamic> json) {
    return ProjectTime(
      created: (json["created"] as num).toInt(),
      updated: (json["updated"] as num).toInt(),
      active: (json["active"] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "updated": updated,
      "active": active,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProjectTime copyWith({
    int? created,
    int? updated,
    int? active,
  }) {
    return ProjectTime(
      created: created ?? this.created,
      updated: updated ?? this.updated,
      active: active ?? this.active,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectTime &&
          other.created == created &&
          other.updated == updated &&
          other.active == active);

  @override
  int get hashCode => Object.hash(created, updated, active);

  final int created;
  final int updated;
  final int active;
}
