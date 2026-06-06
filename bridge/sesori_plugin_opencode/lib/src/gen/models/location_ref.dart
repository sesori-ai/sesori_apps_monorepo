// GENERATED FILE - DO NOT EDIT BY HAND


class LocationRef {
  const LocationRef({
    required this.directory,
    this.workspaceID,
  });

  factory LocationRef.fromJson(Map<String, dynamic> json) {
    return LocationRef(
      directory: json["directory"] as String,
      workspaceID: json["workspaceID"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "directory": directory,
      "workspaceID": workspaceID,
    };
  }

  final String directory;
  final String? workspaceID;
}
