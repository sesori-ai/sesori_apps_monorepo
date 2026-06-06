// GENERATED FILE - DO NOT EDIT BY HAND


class ProviderAuthError {
  const ProviderAuthError({
    required this.name,
    required this.data,
  });

  factory ProviderAuthError.fromJson(Map<String, dynamic> json) {
    return ProviderAuthError(
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
