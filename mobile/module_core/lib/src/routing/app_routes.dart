const bundleId = "com.sesori.app";
const redirectUri = "$bundleId://auth/callback";

enum AppRoute {
  login("/login"),
  projects("/projects"),
  notificationSettings("/settings/notifications"),
  sessions("/projects/:projectId/sessions"),
  newSession("/projects/:projectId/sessions/new"),
  sessionDetail("/projects/:projectId/sessions/:sessionId")
  ;

  const AppRoute(this.path);
  final String path;

  /// Builds a concrete URI string from this route's path template.
  ///
  /// Substitutes [pathParams] into `:param` placeholders and appends
  /// [queryParams] as a query string (values are automatically encoded).
  String buildPath({
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
  }) {
    var result = path;
    if (pathParams != null) {
      for (final entry in pathParams.entries) {
        result = result.replaceFirst(":${entry.key}", Uri.encodeComponent(entry.value));
      }
    }
    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri(path: result, queryParameters: queryParams).toString();
    }
    return result;
  }
}
