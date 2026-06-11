import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('PluginConfig.flag', () {
    test('returns the parsed flag value', () {
      const config = PluginConfig(values: {'no-auto-start': true});
      expect(config.flag('no-auto-start'), isTrue);
    });

    test('throws ArgumentError for an undeclared name', () {
      const config = PluginConfig.empty();
      expect(() => config.flag('no-auto-start'), throwsArgumentError);
    });

    test('throws ArgumentError when the option is not a flag', () {
      const config = PluginConfig(values: {'port': '4096'});
      expect(() => config.flag('port'), throwsArgumentError);
    });
  });

  group('PluginConfig.value', () {
    test('returns the raw string, or null when absent', () {
      const config = PluginConfig(values: {'opencode-bin': 'opencode', 'port': null});
      expect(config.value('opencode-bin'), 'opencode');
      expect(config.value('port'), isNull);
    });

    test('throws ArgumentError for an undeclared name', () {
      const config = PluginConfig.empty();
      expect(() => config.value('port'), throwsArgumentError);
    });

    test('throws ArgumentError when the option is a flag', () {
      const config = PluginConfig(values: {'no-auto-start': false});
      expect(() => config.value('no-auto-start'), throwsArgumentError);
    });
  });

  group('PluginConfig.intValue', () {
    test('parses a numeric value', () {
      const config = PluginConfig(values: {'port': '4096'});
      expect(config.intValue('port'), 4096);
    });

    test('returns null for absent or empty values', () {
      const config = PluginConfig(values: {'port': null, 'debug-port': ''});
      expect(config.intValue('port'), isNull);
      expect(config.intValue('debug-port'), isNull);
    });

    test('throws PluginConfigException naming the flag on a non-numeric value', () {
      const config = PluginConfig(values: {'port': 'not-a-port'});
      expect(
        () => config.intValue('port'),
        throwsA(
          isA<PluginConfigException>().having(
            (exception) => exception.message,
            'message',
            "The --port option expects an integer, got 'not-a-port'.",
          ),
        ),
      );
    });
  });

  group('PluginConfigException', () {
    test('toString carries the message', () {
      const exception = PluginConfigException('The --no-auto-start flag requires --port to be set.');
      expect(exception.toString(), 'PluginConfigException: The --no-auto-start flag requires --port to be set.');
    });
  });
}
