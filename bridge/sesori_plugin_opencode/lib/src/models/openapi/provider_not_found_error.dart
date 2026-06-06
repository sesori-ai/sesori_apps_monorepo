// GENERATED FILE - DO NOT EDIT BY HAND


class ProviderNotFoundError {
  const ProviderNotFoundError({
    required this.tag,
    required this.providerID,
    required this.message,
  });

  factory ProviderNotFoundError.fromJson(Map<String, dynamic> json) {
    return ProviderNotFoundError(
      tag: json["_tag"] as String,
      providerID: json["providerID"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "_tag": tag,
      "providerID": providerID,
      "message": message,
    };
  }

  final String tag;
  final String providerID;
  final String message;
}
