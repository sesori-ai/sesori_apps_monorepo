import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Bridges [AppLinks] deep link events to app routing.
///
/// Legacy OAuth deep-link callbacks are no longer used — the browser completes
/// against the auth server directly, while [OAuthFlowProvider.pollForResult]
/// updates auth state from [LoginCubit]. This service logs and ignores any
/// remaining OAuth callback deep links.
@lazySingleton
class DeepLinkService {
  final DeepLinkSource _deepLinkSource;
  StreamSubscription<Uri>? _sub;
  bool _processing = false;

  DeepLinkService(DeepLinkSource deepLinkSource) : _deepLinkSource = deepLinkSource;

  /// Start listening for deep links. Call once during app initialization.
  ///
  /// [AppLinks.uriLinkStream] covers both cold-start and warm-start links,
  /// so no separate [getInitialLink] call is needed.
  void init() {
    if (_sub != null) {
      logw("DeepLinkService.init() called more than once; ignoring");
      return;
    }

    _sub = _deepLinkSource.linkStream.listen(
      _handleUri,
      onError: (Object e) => loge("Deep link stream error", e),
    );
  }

  Future<void> _handleUri(Uri uri) async {
    // OAuth callbacks are no longer handled via deep links — the auth server
    // handles browser completion directly and clients poll for results.
    if (uri.scheme == bundleId && uri.host == "auth" && uri.path == "/callback") {
      if (_processing) {
        logw("Deep link callback already being processed; ignoring duplicate event");
        return;
      }

      logd("Ignoring legacy OAuth deep link: $uri");
      _processing = true;

      try {
        // No-op: OAuth now completes through auth-server polling
      } finally {
        _processing = false;
      }

      return;
    }

    // Future non-OAuth deep links can be handled here
    logd("Unhandled deep link: $uri");
  }

  @disposeMethod
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
