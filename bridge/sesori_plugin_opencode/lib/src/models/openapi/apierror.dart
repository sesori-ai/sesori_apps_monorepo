// GENERATED FILE - DO NOT EDIT BY HAND


class APIError {
  const APIError({
    required this.name,
    required this.data,
  });

  factory APIError.fromJson(Map<String, dynamic> json) {
    return APIError(
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
