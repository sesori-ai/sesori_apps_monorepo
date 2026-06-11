// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'tool_list_item.dart';

/// Type alias for `List<ToolListItem>` decoded from JSON.
@immutable
class ToolList {
  const ToolList({required this.items});
  factory ToolList.fromJson(List<dynamic> json) => ToolList(items: json.map((e) => ToolListItem.fromJson(e as Map<String, dynamic>)).toList());
  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToolList &&
          const DeepCollectionEquality().equals(other.items, items));

  @override
  int get hashCode => const DeepCollectionEquality().hash(items);

  final List<ToolListItem> items;
}
