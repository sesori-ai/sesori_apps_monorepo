// GENERATED FILE - DO NOT EDIT BY HAND


class ProviderAuthAuthorization {
  const ProviderAuthAuthorization({
    required this.url,
    required this.method,
    required this.instructions,
  });

  factory ProviderAuthAuthorization.fromJson(Map<String, dynamic> json) {
    return ProviderAuthAuthorization(
      url: json["url"] as String,
      method: json["method"] as String,
      instructions: json["instructions"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "url": url,
      "method": method,
      "instructions": instructions,
    };
  }

  final String url;
  final String method;
  final String instructions;
}
