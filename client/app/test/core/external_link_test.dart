import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/external_link.dart";

class _MockUrlLauncher extends Mock implements UrlLauncher {}

class _UriLeakingException implements Exception {
  final Uri uri;

  const _UriLeakingException({required this.uri});

  @override
  String toString() => "Could not launch $uri";
}

void main() {
  late _MockUrlLauncher launcher;

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

  tearDown(() => GetIt.instance.reset());

  test("launcher exceptions remain available in local logs", () async {
    final uri = Uri.parse("https://files.example.com/image.png?token=sensitive-token");
    when(() => launcher.launch(uri, mode: UrlLaunchMode.externalApp)).thenThrow(_UriLeakingException(uri: uri));
    final logs = <String>[];

    await runZoned(
      () => openExternalLink(url: uri, mode: UrlLaunchMode.externalApp),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, message) => logs.add(message),
      ),
    );

    expect(logs.join("\n"), contains("Failed to open external link"));
    expect(logs.join("\n"), contains("sensitive-token"));
  });
}
