import "dart:async";
import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/foundation/sesori_mcp_server.dart";
import "package:test/test.dart";

typedef _RawResponse = ({int status, Map<String, String> headers, String body});

void main() {
  late SesoriMcpServer server;
  late List<SesoriMcpInboundRequest> received;

  setUp(() async {
    server = await SesoriMcpServer.bindLoopback();
    addTearDown(server.close);
    received = [];
    server.requests.listen((request) {
      received.add(request);
      unawaited(request.respond(reply: const SesoriMcpJsonReply(body: '{"ok":true}')));
    });
  });

  String hostHeader() => "127.0.0.1:${server.url.port}";

  /// Sends raw HTTP, so a test controls every header, Host included.
  Future<_RawResponse> send({
    String method = "POST",
    String path = "/mcp",
    String? host,
    Map<String, String> headers = const {
      "Content-Type": "application/json",
      "Authorization": "Bearer token-1",
    },
    String body = '{"jsonrpc":"2.0","id":1,"method":"ping"}',
    bool chunked = false,
  }) async {
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, server.url.port);
    final responseBytes = <int>[];
    final done = socket.listen(responseBytes.addAll).asFuture<void>().catchError((Object _) {});
    final bodyBytes = utf8.encode(body);
    final head = StringBuffer()
      ..write("$method $path HTTP/1.1\r\n")
      ..write("Host: ${host ?? hostHeader()}\r\n")
      ..write("Connection: close\r\n");
    headers.forEach((name, value) => head.write("$name: $value\r\n"));
    if (chunked) {
      head.write("Transfer-Encoding: chunked\r\n\r\n");
      socket
        ..add(utf8.encode(head.toString()))
        ..add(utf8.encode("${bodyBytes.length.toRadixString(16)}\r\n"))
        ..add(bodyBytes)
        ..add(utf8.encode("\r\n0\r\n\r\n"));
    } else {
      if (!headers.containsKey("Content-Length")) head.write("Content-Length: ${bodyBytes.length}\r\n");
      head.write("\r\n");
      socket
        ..add(utf8.encode(head.toString()))
        ..add(bodyBytes);
    }
    unawaited(socket.flush().catchError((Object _) {}));
    await done;
    socket.destroy();
    final text = utf8.decode(responseBytes, allowMalformed: true);
    final [rawHead, ...rest] = text.split("\r\n\r\n");
    final [statusLine, ...headerLines] = rawHead.split("\r\n");
    return (
      status: int.parse(statusLine.split(" ")[1]),
      headers: {
        for (final line in headerLines)
          line.substring(0, line.indexOf(":")).toLowerCase(): line.substring(line.indexOf(":") + 1).trim(),
      },
      body: rest.join("\r\n\r\n"),
    );
  }

  test("binds an ephemeral loopback port and serves /mcp there", () {
    expect(server.url.scheme, "http");
    expect(server.url.host, "127.0.0.1");
    expect(server.url.port, isNot(0));
    expect(server.url.path, "/mcp");
  });

  test("hands a well-formed request to its listener with token and body", () async {
    final response = await send();

    expect(response.status, HttpStatus.ok);
    expect(response.body, '{"ok":true}');
    expect(received.single.token, "token-1");
    expect(received.single.body, '{"jsonrpc":"2.0","id":1,"method":"ping"}');
  });

  test("accepts localhost as the Host", () async {
    expect((await send(host: "localhost:${server.url.port}")).status, HttpStatus.ok);
  });

  test("refuses any request a browser sends, by its Origin", () async {
    final response = await send(
      headers: const {
        "Content-Type": "application/json",
        "Authorization": "Bearer token-1",
        "Origin": "https://evil.example",
      },
    );

    expect(response.status, HttpStatus.forbidden);
    expect(received, isEmpty);
  });

  test("refuses a non-loopback Host, as a DNS-rebound page would send", () async {
    expect((await send(host: "evil.example:${server.url.port}")).status, HttpStatus.forbidden);
    expect((await send(host: "127.0.0.1:1")).status, HttpStatus.forbidden);
    expect(received, isEmpty);
  });

  test("refuses another path, method or content type", () async {
    expect((await send(path: "/other")).status, HttpStatus.notFound);
    final get = await send(method: "GET", body: "");
    expect(get.status, HttpStatus.methodNotAllowed);
    expect(get.headers["allow"], "POST");
    final text = await send(headers: const {"Content-Type": "text/plain", "Authorization": "Bearer token-1"});
    expect(text.status, HttpStatus.unsupportedMediaType);
    expect(received, isEmpty);
  });

  test("refuses a request without a bearer token", () async {
    final missing = await send(headers: const {"Content-Type": "application/json"});
    expect(missing.status, HttpStatus.unauthorized);
    expect(missing.headers["www-authenticate"], "Bearer");
    final basic = await send(headers: const {"Content-Type": "application/json", "Authorization": "Basic dXNlcg=="});
    expect(basic.status, HttpStatus.unauthorized);
    final empty = await send(headers: const {"Content-Type": "application/json", "Authorization": "Bearer "});
    expect(empty.status, HttpStatus.unauthorized);
    expect(received, isEmpty);
  });

  test("refuses a body over the size limit, declared or streamed", () async {
    final declared = await send(
      headers: const {
        "Content-Type": "application/json",
        "Authorization": "Bearer token-1",
        "Content-Length": "${SesoriMcpServer.maxRequestBytes + 1}",
      },
      body: "",
    );
    expect(declared.status, HttpStatus.requestEntityTooLarge);

    final streamed = await send(body: "x" * (SesoriMcpServer.maxRequestBytes + 1), chunked: true);
    expect(streamed.status, HttpStatus.requestEntityTooLarge);
    expect(received, isEmpty);
  });

  test("passes a body at the size limit", () async {
    final response = await send(body: "x" * SesoriMcpServer.maxRequestBytes, chunked: true);

    expect(response.status, HttpStatus.ok);
    expect(received.single.body.length, SesoriMcpServer.maxRequestBytes);
  });
}
