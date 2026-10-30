import "dart:async";

import "package:injectable/injectable.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/founder_call/founder_call_availability.dart";
import "../foundation/models/founder_call/founder_call_config.dart";
import "../foundation/models/founder_call/founder_call_progress.dart";
import "../foundation/models/founder_call/founder_call_sheet_request.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../repositories/founder_call_repository.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "product_analytics_service.dart";

/// Invites new users to book a call with the CEO.
///
/// A fresh sign-in arms the device; users who were already signed in when they
/// updated are never armed, so the invitation never opens by itself for them.
/// On an armed device, the first connected computer claims the sheet: the
/// service retires the invitation and emits on [sheetRequests]. Opening the
/// booking link from any surface also retires it.
///
/// Only the mobile shell calls [start]. Until then every record call that
/// writes progress is a no-op, so the desktop shell, which shares the login
/// cubit, stores nothing.
@lazySingleton
class FounderCallService({
  required final ConnectionService _connectionService,
  required final FounderCallRepository _repository,
  required final ProductAnalyticsService _productAnalyticsService,
}) {
  final StreamController<FounderCallSheetRequest> _sheetRequests =
      StreamController<FounderCallSheetRequest>.broadcast();

  /// Fetched once per launch, on first use.
  late final Future<FounderCallConfig> _config = _repository.readConfig();

  StreamSubscription<ConnectionStatus>? _statusSubscription;

  /// Serializes the read-modify-write updates of the stored progress.
  Future<void> _lastUpdate = Future<void>.value();

  /// Emits once for the automatic sheet, right after it is claimed.
  Stream<FounderCallSheetRequest> get sheetRequests => _sheetRequests.stream;

  /// Starts watching for the first connected computer.
  void start() {
    _statusSubscription ??= _connectionService.status.listen(_onStatus);
    unawaited(_config);
  }

  /// An interactive sign-in succeeded on this device.
  Future<void> recordFreshLogin() => _update(() async {
    if (await _repository.readProgress() is FounderCallUnarmed) {
      await _repository.writeProgress(progress: const FounderCallArmed());
    }
  });

  /// Whether the call is offered at all, for the permanent Settings entry.
  Future<FounderCallAvailability> readAvailability() async => switch (await _config) {
    FounderCallDisabled() => const FounderCallHidden(),
    FounderCallEnabled(:final bookingUrl, :final copy) => FounderCallAvailable(bookingUrl: bookingUrl, copy: copy),
  };

  /// The booking page opened from [surface].
  Future<void> recordLinkOpened({required FounderCallSurface surface}) {
    _log(event: ProductAnalyticsEvent.founderCallLinkOpened(surface: surface));
    return _update(() => _repository.writeProgress(progress: const FounderCallRetired()));
  }

  /// The automatic sheet closed without opening the booking page.
  void recordSheetDeclined() {
    _log(event: const ProductAnalyticsEvent.founderCallDeclined(surface: FounderCallSurface.computerConnectedSheet));
  }

  void _onStatus(ConnectionStatus status) {
    if (status is ConnectionConnected) unawaited(_claimSheet());
  }

  Future<void> _claimSheet() => _update(() async {
    if (await _repository.readProgress() is! FounderCallArmed) return;
    final config = await _config;
    if (config is! FounderCallEnabled || !config.afterComputer) return;
    // Retiring before showing means a crash or relaunch never shows it twice.
    await _repository.writeProgress(progress: const FounderCallRetired());
    logi("Showing the founder call sheet for the first connected computer");
    _log(event: const ProductAnalyticsEvent.founderCallShown(surface: FounderCallSurface.computerConnectedSheet));
    if (!_sheetRequests.isClosed) {
      _sheetRequests.add(FounderCallSheetRequest(bookingUrl: config.bookingUrl, copy: config.copy));
    }
  });

  Future<void> _update(Future<void> Function() update) {
    if (_statusSubscription == null) return Future<void>.value();
    return _lastUpdate = _lastUpdate.then((_) => update()).catchError((Object error, StackTrace stackTrace) {
      logw("Failed to update the founder call progress", error, stackTrace);
    });
  }

  void _log({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService.logEvent(event: event, occurredAtUtc: DateTime.now().toUtc()).then<void>((result) {
        if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
          logw("Failed to deliver founder call analytics event");
        }
      }),
    );
  }

  @disposeMethod
  Future<void> dispose() async {
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    await _sheetRequests.close();
  }
}
