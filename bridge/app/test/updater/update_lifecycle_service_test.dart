import 'package:sesori_bridge/src/updater/services/update_lifecycle_service.dart';
import 'package:sesori_bridge/src/updater/services/update_reconciliation_service.dart';
import 'package:sesori_bridge/src/updater/services/update_service.dart';
import 'package:test/test.dart';

void main() {
  test('delegates reconcile/start and cascades dispose to the update service', () async {
    final updateService = _RecordingUpdateService();
    final reconciliationService = _RecordingReconciliationService();
    final lifecycle = UpdateLifecycleService(
      updateService: updateService,
      reconciliationService: reconciliationService,
    );

    await lifecycle.reconcile();
    lifecycle.start();
    await lifecycle.dispose();

    expect(reconciliationService.reconcileCount, 1);
    expect(updateService.startCount, 1);
    // The single owner tears down the update service — callers never reach into
    // the underlying service to dispose it.
    expect(updateService.disposeCount, 1);
  });
}

class _RecordingUpdateService implements UpdateService {
  int startCount = 0;
  int disposeCount = 0;

  @override
  void start() => startCount++;

  @override
  Future<void> dispose() async => disposeCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingReconciliationService implements UpdateReconciliationService {
  int reconcileCount = 0;

  @override
  Future<void> reconcile() async => reconcileCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
