final class const NewSessionModelIntent({required this.providerId, required this.modelId}) {
  final String providerId;
  final String modelId;
}

sealed class const NewSessionVariantIntent();

final class const NewSessionDefaultVariantIntent() extends NewSessionVariantIntent;

final class const NewSessionNamedVariantIntent({required this.id}) extends NewSessionVariantIntent {
  final String id;
}

final class NewSessionSelectionIntent {
  const NewSessionSelectionIntent({
    required this.agentName,
    required this.model,
    required this.variant,
  });

  const NewSessionSelectionIntent.empty() : agentName = null, model = null, variant = null;

  final String? agentName;
  final NewSessionModelIntent? model;
  final NewSessionVariantIntent? variant;
}
