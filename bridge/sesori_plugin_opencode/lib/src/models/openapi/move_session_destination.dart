// GENERATED FILE - DO NOT EDIT BY HAND


class MoveSessionDestination {
  const MoveSessionDestination({
    required this.directory,
  });

  factory MoveSessionDestination.fromJson(Map<String, dynamic> json) {
    return MoveSessionDestination(
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
