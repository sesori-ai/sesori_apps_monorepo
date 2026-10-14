import "dart:io";

import "package:sesori_bridge/src/auth/machine_id_api.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:test/test.dart";

import "../helpers/fake_command_process_runner.dart";

const _ioreg = "/usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice";
const _reg = r"reg query HKLM\SOFTWARE\Microsoft\Cryptography /v MachineGuid /reg:64";

Future<String?> _read({required PlatformOs platform, required Map<String, ProcessResult> results}) {
  return MachineIdApi.forPlatform(
    platform: platform,
    processRunner: FakeCommandProcessRunner(results: results),
  ).readMachineId();
}

void main() {
  group("macOS", () {
    test("reads IOPlatformUUID from ioreg", () async {
      final id = await _read(
        platform: PlatformOs.macos,
        results: {
          _ioreg: processOutput(
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
          results: {_ioreg: processOutput(stdout: "no uuid here")},
        ),
        isNull,
      );
      expect(
        await _read(
          platform: PlatformOs.macos,
          results: {_ioreg: processOutput(stdout: '"IOPlatformUUID" = " "')},
        ),
        isNull,
      );
    });

    test("returns null when ioreg fails or exits non-zero", () async {
      expect(await _read(platform: PlatformOs.macos, results: {}), isNull);
      expect(
        await _read(platform: PlatformOs.macos, results: {_ioreg: ProcessResult(1, 1, "", "boom")}),
        isNull,
      );
    });
  });

  group("Linux", () {
    test("reads and trims /etc/machine-id", () async {
      final runner = FakeCommandProcessRunner(results: {"cat /etc/machine-id": processOutput(stdout: "abc123\n")});
      final id = await MachineIdApi.forPlatform(platform: PlatformOs.linux, processRunner: runner).readMachineId();
      expect(id, "abc123");
      expect(runner.commands, ["cat /etc/machine-id"]);
    });

    test("falls back to the D-Bus machine id when /etc/machine-id is missing or blank", () async {
      final dbus = processOutput(stdout: "dbus456\n");
      expect(await _read(platform: PlatformOs.linux, results: {"cat /var/lib/dbus/machine-id": dbus}), "dbus456");
      expect(
        await _read(
          platform: PlatformOs.linux,
          results: {
            "cat /etc/machine-id": processOutput(stdout: "\n"),
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
          results: {"cat /etc/machine-id": ProcessResult(1, 1, "", "No such file or directory")},
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
          _reg: processOutput(
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
          results: {_reg: processOutput(stdout: "")},
        ),
        isNull,
      );
      expect(await _read(platform: PlatformOs.windows, results: {}), isNull);
    });
  });
}
