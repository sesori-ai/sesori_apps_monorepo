import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

class _Inventory({required final bool outdated}) implements ManagedRuntimeInventory {
  @override
  bool hasOutdatedVersion({required String stateDirectory}) => outdated;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PathAuthority({required final bool absent}) implements ManagedRuntimePathAuthority {
  int calls = 0;

  @override
  Future<bool> isPathAbsent({
    required Map<String, String> environment,
    required StartAbortSignal abortSignal,
  }) async {
    calls++;
    return absent;
  }
}

void main() {
  test("requires outdated inventory before consulting PATH authority", () async {
    for (final candidate in [
      (outdated: false, pathAbsent: true, expected: false, calls: 0),
      (outdated: true, pathAbsent: false, expected: false, calls: 1),
      (outdated: true, pathAbsent: true, expected: true, calls: 1),
    ]) {
      final authority = _PathAuthority(absent: candidate.pathAbsent);
      final service = ManagedRuntimeUpgradeService(
        pathAuthority: authority,
        inventory: _Inventory(outdated: candidate.outdated),
      );

      expect(
        await service.shouldUpgrade(environment: const {}, stateDirectory: "/state"),
        candidate.expected,
      );
      expect(authority.calls, candidate.calls);
    }
  });
}
