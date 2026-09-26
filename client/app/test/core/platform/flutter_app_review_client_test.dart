import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/flutter_app_review_client.dart";

class _MockUrlLauncher() extends Mock implements UrlLauncher;

final _appStore = Uri.parse("itms-apps://itunes.apple.com/app/id6760642500?action=write-review");
final _playApp = Uri.parse("market://details?id=com.sesori.app");
final _playWeb = Uri.parse("https://play.google.com/store/apps/details?id=com.sesori.app");

void main() {
  late _MockUrlLauncher launcher;
  late FlutterAppReviewClient client;

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    launcher = _MockUrlLauncher();
    client = FlutterAppReviewClient(urlLauncher: launcher);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test("iOS opens the App Store write-review page", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    when(() => launcher.launch(any())).thenAnswer((_) async => true);

    await client.openStoreReviewPage();

    verify(() => launcher.launch(_appStore)).called(1);
    verifyNoMoreInteractions(launcher);
  });

  test("Android opens the Play Store app when it is installed", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    when(() => launcher.launch(any())).thenAnswer((_) async => true);

    await client.openStoreReviewPage();

    verify(() => launcher.launch(_playApp)).called(1);
    verifyNoMoreInteractions(launcher);
  });

  test("Android falls back to the web listing when the Play Store app is missing or fails", () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    for (final playAppResult in [false, null]) {
      clearInteractions(launcher);
      when(() => launcher.launch(_playApp)).thenAnswer((_) async {
        if (playAppResult == null) throw StateError("no activity");
        return playAppResult;
      });
      when(() => launcher.launch(_playWeb)).thenAnswer((_) async => true);

      await client.openStoreReviewPage();

      verifyInOrder([() => launcher.launch(_playApp), () => launcher.launch(_playWeb)]);
    }
  });
}
