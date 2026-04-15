import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/checksum_manifest.dart';

const Duration _kChecksumManifestTimeout = Duration(seconds: 10);

class ChecksumManifestApi {
  final http.Client _httpClient;
  final Duration _requestTimeout;

  ChecksumManifestApi({
    required http.Client httpClient,
    Duration requestTimeout = _kChecksumManifestTimeout,
  }) : _httpClient = httpClient,
       _requestTimeout = requestTimeout;

  Future<ChecksumManifest?> fetchManifest({required String url}) async {
    final response = await _httpClient.get(Uri.parse(url)).timeout(_requestTimeout);
    if (response.statusCode != 200) {
      return null;
    }
    return ChecksumManifest(entries: _parseChecksumsFile(response.body));
  }

  Map<String, String> _parseChecksumsFile(String content) {
    final result = <String, String>{};

    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final parts = trimmed.split('  ');
      if (parts.length < 2) {
        continue;
      }

      final hash = parts[0].trim();
      final filename = parts.sublist(1).join('  ').trim();
      if (hash.length == 64 && _isValidHex(hash)) {
        result[filename] = hash.toLowerCase();
      }
    }

    return result;
  }

  bool _isValidHex(String str) {
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(str);
  }
}
