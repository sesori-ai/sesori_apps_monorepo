import "dart:io";

import "package:sesori_dart_core/src/foundation/io/plugin_authentication_loopback_server.dart";
import "package:test/test.dart";

Future<int> _unusedLoopbackPort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

Future<HttpClientResponse> _get({required Uri uri}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri)
      ..followRedirects = false;
    return await request.close();
  } finally {
    client.close();
  }
}

void main() {
  test("captures only exact GET path and returns nonce-only bounce", () async {
    final port = await _unusedLoopbackPort();
    final expected = Uri.parse("http://127.0.0.1:$port/callback");
    final bounce = Uri.parse("com.sesori.auth://complete/nonce-only");
    final session = await PluginAuthenticationLoopbackServer().bind(
      expectedCallbackUri: expected,
      bounceUri: bounce,
    );
    addTearDown(session.close);

    expect((await _get(uri: expected.replace(path: "/wrong"))).statusCode, HttpStatus.notFound);
    final response = await _get(uri: expected.replace(queryParameters: const {"state": "state", "code": "code"}));

    expect(response.statusCode, HttpStatus.found);
    expect(response.headers.value(HttpHeaders.locationHeader), bounce.toString());
    expect(await session.callback, expected.replace(queryParameters: const {"state": "state", "code": "code"}));
    expect(bounce.query, isEmpty);
  });

  test("close settles a pending callback without an unobserved error", () async {
    final port = await _unusedLoopbackPort();
    final session = await PluginAuthenticationLoopbackServer().bind(
      expectedCallbackUri: Uri.parse("http://127.0.0.1:$port/callback"),
      bounceUri: null,
    );
    final callback = session.callback;

    await session.close();

    expect(await callback, isNull);
    final rebound = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await rebound.close();
  });
}
