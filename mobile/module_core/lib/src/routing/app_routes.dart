const bundleId = "com.sesori.app";
const redirectUri = "$bundleId://auth/callback";

/// Path-template enum for GoRouter registration and route matching.
///
/// [AppRouteDef.values] is compile-time complete, so every route is
/// guaranteed to be registered — no manual list to keep in sync.
enum AppRouteDef {
  login("/login"),
  projects("/projects"),
  notificationSettings("/settings/notifications"),
  sessions("/projects/:projectId/sessions"),
  newSession("/projects/:projectId/sessions/new"),
  sessionDetail("/projects/:projectId/sessions/:sessionId"),
  ;

  const AppRouteDef(this.path);
  final String path;
}

/// Type-safe route definitions for navigation.
///
/// Each subclass carries exactly the parameters its screen needs, so
/// call sites can never forget a required param.
///
/// Use factory constructors for ergonomic creation:
/// ```dart
/// context.pushRoute(AppRoute.sessionDetail(
///   projectId: 'p1',
///   sessionId: 's1',
///   sessionTitle: null,
///   readOnly: false,
/// ));
/// ```
sealed class AppRoute {
  const AppRoute();

  /// The matching [AppRouteDef] for this route.
  AppRouteDef get def;

  /// Builds a concrete URI string from this route's parameters.
  ///
  /// Path parameters are percent-encoded. Query parameters (when present)
  /// are appended and encoded via [Uri].
  String buildPath();

  const factory AppRoute.login() = AppRouteLogin;
  const factory AppRoute.projects() = AppRouteProjects;
  const factory AppRoute.notificationSettings() = AppRouteNotificationSettings;
  const factory AppRoute.sessions({
    required String projectId,
    required String? projectName,
  }) = AppRouteSessions;
  const factory AppRoute.newSession({required String projectId}) = AppRouteNewSession;
  const factory AppRoute.sessionDetail({
    required String projectId,
    required String sessionId,
    required String? sessionTitle,
    required bool readOnly,
  }) = AppRouteSessionDetail;

  /// Creates the correct subclass by decoding path/query params for [def].
  ///
  /// This is the inverse of [buildPath] — encoding and decoding are
  /// co-located in each subclass so they cannot fall out of sync.
  static AppRoute fromDef({
    required AppRouteDef def,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
  }) {
    return switch (def) {
      AppRouteDef.login => const AppRoute.login(),
      AppRouteDef.projects => const AppRoute.projects(),
      AppRouteDef.notificationSettings => const AppRoute.notificationSettings(),
      AppRouteDef.sessions => AppRouteSessions.fromParams(pathParams: pathParams, queryParams: queryParams),
      AppRouteDef.newSession => AppRouteNewSession.fromParams(pathParams: pathParams, queryParams: queryParams),
      AppRouteDef.sessionDetail => AppRouteSessionDetail.fromParams(
        pathParams: pathParams,
        queryParams: queryParams,
      ),
    };
  }
}

class AppRouteLogin extends AppRoute {
  const AppRouteLogin();

  @override
  AppRouteDef get def => AppRouteDef.login;

  @override
  String buildPath() => def.path;
}

class AppRouteProjects extends AppRoute {
  const AppRouteProjects();

  @override
  AppRouteDef get def => AppRouteDef.projects;

  @override
  String buildPath() => def.path;
}

class AppRouteNotificationSettings extends AppRoute {
  const AppRouteNotificationSettings();

  @override
  AppRouteDef get def => AppRouteDef.notificationSettings;

  @override
  String buildPath() => def.path;
}

class AppRouteSessions extends AppRoute {
  static const _projectIdPathParam = "projectId";
  static const _nameQueryParam = "name";

  final String projectId;
  final String? projectName;

  const AppRouteSessions({required this.projectId, required this.projectName});

  /// Decodes from path/query parameter maps (inverse of [buildPath]).
  factory AppRouteSessions.fromParams({
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
  }) {
    return AppRouteSessions(
      projectId: pathParams[_projectIdPathParam] ?? "",
      projectName: queryParams[_nameQueryParam],
    );
  }

  @override
  AppRouteDef get def => AppRouteDef.sessions;

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions";
    final queryParams = <String, String>{
      _nameQueryParam: ?projectName,
    };
    if (queryParams.isNotEmpty) {
      return Uri(path: base, queryParameters: queryParams).toString();
    }
    return base;
  }
}

class AppRouteNewSession extends AppRoute {
  static const _projectIdPathParam = "projectId";

  final String projectId;

  const AppRouteNewSession({required this.projectId});

  /// Decodes from path/query parameter maps (inverse of [buildPath]).
  factory AppRouteNewSession.fromParams({
    required Map<String, String> pathParams,
    // ignore: avoid_unused_constructor_parameters — uniform fromParams signature
    required Map<String, String> queryParams,
  }) {
    return AppRouteNewSession(projectId: pathParams[_projectIdPathParam] ?? "");
  }

  @override
  AppRouteDef get def => AppRouteDef.newSession;

  @override
  String buildPath() => "/projects/${Uri.encodeComponent(projectId)}/sessions/new";
}

class AppRouteSessionDetail extends AppRoute {
  static const _projectIdPathParam = "projectId";
  static const _sessionIdPathParam = "sessionId";
  static const _titleQueryParam = "title";
  static const _readOnlyQueryParam = "readOnly";

  final String projectId;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const AppRouteSessionDetail({
    required this.projectId,
    required this.sessionId,
    required this.sessionTitle,
    required this.readOnly,
  });

  /// Decodes from path/query parameter maps (inverse of [buildPath]).
  factory AppRouteSessionDetail.fromParams({
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
  }) {
    return AppRouteSessionDetail(
      projectId: pathParams[_projectIdPathParam] ?? "",
      sessionId: pathParams[_sessionIdPathParam] ?? "",
      sessionTitle: queryParams[_titleQueryParam],
      readOnly: queryParams[_readOnlyQueryParam] == "true",
    );
  }

  @override
  AppRouteDef get def => AppRouteDef.sessionDetail;

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions/${Uri.encodeComponent(sessionId)}";
    final queryParams = <String, String>{
      _readOnlyQueryParam: readOnly.toString(),
      _titleQueryParam: ?sessionTitle,
    };
    return Uri(path: base, queryParameters: queryParams).toString();
  }
}
