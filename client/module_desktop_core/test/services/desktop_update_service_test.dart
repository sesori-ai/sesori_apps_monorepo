import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  setUpAll(() {
    registerFallbackValue(DesktopAutomaticUpdates.enabled);
    registerFallbackValue(_linuxBuild);
    registerFallbackValue(_feed);
    registerFallbackValue(_release);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(File("fallback"));
  });

  late _FakeInstalledDesktopBundleSource bundleSource;
  late _MockDesktopRelaunchApi relaunchApi;
  late _MockDesktopInstanceRepository instanceRepository;
  late _MockDesktopUpdateFeedApi feedApi;
  late _MockDesktopUpdateFeedValidator feedValidator;
  late _MockVelopackUpdateApi velopackApi;

  setUp(() {
    bundleSource = _FakeInstalledDesktopBundleSource(
      compiledIdentity: _linuxBuild,
      isAppImage: false,
      channel: DesktopReleaseChannel.stable,
    );
    relaunchApi = _MockDesktopRelaunchApi();
    instanceRepository = _MockDesktopInstanceRepository();
    when(() => instanceRepository.readAutomaticUpdates()).thenAnswer((_) async => DesktopAutomaticUpdates.enabled);
    when(
      () => instanceRepository.writeAutomaticUpdates(preference: any(named: "preference")),
    ).thenAnswer((_) async {});
    when(() => relaunchApi.relaunchInstalledPackage()).thenAnswer((_) async {});
    feedApi = _MockDesktopUpdateFeedApi();
    feedValidator = _MockDesktopUpdateFeedValidator();
    velopackApi = _MockVelopackUpdateApi();
  });

  DesktopUpdateService service() => DesktopUpdateService(
    updateRepository: DesktopUpdateRepository(
      bundleSource: bundleSource,
      relaunchApi: relaunchApi,
      feedApi: feedApi,
      feedValidator: feedValidator,
      velopackApi: velopackApi,
    ),
    instanceRepository: instanceRepository,
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

    test("macOS keeps the manual download for its channel and CPU", () {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _linuxBuild.copyWith(
          os: DesktopBundleOs.macos,
          architecture: DesktopBundleArchitecture.arm64,
        ),
        isAppImage: false,
        channel: DesktopReleaseChannel.internal,
      );
      final state = service().currentState;
      expect(state, isA<DesktopUpdateManualDownload>());
      expect(
        (state as DesktopUpdateManualDownload).downloadsUri,
        Uri.parse("https://sesori.com/desktop/#internal-macos-arm64"),
      );
    });

    for (final (os, isAppImage) in [(DesktopBundleOs.windows, false), (DesktopBundleOs.linux, true)]) {
      test("${os.name}${isAppImage ? " AppImage" : ""} updates itself and starts idle", () {
        bundleSource = _FakeInstalledDesktopBundleSource(
          compiledIdentity: _linuxBuild.copyWith(os: os),
          isAppImage: isAppImage,
          channel: DesktopReleaseChannel.stable,
        );
        expect(service().currentState, isA<DesktopUpdateIdle>());
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
        unawaited(updates.check());
        async.flushMicrotasks();
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
      await updates.check();
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
      await updates.check();
      expect(bundleSource.reads, 0);
      expect(updates.currentState, isA<DesktopUpdateManualDownload>());
    });
  });

  group("Velopack checks", () {
    final File stagedPackage = File("staged/sesori-desktop-1.8.5-stable-full.nupkg");

    setUp(() {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _windowsBuild,
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      when(() => velopackApi.readPendingVersion()).thenAnswer((_) async => null);
      when(() => feedApi.fetchFeed(identity: any(named: "identity"))).thenAnswer((_) async => _feed);
      when(() => feedValidator.verify(feed: any(named: "feed"))).thenAnswer((_) async {});
      when(() => velopackApi.stageFeed(feed: any(named: "feed"))).thenAnswer((_) async => _release);
      when(() => velopackApi.stagedPackageFile(release: any(named: "release"))).thenAnswer((_) async => stagedPackage);
      when(
        () => feedApi.downloadPackage(
          identity: any(named: "identity"),
          fileName: any(named: "fileName"),
          destination: any(named: "destination"),
        ),
      ).thenAnswer((_) async {});
      when(() => velopackApi.downloadStagedRelease()).thenAnswer((_) async => "1.8.5");
    });

    test("verify the signed feed before Velopack stages it, then download the package it names", () async {
      final updates = service();
      addTearDown(updates.dispose);

      await updates.check();

      expect(updates.currentState, isA<DesktopUpdateReady>().having((state) => state.version, "version", "1.8.5"));
      verifyInOrder([
        () => feedApi.fetchFeed(identity: _windowsBuild),
        () => feedValidator.verify(feed: _feed),
        () => velopackApi.stageFeed(feed: _feed.bytes),
        () => feedApi.downloadPackage(identity: _windowsBuild, fileName: _release.fileName, destination: stagedPackage),
        () => velopackApi.downloadStagedRelease(),
      ]);
    });

    test("a package Velopack already downloaded is Ready without fetching", () async {
      when(() => velopackApi.readPendingVersion()).thenAnswer((_) async => "1.8.5");
      final updates = service();
      addTearDown(updates.dispose);

      await updates.check();

      expect(updates.currentState, isA<DesktopUpdateReady>());
      verifyNever(() => feedApi.fetchFeed(identity: any(named: "identity")));
    });

    test("a feed with nothing newer stays idle and downloads nothing", () async {
      when(() => velopackApi.stageFeed(feed: any(named: "feed"))).thenAnswer((_) async => null);
      final updates = service();
      addTearDown(updates.dispose);

      await updates.check();

      expect(updates.currentState, isA<DesktopUpdateIdle>());
      verifyNever(() => velopackApi.downloadStagedRelease());
    });

    test("a refused signature stays idle without staging the feed", () async {
      when(() => feedValidator.verify(feed: any(named: "feed"))).thenThrow(const FormatException("bad signature"));
      final updates = service();
      addTearDown(updates.dispose);

      await updates.check();

      expect(updates.currentState, isA<DesktopUpdateIdle>());
      verifyNever(() => velopackApi.stageFeed(feed: any(named: "feed")));
    });

    test("a check that starts while one runs joins it", () async {
      final Completer<DesktopUpdateFeed> feed = Completer<DesktopUpdateFeed>();
      when(() => feedApi.fetchFeed(identity: any(named: "identity"))).thenAnswer((_) => feed.future);
      final updates = service();
      addTearDown(updates.dispose);

      final Future<void> first = updates.check();
      final Future<void> second = updates.check();
      feed.complete(_feed);
      await Future.wait([first, second]);

      verify(() => feedApi.fetchFeed(identity: any(named: "identity"))).called(1);
    });
  });

  group("applyDownloadedUpdate", () {
    setUp(() {
      when(() => velopackApi.applyPendingRelease(restart: any(named: "restart"))).thenAnswer((_) async {});
    });

    test("a Ready Velopack install starts the updater", () async {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _windowsBuild,
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      when(() => velopackApi.readPendingVersion()).thenAnswer((_) async => "1.8.5");
      final updates = service();
      addTearDown(updates.dispose);
      await updates.check();

      await updates.applyDownloadedUpdate(restart: true);

      verify(() => velopackApi.applyPendingRelease(restart: true)).called(1);
    });

    test("an idle Velopack install and a Ready Linux package start nothing", () async {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _windowsBuild,
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      final idle = service();
      addTearDown(idle.dispose);
      await idle.applyDownloadedUpdate(restart: false);

      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _linuxBuild,
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      bundleSource.installed = _linuxBuild.copyWith(version: "1.8.5");
      final package = service();
      addTearDown(package.dispose);
      await package.check();
      expect(package.currentState, isA<DesktopUpdateReady>());
      await package.applyDownloadedUpdate(restart: true);

      verifyNever(() => velopackApi.applyPendingRelease(restart: any(named: "restart")));
    });
  });

  group("prepareRestartToUpdate", () {
    test("a Linux package relaunches the installed package", () async {
      final updates = service();
      addTearDown(updates.dispose);
      await updates.prepareRestartToUpdate();
      verify(() => relaunchApi.relaunchInstalledPackage()).called(1);
    });

    test("installs without an engine do nothing", () async {
      bundleSource = _FakeInstalledDesktopBundleSource(
        compiledIdentity: _linuxBuild.copyWith(os: DesktopBundleOs.macos),
        isAppImage: false,
        channel: DesktopReleaseChannel.stable,
      );
      final updates = service();
      addTearDown(updates.dispose);
      await updates.prepareRestartToUpdate();
      verifyNever(() => relaunchApi.relaunchInstalledPackage());
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

final DesktopBundleIdentity _windowsBuild = _linuxBuild.copyWith(os: DesktopBundleOs.windows);

final DesktopUpdateFeed _feed = DesktopUpdateFeed(bytes: Uint8List.fromList([1, 2, 3]), signature: "signature");

const VelopackStagedRelease _release = VelopackStagedRelease(
  fileName: "sesori-desktop-1.8.5-stable-full.nupkg",
  version: "1.8.5",
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
  String get velopackLibraryPath => "velopack_libc.dll";

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

class _MockDesktopUpdateFeedApi() extends Mock implements DesktopUpdateFeedApi;

class _MockDesktopUpdateFeedValidator() extends Mock implements DesktopUpdateFeedValidator;

class _MockVelopackUpdateApi() extends Mock implements VelopackUpdateApi;
