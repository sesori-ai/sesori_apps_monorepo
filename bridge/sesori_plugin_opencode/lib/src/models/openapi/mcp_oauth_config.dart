// GENERATED FILE - DO NOT EDIT BY HAND


class McpOAuthConfig {
  const McpOAuthConfig({
    this.clientId,
    this.clientSecret,
    this.scope,
    this.callbackPort,
    this.redirectUri,
  });

  factory McpOAuthConfig.fromJson(Map<String, dynamic> json) {
    return McpOAuthConfig(
      clientId: json["clientId"] as String?,
      clientSecret: json["clientSecret"] as String?,
      scope: json["scope"] as String?,
      callbackPort: json["callbackPort"] as int?,
      redirectUri: json["redirectUri"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "clientId": clientId,
      "clientSecret": clientSecret,
      "scope": scope,
      "callbackPort": callbackPort,
      "redirectUri": redirectUri,
    };
  }

  final String? clientId;
  final String? clientSecret;
  final String? scope;
  final int? callbackPort;
  final String? redirectUri;
}
