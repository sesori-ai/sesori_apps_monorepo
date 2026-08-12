/// Immutable provider/model selection used for ACP message translation.
class AcpSessionConfigurationSnapshot {
  const AcpSessionConfigurationSnapshot({
    required this.modelId,
    required this.providerId,
  });

  final String? modelId;
  final String? providerId;
}

/// Owns process defaults and per-session ACP provider/model overrides.
class AcpSessionConfigurationTracker {
  String? _defaultModelId;
  String? _defaultProviderId;
  final Map<String, String> _sessionModelIds = {};
  final Map<String, String> _sessionProviderIds = {};

  AcpSessionConfigurationSnapshot get processDefaults => AcpSessionConfigurationSnapshot(
    modelId: _defaultModelId,
    providerId: _defaultProviderId,
  );

  AcpSessionConfigurationSnapshot snapshotForSession({required String sessionId}) {
    return AcpSessionConfigurationSnapshot(
      modelId: _sessionModelIds[sessionId] ?? _defaultModelId,
      providerId: _sessionProviderIds[sessionId] ?? _defaultProviderId,
    );
  }

  void setProcessDefaults({
    required String? modelId,
    required String? providerId,
  }) {
    _defaultModelId = _useful(value: modelId);
    _defaultProviderId = _useful(value: providerId);
  }

  void setSessionOverride({
    required String sessionId,
    required String? modelId,
    required String? providerId,
  }) {
    final resolvedModelId = _useful(value: modelId);
    if (resolvedModelId == null) {
      _sessionModelIds.remove(sessionId);
    } else {
      _sessionModelIds[sessionId] = resolvedModelId;
    }
    final resolvedProviderId = _useful(value: providerId);
    if (resolvedProviderId == null) {
      _sessionProviderIds.remove(sessionId);
    } else {
      _sessionProviderIds[sessionId] = resolvedProviderId;
    }
  }

  void forgetSession({required String sessionId}) {
    _sessionModelIds.remove(sessionId);
    _sessionProviderIds.remove(sessionId);
  }

  void clear() {
    _defaultModelId = null;
    _defaultProviderId = null;
    _sessionModelIds.clear();
    _sessionProviderIds.clear();
  }

  String? _useful({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
