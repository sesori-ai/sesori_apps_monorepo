import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";

/// Owns one exact loopback callback listener. Binding never uses shared sockets.
@lazySingleton
class PluginAuthenticationLoopbackServer() {
  Future<PluginAuthenticationLoopbackSession> bind({
    required Uri expectedCallbackUri,
    required Uri? bounceUri,
  }) async {
    final server = await HttpServer.bind(expectedCallbackUri.host, expectedCallbackUri.port, shared: false);
    final session = PluginAuthenticationLoopbackSession._(
      server: server,
      expectedCallbackUri: expectedCallbackUri,
      bounceUri: bounceUri,
    );
    session._start();
    return session;
  }
}

class PluginAuthenticationLoopbackSession._({
  required final HttpServer _server,
  required final Uri expectedCallbackUri,
  required final Uri? bounceUri,
}) {
  final Completer<Uri?> _callback = Completer<Uri?>();
  StreamSubscription<HttpRequest>? _subscription;
  bool _closed = false;

  Future<Uri?> get callback => _callback.future;

  void _start() {
    _subscription = _server.listen(
      _handle,
      onError: (Object error, StackTrace stackTrace) {
        if (!_callback.isCompleted) _callback.completeError(error, stackTrace);
      },
      onDone: () {
        if (!_callback.isCompleted) _callback.complete(null);
      },
      cancelOnError: false,
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final matches =
        request.method == "GET" &&
        request.uri.path == expectedCallbackUri.path &&
        request.uri.userInfo.isEmpty &&
        request.uri.fragment.isEmpty;
    if (!matches || _callback.isCompleted) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final captured = Uri(
      scheme: expectedCallbackUri.scheme,
      host: expectedCallbackUri.host,
      port: expectedCallbackUri.port,
      path: expectedCallbackUri.path,
      query: request.uri.query,
    );
    final bounce = bounceUri;
    if (bounce != null) {
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, bounce.toString());
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          "<!doctype html><html><body><h1>Sign-in received</h1> "
          "<p>Return to Sesori to finish signing in.</p></body></html>",
        );
    }
    await request.response.close();
    if (!_callback.isCompleted) _callback.complete(captured);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_callback.isCompleted) _callback.complete(null);
    await _subscription?.cancel();
    await _server.close(force: true);
  }
}
