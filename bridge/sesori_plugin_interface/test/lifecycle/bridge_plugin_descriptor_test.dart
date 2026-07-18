import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgePluginDescriptor', () {
    test('is const-constructible and inert', () {
      const descriptor = _MinimalDescriptor();
      expect(descriptor.id, 'noop');
      expect(descriptor.options, isEmpty);
      expect(descriptor.stateStorage, PluginStateStorage.isolated);
    });

    test('validateConfig accepts everything by default', () {
      const descriptor = _MinimalDescriptor();
      expect(() => descriptor.validateConfig(const PluginConfig.empty()), returnsNormally);
    });

    test('a descriptor can reject configuration with PluginConfigException', () {
      const descriptor = _ValidatingDescriptor();
      const config = PluginConfig(values: {'no-auto-start': true, 'port': null});

      expect(
        () => descriptor.validateConfig(config),
        throwsA(isA<PluginConfigException>()),
      );
    });

    test('checkAvailability reports available by default', () async {
      const descriptor = _MinimalDescriptor();

      final availability = await descriptor.checkAvailability(
        config: const PluginConfig.empty(),
        processes: const _UnusedProcessService(),
        environment: const <String, String>{},
      );

      expect(availability, isA<PluginAvailable>());
    });
  });

  group('PluginOption', () {
    test('a flag option carries its defaults', () {
      const option = PluginFlagOption(
        name: 'no-auto-start',
        help: 'Skip auto-starting the server',
        defaultsTo: false,
        negatable: false,
      );
      expect(option.defaultsTo, isFalse);
      expect(option.negatable, isFalse);
    });

    test('a value option carries default, allowed values, and value help', () {
      const option = PluginValueOption(
        name: 'opencode-bin',
        help: 'Path to opencode binary',
        defaultsTo: 'opencode',
        allowedValues: null,
        valueHelp: 'path',
        validate: null,
      );
      expect(option.defaultsTo, 'opencode');
      expect(option.allowedValues, isNull);
      expect(option.valueHelp, 'path');
    });

    test('the legacy OpenCode option set is expressible', () {
      const options = <PluginOption>[
        PluginValueOption.integer(
          name: 'port',
          help: 'Port for opencode server to listen on',
          defaultsTo: null,
          valueHelp: null,
        ),
        PluginFlagOption(
          name: 'no-auto-start',
          help: 'Skip auto-starting opencode server',
          defaultsTo: false,
          negatable: false,
        ),
        PluginValueOption(
          name: 'password',
          help: 'Override server password',
          defaultsTo: '',
          allowedValues: null,
          valueHelp: null,
          validate: null,
        ),
        PluginValueOption(
          name: 'opencode-bin',
          help: 'Path to opencode binary',
          defaultsTo: 'opencode',
          allowedValues: null,
          valueHelp: null,
          validate: null,
        ),
      ];
      expect(options.map((option) => option.name), ['port', 'no-auto-start', 'password', 'opencode-bin']);
    });

    test('an integer option validates its raw value at parse time', () {
      const option = PluginValueOption.integer(name: 'port', help: 'Port', defaultsTo: null, valueHelp: null);

      expect(() => option.validate!('port', '4096'), returnsNormally);
      expect(
        () => option.validate!('port', 'not-a-port'),
        throwsA(
          isA<PluginConfigException>().having(
            (exception) => exception.message,
            'message',
            "The --port option expects an integer, got 'not-a-port'.",
          ),
        ),
      );
    });

    test('a plain value option has no validate hook', () {
      const option = PluginValueOption(
        name: 'password',
        help: 'Password',
        defaultsTo: null,
        allowedValues: null,
        valueHelp: null,
        validate: null,
      );
      expect(option.validate, isNull);
    });

    test('deprecatedAliases default to empty and are carried when supplied', () {
      const noAliases = PluginValueOption(
        name: 'host',
        help: 'Host',
        defaultsTo: '127.0.0.1',
        allowedValues: null,
        valueHelp: null,
        validate: null,
      );
      expect(noAliases.deprecatedAliases, isEmpty);

      const valueWithAlias = PluginValueOption(
        name: 'password',
        help: 'Password',
        defaultsTo: '',
        allowedValues: null,
        valueHelp: null,
        validate: null,
        deprecatedAliases: ['password'],
      );
      expect(valueWithAlias.deprecatedAliases, ['password']);

      const integerWithAlias = PluginValueOption.integer(
        name: 'port',
        help: 'Port',
        defaultsTo: null,
        valueHelp: null,
        deprecatedAliases: ['port'],
      );
      expect(integerWithAlias.deprecatedAliases, ['port']);

      const flagWithAlias = PluginFlagOption(
        name: 'no-auto-start',
        help: 'Attach to an existing server',
        defaultsTo: false,
        negatable: true,
        deprecatedAliases: ['no-auto-start'],
      );
      expect(flagWithAlias.deprecatedAliases, ['no-auto-start']);
    });
  });
}

class _MinimalDescriptor extends BridgePluginDescriptor {
  const _MinimalDescriptor();

  @override
  String get id => 'noop';

  @override
  String get displayName => 'No-op plugin';

  @override
  List<PluginOption> get options => const [];

  @override
  Future<BridgePlugin> start(PluginHost host) {
    throw UnsupportedError('start is not exercised in this test');
  }
}

/// The default `checkAvailability` ignores its process service, so this fake
/// throws on every call to prove the default never touches it.
class _UnusedProcessService implements HostProcessService {
  const _UnusedProcessService();

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) => throw UnimplementedError();

  @override
  Future<ProcessIdentity?> inspect({required int pid}) => throw UnimplementedError();

  @override
  Future<SignalResult> signalGraceful({required int pid}) => throw UnimplementedError();

  @override
  Future<SignalResult> signalForce({required int pid}) => throw UnimplementedError();
}

class _ValidatingDescriptor extends BridgePluginDescriptor {
  const _ValidatingDescriptor();

  @override
  String get id => 'validating';

  @override
  String get displayName => 'Validating plugin';

  @override
  List<PluginOption> get options => const [
    PluginValueOption(
      name: 'port',
      help: 'Port',
      defaultsTo: null,
      allowedValues: null,
      valueHelp: null,
      validate: null,
    ),
    PluginFlagOption(name: 'no-auto-start', help: 'Attach to an existing server', defaultsTo: false, negatable: false),
  ];

  @override
  void validateConfig(PluginConfig config) {
    if (config.flag('no-auto-start') && config.intValue('port') == null) {
      throw const PluginConfigException('The --no-auto-start flag requires --port to be set.');
    }
  }

  @override
  Future<BridgePlugin> start(PluginHost host) {
    throw UnsupportedError('start is not exercised in this test');
  }
}
