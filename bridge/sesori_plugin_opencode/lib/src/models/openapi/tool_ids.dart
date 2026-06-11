// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Type alias for `List<String>` decoded from JSON.
@immutable
class ToolIDs {
  const ToolIDs({required this.items});
  factory ToolIDs.fromJson(List<dynamic> json) => ToolIDs(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolIDs &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<String> items;
}
