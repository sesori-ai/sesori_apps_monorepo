import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

import "../models/cursor_catalog_models.dart";

/// Layer-2 owner of Cursor's learned catalog and per-scope probe outcomes.
class CursorCatalogTracker {
  int _revision = 0;
  String? _modelConfigId;
  List<CursorCatalogOption> _models = const [];
  String? _modeConfigId;
  List<CursorCatalogOption> _modes = const [];
  String? _defaultModeId;
  final Map<String, CursorThoughtLevelSnapshot> _thoughtLevelsByModel = {};
  List<String> _provisionalThoughtLevelVariants = const [];
  String? _currentModelId;
  final Map<String, CursorCatalogProbeOutcome> _outcomesByScope = {};

  String? get modelConfigId => _modelConfigId;
  List<CursorCatalogOption> get models => _models;
  String? get modeConfigId => _modeConfigId;
  List<CursorCatalogOption> get modes => _modes;
  String? get defaultModeId => _defaultModeId;
  String? get currentModelId => _currentModelId;

  /// Monotonically identifies catalog mutations so an isolated refresh cannot
  /// replace newer state captured from the live Cursor process.
  int get revision => _revision;

  bool get isComplete => _models.isNotEmpty && _modes.isNotEmpty && _provisionalThoughtLevelVariants.isNotEmpty;

  void applyBootstrapSnapshot({required CursorCatalogBootstrapSnapshot snapshot}) {
    _revision++;
    if (_models.isEmpty && snapshot.models.isNotEmpty) _models = snapshot.models;
    if (_modes.isEmpty && snapshot.modes.isNotEmpty) _modes = snapshot.modes;
    _defaultModeId ??= snapshot.defaultModeId;
    for (final entry in snapshot.thoughtLevelsByModel.entries) {
      _thoughtLevelsByModel.putIfAbsent(entry.key, () => entry.value);
      if (_provisionalThoughtLevelVariants.isEmpty && entry.value.variants.isNotEmpty) {
        _provisionalThoughtLevelVariants = entry.value.variants;
      }
    }
  }

  CursorCatalogCaptureResult applySnapshot({
    required CursorCatalogSnapshot snapshot,
    required bool fromNewSession,
    required String? thoughtLevelModelId,
    required bool captureThoughtLevelDefault,
  }) {
    _revision++;
    if (snapshot.modelConfigId != null) _modelConfigId = snapshot.modelConfigId;
    if (snapshot.models.isNotEmpty) _models = snapshot.models;
    final loadedModelId = snapshot.loadedModelId;
    if (fromNewSession) {
      _currentModelId = loadedModelId != null && hasModel(modelId: loadedModelId) ? loadedModelId : null;
    }

    if (snapshot.modeConfigId != null) _modeConfigId = snapshot.modeConfigId;
    if (snapshot.modes.isNotEmpty) _modes = snapshot.modes;
    if (fromNewSession && snapshot.loadedModeId != null) {
      _defaultModeId = snapshot.loadedModeId;
    }

    final thoughtLevel = snapshot.thoughtLevel;
    final resolvedThoughtLevelModelId = thoughtLevelModelId ?? loadedModelId ?? _currentModelId;
    if (thoughtLevel != null && resolvedThoughtLevelModelId != null && resolvedThoughtLevelModelId.isNotEmpty) {
      final previous = _thoughtLevelsByModel[resolvedThoughtLevelModelId];
      _thoughtLevelsByModel[resolvedThoughtLevelModelId] = CursorThoughtLevelSnapshot(
        configId: thoughtLevel.configId,
        variants: thoughtLevel.variants,
        defaultValue: captureThoughtLevelDefault
            ? thoughtLevel.defaultValue ?? previous?.defaultValue
            : previous?.defaultValue,
      );
      if (_provisionalThoughtLevelVariants.isEmpty && thoughtLevel.variants.isNotEmpty) {
        _provisionalThoughtLevelVariants = thoughtLevel.variants;
      }
    }

    return CursorCatalogCaptureResult(loadedModelId: loadedModelId);
  }

  bool hasModel({required String modelId}) => _models.any((option) => option.value == modelId);

  bool hasModeOption({required String modeId}) => _modes.any((option) => option.value == modeId);

