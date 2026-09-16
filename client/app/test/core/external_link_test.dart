import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/external_link.dart";

class _MockUrlLauncher() extends Mock implements UrlLauncher;

class const _UriLeakingException({required final Uri uri}) implements Exception {
  @override
  String toString() => "Could not launch $uri";
}

void main() {
  late _MockUrlLauncher launcher;
  final originalLevel = logLevel;

  setUpAll(() {
    registerFallbackValue(Uri());
    registerFallbackValue(UrlLaunchMode.externalApp);
  });

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

  for (final throws in [false, true]) {
    test("failed launch retains context without the transcript URI (throws=$throws)", () async {
      final uri = Uri.parse(
        "https://private-user:private-password@files.example.com/private-path?token=private-token#private-fragment",
      );
      final launch = when(() => launcher.launch(uri, mode: UrlLaunchMode.externalApp));
      if (throws) {
        launch.thenThrow(_UriLeakingException(uri: uri));
      } else {
        launch.thenAnswer((_) async => false);
      }
      final logs = <String>[];
      final opened = await runZoned(
        () => openExternalLink(url: uri, mode: UrlLaunchMode.externalApp),
        zoneSpecification: ZoneSpecification(print: (_, _, _, message) => logs.add(message)),
      );
      expect(opened, isFalse);
      expect(logs.join("\n"), contains("files.example.com"));
      expect(logs.join("\n"), contains("scheme=https"));
      expect(logs.join("\n"), isNot(contains("private-")));
      if (throws) {
        expect(logs.join("\n"), contains("_UriLeakingException"));
        expect(logs.join("\n"), contains("Could not launch"));
        expect(logs.join("\n"), contains("external_link.dart"));
      }
      verify(() => launcher.launch(uri, mode: UrlLaunchMode.externalApp)).called(1);
    });
  }
}
