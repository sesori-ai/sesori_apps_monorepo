import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockFeedbackApi() extends Mock implements FeedbackApi;

class _MockInstalledAppBuildApi() extends Mock implements InstalledAppBuildApi;

void main() {
  late _MockFeedbackApi api;
  late _MockInstalledAppBuildApi buildApi;
  late FeedbackRepository repository;

  setUpAll(() {
    registerFallbackValue(
      const FeedbackSubmitRequest(
        issues: [],
        message: null,
        source: FeedbackSource.settings,
        platform: DevicePlatform.ios,
        appVersion: "0",
      ),
    );
  });

  setUp(() {
    api = _MockFeedbackApi();
    buildApi = _MockInstalledAppBuildApi();
    when(() => api.submit(request: any(named: "request"))).thenAnswer((_) async {});
    when(() => buildApi.devicePlatform).thenReturn(DevicePlatform.android);
    when(() => buildApi.readVersion()).thenAnswer((_) async => "1.6.0");
    repository = FeedbackRepository(api: api, installedAppBuildApi: buildApi);
  });

  FeedbackSubmitRequest sentRequest() =>
      verify(() => api.submit(request: captureAny(named: "request"))).captured.single as FeedbackSubmitRequest;

  test("trims the message and adds the platform and app version", () async {
    await repository.submit(
      issues: {FeedbackIssue.appSlow, FeedbackIssue.hardToNavigate},
      message: "  Fixture feedback \n",
      source: FeedbackSource.settings,
    );

    expect(
      sentRequest(),
      const FeedbackSubmitRequest(
        issues: [FeedbackIssue.hardToNavigate, FeedbackIssue.appSlow],
        message: "Fixture feedback",
        source: FeedbackSource.settings,
        platform: DevicePlatform.android,
        appVersion: "1.6.0",
      ),
    );
  });

  test("leaves out a whitespace-only message", () async {
    await repository.submit(issues: {}, message: " \n\t ", source: FeedbackSource.automatic);

    expect(sentRequest().message, isNull);
  });
}
