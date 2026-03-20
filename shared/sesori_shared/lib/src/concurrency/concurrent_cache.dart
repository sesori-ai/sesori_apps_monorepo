// ignore_for_file: no_slop_linter/avoid_mutable_class_fields, Must be mutable for the cache to work
import "dart:async";

class ConcurrentCache<T> {
  final Future<T> Function(T?) compute;
  final Duration valid;
  final Duration? grace;

  ({T cachedValue, int expirationTime})? _cacheData;

  Future<T>? _fetchingDataFuture;

  ConcurrentCache({
    required this.compute,
    required this.valid,
    required this.grace,
  });

  bool _isExpired() {
    final expirationTime = _cacheData?.expirationTime ?? 0;
    return DateTime.now().millisecondsSinceEpoch > expirationTime;
  }

  bool _isGraceExpired() {
    final expirationTime = _cacheData?.expirationTime ?? 0;
    return DateTime.now().millisecondsSinceEpoch > expirationTime + (grace?.inMilliseconds ?? 0);
  }

  void invalidate() => _cacheData = null;

  Future<T> getOrFetch({bool forceFetch = false}) async {
    if (forceFetch) {
      return _fetchAndCacheValue();
    }

    final FutureOr<T> newCacheFuture =
        _isExpired() //
        ? _fetchingDataFuture ?? _fetchAndCacheValue()
        : _cacheData?.cachedValue ?? _fetchAndCacheValue();

    return _isGraceExpired() //
        ? newCacheFuture
        : _cacheData?.cachedValue ?? newCacheFuture;
  }

  Future<T> _fetchAndCacheValue() async {
    try {
      final fetchingDataFuture = compute(_cacheData?.cachedValue);
      _fetchingDataFuture = fetchingDataFuture;
      final value = await fetchingDataFuture;

      _cacheData = (
        cachedValue: value,
        expirationTime: DateTime.now().millisecondsSinceEpoch + valid.inMilliseconds,
      );
      return value;
    } finally {
      _fetchingDataFuture = null;
    }
  }
}
