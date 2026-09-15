import "dart:ffi";

import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  test("round-trips every supported OS/CPU without optional identity fields", () {
    for (final DesktopBundleOs os in DesktopBundleOs.values) {
      for (final DesktopBundleArchitecture architecture in DesktopBundleArchitecture.values) {
        final DesktopBundleIdentity identity = DesktopBundleIdentity(
          version: "1.8.4",
          buildNumber: 19,
          sourceSha: "source",
          os: os,
          architecture: architecture,
        );
        expect(DesktopBundleIdentity.decode(encoded: identity.encode()), identity);
      }
    }
  });

  test("maps supported native ABIs and rejects unsupported architectures", () {
    for (final Abi abi in [Abi.macosX64, Abi.windowsX64, Abi.linuxX64]) {
      expect(DesktopBundleArchitecture.fromAbi(abi: abi), DesktopBundleArchitecture.x64);
    }
    for (final Abi abi in [Abi.macosArm64, Abi.windowsArm64, Abi.linuxArm64]) {
      expect(DesktopBundleArchitecture.fromAbi(abi: abi), DesktopBundleArchitecture.arm64);
    }
    expect(() => DesktopBundleArchitecture.fromAbi(abi: Abi.windowsIA32), throwsUnsupportedError);
  });

  test("does not accept an unknown platform or incomplete manifest", () {
    expect(
      () => DesktopBundleIdentity.decode(
        encoded: '{"version":"1.8.4","buildNumber":19,"sourceSha":"source","os":"unknown","architecture":"arm64"}',
      ),
      throwsArgumentError,
    );
    expect(() => DesktopBundleIdentity.decode(encoded: "{}"), throwsA(isA<TypeError>()));
  });
}
