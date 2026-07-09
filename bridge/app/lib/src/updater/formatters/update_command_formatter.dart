import '../models/explicit_update_outcome.dart';
import 'update_output_formatter.dart';

/// Renders an [ExplicitUpdateOutcome] into branded, capability-gated output
/// lines for the `sesori-bridge update` command.
///
/// The brand palette + glyph set + color/glyph gating live in the injected
/// [UpdateOutputFormatter]s (one per stream: [_outFormatter] for stdout,
/// [_errFormatter] for stderr). Pure: [format] returns strings and performs no
/// IO — the command does the writing.
class UpdateCommandFormatter {
  UpdateCommandFormatter({
    required UpdateOutputFormatter outFormatter,
    required UpdateOutputFormatter errFormatter,
  }) : _outFormatter = outFormatter,
       _errFormatter = errFormatter;

  final UpdateOutputFormatter _outFormatter;
  final UpdateOutputFormatter _errFormatter;

  List<RenderedLine> format({required ExplicitUpdateOutcome outcome}) {
    switch (outcome) {
      case ExplicitUpdateApplied():
        return _applied(outcome);
      case ExplicitUpdateAlreadyLatest():
        return [
          _success("You're on the latest ${outcome.track.wireValue} build (v${outcome.version}).", isError: false),
        ];
      case ExplicitUpdateTrackMismatch():
        final track = outcome.track.wireValue;
        return [
          _warn("You're on v${outcome.currentVersion}, not the latest $track build.", isError: false),
          _dimLine('  Latest $track is v${outcome.latestVersion}.', isError: false),
          _note(
            'Run  ${_command('sesori-bridge update --force', isError: false)}  to install it.',
            isError: false,
          ),
        ];
      case ExplicitUpdateNoEligibleRelease():
        return [_error('No ${outcome.track.wireValue} release is available to install.', isError: true)];
      case ExplicitUpdateNotManaged():
        return [
          _error('sesori-bridge update only updates the managed install.', isError: true),
          _dimLine("  You're running from ${outcome.executablePath}.", isError: true),
          _note('Install with the Sesori install script, or run via npx @sesori/bridge.', isError: true),
        ];
      case ExplicitUpdateNpmDirect():
        return [_error(outcome.message, isError: true)];
      case ExplicitUpdateLockBusy():
        return [_warn('Another update is already in progress. Try again shortly.', isError: true)];
      case ExplicitUpdateFailed():
        return _failed(outcome);
    }
  }

  List<RenderedLine> _applied(ExplicitUpdateApplied outcome) {
    final track = outcome.track.wireValue;
    final String headline;
    switch (outcome.kind) {
      case UpdateAppliedKind.upgrade:
        final from = outcome.fromVersion;
        headline = from == null ? 'Updated to v${outcome.toVersion}.' : 'Updated v$from $_arrow v${outcome.toVersion}';
      case UpdateAppliedKind.reinstall:
        headline = 'Reinstalled v${outcome.toVersion} ($track).';
      case UpdateAppliedKind.downgrade:
        headline = 'Switched to $track v${outcome.toVersion}.';
    }
    return [
      _success(headline, isError: false),
      _dimLine('  Takes effect on next launch; restart a running bridge to apply now.', isError: false),
    ];
  }

  List<RenderedLine> _failed(ExplicitUpdateFailed outcome) {
    final lines = <RenderedLine>[
      _error('Update failed: ${outcome.reason}.', isError: true),
      _note('Re-run the install script to update manually: $updateInstallScriptUrl', isError: true),
    ];
    final logPath = outcome.logPath;
    if (logPath != null) {
      lines.add(_dimLine('  Details in $logPath', isError: true));
    }
    return lines;
  }

  String get _arrow => _outFormatter.arrow;

  UpdateOutputFormatter _output({required bool isError}) => isError ? _errFormatter : _outFormatter;

  RenderedLine _success(String text, {required bool isError}) =>
      RenderedLine(isError: isError, text: _output(isError: isError).success(text));

  RenderedLine _warn(String text, {required bool isError}) =>
      RenderedLine(isError: isError, text: _output(isError: isError).warn(text));

  RenderedLine _error(String text, {required bool isError}) =>
      RenderedLine(isError: isError, text: _output(isError: isError).error(text));

  RenderedLine _note(String text, {required bool isError}) =>
      RenderedLine(isError: isError, text: _output(isError: isError).note(text));

  RenderedLine _dimLine(String text, {required bool isError}) =>
      RenderedLine(isError: isError, text: _output(isError: isError).dim(text));

  String _command(String text, {required bool isError}) => _output(isError: isError).command(text);
}
