import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

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
    } on Object {
      return UpdateResult.downloadFailed;
    } finally {
      await sink.close();
    }
  }
}
