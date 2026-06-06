// GENERATED FILE - DO NOT EDIT BY HAND


class Symbol {
  const Symbol({
    required this.name,
    required this.kind,
    required this.location,
  });

  factory Symbol.fromJson(Map<String, dynamic> json) {
    return Symbol(
      name: json["name"] as String,
      kind: json["kind"] as int,
      location: json["location"] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "kind": kind,
      "location": location,
    };
  }

  final String name;
  final int kind;
  final Map<String, dynamic> location;
}
