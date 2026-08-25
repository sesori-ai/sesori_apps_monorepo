import "dart:async";

import "package:flutter/foundation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Bridges [AppLinks] deep link events to app routing.
///
/// OAuth callbacks remain a no-op. Device Canvas session links are queued until
/// authentication completes, then opened through the same typed route stack as
/// in-app session navigation.
@lazySingleton
class DeepLinkService(
  final DeepLinkSource _deepLinkSource,
  final AuthSession _authSession,
  final RouteDispatcher _routeDispatcher,
) {
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  AppRouteDeviceCanvasSession? _pendingSessionRoute;

  /// Start listening for deep links. Call once during app initialization.
  ///
  /// [AppLinks.uriLinkStream] covers both cold-start and warm-start links,
  /// so no separate [getInitialLink] call is needed.
  void init() {
    if (_linkSubscription != null) {
      logw("DeepLinkService.init() called more than once; ignoring");
      return;
    }

    _linkSubscription = _deepLinkSource.linkStream.listen(
      _processUri,
      onError: (Object error, StackTrace stackTrace) => loge("Deep link stream error", error, stackTrace),
    );
    _authSubscription = _authSession.authStateStream.listen(
      _onAuthStateChanged,
      onError: (Object error, StackTrace stackTrace) {
        loge("Deep link auth state stream error", error, stackTrace);
      },
    );
  }

  void _processUri(Uri uri) {
    if (uri.scheme == bundleId && uri.host == "auth" && uri.path == "/callback") {
      logd("Ignoring legacy OAuth deep link");
      return;
    }

    final route = parseDeviceCanvasSessionUri(uri);
    if (route == null) {
      logd("Ignoring unsupported or malformed deep link");
      return;
    }
    _handleSessionRoute(route);
  }

  @visibleForTesting
  static AppRouteDeviceCanvasSession? parseDeviceCanvasSessionUri(Uri uri) {
    if (uri.scheme != bundleId || !uri.hasAuthority || uri.authority.isNotEmpty || uri.fragment.isNotEmpty) {
      return null;
    }
    final query = uri.queryParametersAll;
    if (query.length != 2 || query.keys.any((key) => key != bridgeIdQueryParam && key != "readOnly")) {
      return null;
    }
    final bridgeIds = query[bridgeIdQueryParam];
    final readOnlyValues = query["readOnly"];
    if (bridgeIds == null ||
        readOnlyValues == null ||
        bridgeIds.length != 1 ||
        readOnlyValues.length != 1 ||
        readOnlyValues.single != "false" ||
        bridgeIds.single.isEmpty ||
        bridgeIds.single.length > maxDeviceCanvasClientIdentifierLength) {
      return null;
    }

    try {
      final segments = uri.pathSegments;
      if (segments.length != 2 || segments[0] != "sessions") return null;
      final sessionId = segments[1];
      if (sessionId.isEmpty || sessionId.length > maxDeviceCanvasClientIdentifierLength) {
        return null;
      }
      return AppRouteDeviceCanvasSession(
        sessionId: sessionId,
        readOnly: false,
        bridgeId: bridgeIds.single,
      );
    } on FormatException {
      return null;
    }
  }

  void _handleSessionRoute(AppRouteDeviceCanvasSession route) {
    if (_authSession.currentState is! AuthAuthenticated) {
      _pendingSessionRoute = route;
      return;
    }
    _pendingSessionRoute = null;
    _dispatch(route);
  }

  void _onAuthStateChanged(AuthState state) {
    if (state is! AuthAuthenticated || _authSession.currentState is! AuthAuthenticated) return;
    final route = _pendingSessionRoute;
    if (route == null) return;
    _pendingSessionRoute = null;
    _dispatch(route);
  }

  void _dispatch(AppRouteDeviceCanvasSession route) {
    _routeDispatcher.replaceStack(
      stack: RouteStack(
        paths: [
          const AppRoute.projects(),
          route,
        ].map((route) => route.buildPath()).toList(growable: false),
      ),
    );
  }

  @disposeMethod
  void dispose() {
    unawaited(_linkSubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    _linkSubscription = null;
    _authSubscription = null;
    _pendingSessionRoute = null;
  }
}
