import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const builder = AuthDeviceInfoBuilder();

  test("normalizes detected values", () {
    final info = builder.build(
      clientType: AuthClientType.appMacos,
      detectedName: "  Alex's Mac  ",
      osVersion: "  macOS 15.5  ",
      appVersion: "  1.5.0  ",
    );

    expect(
      info,
      const DeviceInfo(name: "Alex's Mac", osVersion: "macOS 15.5", appVersion: "1.5.0"),
    );
  });

  test("uses client-specific fallback names", () {
    expect(
      builder
          .build(
            clientType: AuthClientType.bridgeLinux,
            detectedName: " ",
            osVersion: null,
            appVersion: null,
          )
          .name,
      "Sesori Bridge",
    );
    expect(
      builder
          .build(
            clientType: AuthClientType.appWindows,
            detectedName: null,
            osVersion: null,
            appVersion: null,
          )
          .name,
      "Windows device",
    );
  });

  test("clamps values to auth-server schema limits", () {
    final info = builder.build(
      clientType: AuthClientType.appLinux,
      detectedName: List.filled(130, "n").join(),
      osVersion: List.filled(50, "o").join(),
      appVersion: List.filled(50, "a").join(),
    );

    expect(info.name.length, 120);
    expect(info.osVersion?.length, 40);
    expect(info.appVersion?.length, 40);
  });
}
