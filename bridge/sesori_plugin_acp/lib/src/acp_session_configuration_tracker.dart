/// Immutable provider/model/variant selection used for ACP message translation.
class const AcpSessionConfigurationSnapshot({
  required final String? modelId,
  required final String? providerId,
  required final String? variantId,
});

/// Owns process defaults and per-session ACP selection overrides.
class AcpSessionConfigurationTracker() {
  String? _defaultModelId;
  String? _defaultProviderId;
  String? _defaultVariantId;
  final Map<String, String> _sessionModelIds = {};
  final Map<String, String> _sessionProviderIds = {};
  final Map<String, String?> _sessionVariantIds = {};

  AcpSessionConfigurationSnapshot get processDefaults => AcpSessionConfigurationSnapshot(
    modelId: _defaultModelId,
    providerId: _defaultProviderId,
    variantId: _defaultVariantId,
  );

  AcpSessionConfigurationSnapshot snapshotForSession({required String sessionId}) {
    return AcpSessionConfigurationSnapshot(
      modelId: _sessionModelIds[sessionId] ?? _defaultModelId,
      providerId: _sessionProviderIds[sessionId] ?? _defaultProviderId,
      variantId: _sessionVariantIds.containsKey(sessionId) ? _sessionVariantIds[sessionId] : _defaultVariantId,
    );
  }

  void setProcessDefaults({required String? modelId, required String? providerId}) =>
      setProcessSelection(modelId: modelId, providerId: providerId, variantId: null);

  void setProcessSelection({
    required String? modelId,
    required String? providerId,
    required String? variantId,
  }) {
    _defaultModelId = _useful(value: modelId);
    _defaultProviderId = _useful(value: providerId);
    _defaultVariantId = _useful(value: variantId);
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
    _sessionVariantIds[sessionId] = null;
  }

  void setSessionSelection({
    required String sessionId,
    required String? modelId,
    required String? providerId,
    required String? variantId,
  }) {
    setSessionOverride(sessionId: sessionId, modelId: modelId, providerId: providerId);
    _sessionVariantIds[sessionId] = _useful(value: variantId);
  }

  void forgetSession({required String sessionId}) {
    _sessionModelIds.remove(sessionId);
    _sessionProviderIds.remove(sessionId);
    _sessionVariantIds.remove(sessionId);
  }

  void clear() {
    _defaultModelId = null;
    _defaultProviderId = null;
    _defaultVariantId = null;
    _sessionModelIds.clear();
    _sessionProviderIds.clear();
    _sessionVariantIds.clear();
  }

  String? _useful({required String? value}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