  String? resolveModeId({required String? agent}) {
    if (agent == null || agent.isEmpty) return null;
    if (hasModeOption(modeId: agent)) return agent;
    for (final mode in _modes) {
      if (mode.name == agent) return mode.value;
    }
    return null;
  }

  CursorThoughtLevelSnapshot? thoughtLevelForModel({required String modelId}) => _thoughtLevelsByModel[modelId];

  List<String> variantsForModel({required String modelId}) =>
      _thoughtLevelsByModel[modelId]?.variants ?? _provisionalThoughtLevelVariants;

  String? get firstModelId => _models.isEmpty ? null : _models.first.value;

  void recordOutcome({
    required String scope,
    required CursorCatalogProbeOutcome outcome,
  }) {
    _outcomesByScope[_normalizeScope(scope: scope)] = outcome;
  }

  CursorCatalogProbeOutcome? outcomeForScope({required String scope}) =>
      _outcomesByScope[_normalizeScope(scope: scope)];

  /// Invalidates discovery decisions made for an older catalog snapshot.
  void invalidateProbeOutcomes() => _outcomesByScope.clear();

  /// Creates an isolated mutable copy for reuse discovery. The service can
  /// commit it atomically only if the live tracker did not change meanwhile.
  CursorCatalogTracker stageForDiscovery() {
    final staged = CursorCatalogTracker();
    staged._revision = _revision;
    staged._modelConfigId = _modelConfigId;
    staged._models = List.unmodifiable(_models);
    staged._modeConfigId = _modeConfigId;
    staged._modes = List.unmodifiable(_modes);
    staged._defaultModeId = _defaultModeId;
    staged._thoughtLevelsByModel.addAll(_thoughtLevelsByModel);
    staged._provisionalThoughtLevelVariants = List.unmodifiable(
      _provisionalThoughtLevelVariants,
    );
    staged._currentModelId = _currentModelId;
    staged._outcomesByScope.addAll(_outcomesByScope);
    return staged;
  }

  /// Commits one staged reuse probe, including partial catalog progress and
  /// per-scope retry outcomes accumulated from the prior live snapshot.
  void replaceReusedCatalog({required CursorCatalogTracker discovered}) {
    _modelConfigId = discovered._modelConfigId;
    _models = List.unmodifiable(discovered._models);
    _modeConfigId = discovered._modeConfigId;
    _modes = List.unmodifiable(discovered._modes);
    _defaultModeId = discovered._defaultModeId;
    _thoughtLevelsByModel
      ..clear()
      ..addAll(discovered._thoughtLevelsByModel);
    _provisionalThoughtLevelVariants = List.unmodifiable(
      discovered._provisionalThoughtLevelVariants,
    );
    _currentModelId = discovered._currentModelId;
    _outcomesByScope
      ..clear()
      ..addAll(discovered._outcomesByScope);
    _revision++;
  }

  /// Replaces discoverable catalog data after a successful forced probe.
  /// Live-process defaults survive only when the refreshed catalog still
  /// contains them; a failed probe never calls this method.
  void replaceDiscoveredCatalog({
    required CursorCatalogTracker discovered,
    required String scope,
    required CursorCatalogProbeOutcome outcome,
  }) {
    final previousModelConfigId = _modelConfigId;
    final previousModeConfigId = _modeConfigId;
    final previousCurrentModelId = _currentModelId;
    final previousDefaultModeId = _defaultModeId;

    _modelConfigId = discovered._modelConfigId ?? previousModelConfigId;
    _models = List.unmodifiable(discovered._models);
    _modeConfigId = discovered._modeConfigId ?? previousModeConfigId;
    _modes = List.unmodifiable(discovered._modes);
    _thoughtLevelsByModel
      ..clear()
      ..addAll(discovered._thoughtLevelsByModel);
    _provisionalThoughtLevelVariants = List.unmodifiable(
      discovered._provisionalThoughtLevelVariants,
    );

    _currentModelId = previousCurrentModelId != null && hasModel(modelId: previousCurrentModelId)
        ? previousCurrentModelId
        : discovered._currentModelId;
    _defaultModeId = previousDefaultModeId != null && hasModeOption(modeId: previousDefaultModeId)
        ? previousDefaultModeId
        : discovered._defaultModeId;
    _outcomesByScope.clear();
    recordOutcome(scope: scope, outcome: outcome);
    _revision++;
  }

  String _normalizeScope({required String scope}) => normalizeProjectDirectory(directory: scope);
}
