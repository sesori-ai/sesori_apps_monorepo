import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:args/args.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Dev-only harness that drives the bridge's **supervised mode** without the
/// desktop GUI (which doesn't exist yet — Phase 2). It stands in for the GUI's
/// control-channel host so a human can exercise the whole Phase-1 supervised
/// surface end-to-end (the MT-1 manual checkpoint).
///
/// It hosts a loopback WebSocket control server, spawns a locally-built bridge
/// with `--control-url`, hands the per-spawn secret to the child off-argv (first
/// stdin line, ADR A8), answers `token_request` from the developer's own
/// `token.json` (or the `SESORI_DEV_CONTROL_TOKEN` env var — kept off argv, which
/// other local processes can read), prints every inbound [ControlMessage],
/// and offers keyboard commands to push a token, log out, answer prompts, and
/// simulate the GUI vanishing so the helper's grace-period exit (ADR A9) can be
/// observed.
///
/// This file lives in `tool/` and is never compiled into the shipped binary
/// (`dart build cli` compiles `bin/bridge.dart` only). It adds no production
/// wiring and no new dependencies.
///
/// Usage (from `bridge/app/`, after `dart build cli -o build/cli`):
/// ```sh
/// dart run tool/dev_control_host.dart --bridge build/cli/bundle/bin/bridge \
///   -- --log-level debug
/// ```
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      "bridge",
      help: "Path to a locally-built bridge binary (e.g. build/cli/bundle/bin/bridge).",
    )
    ..addFlag(
      "deny-token",
      negatable: false,
      help: "Start denying tokens (token_request -> null) to exercise the exit-87 / sign-out paths.",
    )
    ..addFlag("help", abbr: "h", negatable: false, help: "Show usage.");

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (error) {
    stderr.writeln("dev_control_host: ${error.message}\n");
    stderr.writeln(_usage(parser));
    await _flushAndExit(64);
  }

  if (results.flag("help")) {
    stdout.writeln(_usage(parser));
    return;
  }

  final bridgePath = results.option("bridge");
  if (bridgePath == null || bridgePath.isEmpty) {
    stderr.writeln("Missing required --bridge <path>.\n");
    stderr.writeln(_usage(parser));
    await _flushAndExit(64);
  }

  // The token override is read from the environment (not a CLI flag): argv is
  // visible to other local processes via `ps`/`/proc`, and this token
  // authenticates the supervised bridge.
  final envToken = Platform.environment["SESORI_DEV_CONTROL_TOKEN"];
  final token = (envToken != null && envToken.isNotEmpty) ? envToken : _readStoredToken();

  final host = _DevControlHost(
    bridgePath: bridgePath,
    bridgeArgs: results.rest,
    token: token,
    denyToken: results.flag("deny-token"),
  );
  await host.run();
}

String _usage(ArgParser parser) {
  return "Usage: dart run tool/dev_control_host.dart --bridge <path> [--deny-token] [-- <bridge args>]\n\n"
      "${parser.usage}\n\n"
      "The access token defaults to token.json's accessToken; set SESORI_DEV_CONTROL_TOKEN to override\n"
      "it off-argv. Everything after `--` is forwarded verbatim to the bridge (e.g. --log-level debug).";
}

/// Reads the developer's own access token from the standalone bridge's
/// `token.json`. Returns null (and explains why) when it is missing or
/// unreadable so the harness can still run token-less (answering `token_request`
/// with null, which exercises the signed-out / exit-87 paths).
String? _readStoredToken() {
  final String path;
  try {
    path = "${sesoriDataDirectory()}/token.json";
  } on Object catch (error) {
    stderr.writeln("Could not resolve the Sesori data directory ($error). Continuing token-less.");
    return null;
  }

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln("No token at $path — log in with the standalone bridge once, or pass --token. Continuing token-less.");
    return null;
  }

  try {
    final json = jsonDecodeMap(file.readAsStringSync());
    final token = json["accessToken"];
    if (token is String && token.isNotEmpty) {
      return token;
    }
    stderr.writeln("token.json has no usable accessToken. Continuing token-less.");
    return null;
  } on Object catch (error, stackTrace) {
    stderr.writeln("Could not read token.json ($error). Continuing token-less.\n$stackTrace");
    return null;
  }
}

