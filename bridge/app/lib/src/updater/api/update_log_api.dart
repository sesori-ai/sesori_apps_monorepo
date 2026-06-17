import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;

/// Durable, append-only diagnostics log for the update pipeline.
///
/// Every update attempt — success or failure — leaves a permanent trail here so
/// a failure can never be silent (unlike `Log`, which is suppressed at the
/// default level). The file is capped at [_maxBytes] with a single rotation to
/// `.log.1`, and every line is passed through [_redact] so tokens/auth headers
/// never land on disk.
class UpdateLogApi {
  UpdateLogApi({
    required this.installRoot,
    required this.clock,
    int maxBytes = 512 * 1024,
  }) : _maxBytes = maxBytes;

  final String installRoot;
  final Clock clock;

  /// Soft cap before the active log rotates. One rotation is kept, so on-disk
  /// usage stays bounded at ~2x this value.
  final int _maxBytes;

  static const String _fileName = '.sesori-bridge-update.log';
  static const String _rotatedFileName = '.sesori-bridge-update.log.1';

  /// Absolute path of the active log, surfaced to users in failure guidance.
  String get logPath => p.join(installRoot, _fileName);

  String get _rotatedPath => p.join(installRoot, _rotatedFileName);

  /// Writes a per-attempt header delimiting the lines that follow.
  Future<void> appendAttemptHeader({
    required String fromVersion,
    required String toVersion,
  }) {
    return _appendRaw(
      '=== update attempt $fromVersion -> $toVersion '
      'on ${Platform.operatingSystem} at ${_timestamp()} ===\n',
    );
  }

  /// Appends a single timestamped, redacted line.
  Future<void> append({required String message}) {
    return _appendRaw('${_timestamp()} ${_redact(message)}\n');
  }

  Future<void> _appendRaw(String text) async {
    final Directory dir = Directory(installRoot);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final File file = File(logPath);
    await _rotateIfNeeded(file: file, incomingBytes: utf8.encode(text).length);
    await file.writeAsString(text, mode: FileMode.append, flush: true);
  }

  Future<void> _rotateIfNeeded({required File file, required int incomingBytes}) async {
    if (!file.existsSync()) {
      return;
    }
    final int currentSize = await file.length();
    if (currentSize + incomingBytes <= _maxBytes) {
      return;
    }

    final File rotated = File(_rotatedPath);
    if (rotated.existsSync()) {
      await rotated.delete();
    }
    await file.rename(rotated.path);
  }

  String _timestamp() => clock.now().toUtc().toIso8601String();

  /// Strips secrets so they never persist: GitHub tokens and the value side of
  /// any `authorization`/`bearer`/`token`/`access_token` pairing.
  String _redact(String message) {
    return message
        .replaceAll(RegExp('gh[opusr]_[A-Za-z0-9]{20,}'), '[REDACTED_TOKEN]')
        .replaceAll(RegExp('github_pat_[A-Za-z0-9_]{20,}'), '[REDACTED_TOKEN]')
        .replaceAllMapped(
          RegExp(
            r'(?<key>authorization|bearer|token|access_token|api_key)(?<sep>["\s:=]+)(?<val>[^\s"&]+)',
            caseSensitive: false,
          ),
          (Match match) {
            final RegExpMatch m = match as RegExpMatch;
            return '${m.namedGroup('key')}${m.namedGroup('sep')}[REDACTED]';
          },
        );
  }
}
