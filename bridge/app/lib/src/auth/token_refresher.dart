abstract interface class TokenRefresher {
  Future<String> getAccessToken({bool forceRefresh = false});
}
