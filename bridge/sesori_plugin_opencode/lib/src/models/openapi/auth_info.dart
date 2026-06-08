// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.913534Z

import 'package:meta/meta.dart';
import 'auth_credential.dart';

@immutable
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
      credential: AuthCredential.fromJson(json["credential"] as Object),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuthInfo &&
          other.id == id &&
          other.serviceID == serviceID &&
          other.description == description &&
          other.credential == credential);

  @override
  int get hashCode => Object.hash(id, serviceID, description, credential);

  final String id;
  final String serviceID;
  final String description;
  final AuthCredential credential;
}
