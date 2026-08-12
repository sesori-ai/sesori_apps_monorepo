/// Test doubles and fixtures for Pi's JSONL RPC protocol, shared with packages
/// that compose the plugin. Not exported from `pi_plugin.dart` — production
/// code must never depend on a fake process.
library;

export "src/testing/fake_pi_process.dart";
export "src/testing/pi_protocol_fixtures.dart";
