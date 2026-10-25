import "dart:io";
import "dart:typed_data";

import "package:http/http.dart" as http;
import "package:injectable/injectable.dart";

import "../foundation/models/desktop_bundle_identity.dart";
import "../foundation/platform/installed_desktop_bundle_source.dart";

/// An unverified Velopack feed and its detached base64 Ed25519 signature.
class const DesktopUpdateFeed({required final Uint8List bytes, required final String signature});

/// Layer-1 unauthenticated GETs of this install's Velopack feed, its `.sig`
/// and the full package it names, from
/// `https://storage.googleapis.com/sesori-ai-linux-packages/desktop-updates/k1/<channel>/<os>-<arch>/`.
@lazySingleton
class DesktopUpdateFeedApi({
  required final http.Client _client,
  required final InstalledDesktopBundleSource _bundleSource,
}) {
  static const Duration _requestTimeout = Duration(seconds: 30);

  /// A package download fails once no bytes arrived for this long.
  static const Duration _downloadIdleTimeout = Duration(seconds: 60);

  Future<DesktopUpdateFeed> fetchFeed({required DesktopBundleIdentity identity}) async {
    final String feedName = "releases.${_bundleSource.channel.name}.json";
    final Uint8List bytes = await _get(uri: _feedUri(identity: identity, fileName: feedName));
    final Uint8List signature = await _get(uri: _feedUri(identity: identity, fileName: "$feedName.sig"));
    return DesktopUpdateFeed(bytes: bytes, signature: String.fromCharCodes(signature).trim());
  }

  /// Streams the full package [fileName] the verified feed names into [destination].
  Future<void> downloadPackage({
    required DesktopBundleIdentity identity,
    required String fileName,
    required File destination,
  }) async {
    final Uri uri = _feedUri(identity: identity, fileName: fileName);
    final http.StreamedResponse response = await _client.send(http.Request("GET", uri)).timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      await response.stream.drain<void>();
      throw HttpException("Desktop update package returned HTTP ${response.statusCode}", uri: uri);
    }
    // Closed on failure too: Windows cannot clear a staging directory with an open file.
    final IOSink sink = destination.openWrite();
    try {
      await sink.addStream(response.stream.timeout(_downloadIdleTimeout));
    } finally {
      await sink.close();
    }
  }

  Future<Uint8List> _get({required Uri uri}) async {
    final http.Response response = await _client.get(uri).timeout(_requestTimeout);
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException("Desktop update feed returned HTTP ${response.statusCode}", uri: uri);
    }
    return response.bodyBytes;
  }

  Uri _feedUri({required DesktopBundleIdentity identity, required String fileName}) => Uri.https(
    "storage.googleapis.com",
    "/sesori-ai-linux-packages/desktop-updates/k1/${_bundleSource.channel.name}/"
        "${identity.os.name}-${identity.architecture.name}/$fileName",
  );
}
