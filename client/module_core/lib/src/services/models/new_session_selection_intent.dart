final class const NewSessionModelIntent({required final String providerId, required final String modelId});

final class const NewSessionVariantIntent({required final String id});

final class NewSessionSelectionIntent {
  const new({
    required this.agentName,
    required this.model,
    required this.variant,
    required this.fastMode,
  });

  const new empty() : agentName = null, model = null, variant = null, fastMode = null;

  final String? agentName;
  final NewSessionModelIntent? model;
  final NewSessionVariantIntent? variant;

  /// The fast-mode choice, or null when the user made none.
  final bool? fastMode;
}
