import 'update_reconciliation_service.dart';
import 'update_service.dart';

/// Owns the bridge self-update lifecycle as a single unit: the one-shot startup
/// [reconcile], the background check/stage/apply [start] cadence, and [dispose]
/// of the resources the underlying services hold.
///
/// Consumers drive the whole update subsystem through this one object instead of
/// reaching into the individual services, so disposal stays encapsulated here —
/// the single owner that knows what needs tearing down.
class UpdateLifecycleService {
  UpdateLifecycleService({
    required UpdateService updateService,
    required UpdateReconciliationService reconciliationService,
  }) : _updateService = updateService,
       _reconciliationService = reconciliationService;

  final UpdateService _updateService;
  final UpdateReconciliationService _reconciliationService;

  /// Reconciles a prior in-place update (fast, local, network-free). Run once,
  /// early on startup, before the session begins.
  Future<void> reconcile() => _reconciliationService.reconcile();

  /// Starts the background check/download/stage/apply cadence. Idempotent.
  void start() => _updateService.start();

  /// Tears down the update subsystem, releasing resources held by the owned
  /// services (currently the background update cadence subscription).
  Future<void> dispose() => _updateService.dispose();
}
