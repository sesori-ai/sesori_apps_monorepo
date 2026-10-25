// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:meta/meta.dart';

@immutable
class ProjectTime {
  const ProjectTime({
    required this.created,
    required this.updated,
    required this.active,
    required this.archived,
  });

  factory ProjectTime.fromJson(Map<String, dynamic> json) {
    return ProjectTime(
      created: (json["created"] as num).toInt(),
      updated: (json["updated"] as num).toInt(),
      active: (json["active"] as num).toInt(),
      archived: (json["archived"] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "updated": updated,
      "active": active,
      "archived": ?archived,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProjectTime copyWith({
    int? created,
    int? updated,
    int? active,
    int? archived,
  }) {
    return ProjectTime(
      created: created ?? this.created,
      updated: updated ?? this.updated,
      active: active ?? this.active,
      archived: archived ?? this.archived,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectTime &&
          other.created == created &&
          other.updated == updated &&
          other.active == active &&
          other.archived == archived);

  @override
  int get hashCode => Object.hash(created, updated, active, archived);

  final int created;
  final int updated;
  final int active;
  final int? archived;
}
