// GENERATED FILE - DO NOT EDIT BY HAND


/// Type alias for `List<String>` decoded from JSON.
class ToolIDs {
  const ToolIDs({required this.items});
  factory ToolIDs.fromJson(List<dynamic> json) => ToolIDs(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();
  final List<String> items;
}
