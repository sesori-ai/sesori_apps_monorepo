/// The two explicit OpenAI billing routes exposed by the Codex model picker.
enum CodexAuthenticationMode({
  required final String providerID,
}) {
  chatgptSubscription(
    providerID: "openai",
  ),
  apiKey(
    providerID: "sesori-openai-api",
  );

  static CodexAuthenticationMode? fromProviderID({required String? providerID}) {
    for (final mode in values) {
      if (mode.providerID == providerID) return mode;
    }
    return null;
  }
}
