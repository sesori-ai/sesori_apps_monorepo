abstract interface class TokenRefresher {
  Future<String> getFreshAccessToken({bool forceRefresh = false});
}