String _generateSecret() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// Flushes stdout/stderr before terminating: `dart:io`'s [exit] stops the VM
/// immediately and can drop buffered output (e.g. when the harness is piped to
/// a file), so the final status line would otherwise be lost. The `finally`
/// guarantees the exit even if a flush fails on a broken pipe.
Future<Never> _flushAndExit(int code) async {
  try {
    await stdout.flush();
    await stderr.flush();
  } finally {
    exit(code);
  }
}

/// Owns one harness session: the per-spawn secret, the loopback control server,
/// the single connected helper socket, and the pending-prompt bookkeeping. It
/// speaks the real [ControlMessage] wire protocol so it stays on the exact
/// GUI<->helper contract the desktop app will implement in Phase 2.
class _DevControlHost {
  _DevControlHost({
    required String bridgePath,
    required List<String> bridgeArgs,
    required String? token,
    required bool denyToken,
  })  : _bridgePath = bridgePath,
        _bridgeArgs = bridgeArgs,
        _token = token,
        _denyToken = denyToken,
        _secret = _generateSecret();

  final String _bridgePath;
  final List<String> _bridgeArgs;
  final String? _token;
  final String _secret;

  bool _denyToken;
  final List<String> _pendingPrompts = <String>[];

  HttpServer? _server;
  WebSocket? _socket;

