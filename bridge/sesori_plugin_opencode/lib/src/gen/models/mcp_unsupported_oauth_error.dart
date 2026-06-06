// GENERATED FILE - DO NOT EDIT BY HAND


class McpUnsupportedOAuthError {
  const McpUnsupportedOAuthError({
    required this.error,
  });

  factory McpUnsupportedOAuthError.fromJson(Map<String, dynamic> json) {
    return McpUnsupportedOAuthError(
      error: json["error"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "error": error,
    };
  }

  final String error;
}
