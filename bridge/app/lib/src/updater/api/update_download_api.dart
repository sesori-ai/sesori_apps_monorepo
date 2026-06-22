import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../foundation/update_policy.dart';
import '../models/update_result.dart';

const Duration _kDownloadRequestTimeout = Duration(seconds: 30);
const Duration _kDownloadInactivityTimeout = Duration(seconds: 30);

class UpdateDownloadApi {
  final http.Client _httpClient;
  final Duration _requestTimeout;
  final Duration _streamInactivityTimeout;

  UpdateDownloadApi({
    required http.Client httpClient,
    Duration requestTimeout = _kDownloadRequestTimeout,
    Duration streamInactivityTimeout = _kDownloadInactivityTimeout,
  }) : _httpClient = httpClient,
       _requestTimeout = requestTimeout,
       _streamInactivityTimeout = streamInactivityTimeout;

  Future<UpdateResult> downloadTo({
    required String url,
    required String destinationPath,
  }) async {
    final Uri uri = Uri.parse(url);
    final http.Request request = http.Request('GET', uri);
    final http.StreamedResponse response = await _httpClient.send(request).timeout(_requestTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (isRetryableHttpStatus(response.statusCode)) {
        // Transient server-side/throttling outage on the asset endpoint —
        // retryable, not a genuine download failure. Classify as a network
        // error so the caller stays quiet and retries on the next cycle.
        return UpdateResult.networkError;
      }
      return UpdateResult.downloadFailed;
    }

    final File destinationFile = File(destinationPath);
    final IOSink sink = destinationFile.openWrite();
    try {
      await response.stream.timeout(_streamInactivityTimeout).pipe(sink);
      return UpdateResult.success;
    } on TimeoutException {
      return UpdateResult.networkError;
    } on SocketException {
      return UpdateResult.networkError;
    } on HttpException {
      return UpdateResult.networkError;
    } on http.ClientException {
      // A connection reset/drop while reading the response body (after a 2xx)
      // is the same transient outage class as a pre-response failure — keep it
      // retryable/quiet rather than a genuine downloadFailed.
      return UpdateResult.networkError;
    } on Object {
      return UpdateResult.downloadFailed;
    } finally {
      // A failed body stream leaves the sink in an errored/closed state, so
      // closing here can throw "File closed". Guard it so a close failure never
      // masks the result classification above (the partial file is cleaned up
      // by the install step on a non-success result).
      try {
        await sink.close();
      } on Object {
        // Best-effort: the sink is already being torn down.
      }
    }
  }
}
