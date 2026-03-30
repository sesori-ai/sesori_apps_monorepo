import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "app_router.dart";

/// Bridges [AppLinks] deep link events to the OAuth callback flow.
///
/// Listens for incoming custom-scheme URLs (e.g. `com.sesori.app://auth/callback`)
/// and delegates them to [AuthRedirectService] for token exchange, then navigates
/// via [appRouter].
@lazySingleton
class DeepLinkService {
  final AuthRedirectService _authRedirectService;
  final DeepLinkSource _deepLinkSource;
  StreamSubscription<Uri>? _sub;
  bool _processing = false;

  DeepLinkService(AuthRedirectService authRedirectService, DeepLinkSource deepLinkSource)
    : _authRedirectService = authRedirectService,
      _deepLinkSource = deepLinkSource;

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
    if (uri.scheme != bundleId || uri.host != "auth" || uri.path != "/callback") return;

    if (_processing) {
      logw("Deep link callback already being processed; ignoring duplicate event");
      return;
    }

    logd("Deep link received: $uri");
    _processing = true;

    try {
      final route = await _authRedirectService.handleOAuthCallback(uri);
      if (route != null) {
        try {
          appRouter.go(route.path);
        } catch (e, st) {
          loge("Failed to navigate after OAuth callback", e, st);
        }
      }
    } finally {
      _processing = false;
    }
  }

  @disposeMethod
  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
