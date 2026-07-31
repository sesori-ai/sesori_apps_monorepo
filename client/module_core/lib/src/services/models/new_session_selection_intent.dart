final class NewSessionModelIntent {
  const NewSessionModelIntent({required this.providerId, required this.modelId});

  final String providerId;
  final String modelId;
}

sealed class NewSessionVariantIntent {
  const NewSessionVariantIntent();
}

final class NewSessionDefaultVariantIntent extends NewSessionVariantIntent {
  const NewSessionDefaultVariantIntent();
}

final class NewSessionNamedVariantIntent extends NewSessionVariantIntent {
  const NewSessionNamedVariantIntent({required this.id});

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
