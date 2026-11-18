import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

/// Sesori's MCP endpoint: streamable HTTP on the loopback interface, with
/// JSON responses only (no SSE stream and no `Mcp-Session-Id`).
///
/// A transport and nothing more. It refuses what no harness sends — a browser
/// `Origin`, a non-loopback `Host`, an oversized or non-JSON body, a missing
/// bearer token, any other path or method — and hands every other request to
/// [requests] undecided. Whoever listens decides who the token belongs to.
class SesoriMcpServer._({required final HttpServer _server}) {
  /// The largest request body read. Agent tool calls are small; this bounds
  /// what a stray local client can make the bridge buffer.
  static const int maxRequestBytes = 1024 * 1024;

  static const String _path = "/mcp";

  /// Single-subscription, so a request that arrives before the listener
  /// subscribes waits instead of hanging unanswered.
  final StreamController<SesoriMcpInboundRequest> _requests = StreamController<SesoriMcpInboundRequest>();

  this {
    _server.listen(_handle);
  }

  /// Binds an ephemeral port on 127.0.0.1.
  static Future<SesoriMcpServer> bindLoopback() async {
    return SesoriMcpServer._(server: await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
  }

  Uri get url => Uri(scheme: "http", host: InternetAddress.loopbackIPv4.address, port: _server.port, path: _path);

  Stream<SesoriMcpInboundRequest> get requests => _requests.stream;

  /// Stops accepting requests and drops open connections.
  Future<void> close() async {
    await _server.close(force: true);
    await _requests.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      final refusal = _refusal(request: request);
      if (refusal != null) {
        await _reply(request: request, status: refusal);
        return;
      }
      final token = _bearerToken(request: request);
      if (token == null) {
        await _reply(request: request, status: HttpStatus.unauthorized);
        return;
      }
      final body = await _readBody(request: request);
      if (body == null) {
        await _reply(request: request, status: HttpStatus.requestEntityTooLarge);
        return;
      }
      if (_requests.isClosed) {
        await _reply(request: request, status: HttpStatus.serviceUnavailable);
        return;
      }
      _requests.add(SesoriMcpInboundRequest._(token: token, body: body, response: response));
    } on Object catch (error, stackTrace) {
      Log.w("Refusing a Sesori MCP request that could not be read", error, stackTrace);
      await _reply(request: request, status: HttpStatus.badRequest);
    }
  }

  /// The status that refuses [request] before its body is read, or null.
  int? _refusal({required HttpRequest request}) {
    // Harnesses never send Origin; a browser always does. Refusing it closes
    // the endpoint to web pages, DNS-rebound or not.
    if (request.headers.value("origin") != null) return HttpStatus.forbidden;
    if (!_isLoopbackHost(request: request)) return HttpStatus.forbidden;
    if (request.uri.path != _path) return HttpStatus.notFound;
    if (request.method != "POST") return HttpStatus.methodNotAllowed;
    if (request.headers.contentType?.mimeType != ContentType.json.mimeType) return HttpStatus.unsupportedMediaType;
    if (request.contentLength > maxRequestBytes) return HttpStatus.requestEntityTooLarge;
    return null;
  }

  bool _isLoopbackHost({required HttpRequest request}) {
    final host = request.headers.host;
    final port = request.headers.port;
    return (host == InternetAddress.loopbackIPv4.address || host == "localhost") && port == _server.port;
  }

  static String? _bearerToken({required HttpRequest request}) {
    final values = request.headers[HttpHeaders.authorizationHeader];
    if (values == null || values.length != 1) return null;
    const scheme = "Bearer ";
    final value = values.single;
    if (!value.startsWith(scheme)) return null;
    final token = value.substring(scheme.length).trim();
    return token.isEmpty ? null : token;
  }

  /// The UTF-8 body, or null when it outgrows [maxRequestBytes]. An oversized
  /// body is read to its end without being kept, since stopping early drops
  /// the connection before the refusal goes out.
  static Future<String?> _readBody({required HttpRequest request}) async {
    final bytes = BytesBuilder(copy: false);
    var oversized = false;
    await for (final chunk in request) {
      if (oversized) continue;
      if (bytes.length + chunk.length > maxRequestBytes) {
        oversized = true;
        bytes.clear();
        continue;
      }
      bytes.add(chunk);
    }
    return oversized ? null : utf8.decode(bytes.takeBytes());
  }

  static Future<void> _reply({required HttpRequest request, required int status}) async {
    final response = request.response;
    try {
      response.statusCode = status;
      if (status == HttpStatus.methodNotAllowed) response.headers.set(HttpHeaders.allowHeader, "POST");
      if (status == HttpStatus.unauthorized) response.headers.set(HttpHeaders.wwwAuthenticateHeader, "Bearer");
      response.persistentConnection = false;
      response.contentLength = 0;
      if (status == HttpStatus.requestEntityTooLarge && request.contentLength > maxRequestBytes) {
        // The body is still unread; closing normally would wait to drain all
        // of what the client declared.
        final socket = await response.detachSocket();
        await socket.flush();
        socket.destroy();
        return;
      }
      await response.close();
    } on Object catch (error, stackTrace) {
      Log.w("Failed to refuse a Sesori MCP request", error, stackTrace);
    }
  }
}

/// One request that passed the transport checks: its bearer token, its raw
/// body and the handle that answers it. Answer each exactly once.
final class SesoriMcpInboundRequest._({
  required final String token,
  required final String body,
  required final HttpResponse _response,
}) {
  Future<void> respond({required SesoriMcpReply reply}) async {
    try {
      switch (reply) {
        case SesoriMcpJsonReply(:final body):
          final bytes = utf8.encode(body);
          _response.statusCode = HttpStatus.ok;
          _response.headers.contentType = ContentType.json;
          _response.contentLength = bytes.length;
          _response.add(bytes);
        case SesoriMcpAcceptedReply():
          _response.statusCode = HttpStatus.accepted;
        case SesoriMcpUnauthorizedReply():
          _response.statusCode = HttpStatus.unauthorized;
          _response.headers.set(HttpHeaders.wwwAuthenticateHeader, "Bearer");
      }
      await _response.close();
    } on Object catch (error, stackTrace) {
      Log.w("Failed to answer a Sesori MCP request", error, stackTrace);
    }
  }
}

/// How a Sesori MCP request is answered.
sealed class const SesoriMcpReply();

/// A JSON-RPC response body.
final class const SesoriMcpJsonReply({required final String body}) extends SesoriMcpReply;

/// A notification, which gets no body.
final class const SesoriMcpAcceptedReply() extends SesoriMcpReply;

/// A token the bridge did not mint.
final class const SesoriMcpUnauthorizedReply() extends SesoriMcpReply;
