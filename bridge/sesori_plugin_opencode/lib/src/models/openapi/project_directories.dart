// GENERATED FILE - DO NOT EDIT BY HAND


/// Type alias for `List<String>` decoded from JSON.
class ProjectDirectories {
  const ProjectDirectories({required this.items});
  factory ProjectDirectories.fromJson(List<dynamic> json) => ProjectDirectories(items: json.map((e) => e as String).toList());
  List<dynamic> toJson() => items.toList();
  final List<String> items;
}
