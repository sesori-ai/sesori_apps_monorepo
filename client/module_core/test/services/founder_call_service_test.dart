import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/repositories/models/analytics_delivery_result.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_persistence/sesori_persistence.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MemoryPersister() extends Fake implements PersisterRepository {
  final values = <String, String>{};

  @override
  Future<String?> readString({required StringPersistenceKey key}) async => values[key.storageKey];

  @override
  Future<void> writeString({required StringPersistenceKey key, required String value}) async {
    values[key.storageKey] = value;
  }
}

class _FakeConfigSource() implements FounderCallConfigSource {
  FounderCallConfigValues values = _unset;

  @override
  Future<FounderCallConfigValues> fetchValues() async => values;
}

const FounderCallConfigValues _unset = (
  enabled: null,
  afterComputer: null,
  bookingUrl: null,
  title: null,
  message: null,
  buttonLabel: null,
);

const _connected = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "relay.example.com", authToken: "token", bridgeId: null),
  health: HealthResponse(healthy: true, version: "0.1.200", filesystemAccessDegraded: false),
);

void main() {
  late BehaviorSubject<ConnectionStatus> status;
  late _MemoryPersister persister;
  late _FakeConfigSource configSource;
  late MockProductAnalyticsService analytics;
  late FounderCallService service;
  late List<FounderCallSheetRequest> requests;

  setUpAll(() {
    registerFallbackValue(const ProductAnalyticsEvent.founderCallShown(surface: FounderCallSurface.settings));
  });

  FounderCallService serviceFor({required ConnectionService connection}) {
    final built = FounderCallService(
      connectionService: connection,
      repository: FounderCallRepository(
        configApi: FounderCallConfigApi(source: configSource),
        storage: FounderCallStorage(persister: persister),
      ),
      productAnalyticsService: analytics,
    );
    requests = [];
    built.sheetRequests.listen(requests.add);
    return built;
  }

  setUp(() {
    status = BehaviorSubject<ConnectionStatus>.seeded(const ConnectionStatus.disconnected());
    persister = _MemoryPersister();
    configSource = _FakeConfigSource();
    analytics = MockProductAnalyticsService();
    when(
      () => analytics.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    ).thenAnswer((_) async => AnalyticsDeliveryResult.acceptedBySdk);
    service = serviceFor(connection: MockConnectionService());
  });

  tearDown(() async {
    await service.dispose();
    await status.close();
  });

  /// A started service on this device's storage, as on a phone launch.
  void launch() {
    final connection = MockConnectionService();
    when(() => connection.status).thenAnswer((_) => status);
    service = serviceFor(connection: connection)..start();
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> connect() async {
    status.add(_connected);
    await settle();
  }

  List<ProductAnalyticsEvent> loggedEvents() => verify(
    () => analytics.logEvent(
      event: captureAny(named: "event"),
      occurredAtUtc: any(named: "occurredAtUtc"),
    ),
  ).captured.cast<ProductAnalyticsEvent>();

  test("a fresh sign-in arms the device and the first connected computer shows the sheet once", () async {
    launch();
    await service.recordFreshLogin();

    await connect();
    status.add(const ConnectionStatus.disconnected());
    await connect();

    expect(requests, hasLength(1));
    expect(requests.single.bookingUrl, FounderCallRepository.defaultBookingUrl);
    expect(requests.single.copy.title, isNull);
    expect(loggedEvents().single, isA<FounderCallShownEvent>());
  });

  test("a device signed in before the update is never armed, so the sheet never opens", () async {
    launch();

    await connect();

    expect(requests, isEmpty);
    verifyNever(
      () => analytics.logEvent(
        event: any(named: "event"),
        occurredAtUtc: any(named: "occurredAtUtc"),
      ),
    );
  });

  test("the sheet does not open again after a relaunch", () async {
    launch();
    await service.recordFreshLogin();
    await connect();
    await service.dispose();

    launch();
    await service.recordFreshLogin();
    await connect();

    expect(requests, isEmpty);
  });

  test("opening the booking link retires the invitation before any computer connects", () async {
    launch();
    await service.recordFreshLogin();

    await service.recordLinkOpened(surface: FounderCallSurface.settings);
    await connect();

    expect(requests, isEmpty);
    expect(loggedEvents().single, isA<FounderCallLinkOpenedEvent>());
  });

  test("the computer moment switched off keeps the device armed without showing", () async {
    configSource.values = (
      enabled: null,
      afterComputer: false,
      bookingUrl: null,
      title: null,
      message: null,
      buttonLabel: null,
    );
    launch();
    await service.recordFreshLogin();

    await connect();

    expect(requests, isEmpty);
  });

  test("the master switch off hides the invitation everywhere", () async {
    configSource.values = (
      enabled: false,
      afterComputer: true,
      bookingUrl: null,
      title: null,
      message: null,
      buttonLabel: null,
    );
    launch();
    await service.recordFreshLogin();

    await connect();

    expect(requests, isEmpty);
    expect(await service.readAvailability(), isA<FounderCallHidden>());
  });

  test("Settings offers the remote link and wording, trimmed, and ignores a non-https link", () async {
    configSource.values = (
      enabled: true,
      afterComputer: null,
      bookingUrl: " https://cal.com/example ",
      title: " Talk to the founder ",
      message: "  ",
      buttonLabel: null,
    );
    launch();

    final availability = await service.readAvailability();

    expect(availability, isA<FounderCallAvailable>());
    final available = availability as FounderCallAvailable;
    expect(available.bookingUrl, Uri.parse("https://cal.com/example"));
    expect(available.copy.title, "Talk to the founder");
    expect(available.copy.message, isNull);

    configSource.values = (
      enabled: true,
      afterComputer: null,
      bookingUrl: "http://example.com",
      title: null,
      message: null,
      buttonLabel: null,
    );
    launch();
    final fallback = await service.readAvailability() as FounderCallAvailable;
    expect(fallback.bookingUrl, FounderCallRepository.defaultBookingUrl);
  });

  test("an unstarted service stores nothing, as on desktop", () async {
    await service.recordFreshLogin();

    expect(persister.values, isEmpty);
  });

  test("an unreadable stored value reads as never armed", () async {
    persister.values[StringPreferenceKey.founderCall.storageKey] = "not json";
    launch();

    await connect();

    expect(requests, isEmpty);
  });
}
