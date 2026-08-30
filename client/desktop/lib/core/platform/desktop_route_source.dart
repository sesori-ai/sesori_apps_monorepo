import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Route boundary for the pre-router desktop shell.
///
/// Desktop currently composes the auth gate directly rather than using the
/// shared router. Keeping a real [RouteSource] in the shell lets the shared
/// SSE toast and connection services start now; session-attributed toasts are
/// correctly withheld until Step 14 supplies a route identity, while
/// unattributed app-wide toasts remain available.
@Singleton(as: RouteSource)
class DesktopRouteSource() implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRoute = BehaviorSubject.seeded(null);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  @override
  String? get currentLocation => null;

  /// Closes the stream when a test or shell explicitly tears down the source.
  /// The desktop process owns this singleton for its whole lifetime.
  Future<void> dispose() => _currentRoute.close();
}
