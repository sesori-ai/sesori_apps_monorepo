import 'dart:async';
import 'dart:io' show HttpException, SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Console, Log;

import '../foundation/github_rate_limit_exception.dart';
import '../foundation/update_message_formatter.dart';
import '../foundation/update_policy.dart';
import '../models/release_info.dart';
import '../models/update_apply_outcome.dart';
import '../models/update_result.dart';
import '../repositories/release_repository.dart';
import '../repositories/update_log_repository.dart';
import 'update_apply_service.dart';
import 'update_install_service.dart';

/// Periodic + startup update coordinator.
///
/// On start (and every 4h) it checks for a newer eligible release, stages it via
/// [UpdateInstallService], and delegates the in-place swap to [UpdateApplyService].
/// It never relaunches — the swapped binary takes effect on the next launch
/// (or an explicit phone-triggered restart). Benign conditions (no newer
/// release, offline, rate-limited, disabled) stay quiet; genuine failures are
/// surfaced via `Console.error` and the durable update log.
class UpdateService {
  UpdateService({
    required ReleaseRepository releaseRepository,
    required UpdateInstallService updateInstallService,
    required UpdateApplyService updateApplyService,
    required UpdateLogRepository logRepository,
    required UpdateMessageFormatter messageFormatter,
    required String installRoot,
    required String executablePath,
    required String managedExecutablePath,
    required Map<String, String> environment,
    required bool isSupervised,
  }) : _releaseRepository = releaseRepository,
       _updateInstallService = updateInstallService,
       _updateApplyService = updateApplyService,
       _logRepository = logRepository,
       _messageFormatter = messageFormatter,
       _installRoot = installRoot,
       _executablePath = executablePath,
       _managedExecutablePath = managedExecutablePath,
       _environment = environment,
       _isSupervised = isSupervised;

  final ReleaseRepository _releaseRepository;
  final UpdateInstallService _updateInstallService;
  final UpdateApplyService _updateApplyService;
  final UpdateLogRepository _logRepository;
  final UpdateMessageFormatter _messageFormatter;
  final String _installRoot;
  final String _executablePath;
  final String _managedExecutablePath;
  final Map<String, String> _environment;
  final bool _isSupervised;

  StreamSubscription<void>? _subscription;
  bool _disposed = false;

  @visibleForTesting
  void Function(String message) emitMessage = Console.message;

  @visibleForTesting
  void Function(String message) emitError = Console.error;

  @visibleForTesting
  void Function(String message) logWarning = Log.w;

  @visibleForTesting
  void Function(String message, Object error, StackTrace stackTrace) logError = Log.e;

  @visibleForTesting
  Duration pollInterval = const Duration(hours: 4);

