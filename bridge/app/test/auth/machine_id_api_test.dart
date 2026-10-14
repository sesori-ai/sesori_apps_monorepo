import "package:sesori_bridge/src/auth/machine_id_api.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show CommandResult, PlatformOs;
import "package:test/test.dart";

import "../helpers/fake_command_executor.dart";

const _ioreg = "/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice";
const _reg = r"reg query HKLM\SOFTWARE\Microsoft\Cryptography /v MachineGuid /reg:64";

Future<String?> _read({required PlatformOs platform, required Map<String, CommandResult> results}) {
  return MachineIdApi.forPlatform(
    platform: platform,
    commandExecutor: FakeCommandExecutor(results: results),
  ).readMachineId();
}

void main() {
  group("macOS", () {
    test("reads IOPlatformUUID from ioreg", () async {
      final id = await _read(
        platform: PlatformOs.macos,
        results: {
          _ioreg: commandOutput(
            stdout:
                '+-o J316sAP  <class IOPlatformExpertDevice>\n'
                '    "IOPlatformSerialNumber" = "SERIAL"\n'
                '    "IOPlatformUUID" = "1A2B3C4D-0000-1111-2222-333344445555"\n',
          ),
        },
      );
      expect(id, "1A2B3C4D-0000-1111-2222-333344445555");
    });

    test("returns null when the UUID is missing or blank", () async {
      expect(
        await _read(
          platform: PlatformOs.macos,
          results: {_ioreg: commandOutput(stdout: "no uuid here")},
        ),
        isNull,
      );
      expect(
        await _read(
          platform: PlatformOs.macos,
          results: {_ioreg: commandOutput(stdout: '"IOPlatformUUID" = " "')},
        ),
        isNull,
      );
    });

    test("returns null when ioreg fails or exits non-zero", () async {
      expect(await _read(platform: PlatformOs.macos, results: {}), isNull);
      expect(
        await _read(
          platform: PlatformOs.macos,
          results: {_ioreg: const CommandResult(exitCode: 1, stdout: "", stderr: "boom")},
        ),
        isNull,
      );
    });
  });

  group("Linux", () {
    test("reads and trims /etc/machine-id", () async {
      final runner = FakeCommandExecutor(results: {"cat /etc/machine-id": commandOutput(stdout: "abc123\n")});
      final id = await MachineIdApi.forPlatform(platform: PlatformOs.linux, commandExecutor: runner).readMachineId();
      expect(id, "abc123");
      expect(runner.commands, ["cat /etc/machine-id"]);
    });

    test("falls back to the D-Bus machine id when /etc/machine-id is missing or blank", () async {
      final dbus = commandOutput(stdout: "dbus456\n");
      expect(await _read(platform: PlatformOs.linux, results: {"cat /var/lib/dbus/machine-id": dbus}), "dbus456");
      expect(
        await _read(
          platform: PlatformOs.linux,
          results: {
            "cat /etc/machine-id": commandOutput(stdout: "\n"),
            "cat /var/lib/dbus/machine-id": dbus,
          },
        ),
        "dbus456",
      );
    });

    test("returns null when neither file can be read", () async {
      expect(
        await _read(
          platform: PlatformOs.linux,
          results: {
            "cat /etc/machine-id": const CommandResult(exitCode: 1, stdout: "", stderr: "No such file or directory"),
          },
        ),
        isNull,
      );
    });
  });

  group("Windows", () {
    test("reads MachineGuid from the registry", () async {
      final id = await _read(
        platform: PlatformOs.windows,
        results: {
          _reg: commandOutput(
            stdout:
                "\r\nHKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography\r\n"
                "    MachineGuid    REG_SZ    9f8e7d6c-0000-1111-2222-333344445555\r\n\r\n",
          ),
        },
      );
      expect(id, "9f8e7d6c-0000-1111-2222-333344445555");
    });

    test("returns null when the value is missing or reg fails", () async {
      expect(
        await _read(
          platform: PlatformOs.windows,
          results: {_reg: commandOutput(stdout: "")},
        ),
        isNull,
      );
      expect(await _read(platform: PlatformOs.windows, results: {}), isNull);
    });
  });
}
