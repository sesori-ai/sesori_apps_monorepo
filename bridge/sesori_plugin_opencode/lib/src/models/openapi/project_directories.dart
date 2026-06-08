// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:24:06.238944Z

import 'package:meta/meta.dart';

/// Type alias for `List<String>` decoded from JSON.
@immutable
class ProjectDirectories {
  const ProjectDirectories({required this.items});
  factory ProjectDirectories.fromJson(List<dynamic> json) => ProjectDirectories(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();
  final List<String> items;
}
