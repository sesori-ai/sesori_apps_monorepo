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
enum DownloadFailureKind() {
  network,
  failed,
}

/// Raised by [BinaryDownloadClient.download] (as a stream error) when a download
/// cannot complete. Carries a neutral [kind] so each consumer maps it to its own
/// result type at its boundary rather than the client knowing about them.
class const DownloadException({
  required final DownloadFailureKind kind,
  required final String message,
  final int? statusCode,
}) implements Exception {
  @override
  String toString() => "DownloadException(${kind.name}, status: $statusCode): $message";
}

/// A byte-progress update emitted while a download streams to disk.
class const DownloadProgress({
  required final int receivedBytes,

  /// Total expected bytes from `Content-Length`, or `null` when the server did
  /// not advertise a length (progress is then indeterminate).
  required final int? totalBytes,
}) {
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
class BinaryDownloadClient({
  required final http.Client _httpClient,
  final Duration _requestTimeout = _kDownloadRequestTimeout,
  final Duration _streamInactivityTimeout = _kDownloadInactivityTimeout,
}) {
  Stream<DownloadProgress> download({
    required String url,
    required String destinationPath,
  }) async* {
    final Uri uri = Uri.parse(url);
    final http.Request request = http.Request("GET", uri);

    // Connection phase: classify transport failures into a DownloadException so
    // a raw SocketException/TimeoutException can never escape the contract.
    final http.StreamedResponse response;
    try {
      response = await _httpClient.send(request).timeout(_requestTimeout);
    } on TimeoutException catch (error) {
      throw DownloadException(
        kind: DownloadFailureKind.network,
        message: "Download connection timed out: ${error.toString()}",
      );
    } on SocketException catch (error) {
      throw DownloadException(
        kind: DownloadFailureKind.network,
        message: "Download connection failed: ${error.toString()}",
      );
    } on HttpException catch (error) {
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download HTTP error: ${error.toString()}");
    } on http.ClientException catch (error) {
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download client error: ${error.toString()}");
    } on Object catch (error) {
      throw DownloadException(
        kind: DownloadFailureKind.failed,
        message: "Download failed to start: ${error.toString()}",
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DownloadException(
        kind: _isRetryableHttpStatus(response.statusCode) ? DownloadFailureKind.network : DownloadFailureKind.failed,
        message: "Download request to $url failed with status ${response.statusCode}",
        statusCode: response.statusCode,
      );
    }

    final int? totalBytes = response.contentLength;
    // Opening the destination is part of the contract too: a filesystem error
    // here is a failed download, not a raw FileSystemException.
    //
    // Opened eagerly as a RandomAccessFile rather than through openWrite():
    // an IOSink defers the real open until its first write, so a permission,
    // path, or read-only-volume error escaped this try as an unhandled
    // asynchronous error inside the sink and took the isolate down instead of
    // failing the download.
    final RandomAccessFile file;
    try {
      file = File(destinationPath).openSync(mode: FileMode.write);
    } on Object catch (error) {
      throw DownloadException(
        kind: DownloadFailureKind.failed,
        message: "Could not open download destination: ${error.toString()}",
      );
    }

    var receivedBytes = 0;
    var bodyCompleted = false;
    try {
      await for (final List<int> chunk in response.stream.timeout(_streamInactivityTimeout)) {
        // Awaited per chunk so a write failure (disk full, quota, revoked
        // permission) is raised into this try instead of into the file's own
        // asynchronous machinery.
        await file.writeFrom(chunk);
        receivedBytes += chunk.length;
        yield DownloadProgress(receivedBytes: receivedBytes, totalBytes: totalBytes);
      }
      bodyCompleted = true;
    } on TimeoutException catch (error) {
      throw DownloadException(
        kind: DownloadFailureKind.network,
        message: "Download stream stalled: ${error.toString()}",
      );
    } on SocketException catch (error) {
      throw DownloadException(
        kind: DownloadFailureKind.network,
        message: "Download connection failed: ${error.toString()}",
      );
    } on HttpException catch (error) {
      throw DownloadException(kind: DownloadFailureKind.network, message: "Download HTTP error: ${error.toString()}");
    } on http.ClientException catch (error) {
      // A connection reset/drop while reading the body (after a 2xx) is the same
      // transient outage class as a pre-response failure — keep it retryable.
      throw DownloadException(
        kind: DownloadFailureKind.network,
        message: "Download connection dropped: ${error.toString()}",
      );
    } on Object catch (error) {
      throw DownloadException(kind: DownloadFailureKind.failed, message: "Download failed: ${error.toString()}");
    } finally {
      // The finally also runs when the consumer cancels the subscription
      // mid-stream, so the file is always closed — no leaked handle or locked
      // partial file on an abort/retry.
      if (bodyCompleted) {
        // Success: a close failure means the on-disk file may be incomplete, so
        // it must fail the download rather than be silently swallowed. There is
        // no in-flight exception here, so throwing from finally surfaces it as
        // the result.
        try {
          await file.close();
        } on Object catch (error) {
          throw DownloadException(
            kind: DownloadFailureKind.failed,
            message: "Could not finalize download: ${error.toString()}",
          );
        }
      } else {
        // Error or cancellation: close quietly so a teardown failure never masks
        // the in-flight error (and cancellation produces no error to mask).
        try {
          await file.close();
        } on Object catch (error, stackTrace) {
          Log.w("BinaryDownloadClient: destination close failed during teardown", error, stackTrace);
        }
      }
    }
  }

  bool _isRetryableHttpStatus(int statusCode) => statusCode >= 500 || statusCode == 429 || statusCode == 408;
}
