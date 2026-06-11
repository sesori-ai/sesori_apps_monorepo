import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('PluginDiagnostics', () {
    test('toString is just the plugin id without an endpoint', () {
      const diagnostics = PluginDiagnostics(pluginId: 'opencode', endpoint: null, details: {});
      expect(diagnostics.toString(), 'opencode');
    });

    test('toString includes the endpoint when present', () {
      const diagnostics = PluginDiagnostics(pluginId: 'opencode', endpoint: 'http://127.0.0.1:4096', details: {});
      expect(diagnostics.toString(), 'opencode @ http://127.0.0.1:4096');
    });

    test('toString appends detail facts', () {
      const diagnostics = PluginDiagnostics(
        pluginId: 'opencode',
        endpoint: 'http://127.0.0.1:4096',
        details: {'mode': 'attached'},
      );
      expect(diagnostics.toString(), 'opencode @ http://127.0.0.1:4096 (mode: attached)');
    });
  });
}
