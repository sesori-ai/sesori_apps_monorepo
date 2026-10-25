import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(DesktopAutomaticUpdates.enabled);
  });

  late _FakeInstalledDesktopBundleSource bundleSource;
  late _MockDesktopRelaunchApi relaunchApi;
  late _MockDesktopInstanceRepository instanceRepository;
  late _MockBridgeProcessService processService;

  setUp(() {
    bundleSource = _FakeInstalledDesktopBundleSource(
      compiledIdentity: _linuxBuild,
      isAppImage: false,
      channel: DesktopReleaseChannel.stable,
    );
    relaunchApi = _MockDesktopRelaunchApi();
    instanceRepository = _MockDesktopInstanceRepository();
    processService = _MockBridgeProcessService();
    when(() => instanceRepository.readAutomaticUpdates()).thenAnswer((_) async => DesktopAutomaticUpdates.enabled);
    when(
      () => instanceRepository.writeAutomaticUpdates(preference: any(named: "preference")),
    ).thenAnswer((_) async {});
    when(() => processService.desiredState).thenReturn(BridgeProcessDesiredState.on);
    when(() => processService.stop()).thenAnswer((_) async {});
    when(() => processService.start()).thenAnswer((_) async {});
    when(() => relaunchApi.relaunchInstalledPackage()).thenAnswer((_) async {});
  });

  DesktopUpdateService service() => DesktopUpdateService(
    updateRepository: DesktopUpdateRepository(bundleSource: bundleSource, relaunchApi: relaunchApi),
    instanceRepository: instanceRepository,
    processService: processService,
  );

  group("initial state", () {
    test("a source build is a development build", () {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: null,
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      expect(
        service().currentState,
        isA<DesktopUpdateUnavailable>().having(
          (state) => state.reason,
          "reason",
          DesktopUpdateUnavailableReason.developmentBuild,
        ),
      );
    });

    test("a Linux package is managed by the system", () {
      expect(service().currentState, isA<DesktopUpdateManagedBySystem>());
    });

    for (final (os, isAppImage, fragment) in [
      (DesktopBundleOs.macos, false, "internal-macos-arm64"),
      (DesktopBundleOs.windows, false, "internal-windows-arm64"),
      (DesktopBundleOs.linux, true, "internal-linux-arm64-appimage"),
    ]) {
      test("${os.name}${isAppImage ? " AppImage" : ""} keeps the manual download for its channel and CPU", () {
        bundleSource = _FakeInstalledDesktopBundleSource(
          compiledIdentity: _linuxBuild.copyWith(os: os, architecture: DesktopBundleArchitecture.arm64),
          isAppImage: isAppImage,
          channel: DesktopReleaseChannel.internal,
        );
        final state = service().currentState;
        expect(state, isA<DesktopUpdateManualDownload>());
        expect(
          (state as DesktopUpdateManualDownload).downloadsUri,
          Uri.parse("https://sesori.com/desktop/#$fragment"),
        );
      });
    }
  });

  group("checks", () {
    test("start checks at once and every six hours, and finds an installed update", () {
      fakeAsync((async) {
        final updates = service();
        unawaited(updates.start());
        async.flushMicrotasks();
        expect(bundleSource.reads, 1);
        expect(updates.currentState, isA<DesktopUpdateManagedBySystem>());

        bundleSource.installed = _linuxBuild.copyWith(version: "1.8.5", buildNumber: 25);
        async.elapse(DesktopUpdateService.checkInterval);

        expect(bundleSource.reads, 2);
        expect(updates.currentState, isA<DesktopUpdateReady>().having((state) => state.version, "version", "1.8.5"));
        unawaited(updates.dispose());
      });
    });

    test("turning automatic updates off stops background checks but keeps Check for updates", () {
      fakeAsync((async) {
        final updates = service();
        unawaited(updates.start());
        async.flushMicrotasks();
        unawaited(updates.setAutomaticUpdates(preference: DesktopAutomaticUpdates.disabled));
        async.flushMicrotasks();
        verify(() => instanceRepository.writeAutomaticUpdates(preference: DesktopAutomaticUpdates.disabled)).called(1);
        expect(updates.currentAutomaticUpdates, DesktopAutomaticUpdates.disabled);

        async.elapse(DesktopUpdateService.checkInterval * 2);
        expect(bundleSource.reads, 1);

        bundleSource.installed = _linuxBuild.copyWith(sourceSha: "rebuilt");
        updates.check();
        expect(bundleSource.reads, 2);
        expect(updates.currentState, isA<DesktopUpdateReady>());
        unawaited(updates.dispose());
      });
    });

    test("a persisted Off preference never checks in the background", () {
      fakeAsync((async) {
        when(() => instanceRepository.readAutomaticUpdates()).thenAnswer((_) async => DesktopAutomaticUpdates.disabled);
        final updates = service();
        unawaited(updates.start());
        async.elapse(DesktopUpdateService.checkInterval);
        expect(bundleSource.reads, 0);
        unawaited(updates.dispose());
      });
    });

    test("an unreadable manifest keeps the current state", () async {
      final updates = service();
      addTearDown(updates.dispose);
      bundleSource.readError = const FormatException("partial manifest");
      updates.check();
      expect(updates.currentState, isA<DesktopUpdateManagedBySystem>());
    });

    test("installs without an engine never read the installed manifest", () async {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _linuxBuild.copyWith(os: DesktopBundleOs.macos),
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      final updates = service();
      addTearDown(updates.dispose);
      await updates.start();
      updates.check();
      expect(bundleSource.reads, 0);
      expect(updates.currentState, isA<DesktopUpdateManualDownload>());
    });
  });

  group("prepareExit", () {
    test("quit only stops the helper", () async {
      final updates = service();
      addTearDown(updates.dispose);
      await updates.prepareExit(intent: DesktopExitIntent.quit);
      verify(() => processService.stop()).called(1);
      verifyNever(() => relaunchApi.relaunchInstalledPackage());
    });

    test("restart to update relaunches the package after the helper stopped", () async {
      final updates = service();
      addTearDown(updates.dispose);
      await updates.prepareExit(intent: DesktopExitIntent.restartToUpdate);
      verifyInOrder([() => processService.stop(), () => relaunchApi.relaunchInstalledPackage()]);
      verifyNever(() => processService.start());
    });

    test("a failed relaunch restores a helper that was on and reports the failure", () async {
      final updates = service();
      addTearDown(updates.dispose);
      when(() => relaunchApi.relaunchInstalledPackage()).thenThrow(const ProcessException("sesori-desktop", []));
      await expectLater(
        updates.prepareExit(intent: DesktopExitIntent.restartToUpdate),
        throwsA(isA<ProcessException>()),
      );
      verifyInOrder([
        () => processService.stop(),
        () => relaunchApi.relaunchInstalledPackage(),
        () => processService.start(),
      ]);
    });

    test("a failed relaunch leaves a helper that was off stopped", () async {
      final updates = service();
      addTearDown(updates.dispose);
      when(() => processService.desiredState).thenReturn(BridgeProcessDesiredState.off);
      when(() => relaunchApi.relaunchInstalledPackage()).thenThrow(const ProcessException("sesori-desktop", []));
      await expectLater(updates.prepareExit(intent: DesktopExitIntent.restartToUpdate), throwsA(anything));
      verifyNever(() => processService.start());
    });
  });
}

const DesktopBundleIdentity _linuxBuild = DesktopBundleIdentity(
  version: "1.8.4",
  buildNumber: 24,
  sourceSha: "source",
  os: DesktopBundleOs.linux,
  architecture: DesktopBundleArchitecture.x64,
);

class _FakeInstalledDesktopBundleSource({
  @override required final DesktopBundleIdentity? compiledIdentity,
  @override required final bool isAppImage,
  @override required final DesktopReleaseChannel channel,
}) implements InstalledDesktopBundleSource {
  late DesktopBundleIdentity installed = compiledIdentity ?? _linuxBuild;
  Object? readError;
  int reads = 0;

  @override
  DesktopBundleIdentity readInstalledIdentity() {
    reads++;
    final Object? error = readError;
    if (error != null) {
      throw error;
    }
    return installed;
  }
}

class _MockDesktopRelaunchApi() extends Mock implements DesktopRelaunchApi;

class _MockDesktopInstanceRepository() extends Mock implements DesktopInstanceRepository;

class _MockBridgeProcessService() extends Mock implements BridgeProcessService;
