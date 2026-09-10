import "dart:async";

enum PluginGenerationResidency() {
  importOnly,
  normal,
}

class PluginGenerationResidencyController({required PluginGenerationResidency initial}) {
  PluginGenerationResidency _value = initial;
  final StreamController<PluginGenerationResidency> _changes = StreamController<PluginGenerationResidency>.broadcast(
    sync: true,
  );

  PluginGenerationResidency get value => _value;
  Stream<PluginGenerationResidency> get changes => _changes.stream;

  void promoteToNormal() {
    if (_value == PluginGenerationResidency.normal) return;
    _value = PluginGenerationResidency.normal;
    if (!_changes.isClosed) _changes.add(_value);
  }

  Future<void> dispose() => _changes.close();
}
