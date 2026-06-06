// GENERATED FILE - DO NOT EDIT BY HAND


class UnknownError {
  const UnknownError({
    required this.name,
    required this.data,
  });

  factory UnknownError.fromJson(Map<String, dynamic> json) {
    return UnknownError(
      name: json["name"] as String,
      data: json["data"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data,
    };
  }

  final String name;
  final Map<String, dynamic> data;
}
