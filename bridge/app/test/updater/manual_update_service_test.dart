import 'dart:io';

import 'package:sesori_bridge/src/updater/foundation/release_track.dart';
import 'package:sesori_bridge/src/updater/models/explicit_update_outcome.dart';
import 'package:sesori_bridge/src/updater/models/release_info.dart';
import 'package:sesori_bridge/src/updater/models/update_apply_outcome.dart';
import 'package:sesori_bridge/src/updater/models/update_install_result.dart';
import 'package:sesori_bridge/src/updater/models/update_resolution.dart';
import 'package:sesori_bridge/src/updater/models/update_result.dart';
import 'package:sesori_bridge/src/updater/repositories/release_repository.dart';
import 'package:sesori_bridge/src/updater/services/manual_update_service.dart';
import 'package:sesori_bridge/src/updater/services/update_apply_service.dart';
import 'package:sesori_bridge/src/updater/services/update_install_service.dart';
import 'package:sesori_plugin_runtime/sesori_plugin_runtime.dart';
import 'package:test/test.dart';

const String _managed = '/usr/local/bin/sesori-bridge';

ReleaseInfo _release(String version) => ReleaseInfo(
  version: version,
  assetUrl: 'https://example.com/bridge.tar.gz',
  checksumsUrl: 'https://example.com/checksums.txt',
  publishedAt: DateTime.utc(2026),
);

UpdateResolution _resolution({
  required String current,
  required bool currentEligible,
  String? latest,
}) => UpdateResolution(
  currentVersion: SemanticVersion.parse(value: current),
  currentEligible: currentEligible,
  latestEligible: latest == null ? null : _release(latest),
  latestVersion: latest == null ? null : SemanticVersion.parse(value: latest),
);

class _FakeReleaseRepository implements ReleaseRepository {
  UpdateResolution Function()? onResolve;
  Object? resolveError;

  @override
  Future<UpdateResolution> resolveUpdate() async {
    if (resolveError != null) {
      throw resolveError!;
    }
    return onResolve!();
  }

  @override
  Future<ReleaseInfo?> checkForNewerRelease() => throw UnimplementedError();
}

class _FakeInstallService implements UpdateInstallService {
  UpdateInstallResult result = const UpdateInstallResult.staged(stagingPath: '/tmp/staging');
  int stageCount = 0;

  @override
  Future<UpdateInstallResult> stageUpdate({required ReleaseInfo release, required String installRoot}) async {
    stageCount++;
    return result;
  }
}

class _FakeApplyService implements UpdateApplyService {
  UpdateApplyOutcome Function(ReleaseInfo release)? onApply;
  int applyCount = 0;

  @override
  void Function(String message) logWarning = (_) {};

  @override
  Future<UpdateApplyOutcome> apply({required ReleaseInfo release, required String stagingPath}) async {
    applyCount++;
    return onApply?.call(release) ?? UpdateApplied(version: release.version);
  }
}

