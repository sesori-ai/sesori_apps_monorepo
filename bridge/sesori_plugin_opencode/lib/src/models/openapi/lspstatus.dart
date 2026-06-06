// GENERATED FILE - DO NOT EDIT BY HAND


class LSPStatus {
  const LSPStatus({
    required this.id,
    required this.name,
    required this.root,
    required this.status,
  });

  factory LSPStatus.fromJson(Map<String, dynamic> json) {
    return LSPStatus(
      id: json["id"] as String,
      name: json["name"] as String,
      root: json["root"] as String,
      status: json["status"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "name": name,
      "root": root,
      "status": status,
    };
  }

  final String id;
  final String name;
  final String root;
  final String status;
}
