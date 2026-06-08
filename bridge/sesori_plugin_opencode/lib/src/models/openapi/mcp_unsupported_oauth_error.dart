// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T07:51:39.991755Z


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
