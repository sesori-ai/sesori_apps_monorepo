import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sesori_bridge/src/server/api/open_code_process_api.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('OpenCodeProcessApi', () {
    test('probeHealth returns unhealthy fact when send and drain exceed timeout', () async {
      final api = OpenCodeProcessApi(
        processStarter: _unusedProcessStarter,
        httpClient: _NeverCompletingClient(),
        clock: const ServerClock(),
        environment: const <String, String>{},
        currentUser: null,
        isWindows: false,
        platform: 'macos',
        probeTimeout: const Duration(milliseconds: 10),
      );

      final fact = await api.probeHealth(
        serverUri: Uri.parse('http://127.0.0.1:4096'),
        password: 'password',
      );

      expect(fact.statusCode, isNull);
      expect(fact.error, isA<TimeoutException>());
    });
  });
}

Future<Process> _unusedProcessStarter(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  bool runInShell = false,
}) {
  throw UnimplementedError();
}

class _NeverCompletingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return Completer<http.StreamedResponse>().future;
  }
}
