sealed class CodexAppServerCommandProjection {
  const CodexAppServerCommandProjection();
}

final class CodexAppServerCommandNative extends CodexAppServerCommandProjection {
  const CodexAppServerCommandNative();
}

final class CodexAppServerCommandCanonical extends CodexAppServerCommandProjection {
  const CodexAppServerCommandCanonical({required this.callId});

  final String callId;
}

sealed class CodexRolloutToolProjection {
  const CodexRolloutToolProjection();
}

final class CodexRolloutToolPassthrough extends CodexRolloutToolProjection {
  const CodexRolloutToolPassthrough();
}

final class CodexRolloutToolSuppressed extends CodexRolloutToolProjection {
  const CodexRolloutToolSuppressed();
}

final class CodexRolloutToolCanonical extends CodexRolloutToolProjection {
  const CodexRolloutToolCanonical({required this.callId});

  final String callId;
}

final class CodexRolloutToolCanonicalRunning extends CodexRolloutToolProjection {
  const CodexRolloutToolCanonicalRunning({
    required this.callId,
    required this.remainingCellIds,
  });

  final String callId;
  final List<String> remainingCellIds;
}
