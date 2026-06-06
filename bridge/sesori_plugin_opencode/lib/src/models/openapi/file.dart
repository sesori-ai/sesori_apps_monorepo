// GENERATED FILE - DO NOT EDIT BY HAND


class File {
  const File({
    required this.path,
    required this.added,
    required this.removed,
    required this.status,
  });

  factory File.fromJson(Map<String, dynamic> json) {
    return File(
      path: json["path"] as String,
      added: json["added"] as int,
      removed: json["removed"] as int,
      status: json["status"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "path": path,
      "added": added,
      "removed": removed,
      "status": status,
    };
  }

  final String path;
  final int added;
  final int removed;
  final String status;
}
