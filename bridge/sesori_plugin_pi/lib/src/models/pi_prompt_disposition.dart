/// How Pi handled an accepted `prompt` request, from its response
/// `data.disposition` (Pi 0.99.0+).
enum PiPromptDisposition(final String wireValue) {
  /// The prompt started a new agent run.
  started("started"),

  /// The prompt was steered into the agent run already in progress.
  queued("queued"),

  /// The prompt was handled without starting agent work, such as an extension
  /// command. Such a command can still start a run later through
  /// `sendUserMessage`.
  handled("handled");

  /// Missing or unknown values map to [handled], the conservative choice that
  /// keeps the `get_state` acceptance barrier.
  static PiPromptDisposition parse({required Object? value}) {
    for (final disposition in values) {
      if (disposition.wireValue == value) return disposition;
    }
    return handled;
  }
}
