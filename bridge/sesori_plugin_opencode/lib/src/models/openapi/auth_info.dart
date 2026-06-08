// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T08:11:58.881142Z

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
