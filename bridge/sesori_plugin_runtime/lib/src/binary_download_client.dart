import "dart:async";
import "dart:io";

import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

const Duration _kDownloadRequestTimeout = Duration(seconds: 30);
const Duration _kDownloadInactivityTimeout = Duration(seconds: 30);

/// Why a [BinaryDownloadClient.download] failed, in neutral terms a caller can
/// map to its own outcome vocabulary.
///
/// - [network]: a transient/retryable outage (server-side 5xx, throttling,
///   request timeout, or a dropped connection mid-body). Stay quiet and retry.
/// - [failed]: a genuine failure (a non-retryable status such as 404, or an
///   unexpected local error) that will not fix itself on the next attempt.
enum DownloadFailureKind { network, failed }

/// Raised by [BinaryDownloadClient.download] (as a stream error) when a download
/// cannot complete. Carries a neutral [kind] so each consumer maps it to its own
/// result type at its boundary rather than the client knowing about them.
class DownloadException implements Exception {
  const DownloadException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final DownloadFailureKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => "DownloadException(${kind.name}, status: $statusCode): $message";
}

/// A byte-progress update emitted while a download streams to disk.
class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
  });

  final int receivedBytes;

  /// Total expected bytes from `Content-Length`, or `null` when the server did
  /// not advertise a length (progress is then indeterminate).
  final int? totalBytes;

  /// Fraction in `[0, 1]`, or `null` when the total size is unknown.
  double? get fraction {
    final int? total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return receivedBytes / total;
  }
}

/// Streams a binary asset from a URL to a local file, reporting byte progress.
///
/// Transport-level only: it knows nothing about what is being downloaded or how
/// failure should be surfaced. The returned stream emits a [DownloadProgress]
/// per body chunk, completes when the file is fully written, and raises a
/// [DownloadException] (carrying a neutral [DownloadFailureKind]) on failure.
class BinaryDownloadClient {
  final http.Client _httpClient;
  final Duration _requestTimeout;
  final Duration _streamInactivityTimeout;

  BinaryDownloadClient({
    required http.Client httpClient,
    Duration requestTimeout = _kDownloadRequestTimeout,
    Duration streamInactivityTimeout = _kDownloadInactivityTimeout,
  }) : _httpClient = httpClient,
       _requestTimeout = requestTimeout,
       _streamInactivityTimeout = streamInactivityTimeout;

  Stream<DownloadProgress> download({
    required String url,
    required String destinationPath,
  }) async* {
    final Uri uri = Uri.parse(url);
    final http.Request request = http.Request("GET", uri);
    final http.StreamedResponse response = await _httpClient.send(request).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DownloadException(
        kind: _isRetryableHttpStatus(response.statusCode) ? DownloadFailureKind.network : DownloadFailureKind.failed,
        message: "Download request to $url failed with status ${response.statusCode}",
        statusCode: response.statusCode,
      );
    }

    final int? totalBytes = response.contentLength;
    final File destinationFile = File(destinationPath);
    final IOSink sink = destinationFile.openWrite();
    var receivedBytes = 0;
    try {
      await for (final List<int> chunk in response.stream.timeout(_streamInactivityTimeout)) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        yield DownloadProgress(receivedBytes: receivedBytes, totalBytes: totalBytes);
      }
    } on TimeoutException catch (error) {
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download stream stalled: $error");
    } on SocketException catch (error) {
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download connection failed: $error");
    } on HttpException catch (error) {
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download HTTP error: $error");
    } on http.ClientException catch (error) {
      // A connection reset/drop while reading the body (after a 2xx) is the same
      // transient outage class as a pre-response failure — keep it retryable.
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download connection dropped: $error");
    } on DownloadException {
      rethrow;
    } on Object catch (error) {
      throw DownloadException(kind: DownloadFailureKind.failed, message: "Download failed: $error");
    } finally {
      // A failed body stream leaves the sink in an errored/closed state, so
      // closing here can throw "File closed". Guard it so a close failure never
      // masks the classification above (the partial file is cleaned up by the
      // caller on a non-success result).
      try {
        await sink.close();
      } on Object catch (error) {
        Log.d("BinaryDownloadClient: ignoring sink close failure during teardown: $error");
      }
    }
  }

  bool _isRetryableHttpStatus(int statusCode) => statusCode >= 500 || statusCode == 429 || statusCode == 408;
}
