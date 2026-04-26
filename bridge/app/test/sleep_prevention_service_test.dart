import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings.dart';
import 'package:sesori_bridge/src/repositories/bridge_settings_repository.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:sesori_bridge/src/services/sleep_prevention_service.dart';
import 'package:test/test.dart';

void main() {
  group('SleepPreventionService', () {
    test('enables wake lock when configured mode is always', () async {
      final settingsApi = _QueueBridgeSettingsApi(
        readResults: <String?>['{"sleepPrevention":"always"}'],
      );
      final wakeLockClient = _FakeWakeLockClient();
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      final appliedMode = await service.applyConfiguredMode();

      expect(appliedMode, SleepPreventionMode.always);
      expect(wakeLockClient.enableCalls, equals(1));
      expect(wakeLockClient.disableCalls, equals(0));
    });

    test('disables wake lock when configured mode is off', () async {
      final settingsApi = _QueueBridgeSettingsApi(
        readResults: <String?>['{"sleepPrevention":"off"}'],
      );
      final wakeLockClient = _FakeWakeLockClient();
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      final appliedMode = await service.applyConfiguredMode();

      expect(appliedMode, SleepPreventionMode.off);
      expect(wakeLockClient.enableCalls, equals(0));
      expect(wakeLockClient.disableCalls, equals(1));
    });

    test('loads settings fresh on every applyConfiguredMode call', () async {
      final settingsApi = _QueueBridgeSettingsApi(
        readResults: <String?>[
          '{"sleepPrevention":"always"}',
          '{"sleepPrevention":"off"}',
        ],
      );
      final wakeLockClient = _FakeWakeLockClient();
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      final firstMode = await service.applyConfiguredMode();
      final secondMode = await service.applyConfiguredMode();

      expect(firstMode, SleepPreventionMode.always);
      expect(secondMode, SleepPreventionMode.off);
      expect(settingsApi.readCount, equals(2));
      expect(wakeLockClient.enableCalls, equals(1));
      expect(wakeLockClient.disableCalls, equals(1));
    });

    test('returns configured mode when enabling wake lock fails', () async {
      final settingsApi = _QueueBridgeSettingsApi(
        readResults: <String?>['{"sleepPrevention":"always"}'],
      );
      final wakeLockClient = _FakeWakeLockClient(failEnable: true);
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      final appliedMode = await service.applyConfiguredMode();

      expect(appliedMode, SleepPreventionMode.always);
      expect(wakeLockClient.enableCalls, equals(1));
    });

    test('returns configured mode when disabling wake lock fails', () async {
      final settingsApi = _QueueBridgeSettingsApi(
        readResults: <String?>['{"sleepPrevention":"off"}'],
      );
      final wakeLockClient = _FakeWakeLockClient(failDisable: true);
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      final appliedMode = await service.applyConfiguredMode();

      expect(appliedMode, SleepPreventionMode.off);
      expect(wakeLockClient.disableCalls, equals(1));
    });

    test('dispose disables wake lock', () async {
      final settingsApi = _QueueBridgeSettingsApi(
        readResults: <String?>['{"sleepPrevention":"always"}'],
      );
      final wakeLockClient = _FakeWakeLockClient();
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      await service.dispose();

      expect(wakeLockClient.disableCalls, equals(1));
      expect(settingsApi.readCount, equals(0));
    });

    test('dispose swallows wake lock disable failures', () async {
      final settingsApi = _QueueBridgeSettingsApi(readResults: const <String?>[]);
      final wakeLockClient = _FakeWakeLockClient(failDisable: true);
      final service = SleepPreventionService(
        bridgeSettingsRepository: BridgeSettingsRepository(api: settingsApi),
        wakeLockRepository: WakeLockRepository(client: wakeLockClient),
      );

      await service.dispose();

      expect(wakeLockClient.disableCalls, equals(1));
    });
  });
}

class _QueueBridgeSettingsApi implements BridgeSettingsApi {
  final List<String?> _readResults;

  @override
  String get configFilePath => '/tmp/config.json';

  int readCount = 0;

  _QueueBridgeSettingsApi({
    required List<String?> readResults,
  }) : _readResults = List<String?>.from(readResults);

  @override
  Future<String?> readConfig() async {
    readCount += 1;
    if (_readResults.isEmpty) {
      return null;
    }
    return _readResults.removeAt(0);
  }

  @override
  Future<void> writeConfig(String jsonContent) async {}
}

class _FakeWakeLockClient implements WakeLockClient {
  final bool failEnable;
  final bool failDisable;

  int enableCalls = 0;
  int disableCalls = 0;

  _FakeWakeLockClient({
    this.failEnable = false,
    this.failDisable = false,
  });

  @override
  Future<void> enable() async {
    enableCalls += 1;
    if (failEnable) {
      throw StateError('enable failed');
    }
  }

  @override
  Future<void> disable() async {
    disableCalls += 1;
    if (failDisable) {
      throw StateError('disable failed');
    }
  }
}
