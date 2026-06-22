/// Builds the user-facing strings the update pipeline emits. Pure formatting,
/// shared by the check/apply/reconcile services so the wording (and the
/// re-install guidance) stays consistent everywhere.
class UpdateMessageFormatter {
  const UpdateMessageFormatter();

  /// Where users are sent to re-run the installer after an update failure.
  static const String installScriptUrl = 'https://sesori.com/';

  /// Genuine-failure message: always surfaced via `Console.error`.
  String failureGuidance({
    required String toVersion,
    required String reason,
    required String logPath,
  }) {
    return 'Automatic update to $toVersion failed: $reason. '
        'Re-run the install script to update manually: $installScriptUrl '
        '— details in $logPath';
  }

  /// Confirmation that a swap is staged and will take effect on next launch.
  String installedPendingActivation({required String toVersion}) {
    return 'Update $toVersion installed; it takes effect on the next launch '
        '(or restart from your phone).';
  }

  /// Confirmation, on the next launch, that the new version is now running.
  String activated({required String toVersion}) => 'Updated to $toVersion.';
}
