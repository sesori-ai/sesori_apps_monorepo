import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/external_link.dart";
import "package:sesori_desktop/core/platform/desktop_url_launcher.dart";

class _MockUrlLauncher() extends Mock implements UrlLauncher;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final originalLevel = logLevel;
  late _MockUrlLauncher launcher;
  setUp(() async {
    await GetIt.instance.reset();
    launcher = _MockUrlLauncher();
    GetIt.instance.registerSingleton<UrlLauncher>(launcher);
    setLogLevel(LogLevel.warning);
  });
  tearDown(() async {
    setLogLevel(originalLevel);
    await GetIt.instance.reset();
  });

  test("production adapter omits the known URI before degrading platform failure to false", () async {
    await GetIt.instance.unregister<UrlLauncher>();
    GetIt.instance.registerSingleton<UrlLauncher>(DesktopUrlLauncher());
    final uri = Uri.parse(
      "https://private-user:private-password@files.example.com/private-path?private-token#private-fragment",
    );
    const channel = MethodChannel("plugins.flutter.io/url_launcher");
    final calls = <MethodCall>[];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: "launcher_unavailable", message: "OS code 42: cannot open $uri");
    });
    addTearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final logs = <String>[];
    final opened = await runZoned(
      () => openDesktopExternalLink(url: uri, mode: UrlLaunchMode.externalApp),
      zoneSpecification: ZoneSpecification(print: (_, _, _, message) => logs.add(message)),
    );
    expect(opened, isFalse);
    expect(calls.single.method, "launch");
    expect(calls.single.arguments, containsPair("url", uri.toString()));
    expect(logs.join("\n"), isNot(contains("private-")));
    expect(logs.join("\n"), contains("launcher_unavailable"));
    expect(logs.join("\n"), contains("OS code 42"));
    expect(logs.join("\n"), contains("desktop_url_launcher.dart"));
  });

  for (final throws in [false, true]) {
    test("failed desktop link retains diagnostics without the transcript URI (throws=$throws)", () async {
      final uri = Uri.parse(
        "https://private-user:private-password@files.example.com/private-path?private-token#private-fragment",
      );
      final launch = when(() => launcher.launch(uri, mode: UrlLaunchMode.externalApp));
      if (throws) {
        launch.thenThrow(StateError("OS code 42: cannot open $uri"));
      } else {
        launch.thenAnswer((_) async => false);
      }
      final logs = <String>[];
      final opened = await runZoned(
        () => openDesktopExternalLink(url: uri, mode: UrlLaunchMode.externalApp),
        zoneSpecification: ZoneSpecification(print: (_, _, _, message) => logs.add(message)),
      );
      expect(opened, isFalse);
      expect(logs.join("\n"), contains("scheme=https, host=files.example.com"));
      expect(logs.join("\n"), isNot(contains("private-")));
      if (throws) {
        expect(logs.join("\n"), contains("OS code 42"));
        expect(logs.join("\n"), contains("external_link.dart"));
      }
      verify(() => launcher.launch(uri, mode: UrlLaunchMode.externalApp)).called(1);
    });
  }
}
