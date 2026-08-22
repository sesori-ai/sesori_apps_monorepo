import 'package:rxdart/streams.dart';

/// Provides read access to the current OAuth access token.
abstract class AccessTokenProvider() {
  ValueStream<String> get tokenStream;

  String get accessToken;
}
