import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:path/path.dart' as p;
import 'package:sesori_shared/sesori_shared.dart';

import '../models/cached_release.dart';

/// File-based JSON cache for storing update check results with TTL expiration.
class UpdateCacheApi {
  final String cacheDirectory;
  final Clock clock;

  UpdateCacheApi({
    required this.cacheDirectory,
    required this.clock,
  });

  String get _cacheFilePath => p.join(cacheDirectory, 'update_cache.json');

  Future<CachedRelease?> read({required Duration ttl}) async {
    final file = File(_cacheFilePath);

    if (!file.existsSync()) {
      return null;
    }

    final String contents;
    try {
      contents = await file.readAsString();
    } on FileSystemException {
      return null;
    }

    try {
      final cached = CachedRelease.fromJson(jsonDecodeMap(contents));

      final expiresAt = cached.checkedAt.add(ttl);
      if (!clock.now().isBefore(expiresAt)) {
        return null;
      }

      return cached;
    } on FormatException {
      return null;
    } on Object catch (error) {
      if (error is FormatException || error is TypeError) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> write({required CachedRelease release}) async {
    final dir = Directory(cacheDirectory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final tmpFile = File(p.join(cacheDirectory, 'update_cache.json.tmp'));
    await tmpFile.writeAsString(jsonEncode(release.toJson()));

    final cacheFile = File(_cacheFilePath);
    await tmpFile.rename(cacheFile.path);
  }
}
