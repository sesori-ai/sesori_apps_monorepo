import 'dart:io';

import 'package:sesori_plugin_interface/plugin_interface_testing.dart';
import 'package:test/test.dart';

/// Captures `Log` output, which goes to stderr, until the current test ends.
BufferingStdout captureLogOutput() {
  final output = BufferingStdout();
  IOOverrides.global = _StderrOverrides(output: output);
  addTearDown(() => IOOverrides.global = null);
  return output;
}

final class _StderrOverrides({required final BufferingStdout _output}) extends IOOverrides {
  @override
  Stdout get stderr => _output;
}
