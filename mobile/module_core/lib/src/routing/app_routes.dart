const bundleId = "com.sesori.app";
const redirectUri = "$bundleId://auth/callback";
const projectNameQueryParam = "name";

String _appendQuery({required String path, required Map<String, String> queryParameters}) {
  if (queryParameters.isEmpty) return path;
  return "$path?${Uri(queryParameters: queryParameters).query}";
}

/// Path-template enum for GoRouter registration and route matching.
///
/// [AppRouteDef.values] is compile-time complete, so every route is
/// guaranteed to be registered — no manual list to keep in sync.
enum AppRouteDef {
  splash("/splash"),
  login("/login"),
  projects("/projects"),
  settings("/settings"),
  sessions("/projects/:projectId/sessions"),
  newSession("/projects/:projectId/sessions/new"),
  sessionDetail("/projects/:projectId/sessions/:sessionId"),
  sessionDiffs("/projects/:projectId/sessions/:sessionId/diffs"),
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
///   projectName: null,
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

  const factory AppRoute.splash() = AppRouteSplash;
  const factory AppRoute.login() = AppRouteLogin;
  const factory AppRoute.projects() = AppRouteProjects;
  const factory AppRoute.settings() = AppRouteSettings;
  const factory AppRoute.sessions({
    required String projectId,
    required String? projectName,
  }) = AppRouteSessions;
  const factory AppRoute.newSession({
    required String projectId,
    required String? projectName,
  }) = AppRouteNewSession;
  const factory AppRoute.sessionDetail({
    required String projectId,
    required String? projectName,
    required String sessionId,
    required String? sessionTitle,
    required bool readOnly,
  }) = AppRouteSessionDetail;
  const factory AppRoute.sessionDiffs({
    required String projectId,
    required String? projectName,
    required String sessionId,
  }) = AppRouteSessionDiffs;

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
      AppRouteDef.splash => const AppRoute.splash(),
      AppRouteDef.login => const AppRoute.login(),
      AppRouteDef.projects => const AppRoute.projects(),
      AppRouteDef.settings => const AppRoute.settings(),
      AppRouteDef.sessions => AppRouteSessions.fromParams(pathParams: pathParams, queryParams: queryParams),
      AppRouteDef.newSession => AppRouteNewSession.fromParams(pathParams: pathParams, queryParams: queryParams),
      AppRouteDef.sessionDetail => AppRouteSessionDetail.fromParams(
        pathParams: pathParams,
        queryParams: queryParams,
      ),
      AppRouteDef.sessionDiffs => AppRouteSessionDiffs.fromParams(
        pathParams: pathParams,
        queryParams: queryParams,
      ),
    };
  }
}

class AppRouteSplash extends AppRoute {
  const AppRouteSplash();

  @override
  AppRouteDef get def => AppRouteDef.splash;

  @override
  String buildPath() => def.path;
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

class AppRouteSettings extends AppRoute {
  const AppRouteSettings();

  @override
  AppRouteDef get def => AppRouteDef.settings;

  @override
  String buildPath() => def.path;
}

class AppRouteSessions extends AppRoute {
  static const _projectIdPathParam = "projectId";
  static const _nameQueryParam = projectNameQueryParam;

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
    return _appendQuery(path: base, queryParameters: queryParams);
  }
}

class AppRouteNewSession extends AppRoute {
  static const _projectIdPathParam = "projectId";
  static const _nameQueryParam = projectNameQueryParam;

  final String projectId;
  final String? projectName;

  const AppRouteNewSession({required this.projectId, required this.projectName});

  /// Decodes from path/query parameter maps (inverse of [buildPath]).
  factory AppRouteNewSession.fromParams({
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
  }) {
    return AppRouteNewSession(
      projectId: pathParams[_projectIdPathParam] ?? "",
      projectName: queryParams[_nameQueryParam],
    );
  }

  @override
  AppRouteDef get def => AppRouteDef.newSession;

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions/new";
    final queryParams = <String, String>{
      _nameQueryParam: ?projectName,
    };
    return _appendQuery(path: base, queryParameters: queryParams);
  }
}

class AppRouteSessionDetail extends AppRoute {
  static const _projectIdPathParam = "projectId";
  static const _sessionIdPathParam = "sessionId";
  static const _nameQueryParam = projectNameQueryParam;
  static const _titleQueryParam = "title";
  static const _readOnlyQueryParam = "readOnly";

  final String projectId;
  final String? projectName;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

  const AppRouteSessionDetail({
    required this.projectId,
    required this.projectName,
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
      projectName: queryParams[_nameQueryParam],
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
      _nameQueryParam: ?projectName,
      _titleQueryParam: ?sessionTitle,
    };
    return _appendQuery(path: base, queryParameters: queryParams);
  }
}

class AppRouteSessionDiffs extends AppRoute {
  static const _projectIdPathParam = "projectId";
  static const _sessionIdPathParam = "sessionId";
  static const _nameQueryParam = projectNameQueryParam;

  final String projectId;
  final String? projectName;
  final String sessionId;

  const AppRouteSessionDiffs({required this.projectId, required this.projectName, required this.sessionId});

  /// Decodes from path/query parameter maps (inverse of [buildPath]).
  factory AppRouteSessionDiffs.fromParams({
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
  }) {
    return AppRouteSessionDiffs(
      projectId: pathParams[_projectIdPathParam] ?? "",
      projectName: queryParams[_nameQueryParam],
      sessionId: pathParams[_sessionIdPathParam] ?? "",
    );
  }

  @override
  AppRouteDef get def => AppRouteDef.sessionDiffs;

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions/${Uri.encodeComponent(sessionId)}/diffs";
    final queryParams = <String, String>{
      _nameQueryParam: ?projectName,
    };
    return _appendQuery(path: base, queryParameters: queryParams);
  }
}
