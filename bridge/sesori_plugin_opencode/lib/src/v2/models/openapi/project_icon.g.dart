// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.4.1 (6f0514052a3c859894ad01bb14cc14dda1e44b96)

import 'package:meta/meta.dart';

@immutable
class ProjectIcon {
  const ProjectIcon({
    required this.url,
    required this.overrideValue,
    required this.color,
  });

  factory ProjectIcon.fromJson(Map<String, dynamic> json) {
    return ProjectIcon(
      url: json["url"] as String?,
      overrideValue: json["override"] as String?,
      color: json["color"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": ?url,
      "override": ?overrideValue,
      "color": ?color,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  ProjectIcon copyWith({
    String? url,
    String? overrideValue,
    String? color,
  }) {
    return ProjectIcon(
      url: url ?? this.url,
      overrideValue: overrideValue ?? this.overrideValue,
      color: color ?? this.color,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectIcon &&
          other.url == url &&
          other.overrideValue == overrideValue &&
          other.color == color);

  @override
  int get hashCode => Object.hash(url, overrideValue, color);

  final String? url;
  final String? overrideValue;
  final String? color;
}
