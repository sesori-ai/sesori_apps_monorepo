import "package:rxdart/rxdart.dart";

import "access_token_provider.dart";

class AccessTokenService implements AccessTokenProvider, AccessTokenUpdater {
  final BehaviorSubject<String> _tokenSubject;

  AccessTokenService(String initialToken) : _tokenSubject = BehaviorSubject.seeded(initialToken);

  @override
  String get accessToken => _tokenSubject.value;

  @override
  set accessToken(String token) => _tokenSubject.add(token);

  /// Stream of token updates. Useful for components that need to react to token changes.
  Stream<String> get tokenStream => _tokenSubject.stream;

  void dispose() => _tokenSubject.close();
}
