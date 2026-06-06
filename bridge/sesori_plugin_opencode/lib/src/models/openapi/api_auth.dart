// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth.dart';

class ApiAuth implements Auth {
  const ApiAuth({
    required this.type,
    required this.key,
    this.metadata,
  });

  factory ApiAuth.fromJson(Map<String, dynamic> json) {
    return ApiAuth(
      type: json["type"] as String,
      key: json["key"] as String,
      metadata: (json["metadata"] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
    );
  }


  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "key": key,
      "metadata": metadata,
    };
  }

  final String type;
  final String key;
  final Map<String, String>? metadata;
}
