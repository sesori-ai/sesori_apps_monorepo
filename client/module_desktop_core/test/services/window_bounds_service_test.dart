import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(const WindowBounds(left: 0, top: 0, width: 1, height: 1));
    registerFallbackValue(const WindowSize(width: 1, height: 1));
  });

  late _MockWindowHost windowHost;
  late _MockDesktopInstanceRepository repository;
  late StreamController<WindowHostEvent> events;
  late WindowBoundsService service;

  setUp(() {
    windowHost = _MockWindowHost();
    repository = _MockDesktopInstanceRepository();
    events = StreamController<WindowHostEvent>.broadcast(sync: true);
    service = WindowBoundsService.test(
      windowHost: windowHost,
      repository: repository,
      persistenceDebounce: const Duration(milliseconds: 5),
    );
    when(() => windowHost.events).thenAnswer((_) => events.stream);
    when(() => repository.readWindowBounds()).thenAnswer((_) async => null);
    when(
      () => windowHost.initialize(
        hidden: any(named: "hidden"),
        initialBounds: any(named: "initialBounds"),
        minimumSize: any(named: "minimumSize"),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    await service.dispose();
    await events.close();
  });

  test("uses the centered default when no bounds were persisted", () async {
    await service.initializeWindow(hidden: false);

    verify(() => repository.readWindowBounds()).called(1);
    verifyNever(() => windowHost.getDisplayBounds());
    verify(
      () => windowHost.initialize(
        hidden: false,
        initialBounds: null,
        minimumSize: WindowBoundsService.minimumSize,
      ),
    ).called(1);
  });

  test("clamps restored bounds to the display they overlap before initializing", () async {
    const saved = WindowBounds(left: 1300, top: -100, width: 900, height: 1200);
    const primary = WindowBounds(left: 0, top: 24, width: 1440, height: 876);
    const secondary = WindowBounds(left: 1440, top: 0, width: 1920, height: 1080);
    when(() => repository.readWindowBounds()).thenAnswer((_) async => saved);
    when(() => windowHost.getDisplayBounds()).thenAnswer((_) async => const <WindowBounds>[primary, secondary]);

    await service.initializeWindow(hidden: true);

    verifyInOrder(<void Function()>[
      () => repository.readWindowBounds(),
      () => windowHost.getDisplayBounds(),
      () => windowHost.initialize(
        hidden: true,
        initialBounds: const WindowBounds(left: 1440, top: 0, width: 900, height: 1080),
        minimumSize: WindowBoundsService.minimumSize,
      ),
    ]);
  });

  test("reduces the native minimum to a smaller selected work area", () async {
    const saved = WindowBounds(left: 10, top: 20, width: 800, height: 600);
    const compactDisplay = WindowBounds(left: 0, top: 0, width: 480, height: 360);
    when(() => repository.readWindowBounds()).thenAnswer((_) async => saved);
    when(() => windowHost.getDisplayBounds()).thenAnswer((_) async => const <WindowBounds>[compactDisplay]);

    await service.initializeWindow(hidden: false);

    verify(
      () => windowHost.initialize(
        hidden: false,
        initialBounds: compactDisplay,
        minimumSize: const WindowSize(width: 480, height: 360),
      ),
    ).called(1);
  });

  test("chooses the nearest display for fully off-screen saved bounds", () async {
    const saved = WindowBounds(left: -5000, top: 100, width: 800, height: 600);
    const leftDisplay = WindowBounds(left: -1920, top: 0, width: 1920, height: 1080);
    const primary = WindowBounds(left: 0, top: 0, width: 1440, height: 900);
    when(() => repository.readWindowBounds()).thenAnswer((_) async => saved);
    when(() => windowHost.getDisplayBounds()).thenAnswer((_) async => const <WindowBounds>[primary, leftDisplay]);

    await service.initializeWindow(hidden: false);

    verify(
      () => windowHost.initialize(
        hidden: false,
        initialBounds: const WindowBounds(left: -1920, top: 100, width: 800, height: 600),
        minimumSize: WindowBoundsService.minimumSize,
      ),
    ).called(1);
  });

  test("ignores unusable saved bounds", () async {
    when(
      () => repository.readWindowBounds(),
    ).thenAnswer((_) async => const WindowBounds(left: double.nan, top: 0, width: 720, height: 620));

    await service.initializeWindow(hidden: false);

    verifyNever(() => windowHost.getDisplayBounds());
    verify(
      () => windowHost.initialize(
        hidden: false,
        initialBounds: null,
        minimumSize: WindowBoundsService.minimumSize,
      ),
    ).called(1);
  });

  test("debounces move and resize events into the latest bounds write", () async {
    const latest = WindowBounds(left: 120, top: 80, width: 1000, height: 760);
    when(() => windowHost.getBounds()).thenAnswer((_) async => latest);
    when(() => repository.writeWindowBounds(bounds: latest)).thenAnswer((_) async {});
    await service.initializeWindow(hidden: false);

    events.add(WindowHostEvent.moved);
    events.add(WindowHostEvent.resized);
    events.add(WindowHostEvent.moved);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    verify(() => windowHost.getBounds()).called(1);
    verify(() => repository.writeWindowBounds(bounds: latest)).called(1);
  });

  test("a close request flushes a pending bounds update", () async {
    const latest = WindowBounds(left: 30, top: 40, width: 800, height: 600);
    when(() => windowHost.getBounds()).thenAnswer((_) async => latest);
    when(() => repository.writeWindowBounds(bounds: latest)).thenAnswer((_) async {});
    await service.initializeWindow(hidden: false);

    events.add(WindowHostEvent.resized);
    events.add(WindowHostEvent.closeRequested);
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.writeWindowBounds(bounds: latest)).called(1);
  });

  test("dispose flushes and awaits a pending bounds update", () async {
    const latest = WindowBounds(left: 60, top: 70, width: 840, height: 640);
    when(() => windowHost.getBounds()).thenAnswer((_) async => latest);
    when(() => repository.writeWindowBounds(bounds: latest)).thenAnswer((_) async {});
    await service.initializeWindow(hidden: false);

    events.add(WindowHostEvent.resized);
    await service.dispose();

    verify(() => repository.writeWindowBounds(bounds: latest)).called(1);
  });

  test("a failed persistence attempt does not poison later updates", () async {
    const first = WindowBounds(left: 10, top: 20, width: 800, height: 600);
    const second = WindowBounds(left: 30, top: 40, width: 900, height: 700);
    var readCount = 0;
    when(() => windowHost.getBounds()).thenAnswer((_) async => readCount++ == 0 ? first : second);
    when(() => repository.writeWindowBounds(bounds: first)).thenThrow(StateError("disk unavailable"));
    when(() => repository.writeWindowBounds(bounds: second)).thenAnswer((_) async {});
    await service.initializeWindow(hidden: false);

    events.add(WindowHostEvent.moved);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    events.add(WindowHostEvent.resized);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    verify(() => repository.writeWindowBounds(bounds: first)).called(1);
    verify(() => repository.writeWindowBounds(bounds: second)).called(1);
  });
}

class _MockWindowHost() extends Mock implements WindowHost;

class _MockDesktopInstanceRepository() extends Mock implements DesktopInstanceRepository;
