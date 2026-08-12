const bundleId = "com.sesori.app";
const redirectUri = "$bundleId://auth/callback";
const projectNameQueryParam = "name";
const supportsDedicatedWorktreesQueryParam = "supportsDedicatedWorktrees";
const projectIdPathParam = "projectId";
const sessionIdPathParam = "sessionId";
const harnessSettingsPresentationQueryParam = "presentation";

/// How the harness settings page was raised, which decides both its page
/// transition and the way out of it.
enum HarnessSettingsPresentation() {
  /// Raised over a screen it does not belong to — the new-session harness
  /// menu. It slides up as a modal and closes back onto its opener.
  modal,

  /// Pushed as the next page of the settings stack. It slides in like any
  /// other settings page and returns with the back button.
  pushed;

  /// Reads a presentation from its URL spelling, or null when the value is
  /// absent or unknown.
  static HarnessSettingsPresentation? tryParse(String? value) {
    for (final presentation in values) {
      if (presentation.name == value) return presentation;
    }
    return null;
  }
}

String _appendQuery({required String path, required Map<String, String> queryParameters}) {
  if (queryParameters.isEmpty) return path;
  return "$path?${Uri(queryParameters: queryParameters).query}";
}

/// Path-template enum for GoRouter registration and route matching.
///
/// [AppRouteDef.values] is compile-time complete, so every route is
/// guaranteed to be registered — no manual list to keep in sync.
enum AppRouteDef(this.path) {
  splash("/splash"),
  login("/login"),
  projects("/projects"),
  settings("/settings"),
  settingsNotifications("/settings/notifications"),
  settingsHarnesses("/settings/harnesses"),
  settingsProfile("/settings/profile"),
  sessions("/projects/:$projectIdPathParam/sessions"),
  newSession("/projects/:$projectIdPathParam/sessions/new"),
  sessionDetail("/projects/:$projectIdPathParam/sessions/:$sessionIdPathParam"),
  sessionDiffs("/projects/:$projectIdPathParam/sessions/:$sessionIdPathParam/diffs"),
  ;

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
sealed class const AppRoute() {
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
  const factory AppRoute.settingsNotifications() = AppRouteSettingsNotifications;
  const factory AppRoute.settingsHarnesses({
    required HarnessSettingsPresentation presentation,
  }) = AppRouteSettingsHarnesses;
  const factory AppRoute.settingsProfile() = AppRouteSettingsProfile;
  const factory AppRoute.sessions({
    required String projectId,
    required String? projectName,
    required bool? supportsDedicatedWorktrees,
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
      AppRouteDef.settingsNotifications => const AppRoute.settingsNotifications(),
      AppRouteDef.settingsHarnesses => AppRouteSettingsHarnesses.fromParams(queryParams: queryParams),
      AppRouteDef.settingsProfile => const AppRoute.settingsProfile(),
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

class const AppRouteSplash() extends AppRoute {
  @override
  AppRouteDef get def => AppRouteDef.splash;

  @override
  String buildPath() => def.path;
}

class const AppRouteLogin() extends AppRoute {
  @override
  AppRouteDef get def => AppRouteDef.login;

  @override
  String buildPath() => def.path;
}

class const AppRouteProjects() extends AppRoute {
  @override
  AppRouteDef get def => AppRouteDef.projects;

  @override
  String buildPath() => def.path;
}

class const AppRouteSettings() extends AppRoute {
  @override
  AppRouteDef get def => AppRouteDef.settings;

  @override
  String buildPath() => def.path;
}

class const AppRouteSettingsNotifications() extends AppRoute {
  @override
  AppRouteDef get def => AppRouteDef.settingsNotifications;

  @override
  String buildPath() => def.path;
}

class const AppRouteSettingsHarnesses({required this.presentation}) extends AppRoute {
  static const _presentationQueryParam = harnessSettingsPresentationQueryParam;

  final HarnessSettingsPresentation presentation;

  /// Decodes from query parameter maps (inverse of [buildPath]).
  factory AppRouteSettingsHarnesses.fromParams({required Map<String, String> queryParams}) {
    return AppRouteSettingsHarnesses(
      // A deep link or a hand-typed URL names no presentation. It arrives over
      // whatever was on screen rather than over the settings list, so it is
      // raised the same way that detour is: as a modal with a way out.
      presentation:
          HarnessSettingsPresentation.tryParse(queryParams[_presentationQueryParam]) ??
          HarnessSettingsPresentation.modal,
    );
  }

  @override
  AppRouteDef get def => AppRouteDef.settingsHarnesses;

  @override
  String buildPath() {
    return _appendQuery(
      path: def.path,
      queryParameters: {_presentationQueryParam: presentation.name},
    );
  }
}

class const AppRouteSettingsProfile() extends AppRoute {
  @override
  AppRouteDef get def => AppRouteDef.settingsProfile;

  @override
  String buildPath() => def.path;
}

class const AppRouteSessions({
    required this.projectId,
    required this.projectName,
    required this.supportsDedicatedWorktrees,
  }) extends AppRoute {
  static const _projectIdPathParam = projectIdPathParam;
  static const _nameQueryParam = projectNameQueryParam;
  static const _supportsDedicatedWorktreesQueryParam = supportsDedicatedWorktreesQueryParam;

  final String projectId;
  final String? projectName;
  final bool? supportsDedicatedWorktrees;

  /// Decodes from path/query parameter maps (inverse of [buildPath]).
  factory AppRouteSessions.fromParams({
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
  }) {
    return AppRouteSessions(
      projectId: pathParams[_projectIdPathParam] ?? "",
      projectName: queryParams[_nameQueryParam],
      supportsDedicatedWorktrees: switch (queryParams[_supportsDedicatedWorktreesQueryParam]) {
        "true" => true,
        "false" => false,
        _ => null,
      },
    );
  }

  @override
  AppRouteDef get def => AppRouteDef.sessions;

  @override
  String buildPath() {
    final base = "/projects/${Uri.encodeComponent(projectId)}/sessions";
    final queryParams = <String, String>{
      _nameQueryParam: ?projectName,
      _supportsDedicatedWorktreesQueryParam: ?supportsDedicatedWorktrees?.toString(),
    };
    return _appendQuery(path: base, queryParameters: queryParams);
  }
}

class const AppRouteNewSession({required this.projectId, required this.projectName}) extends AppRoute {
  static const _projectIdPathParam = projectIdPathParam;
  static const _nameQueryParam = projectNameQueryParam;

  final String projectId;
  final String? projectName;

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

class const AppRouteSessionDetail({
    required this.projectId,
    required this.projectName,
    required this.sessionId,
    required this.sessionTitle,
    required this.readOnly,
  }) extends AppRoute {
  static const _projectIdPathParam = projectIdPathParam;
  static const _sessionIdPathParam = sessionIdPathParam;
  static const _nameQueryParam = projectNameQueryParam;
  static const _titleQueryParam = "title";
  static const _readOnlyQueryParam = "readOnly";

  final String projectId;
  final String? projectName;
  final String sessionId;
  final String? sessionTitle;
  final bool readOnly;

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

  /// Whether [location] — a resolved location as reported by
  /// `RouteSource.currentLocation` — already shows this session in its
  /// editable form.
  ///
  /// The read-only variant of a session (background tasks and subtasks open
  /// that way) shares this route's path and differs only by query, so a plain
  /// path comparison would treat the two as interchangeable. They are not: the
  /// read-only screen renders without the composer or mutating controls, so a
  /// caller that wants the editable screen must still navigate to it.
  ///
  /// [projectName] and [sessionTitle] are display-only and deliberately
  /// ignored — the same session labelled differently is still the same screen.
  bool showsEditableLocation({required Uri location}) {
    if (location.path != Uri.parse(buildPath()).path) return false;
    return location.queryParameters[_readOnlyQueryParam] != true.toString();
  }
}

class const AppRouteSessionDiffs({required this.projectId, required this.projectName, required this.sessionId}) extends AppRoute {
  static const _projectIdPathParam = projectIdPathParam;
  static const _sessionIdPathParam = sessionIdPathParam;
  static const _nameQueryParam = projectNameQueryParam;

  final String projectId;
  final String? projectName;
  final String sessionId;

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