void main() {
  late _FakeReleaseRepository release;
  late _FakeInstallService install;
  late _FakeApplyService apply;

  ManualUpdateService buildService({
    ReleaseTrack track = ReleaseTrack.stable,
    String executablePath = _managed,
  }) => ManualUpdateService(
    releaseRepository: release,
    updateInstallService: install,
    updateApplyService: apply,
    track: track,
    installRoot: '/tmp/install',
    executablePath: executablePath,
    managedExecutablePath: _managed,
  );

  setUp(() {
    release = _FakeReleaseRepository();
    install = _FakeInstallService();
    apply = _FakeApplyService();
  });

  group('plain update', () {
    test('installs a strictly-newer release as an upgrade', () async {
      release.onResolve = () => _resolution(current: '1.0.0', currentEligible: true, latest: '2.0.0');

      final outcome = await buildService().runUpdate(force: false);

      expect(
        outcome,
        isA<ExplicitUpdateApplied>()
            .having((o) => o.kind, 'kind', UpdateAppliedKind.upgrade)
            .having((o) => o.fromVersion, 'from', '1.0.0')
            .having((o) => o.toVersion, 'to', '2.0.0'),
      );
      expect(install.stageCount, 1);
      expect(apply.applyCount, 1);
    });

    test('reports already-latest without staging when nothing newer exists', () async {
      release.onResolve = () => _resolution(current: '2.0.0', currentEligible: true, latest: '2.0.0');

      final outcome = await buildService().runUpdate(force: false);

      expect(
        outcome,
        isA<ExplicitUpdateAlreadyLatest>().having((o) => o.version, 'version', '2.0.0'),
      );
      expect(install.stageCount, 0);
      expect(apply.applyCount, 0);
    });

    test('reports a track mismatch when the running build is off-track', () async {
      // Running an internal build while track=stable; latest stable is older.
      release.onResolve = () => _resolution(current: '2.0.0-internal.3', currentEligible: false, latest: '1.5.0');

      final outcome = await buildService().runUpdate(force: false);

      expect(
        outcome,
        isA<ExplicitUpdateTrackMismatch>()
            .having((o) => o.currentVersion, 'current', '2.0.0-internal.3')
            .having((o) => o.latestVersion, 'latest', '1.5.0')
            .having((o) => o.track, 'track', ReleaseTrack.stable),
      );
      expect(install.stageCount, 0);
    });

    test('reports a mismatch (force hint) when ahead of the latest published build', () async {
      // A stable-looking build that is ahead of the latest published release —
      // a copied dev/QA build, or a release that was yanked. This must NOT
      // report "already latest"; --force is the only path back to the latest
      // published build.
      release.onResolve = () => _resolution(current: '9.9.9', currentEligible: true, latest: '1.5.0');

      final outcome = await buildService().runUpdate(force: false);

      expect(
        outcome,
        isA<ExplicitUpdateTrackMismatch>()
            .having((o) => o.currentVersion, 'current', '9.9.9')
            .having((o) => o.latestVersion, 'latest', '1.5.0'),
      );
      expect(install.stageCount, 0);
    });

    test('reports no eligible release when none is found', () async {
      release.onResolve = () => _resolution(current: '1.0.0', currentEligible: true, latest: null);

      final outcome = await buildService().runUpdate(force: false);

      expect(outcome, isA<ExplicitUpdateNoEligibleRelease>());
      expect(install.stageCount, 0);
    });
  });

  group('force update', () {
    test('reinstalls the same version', () async {
      release.onResolve = () => _resolution(current: '2.0.0', currentEligible: true, latest: '2.0.0');

      final outcome = await buildService().runUpdate(force: true);

      expect(
        outcome,
        isA<ExplicitUpdateApplied>().having((o) => o.kind, 'kind', UpdateAppliedKind.reinstall),
      );
      expect(apply.applyCount, 1);
    });

    test('downgrades from an internal build to the latest stable', () async {
      release.onResolve = () => _resolution(current: '2.0.0-internal.3', currentEligible: false, latest: '1.5.0');

      final outcome = await buildService().runUpdate(force: true);

      expect(
        outcome,
        isA<ExplicitUpdateApplied>()
            .having((o) => o.kind, 'kind', UpdateAppliedKind.downgrade)
            .having((o) => o.toVersion, 'to', '1.5.0'),
      );
      expect(apply.applyCount, 1);
    });

    test('upgrades when a newer release exists', () async {
      release.onResolve = () => _resolution(current: '1.0.0', currentEligible: true, latest: '2.0.0');

      final outcome = await buildService().runUpdate(force: true);

      expect(outcome, isA<ExplicitUpdateApplied>().having((o) => o.kind, 'kind', UpdateAppliedKind.upgrade));
    });
  });

  group('gating', () {
    test('refuses a non-managed install without resolving', () async {
      final outcome = await buildService(executablePath: '/somewhere/else/sesori-bridge').runUpdate(force: false);

      expect(
        outcome,
        isA<ExplicitUpdateNotManaged>().having((o) => o.executablePath, 'path', '/somewhere/else/sesori-bridge'),
      );
      expect(install.stageCount, 0);
    });

    test('refuses an npm-payload run directly', () async {
      final outcome = await buildService(
        executablePath: '/x/node_modules/sesori-bridge-darwin-arm64/lib/runtime/bin/sesori-bridge',
      ).runUpdate(force: false);

      expect(outcome, isA<ExplicitUpdateNpmDirect>());
      expect(install.stageCount, 0);
    });
  });

  group('failures', () {
    test('a network error during resolution is a failure', () async {
      release.resolveError = const SocketException('offline');

      final outcome = await buildService().runUpdate(force: false);

      expect(outcome, isA<ExplicitUpdateFailed>().having((o) => o.reason, 'reason', contains('GitHub')));
    });

    test('a stage failure is surfaced with a reason', () async {
      release.onResolve = () => _resolution(current: '1.0.0', currentEligible: true, latest: '2.0.0');
      install.result = const UpdateInstallResult.failed(result: UpdateResult.checksumFailed);

      final outcome = await buildService().runUpdate(force: false);

      expect(outcome, isA<ExplicitUpdateFailed>().having((o) => o.reason, 'reason', contains('checksum')));
      expect(apply.applyCount, 0);
    });

    test('an apply failure carries the reason and log path', () async {
      release.onResolve = () => _resolution(current: '1.0.0', currentEligible: true, latest: '2.0.0');
      apply.onApply = (_) => const UpdateApplyFailed(reason: 'disk full', logPath: '/tmp/update.log');

      final outcome = await buildService().runUpdate(force: false);

      expect(
        outcome,
        isA<ExplicitUpdateFailed>()
            .having((o) => o.reason, 'reason', 'disk full')
            .having((o) => o.logPath, 'logPath', '/tmp/update.log'),
      );
    });

    test('apply lock contention maps to a lock-busy outcome', () async {
      release.onResolve = () => _resolution(current: '1.0.0', currentEligible: true, latest: '2.0.0');
      apply.onApply = (_) => const UpdateApplyLockBusy();

      final outcome = await buildService().runUpdate(force: false);

      expect(outcome, isA<ExplicitUpdateLockBusy>());
    });
  });
}
