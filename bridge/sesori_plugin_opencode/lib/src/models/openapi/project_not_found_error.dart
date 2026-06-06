// GENERATED FILE - DO NOT EDIT BY HAND


class ProjectNotFoundError {
  const ProjectNotFoundError({
    required this.tag,
    required this.projectID,
    required this.message,
  });

  factory ProjectNotFoundError.fromJson(Map<String, dynamic> json) {
    return ProjectNotFoundError(
      tag: json["_tag"] as String,
      projectID: json["projectID"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "projectID": projectID,
      "message": message,
    };
  }

  final String tag;
  final String projectID;
  final String message;
}
