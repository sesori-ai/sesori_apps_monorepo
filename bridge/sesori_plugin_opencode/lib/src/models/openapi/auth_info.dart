// GENERATED FILE - DO NOT EDIT BY HAND

import 'auth_credential.dart';

class AuthInfo {
  const AuthInfo({
    required this.id,
    required this.serviceID,
    required this.description,
    required this.credential,
  });

  factory AuthInfo.fromJson(Map<String, dynamic> json) {
    return AuthInfo(
      id: json["id"] as String,
      serviceID: json["serviceID"] as String,
      description: json["description"] as String,
      credential: AuthCredential.fromJson(json["credential"]),
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "serviceID": serviceID,
      "description": description,
      "credential": credential.toJson(),
    };
  }

  final String id;
  final String serviceID;
  final String description;
  final AuthCredential credential;
}
