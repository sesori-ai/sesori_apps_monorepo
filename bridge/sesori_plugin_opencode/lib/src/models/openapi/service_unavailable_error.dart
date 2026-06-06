// GENERATED FILE - DO NOT EDIT BY HAND


class ServiceUnavailableError {
  const ServiceUnavailableError({
    required this.tag,
    required this.message,
    this.service,
  });

  factory ServiceUnavailableError.fromJson(Map<String, dynamic> json) {
    return ServiceUnavailableError(
      tag: json["_tag"] as String,
      message: json["message"] as String,
      service: json["service"] as String?,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "message": message,
      "service": service,
    };
  }

  final String tag;
  final String message;
  final String? service;
}
