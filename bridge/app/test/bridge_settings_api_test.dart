import 'dart:io';

import 'package:sesori_bridge/src/api/bridge_settings_api.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempHome;

  setUp(() {
    tempHome = Directory.systemTemp.createTempSync('bridge_settings_api_test_');
  });

  tearDown(() {
    if (tempHome.existsSync()) {
      tempHome.deleteSync(recursive: true);
    }
  });

  group('BridgeSettingsApi', () {
    test('configFilePath points to the bridge config file', () {
      final api = BridgeSettingsApi(homeDirectory: tempHome.path);

      expect(
        api.configFilePath,
        equals('${tempHome.path}/.config/sesori-bridge/config.json'),
      );
    });

    test('readConfig returns null when the file is missing', () async {
      final api = BridgeSettingsApi(homeDirectory: tempHome.path);

      final result = await api.readConfig();

      expect(result, isNull);
    });

    test('writeConfig creates the directory and writes raw contents', () async {
      final api = BridgeSettingsApi(homeDirectory: tempHome.path);

      await api.writeConfig('{"sleepPrevention":"always"}');

      expect(Directory('${tempHome.path}/.config/sesori-bridge').existsSync(), isTrue);
      expect(File(api.configFilePath).existsSync(), isTrue);
      expect(await api.readConfig(), equals('{"sleepPrevention":"always"}'));
    });
  });
}
