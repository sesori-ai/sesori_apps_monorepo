import 'update_output_formatter.dart';

/// Builds the branded, capability-gated output lines the background + startup
/// update pipeline emits (staged-for-activation, activated, and genuine-failure
/// guidance). The wording and the re-install guidance stay consistent across the
/// check/apply/reconcile services, and the visual vocabulary matches the
/// `sesori-bridge update` command via the shared [UpdateOutputFormatter].
///
/// Status/success lines are rendered with [_outFormatter] (stdout); failure
/// guidance with [_errFormatter] (stderr). Pure: the methods return
/// [RenderedLine]s and perform no IO — the services do the writing.
class UpdateMessageFormatter {
  UpdateMessageFormatter({
    required UpdateOutputFormatter outFormatter,
    required UpdateOutputFormatter errFormatter,
  }) : _outFormatter = outFormatter,
       _errFormatter = errFormatter;

  final UpdateOutputFormatter _outFormatter;
  final UpdateOutputFormatter _errFormatter;

  /// Where users are sent to re-run the installer after an update failure.
  static const String installScriptUrl = 'https://sesori.com/';

  /// Genuine-failure guidance: always surfaced on stderr. [toVersion] may be a
  /// concrete version or a phrase ("the latest release") when the failure
  /// predates knowing the target, so it is not `v`-prefixed here.
  List<RenderedLine> failureGuidance({
    required String toVersion,
    required String reason,
    required String logPath,
  }) {
    return [
      RenderedLine(isError: true, text: _errFormatter.error('Automatic update to $toVersion failed: $reason.')),
      RenderedLine(isError: true, text: _errFormatter.note('Re-run the install script to update manually: $installScriptUrl')),
      RenderedLine(isError: true, text: _errFormatter.dim('  Details in $logPath')),
    ];
  }

  /// Confirmation that a swap is staged and will take effect on next launch.
  List<RenderedLine> installedPendingActivation({required String toVersion}) {
    return [
      RenderedLine(isError: false, text: _outFormatter.success('Update v$toVersion installed.')),
      RenderedLine(
        isError: false,
        text: _outFormatter.dim('  Takes effect on next launch; restart a running bridge to apply now.'),
      ),
    ];
  }

  /// Confirmation, on the next launch, that the new version is now running.
  List<RenderedLine> activated({required String toVersion}) {
    return [RenderedLine(isError: false, text: _outFormatter.success('Updated to v$toVersion.'))];
  }
}
