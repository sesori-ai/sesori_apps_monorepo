import "package:json_annotation/json_annotation.dart";

import "../models/auth/auth_provider.dart";

const authProviderConverter = AuthProviderConverter();

class const AuthProviderConverter() implements JsonConverter<AuthProvider, String> {
  @override
  AuthProvider fromJson(String json) {
    final provider = AuthProvider.fromKey(json);
    if (provider == null) {
      throw FormatException("Unknown AuthProvider key: $json");
    }
    return provider;
  }

  @override
  String toJson(AuthProvider object) => object.key;
}
