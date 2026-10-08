import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:http/testing.dart";
import "package:opencode_plugin/src/api/open_code_service_command_api.dart";
import "package:opencode_plugin/src/api/open_code_service_registration_api.dart";
import "package:opencode_plugin/src/repositories/open_code_shared_server_repository.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show HostProcessCommandExecutor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show HostProcessService;
import "package:test/test.dart";

const String _password = "service-secret";

void main() {
  late Directory root;
  late List<http.Request> requests;

  setUp(() {
    root = Directory.systemTemp.createTempSync("opencode-shared-server-");
    requests = <http.Request>[];
  });

  tearDown(() => root.deleteSync(recursive: true));

  void register({required String stateRoot, required Object registration}) {
    final file = File(p.join(stateRoot, "opencode", "service.json"))..createSync(recursive: true);
    file.writeAsStringSync(registration is String ? registration : jsonEncode(registration));
  }

  Map<String, Object?> registration({String url = "http://127.0.0.1:49374", int pid = 321}) => {
    "id": "service-id",
    "version": "2.0.25",
    "url": url,
    "pid": pid,
    "password": _password,
  };

  OpenCodeSharedServerRepository repository({required Future<http.Response> Function(http.Request) handler}) {
    return OpenCodeSharedServerRepository(
      registrationApi: const OpenCodeServiceRegistrationApi(),
      // Discovery never runs the CLI.
      commandApi: OpenCodeServiceCommandApi(
        executor: HostProcessCommandExecutor(
          processes: const _NoProcesses(),
          runInShell: false,
          includeParentEnvironment: true,
          maxCapturedOutputCharactersPerStream: null,
        ),
      ),
      probeClientFactory: () => MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
  }

  Future<http.Response> info(http.Request _) async => http.Response(jsonEncode({"version": "2.0.25", "pid": 321}), 200);

  test("returns the registered server when it answers for the registered pid", () async {
    register(stateRoot: root.path, registration: registration());

    final endpoint = await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path});

    expect(endpoint, isNotNull);
    expect(endpoint!.url, equals("http://127.0.0.1:49374"));
    expect(endpoint.password, equals(_password));
    expect(endpoint.version.raw, equals("2.0.25"));
    expect(requests.single.url.path, equals("/api/info"));
    expect(
      requests.single.headers["Authorization"],
      equals("Basic ${base64Encode(utf8.encode("opencode:$_password"))}"),
    );
  });

  test("uses <home>/.local/state when XDG_STATE_HOME is unset or empty", () async {
    register(stateRoot: p.join(root.path, ".local", "state"), registration: registration());

    for (final environment in [
      {"HOME": root.path, "USERPROFILE": root.path},
      {"HOME": root.path, "USERPROFILE": root.path, "XDG_STATE_HOME": ""},
    ]) {
      expect(await repository(handler: info).discover(environment: environment), isNotNull);
    }
  });

  test("XDG_STATE_HOME wins over the home directory", () async {
    register(stateRoot: p.join(root.path, ".local", "state"), registration: registration());
    final emptyState = Directory(p.join(root.path, "xdg"))..createSync();

    final endpoint = await repository(
      handler: info,
    ).discover(environment: {"HOME": root.path, "USERPROFILE": root.path, "XDG_STATE_HOME": emptyState.path});

    expect(endpoint, isNull);
    expect(requests, isEmpty);
  });

  test("finds nothing without a registration file or a home directory", () async {
    expect(await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path}), isNull);
    expect(await repository(handler: info).discover(environment: const {"PATH": "/usr/bin"}), isNull);
    expect(requests, isEmpty);
  });

  test("ignores a corrupt or incomplete registration without probing", () async {
    for (final corrupt in <Object>[
      "{not json",
      "[]",
      {"url": "http://127.0.0.1:49374"},
      {"url": 7, "pid": 321},
    ]) {
      register(stateRoot: root.path, registration: corrupt);
      expect(await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path}), isNull);
    }
    File(p.join(root.path, "opencode", "service.json")).writeAsBytesSync([0xff, 0xfe, 0x7b]);
    expect(await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path}), isNull);
    expect(requests, isEmpty);
  });

  test("ignores a URL it cannot reach as plain http host:port", () async {
    for (final url in [
      "https://127.0.0.1:49374",
      "http://127.0.0.1",
      "http://127.0.0.1:49374/prefix",
      "127.0.0.1:49374",
    ]) {
      register(
        stateRoot: root.path,
        registration: registration(url: url),
      );
      expect(
        await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path}),
        isNull,
        reason: url,
      );
    }
    expect(requests, isEmpty);
  });

  test("connects to the registered host as listed, reaching a wildcard bind over loopback", () async {
    final cases = {
      "http://0.0.0.0:49374": "http://127.0.0.1:49374",
      "http://[::]:49374": "http://[::1]:49374",
      "http://[::1]:49374/": "http://[::1]:49374",
      "http://192.168.1.20:49374": "http://192.168.1.20:49374",
    };
    for (final MapEntry(key: registered, value: expected) in cases.entries) {
      register(
        stateRoot: root.path,
        registration: registration(url: registered),
      );
      final endpoint = await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path});
      expect(endpoint?.url, equals(expected), reason: registered);
    }
  });

  test("rejects a server that is booting, failed, foreign, or unreachable", () async {
    register(stateRoot: root.path, registration: registration());
    final handlers = <String, Future<http.Response> Function(http.Request)>{
      "booting": (_) async => http.Response("", 503),
      "failed": (_) async => http.Response("", 500),
      "incompatible": (_) async => http.Response("", 404),
      "html": (_) async => http.Response("<!doctype html>", 200),
      "other pid": (_) async => http.Response(jsonEncode({"version": "2.0.25", "pid": 999}), 200),
      "no pid": (_) async => http.Response(jsonEncode({"version": "2.0.25"}), 200),
      "unreachable": (_) async => throw const SocketException("connection refused"),
    };
    for (final MapEntry(key: name, value: handler) in handlers.entries) {
      expect(
        await repository(handler: handler).discover(environment: {"XDG_STATE_HOME": root.path}),
        isNull,
        reason: name,
      );
    }
  });

  test("rejects a server older than the v2 minimum or without a version", () async {
    register(stateRoot: root.path, registration: registration());
    for (final version in <String?>["2.0.10", "1.18.32", "not-a-version", null]) {
      final endpoint = await repository(
        handler: (_) async => http.Response(jsonEncode({"version": version, "pid": 321}), 200),
      ).discover(environment: {"XDG_STATE_HOME": root.path});
      expect(endpoint, isNull, reason: "$version");
    }
  });

  test("probes without authentication when the registration has no password", () async {
    register(stateRoot: root.path, registration: {"url": "http://127.0.0.1:49374", "pid": 321});

    final endpoint = await repository(handler: info).discover(environment: {"XDG_STATE_HOME": root.path});

    expect(endpoint?.password, isNull);
    expect(requests.single.headers.containsKey("Authorization"), isFalse);
  });
}

class const _NoProcesses() implements HostProcessService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError("discovery must not run a process");
}
