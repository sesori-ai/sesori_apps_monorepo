import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart'
    show TerminalColorValidator, TerminalGlyphValidator;

import '../models/explicit_update_outcome.dart';

/// A single rendered output line and where it belongs. [isError] lines go to
/// stderr; the rest go to stdout. The [text] is already styled (color/glyphs
/// applied or stripped) for its destination, so the command only writes it.
class RenderedLine {
  final bool isError;
  final String text;

  const RenderedLine({required this.isError, required this.text});
}

/// Renders an [ExplicitUpdateOutcome] into branded, capability-gated output
/// lines for the `sesori-bridge update` command.
///
/// Self-contained on purpose: it owns the brand palette + glyph set (kept
/// visually consistent with the installer scripts) and decides color/glyph
/// support per output stream via [TerminalColorValidator] / [TerminalGlyphValidator].
/// Pure: given the streams + environment, [format] returns strings and performs
/// no IO — the command does the writing.
class UpdateCommandFormatter {
  UpdateCommandFormatter({
    required Stdout outStream,
    required Stdout errorStream,
    required Map<String, String> environment,
  }) : _colorOut = TerminalColorValidator.isSupported(out: outStream, environment: environment),
       _colorErr = TerminalColorValidator.isSupported(out: errorStream, environment: environment),
       _unicode = TerminalGlyphValidator.isSupported(environment: environment);

  final bool _colorOut;
  final bool _colorErr;
  final bool _unicode;

  /// Where users are sent to reinstall manually after a failure.
  static const String installScriptUrl = 'https://sesori.com/';

  static const String _reset = '\x1B[0m';
  static const String _brand = '\x1B[38;5;39m';
  static const String _green = '\x1B[38;5;42m';
  static const String _yellow = '\x1B[38;5;214m';
  static const String _red = '\x1B[38;5;203m';
  static const String _dim = '\x1B[2m';
  static const String _bold = '\x1B[1m';

  List<RenderedLine> format(ExplicitUpdateOutcome outcome) {
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
      _note('Re-run the install script to update manually: $installScriptUrl', isError: true),
    ];
    final logPath = outcome.logPath;
    if (logPath != null) {
      lines.add(_dimLine('  Details in $logPath', isError: true));
    }
    return lines;
  }

  String get _arrow => _unicode ? '\u2192' : '->';

  RenderedLine _success(String text, {required bool isError}) => RenderedLine(
    isError: isError,
    text: '${_glyph(_green, '\u2713', '[OK]', isError: isError)} $text',
  );

  RenderedLine _warn(String text, {required bool isError}) => RenderedLine(
    isError: isError,
    text: '${_glyph(_yellow, '\u26a0', '!', isError: isError)} $text',
  );

  RenderedLine _error(String text, {required bool isError}) => RenderedLine(
    isError: isError,
    text: '${_glyph(_red, '\u2717', 'x', isError: isError)} $text',
  );

  RenderedLine _note(String text, {required bool isError}) => RenderedLine(
    isError: isError,
    text: '${_glyph(_brand, '\u279c', '>', isError: isError)} $text',
  );

  RenderedLine _dimLine(String text, {required bool isError}) => RenderedLine(
    isError: isError,
    text: _paint(_dim, text, isError: isError),
  );

  String _command(String text, {required bool isError}) => _paint('$_brand$_bold', text, isError: isError);

  String _glyph(String code, String unicode, String ascii, {required bool isError}) =>
      _paint(code, _unicode ? unicode : ascii, isError: isError);

  String _paint(String code, String text, {required bool isError}) {
    final bool color = isError ? _colorErr : _colorOut;
    return color ? '$code$text$_reset' : text;
  }
}
