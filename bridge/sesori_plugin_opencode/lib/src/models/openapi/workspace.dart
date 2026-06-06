// GENERATED FILE - DO NOT EDIT BY HAND


class Workspace {
  const Workspace({
    required this.id,
    required this.type,
    required this.name,
    this.branch,
    this.directory,
    this.extra,
    required this.projectID,
    required this.timeUsed,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json["id"] as String,
      type: json["type"] as String,
      name: json["name"] as String,
      branch: json["branch"] as String?,
      directory: json["directory"] as String?,
      extra: json["extra"],
      projectID: json["projectID"] as String,
      timeUsed: json["timeUsed"],
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": type,
      "name": name,
      "branch": branch,
      "directory": directory,
      "extra": extra,
      "projectID": projectID,
      "timeUsed": timeUsed,
    };
  }

  final String id;
  final String type;
  final String name;
  final String? branch;
  final String? directory;
  final dynamic extra;
  final String projectID;
  final dynamic timeUsed;
}
