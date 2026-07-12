import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_desktop/core/platform/desktop_oauth_device_descriptor_provider.dart";
import "package:sesori_shared/sesori_shared.dart";

class _MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

MacOsDeviceInfo _macOsInfo({required String computerName}) {
  return MacOsDeviceInfo.setMockInitialValues(
    computerName: computerName,
    hostName: "host.local",
    arch: "arm64",
    model: "Mac15,6",
    modelName: "MacBook Pro (14-inch, Nov 2023)",
    kernelVersion: "Darwin Kernel Version 23.5.0",
    osRelease: "Version 14.5 (Build 23F79)",
    majorVersion: 14,
    minorVersion: 5,
    patchVersion: 0,
    activeCPUs: 8,
    memorySize: 17179869184,
    cpuFrequency: 0,
    systemGUID: "guid",
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockDeviceInfoPlugin deviceInfo;
  late DesktopOAuthDeviceDescriptorProvider provider;

  setUp(() {
    deviceInfo = _MockDeviceInfoPlugin();
    provider = DesktopOAuthDeviceDescriptorProvider(deviceInfo);
    PackageInfo.setMockInitialValues(
      appName: "Sesori",
      packageName: "com.sesori.desktop",
      version: "1.2.3",
      buildNumber: "1",
      buildSignature: "",
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test("macOS: app_macos clientType, computer name, macOS version, app version", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    when(() => deviceInfo.macOsInfo).thenAnswer((_) async => _macOsInfo(computerName: "Alex's MacBook Pro"));

    final descriptor = await provider.describe();

    expect(descriptor.clientType, AuthClientType.appMacos);
    expect(descriptor.device.name, "Alex's MacBook Pro");
    expect(descriptor.device.osVersion, "macOS 14.5.0");
    expect(descriptor.device.appVersion, "1.2.3");
  });

  test("linux: app_linux clientType, hostname as name, pretty name as OS version", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    when(() => deviceInfo.linuxInfo).thenAnswer(
      (_) async => LinuxDeviceInfo(
        name: "Ubuntu",
        id: "ubuntu",
        prettyName: "Ubuntu 24.04 LTS",
        machineId: "machine-id",
      ),
    );

    final descriptor = await provider.describe();

    expect(descriptor.clientType, AuthClientType.appLinux);
    expect(descriptor.device.name, isNotEmpty);
    expect(descriptor.device.osVersion, "Ubuntu 24.04 LTS");
  });

  test("windows: a device-info failure degrades to the fallback name and never throws", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    when(() => deviceInfo.windowsInfo).thenThrow(StateError("no channel"));

    final descriptor = await provider.describe();

    expect(descriptor.clientType, AuthClientType.appWindows);
    expect(descriptor.device.name, "Windows device");
    expect(descriptor.device.osVersion, isNull);
    expect(descriptor.device.appVersion, "1.2.3");
  });

  test("clamps an overlong device name to the auth-server limit", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final longName = "N" * 200;
    when(() => deviceInfo.macOsInfo).thenAnswer((_) async => _macOsInfo(computerName: longName));

    final descriptor = await provider.describe();

    expect(descriptor.device.name.length, 120);
  });
}
