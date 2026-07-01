import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeDerivedProjectsMixin', () {
    final derived = _DerivedPlugin();

    test('getProjects returns empty (never consulted for derived plugins)', () async {
      expect(await derived.getProjects(), isEmpty);
    });

    test('getProject throws — reaching it means the derived path was bypassed', () {
      expect(
        () => derived.getProject('/some/dir'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('renameProject throws — renames are persisted bridge-side', () {
      expect(
        () => derived.renameProject(projectId: '/some/dir', name: 'New'),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('listAllSessions is the only project-related member a derived plugin supplies', () async {
      expect(await derived.listAllSessions(), isEmpty);
    });
  });
}

/// The shape of a real derive-style plugin: mix in the boilerplate no-ops and
/// implement only [BridgeDerivedProjectSource.listAllSessions]. Compiling this
/// composition proves the mixin attaches without `extends` (plugins
/// `implements`) and that the capability interface lives off `BridgePluginApi`.
class _DerivedPlugin with BridgeDerivedProjectsMixin implements BridgeDerivedProjectSource {
  @override
  Future<List<PluginSession>> listAllSessions() async => const [];

  @override
  String get launchDirectory => "/tmp/launch";
}