  /// Begins the initial + periodic check/stage/apply pipeline in the
  /// background. A no-op when updates are disabled, this is not the managed
  /// install, or the bridge is supervised (the GUI updater owns the bundle).
  /// Idempotent — calling it again while already running does nothing.
  void start() {
    if (_subscription != null || _shouldSkipUpdates()) {
      return;
    }

    _subscription =
        Rx.concat<void>([
          Stream<void>.value(null),
          Stream<void>.periodic(pollInterval, (_) {}),
        ]).asyncMap((_) => _runCycle()).listen(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            logError('Update cycle stream error', error, stackTrace);
          },
        );
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
  }

  bool _shouldSkipUpdates() {
    return shouldSkipUpdates(
      environment: _environment,
      executablePath: _executablePath,
      managedExecutablePath: _managedExecutablePath,
      isSupervised: _isSupervised,
    );
  }

  Future<void> _runCycle() async {
    final ReleaseInfo? release;
    try {
      release = await _releaseRepository.checkForNewerRelease();
    } on GitHubRateLimitException catch (error) {
      // Expected, benign for a best-effort updater — stays quiet in Log.
      logWarning(_rateLimitMessage(error));
      return;
    } on SocketException catch (error) {
      // Offline / unreachable — benign; the next cycle retries.
      logWarning('Skipping update check — network unavailable: $error');
      return;
    } on TimeoutException catch (error) {
      logWarning('Skipping update check — the release check timed out: $error');
      return;
    } on HttpException catch (error) {
      logWarning('Skipping update check — network error: $error');
      return;
    } on ClientException catch (error) {
      logWarning('Skipping update check — network error: $error');
      return;
    } on Object catch (error, stackTrace) {
      await _reportGenuineFailure(
        toVersion: 'the latest release',
        reason: error.toString(),
        logDetail: 'Update check failed: $error\n$stackTrace',
      );
      return;
    }

    if (release == null) {
      return;
    }

    // Bail before any destructive work if the subsystem was disposed while the
    // (awaited) release check was in flight — dispose() cancels the schedule but
    // cannot abort an already-running cycle.
    if (_disposed) {
      return;
    }

    // Stage + apply can throw (unexpected stage error, lock/log/attempt write
    // failure). Catch here so a thrown failure is still surfaced to the user
    // and the durable log rather than vanishing into the stream's onError.
    try {
      final staged = await _updateInstallService.stageUpdate(
        release: release,
        installRoot: _installRoot,
      );
      final stagingPath = staged.stagingPath;
      if (staged.result != UpdateResult.success || stagingPath == null) {
        await _reportStageFailure(release: release, result: staged.result);
        return;
      }

      // Re-check after staging (another await): never apply an in-place swap
      // once disposed.
      if (_disposed) {
        return;
      }
      final UpdateApplyOutcome outcome = await _updateApplyService.apply(
        release: release,
        stagingPath: stagingPath,
      );
      switch (outcome) {
        case UpdateApplied(:final version):
          emitMessage(_messageFormatter.installedPendingActivation(toVersion: version));
          _handleApplied(version: version);
        case UpdateApplyLockBusy():
          // Another update is in progress — benign; apply logged a diagnostic.
          // The next cycle retries.
          break;
        case UpdateApplyFailed(:final reason, :final logPath):
          emitError(
            _messageFormatter.failureGuidance(
              toVersion: release.version,
              reason: reason,
              logPath: logPath,
            ),
          );
      }
    } on Object catch (error, stackTrace) {
      await _reportGenuineFailure(
        toVersion: release.version,
        reason: error.toString(),
        logDetail: 'Applying update to ${release.version} failed: $error\n$stackTrace',
      );
    }
  }

  /// Decides what to do after a successful in-place swap.
  ///
  /// The release is now staged for activation on the next launch, but this
  /// process still reports its old appVersion. When the platform applier can
  /// chain applies in-session (POSIX), advance the release baseline to what we
  /// just staged so the cycle keeps running and only acts on a strictly-newer
  /// release — picking up further updates published this session without ever
  /// re-applying this one. When it cannot (Windows, where the displaced backup
  /// stays locked until a restart), stop the cycle so a second apply never
  /// collides with the locked backup and fails on every retry.
  void _handleApplied({required String version}) {
    if (_updateApplyService.supportsInSessionChaining) {
      _releaseRepository.advanceBaselineTo(version: version);
    } else {
      _stopPolling();
    }
  }

  void _stopPolling() {
    final subscription = _subscription;
    _subscription = null;
    // Defer so we never cancel the subscription from within its own event.
    scheduleMicrotask(() => subscription?.cancel());
  }

  Future<void> _reportStageFailure({required ReleaseInfo release, required UpdateResult result}) async {
    switch (result) {
      case UpdateResult.networkError:
      case UpdateResult.alreadyLocked:
        // Transient/contended — benign; the next cycle retries.
        logWarning('Skipping update to ${release.version}: ${result.name}');
      case UpdateResult.permissionDenied:
      case UpdateResult.checksumFailed:
      case UpdateResult.downloadFailed:
      case UpdateResult.success:
        await _reportGenuineFailure(
          toVersion: release.version,
          reason: _stageFailureReason(result),
          logDetail: 'Staging ${release.version} failed: ${result.name}',
        );
    }
  }

  Future<void> _reportGenuineFailure({
    required String toVersion,
    required String reason,
    required String logDetail,
  }) async {
    // The durable log is best-effort: a failed write (e.g. an unwritable
    // install root — exactly the failure we may be reporting) must never
    // suppress the user-facing guidance.
    try {
      await _logRepository.log(message: logDetail);
    } on Object catch (error, stackTrace) {
      logError('Failed to persist update failure log', error, stackTrace);
    }
    emitError(
      _messageFormatter.failureGuidance(
        toVersion: toVersion,
        reason: reason,
        logPath: _logRepository.logPath,
      ),
    );
  }

  String _stageFailureReason(UpdateResult result) {
    switch (result) {
      case UpdateResult.permissionDenied:
        return 'permission denied writing to the install directory';
      case UpdateResult.checksumFailed:
        return 'the downloaded archive failed checksum verification';
      case UpdateResult.downloadFailed:
        return 'the release archive could not be downloaded or extracted';
      case UpdateResult.networkError:
        return 'a network error occurred';
      case UpdateResult.alreadyLocked:
        return 'another update is already in progress';
      case UpdateResult.success:
        return 'an unexpected error occurred';
    }
  }

  String _rateLimitMessage(GitHubRateLimitException error) {
    final reset = error.resetAt;
    final resetHint = reset == null ? '' : ' Limit resets around ${_formatLocalTime(reset)}.';
    if (error.authenticated) {
      return 'Skipping update check — GitHub API rate limit reached for the '
          'authenticated token (usually a temporary secondary limit).$resetHint';
    }
    return 'Skipping update check — GitHub API rate limit reached. '
        'Unauthenticated requests are capped at 60/hour per IP; set GITHUB_TOKEN '
        '(or GH_TOKEN) to raise this to 5000/hour.$resetHint';
  }

  String _formatLocalTime(DateTime time) {
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(time.hour)}:${pad(time.minute)}';
  }
}
