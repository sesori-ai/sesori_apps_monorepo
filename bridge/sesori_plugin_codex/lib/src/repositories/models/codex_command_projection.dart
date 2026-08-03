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