  Future<void> run() async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    } on Object catch (error) {
      stderr.writeln("Could not bind the loopback control server: $error");
      await _flushAndExit(70);
    }
    _server = server;
    final controlUrl = "ws://127.0.0.1:${server.port}";
    server.listen(
      (request) => unawaited(_handleHttpRequest(request)),
      onError: (Object error, StackTrace stackTrace) => stderr.writeln("control server error: $error"),
    );

    _printBanner(controlUrl);
    stdin.transform(utf8.decoder).transform(const LineSplitter()).listen(
          _onCommand,
          onError: (Object error, StackTrace stackTrace) => stderr.writeln("stdin error: $error"),
        );

    await _spawnBridge(controlUrl: controlUrl);
    // The event loop keeps the harness alive (listening server + stdin + the
    // child's exitCode future) until the child exits or the dev quits.
  }

  Future<void> _spawnBridge({required String controlUrl}) async {
    stdout.writeln("spawning: $_bridgePath --control-url $controlUrl ${_bridgeArgs.join(" ")}");
    final Process child;
    try {
      child = await Process.start(_bridgePath, ["--control-url", controlUrl, ..._bridgeArgs]);
    } on Object catch (error) {
      stderr.writeln("Failed to spawn the bridge at '$_bridgePath': $error");
      await _flushAndExit(70);
    }

    // Wire observation BEFORE handing off the secret, so a child that crashes
    // immediately (bad path, missing dependency) is still reported via its exit
    // code instead of being masked by a broken-pipe throw on the stdin write.
    child.stdout.transform(utf8.decoder).listen(
          (chunk) => stdout.write(chunk),
          onError: (Object error, StackTrace stackTrace) => stderr.writeln("bridge stdout pipe error: $error"),
        );
    child.stderr.transform(utf8.decoder).listen(
          (chunk) => stderr.write(chunk),
          onError: (Object error, StackTrace stackTrace) => stderr.writeln("bridge stderr pipe error: $error"),
        );
    unawaited(child.exitCode.then(_onChildExit));

    // Deliver the per-spawn secret off-argv as the first stdin line (ADR A8).
    // Best-effort: if the child already exited, the write throws a broken-pipe
    // error — log it and let the exit-code handler above report the exit.
    try {
      child.stdin.writeln(_secret);
      await child.stdin.flush();
    } on Object catch (error) {
      stderr.writeln("Failed to deliver the secret to the bridge (it may have exited): $error");
    }
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    // A premature client disconnect can make the upgrade or a response close
    // throw; catch it so one bad connection never crashes the harness server.
    try {
      // The helper presents the per-spawn secret as the WS upgrade bearer;
      // reject anything that doesn't match so a leaked/absent secret can't attach.
      final authorization = request.headers.value(HttpHeaders.authorizationHeader);
      if (authorization != "Bearer $_secret") {
        stderr.writeln("Rejecting control upgrade: bad or missing Authorization header.");
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }
      if (_socket != null) {
        // One authenticated helper per spawn, mirroring the real control server.
        stderr.writeln("A helper is already connected; rejecting the extra connection.");
        request.response.statusCode = HttpStatus.conflict;
        await request.response.close();
        return;
      }

      final socket = await WebSocketTransformer.upgrade(request);
      _socket = socket;
      stdout.writeln("[ok] helper connected — secret verified");
      socket.listen(
        _onFrameData,
        onError: (Object error, StackTrace stackTrace) {
          stderr.writeln("helper socket error: $error");
          _clearSocket(socket);
        },
        onDone: () {
          stdout.writeln("[--] helper closed the control socket");
          _clearSocket(socket);
        },
        cancelOnError: false,
      );
    } on Object catch (error) {
      stderr.writeln("Error handling a control-upgrade request: $error");
    }
  }

  /// Drops the current helper socket when it disconnects (only if it is still
  /// the one we hold), so the helper's normal reconnect is accepted instead of
  /// being rejected as "already connected" — the harness must exercise the real
  /// reconnect / control-loss behaviour.
  void _clearSocket(WebSocket socket) {
    if (identical(_socket, socket)) {
      _socket = null;
    }
  }

  void _onFrameData(dynamic data) {
    String? frame;
    if (data is String) {
      frame = data;
    } else if (data is List<int>) {
      // Control frames are UTF-8 JSON; tolerate a malformed binary frame instead
      // of letting the decode throw and tear down the socket listener.
      frame = utf8.decode(data, allowMalformed: true);
    }
    if (frame == null) {
      stderr.writeln("ignoring non-text control frame: ${data.runtimeType}");
      return;
    }

    final ControlMessage message;
    try {
      message = ControlMessage.fromJson(jsonDecodeMap(frame));
    } on Object catch (error) {
      stderr.writeln("[helper->harness] undecodable frame ($error): $frame");
      return;
    }

    stdout.writeln("[helper->harness] ${_describe(message)}");
    _react(message);
  }

  /// Human-readable one-liner for a control message with access tokens redacted,
  /// so a saved harness/MT-1 terminal log never captures the developer's bearer
  /// token (Freezed's `toString()` would otherwise print `accessToken` in full).
  String _describe(ControlMessage message) {
    if (message is ControlTokenResponse) {
      final token = message.accessToken == null ? "null" : "<redacted>";
      return "ControlMessage.tokenResponse(id: ${message.id}, accessToken: $token)";
    }
    if (message is ControlTokenUpdate) {
      return "ControlMessage.tokenUpdate(accessToken: <redacted>)";
    }
    return message.toString();
  }

  void _react(ControlMessage message) {
    switch (message) {
      case ControlTokenRequest(:final id, :final forceRefresh):
        _respondToken(id: id, forceRefresh: forceRefresh);
      case ControlPromptRequest(:final id, :final kind, message: final promptMessage):
        _pendingPrompts.add(id);
        stdout.writeln("  >> prompt [$id] $kind: ${promptMessage ?? "(no message)"} — reply 'y $id' or 'n $id'");
      // The remaining variants are informational (already printed above) or are
      // GUI->helper messages the harness would not normally receive back.
      case ControlTokenResponse():
      case ControlTokenUpdate():
      case ControlStatus():
      case ControlPromptResponse():
      case ControlRestart():
      case ControlUnregisterAndExit():
      case ControlRegistered():
      case ControlProvisionProgressMessage():
        break;
    }
  }

  void _respondToken({required String id, required bool forceRefresh}) {
    final token = _denyToken ? null : _token;
    if (token == null) {
      stdout.writeln("  << token_request[$id]: replying NULL (denyToken=$_denyToken, hasToken=${_token != null})");
    } else {
      stdout.writeln("  << token_request[$id] (forceRefresh=$forceRefresh): replying with token");
    }
    _send(ControlMessage.tokenResponse(id: id, accessToken: token));
  }

  void _onCommand(String line) {
    final parts = line.trim().split(RegExp(r"\s+"));
    final command = parts.first.toLowerCase();
    final argument = parts.length > 1 ? parts[1] : null;
    switch (command) {
      case "":
        break;
      case "t":
      case "token":
        _pushTokenUpdate();
      case "u":
      case "unregister":
        _send(const ControlMessage.unregisterAndExit());
      case "y":
      case "a":
        _answerPrompt(accepted: true, id: argument);
      case "n":
        _answerPrompt(accepted: false, id: argument);
      case "x":
      case "deny":
        _denyToken = !_denyToken;
        stdout.writeln("token denial is now ${_denyToken ? "ON" : "OFF"}");
      case "q":
      case "quit":
        unawaited(_simulateGuiGone());
      case "?":
      case "h":
      case "help":
        _printCommands();
      default:
        stderr.writeln("unknown command '$command' — type '?' for help");
    }
  }

  void _pushTokenUpdate() {
    final token = _denyToken ? null : _token;
    if (token == null) {
      stderr.writeln("no token to push (denyToken=$_denyToken, hasToken=${_token != null})");
      return;
    }
    _send(ControlMessage.tokenUpdate(accessToken: token));
  }

  void _answerPrompt({required bool accepted, required String? id}) {
    final promptId = id ?? (_pendingPrompts.isNotEmpty ? _pendingPrompts.first : null);
    if (promptId == null) {
      stderr.writeln("no pending prompt to answer");
      return;
    }
    _pendingPrompts.remove(promptId);
    _send(ControlMessage.promptResponse(id: promptId, accepted: accepted));
  }

  /// Closes the control channel (socket + server) so the helper's reconnects
  /// fail, letting the dev watch its ADR-A9 grace-period exit. The harness stays
  /// alive so it can still print the child's exit code when it terminates.
  Future<void> _simulateGuiGone() async {
    stdout.writeln("simulating GUI-gone: closing the control channel — the helper should exit after its ~5s grace (ADR A9)…");
    final socket = _socket;
    _socket = null;
    await socket?.close();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  void _send(ControlMessage message) {
    final socket = _socket;
    if (socket == null) {
      stderr.writeln("[harness->helper] no helper connected — dropping ${message.runtimeType}");
      return;
    }
    // Keep serialization outside the try so only the transport send is guarded:
    // add() throws StateError once the socket has closed, and _send runs
    // synchronously from the stdin command handler, so an uncaught throw here
    // would take down the harness.
    final payload = jsonEncode(message.toJson());
    try {
      socket.add(payload);
    } on Object catch (error) {
      stderr.writeln("[harness->helper] send failed (socket closed?): $error — dropping ${message.runtimeType}");
      return;
    }
    stdout.writeln("[harness->helper] ${_describe(message)}");
  }

  Future<void> _onChildExit(int code) async {
    stdout.writeln("== bridge exited with code $code (${_interpretExitCode(code)}) ==");
    await _flushAndExit(0);
  }

  String _interpretExitCode(int code) {
    switch (code) {
      case 0:
        return "clean stop / logout";
      case 1:
        return "control-channel lost (ADR A9 grace exit) or generic error";
      case 86:
        return "intentional restart — GUI would respawn";
      case 87:
        return "auth required — GUI would prompt for login";
      case 88:
        return "single-live contention — GUI would offer 'take over'";
      default:
        return "crash / unrecognized";
    }
  }

  void _printBanner(String controlUrl) {
    stdout.writeln("Sesori dev control-host harness");
    stdout.writeln("control URL : $controlUrl (loopback WS; per-spawn secret via child stdin)");
    final tokenState = _token == null ? "NONE (token_request -> null)" : "loaded from token.json / SESORI_DEV_CONTROL_TOKEN";
    stdout.writeln("token       : $tokenState${_denyToken ? "  [deny ON]" : ""}");
    _printCommands();
  }

  void _printCommands() {
    stdout.writeln(
      "commands: t=push token_update  u=unregister_and_exit  y/n [id]=answer prompt  "
      "x=toggle token-deny  q=simulate GUI-gone (grace exit)  ?=help",
    );
  }
}
