final class const NewSessionModelIntent({required final String providerId, required final String modelId});

sealed class const NewSessionVariantIntent();

final class const NewSessionDefaultVariantIntent() extends NewSessionVariantIntent;

final class const NewSessionNamedVariantIntent({required final String id}) extends NewSessionVariantIntent;

final class NewSessionSelectionIntent {
  const new({
    required this.agentName,
    required this.model,
    required this.variant,
  });

  const new empty() : agentName = null, model = null, variant = null;

  final String? agentName;
  final NewSessionModelIntent? model;
  final NewSessionVariantIntent? variant;
}
