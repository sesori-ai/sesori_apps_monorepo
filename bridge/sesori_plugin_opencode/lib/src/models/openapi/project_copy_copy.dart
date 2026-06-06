// GENERATED FILE - DO NOT EDIT BY HAND


class ProjectCopyCopy {
  const ProjectCopyCopy({
    required this.directory,
  });

  factory ProjectCopyCopy.fromJson(Map<String, dynamic> json) {
    return ProjectCopyCopy(
      directory: json["directory"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
    };
  }

  final String directory;
}
