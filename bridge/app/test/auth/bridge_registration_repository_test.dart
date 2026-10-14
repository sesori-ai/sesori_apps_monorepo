import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/auth_api.dart";
import "package:sesori_bridge/src/auth/bridge_registration_repository.dart";
import "package:sesori_bridge/src/auth/machine_id_api.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:test/test.dart";

import "../helpers/fake_command_executor.dart";

void main() {
  group("BridgeRegistrationRepository.hostKeyFor", () {
    test("is the salted SHA-256 of the machine id as lowercase hex", () {
      final key = BridgeRegistrationRepository.hostKeyFor(machineId: "abc123");

      expect(key, matches(RegExp(r"^[0-9a-f]{64}$")));
      expect(key, BridgeRegistrationRepository.hostKeyFor(machineId: "abc123"));
      expect(key, sha256.convert(utf8.encode("sesori-bridge-host-key-v1abc123")).toString());
      expect(key, isNot(sha256.convert(utf8.encode("abc123")).toString()));
    });
  });

  group("BridgeRegistrationRepository.register", () {
    test("sends the host key, never the raw machine id, and reads the id once", () async {
      final runner = FakeCommandExecutor(
        results: {"cat /etc/machine-id": commandOutput(stdout: "abc123\n")},
      );
      final bodies = <String?>[];
      final repository = _repository(runner: runner, bodies: bodies);

      await repository.register(name: "dev", platform: "linux", bridgeId: null, accessToken: "token");
      await repository.register(name: "dev", platform: "linux", bridgeId: "br_existing01", accessToken: "token");

      final first = jsonDecode(bodies.first ?? "") as Map<String, dynamic>;
      expect(first["hostKey"], BridgeRegistrationRepository.hostKeyFor(machineId: "abc123"));
      expect(bodies.every((body) => !(body ?? "").contains("abc123")), isTrue);
      expect(runner.commands, ["cat /etc/machine-id"]);
    });

    test("omits the host key when the machine id cannot be read", () async {
      final bodies = <String?>[];
      final repository = _repository(
        runner: FakeCommandExecutor(results: {}),
        bodies: bodies,
      );

      await repository.register(name: "dev", platform: "linux", bridgeId: null, accessToken: "token");

      expect(jsonDecode(bodies.single ?? ""), {"name": "dev", "platform": "linux"});
    });
  });
}

BridgeRegistrationRepository _repository({
  required FakeCommandExecutor runner,
  required List<String?> bodies,
}) {
  final client = http.Client();
  addTearDown(client.close);
  return BridgeRegistrationRepository(
    api: AuthApi(
      authBackendUrl: "https://auth.example",
      client: client,
      requestDeadline: AuthApi.defaultRequestDeadline,
      sendRequest:
          ({
            required client,
            required method,
            required url,
            required headers,
            required body,
            required deadline,
          }) async {
            bodies.add(body);
            return http.Response(
              '{"id":"br_server001","name":"dev","platform":"linux","status":"active","addedAt":"2026-06-01T00:00:00.000Z"}',
              HttpStatus.ok,
            );
          },
    ),
    machineIdApi: MachineIdApi.forPlatform(platform: PlatformOs.linux, commandExecutor: runner),
  );
}
