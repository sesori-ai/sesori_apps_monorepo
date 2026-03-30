const bundleId = "com.sesori.app";
const redirectUri = "$bundleId://auth/callback";

/// Type-safe route definitions for the app.
///
/// Each subclass carries exactly the parameters its screen needs, so
/// navigation call sites can never forget a required param.
///
/// Use factory constructors for ergonomic creation:
/// ```dart
/// context.pushRoute(AppRoute.sessionDetail(projectId: 'p1', sessionId: 's1'));
/// ```
sealed class AppRoute {
  const AppRoute();

  /// Path template with `:param` placeholders (used for GoRouter registration).
  String get path;

  /// Builds a concrete URI string from this route's parameters.
  ///
  /// Path parameters are percent-encoded. Query parameters (when present)
  /// are appended and encoded via [Uri].
  String buildPath();

  const factory AppRoute.login() = AppRouteLogin;
  const factory AppRoute.projects() = AppRouteProjects;
  const factory AppRoute.notificationSettings() = AppRouteNotificationSettings;
  const factory AppRoute.sessions({required String projectId, String? projectName}) = AppRouteSessions;
  const factory AppRoute.newSession({required String projectId}) = AppRouteNewSession;
  const factory AppRoute.sessionDetail({
    required String projectId,
    required String sessionId,
    String? sessionTitle,
    bool readOnly,
  }) = AppRouteSessionDetail;

  /// One instance per route type — used for GoRouter registration and route
  /// matching. Parameter values are irrelevant; only [path] templates matter.
  static const values = <AppRoute>[
    AppRouteLogin(),
    AppRouteProjects(),
    AppRouteNotificationSettings(),
    AppRouteSessions(projectId: ""),
    AppRouteNewSession(projectId: ""),
    AppRouteSessionDetail(projectId: "", sessionId: ""),
  ];
}

class AppRouteLogin extends AppRoute {
  const AppRouteLogin();

  @override
  String get path => "/login";

  @override
  String buildPath() => path;
}

class AppRouteProjects extends AppRoute {
  const AppRouteProjects();

  @override
  String get path => "/projects";

  @override
  String buildPath() => path;
}

class AppRouteNotificationSettings extends AppRoute {
  const AppRouteNotificationSettings();

  @override
  String get path => "/settings/notifications";

  @override
  String buildPath() => path;
}

class AppRouteSessions extends AppRoute {
  final String projectId;
  final String? projectName;

  const AppRouteSessions({required this.projectId, this.projectName});

  @override
  String get path => "/projects/:projectId/sessions";

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions";
    if (projectName != null) {
      return Uri(path: base, queryParameters: {"name": projectName}).toString();
    }
    return base;
  }
}

class AppRouteNewSession extends AppRoute {
  final String projectId;

  const AppRouteNewSession({required this.projectId});

  @override
  String get path => "/projects/:projectId/sessions/new";

  @override
  String buildPath() => "/projects/${Uri.encodeComponent(projectId)}/sessions/new";
}

class AppRouteSessionDetail extends AppRoute {
  final String projectId;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const AppRouteSessionDetail({
    required this.projectId,
    required this.sessionId,
    this.sessionTitle,
    this.readOnly = false,
  });

  @override
  String get path => "/projects/:projectId/sessions/:sessionId";

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions/${Uri.encodeComponent(sessionId)}";
    final queryParams = <String, String>{};
    if (sessionTitle != null) queryParams["title"] = sessionTitle!;
    if (readOnly) queryParams["readOnly"] = "true";
    if (queryParams.isNotEmpty) {
      return Uri(path: base, queryParameters: queryParams).toString();
    }
    return base;
  }
}
