// ignore_for_file: no_slop_linter/prefer_required_named_parameters
import "dart:async" as async show unawaited;
import "dart:async" hide unawaited;
import "dart:convert";
import "dart:core";
import "dart:math";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:rxdart/rxdart.dart";

final _random = Random.secure();

// ignore: no_slop_linter/avoid_dynamic_type, JSON decoding
Map<String, dynamic> jsonDecodeMap(String source) {
  final result = jsonDecode(source);

  if (result is Map) {
    return result.cast();
  } else {
    throw FormatException(
      "Invalid JSON Object (not a Map) in jsonDecodeMap: $source",
    );
  }
}

typedef ComputeCallback<M, R> = FutureOr<R> Function(M message);

extension Sugar<T> on T {
  Future<T> get toFuture => Future.value(this);

  (T, Y) to<Y>(Y other) => (this, other);

  T also(void Function(T data) invoker) {
    invoker(this);
    return this;
  }

  Y let<Y>(Y Function(T data) invoker) => invoker(this);

  T verify({required bool Function(T data) condition, String? message}) {
    final successful = condition(this);
    if (!successful) {
      throw Exception("Failed verification!\n${message ?? ''}");
    }
    return this;
  }
}

extension FutureSugar<T> on Future<T> {
  ValueStream<T> asValueStream({required CompositeSubscription? disposeWith}) => asStream().shareValueConnected(
    connection: (subscription) => disposeWith?.isDisposed == true
        // ignore: discarded_futures
        ? subscription
              .cancel() //
        : disposeWith?.add(subscription),
  );
  void unawaited() => async.unawaited(this);
}

extension StreamExtensions<T> on Stream<T> {
  Stream<OUT> combineWith<OUT, B>(
    Stream<B> other,
    OUT Function(T a, B b) invoker,
  ) => CombineLatestStream.combine2(this, other, invoker);

  Stream<OUT> combineWith2<OUT, B, C>(
    Stream<B> other1,
    Stream<C> other2,
    OUT Function(T a, B b, C c) invoker,
  ) => CombineLatestStream.combine3(this, other1, other2, invoker);

  Stream<OUT> combineWith3<OUT, B, C, D>(
    Stream<B> other1,
    Stream<C> other2,
    Stream<D> other3,
    OUT Function(T a, B b, C c, D d) invoker,
  ) => CombineLatestStream.combine4(this, other1, other2, other3, invoker);

  ValueStream<T> shareValueAutoConnect({
    required CompositeSubscription? disposeWith,
  }) => publishValue().autoConnect(
    connection: (subscription) => disposeWith?.isDisposed == true
        // ignore: discarded_futures
        ? subscription
              .cancel() //
        : disposeWith?.add(subscription),
  );

  Stream<T> shareAutoConnect({required CompositeSubscription? disposeWith}) => publish().autoConnect(
    connection: (subscription) => disposeWith?.isDisposed == true
        // ignore: discarded_futures
        ? subscription
              .cancel() //
        : disposeWith?.add(subscription),
  );

  ValueStream<T> shareValueConnected({
    void Function(StreamSubscription<T> subscription)? connection,
  }) => publishValue().also((data) {
    // ignore: cancel_subscriptions
    final conn = data.connect();
    if (connection != null) connection(conn);
  });

  ValueStream<T> shareValueSeededAutoConnect(
    T seedValue, {
    void Function(StreamSubscription<T> subscription)? connection,
  }) => publishValueSeeded(seedValue).autoConnect(connection: connection);

  Stream<T> distinctBy<Q>(Q Function(T item) invoker) => distinct(
    (previous, next) => const DeepCollectionEquality().equals(invoker(previous), invoker(next)),
  );

  Stream<T> skipWhen(bool Function(T previous, T current) skipIfTrue) => distinct(skipIfTrue);

  Stream<T> seeded(T initialValue) => ConcatStream([Stream.value(initialValue), this]);

  // initialValue != null ? seeded(initialValue) : this
  Stream<T> maybeSeeded(FutureOr<T?> initialValue) => ConcatStream([optionalValueStream(initialValue), this]);
}

Stream<T> optionalValueStream<T>(FutureOr<T?> value) async* {
  final v = await value;
  if (v != null) {
    yield v;
  }
}

Y tryCatch<Y>({required Y Function() t, required Y Function(Object error) c}) {
  try {
    return t();
  } catch (err) {
    return c(err);
  }
}

Future<Y> tryCatchAsync<Y>({
  required FutureOr<Y> Function() t,
  required FutureOr<Y> Function(Object error) c,
}) async {
  try {
    return await t();
  } catch (err) {
    return await c(err);
  }
}

extension Utf8Extension on Utf8Codec {
  String decodeOrEmpty(List<int> codeUnits) => tryCatch(
    t: () => decode(codeUnits, allowMalformed: true),
    c: (err) => "",
  );
}

extension IterableSugar<T> on Iterable<T> {
  T? random() => length == 0 ? null : elementAt(_random.nextInt(length));

  Iterable<T> distinctBy<Q>(Q Function(T item) invoker) {
    final seen = <Q>{};
    return where((item) {
      final key = invoker(item);
      if (seen.contains(key)) {
        return false;
      }
      seen.add(key);
      return true;
    });
  }

  List<List<T>> chunked(int chunkSize) {
    final thisAsList = toList();
    return List.generate((length / chunkSize).ceil(), (index) {
      final int start = index * chunkSize;
      final int end = start + chunkSize;
      return thisAsList.sublist(start, end > length ? length : end);
    });
  }

  /// Same as [Iterable.singleWhereOrNull] except that it throws if there is more
  ///   than once entry instead of returning null
  T? singleWhereOrNullIfNone(bool Function(T element) test) {
    late T result;
    bool foundMatching = false;
    for (final T element in this) {
      if (test(element)) {
        if (foundMatching) {
          throw StateError("Too many elements");
        }
        result = element;
        foundMatching = true;
      }
    }
    if (foundMatching) return result;
    return null;
  }
}

extension StringExtensions on String {
  String substringAfter(String substr) {
    final index = indexOf(substr);
    return index < 0 ? this : substring(index + substr.length);
  }

  String take(int i) => length > i ? substring(0, i) : this;

  String takeLast(int i) => length > i ? substring(i) : this;

  String ellipsizeStart(int maxLen) => length > maxLen ? "...${substring(length - maxLen)}" : this;

  String ellipsizeEnd(int maxLen) => length > maxLen ? "${substring(0, maxLen)}..." : this;

  String ellipsizeMiddle(int maxLen) {
    final lenEachSide = maxLen ~/ 2;
    return length > (maxLen + 2) ? "${substring(0, lenEachSide)}...${substring(length - lenEachSide)}" : this;
  }

  String substringAfterLast(String matcher) {
    final lastIndex = lastIndexOf(matcher);
    return lastIndex < 0 ? this : substring(lastIndex + matcher.length);
  }

  String drop(int n) {
    verify(condition: (v) => n > 0, message: "drop argument must be positive");

    return length <= n ? "" : substring(n);
  }

  String dropLast(int n) {
    verify(
      condition: (v) => n > 0,
      message: "dropLast argument must be positive",
    );

    return length <= n ? "" : substring(0, length - n);
  }

  String capitalizeWord() => length > 0 ? "${this[0].toUpperCase()}${substring(1).toLowerCase()}" : this;

  String capitalizeAll() => split(" ").map((word) => word.capitalizeWord()).join(" ");

  List<String> chunked(int chunkSize) {
    final chunks = <String>[];

    var chunkIndex = 0;
    while (true) {
      final start = chunkIndex * chunkSize;
      final end = min((chunkIndex + 1) * chunkSize, length);

      if (start >= length) {
        break;
      }
      chunks.add(substring(start, end));
      chunkIndex++;
    }

    return chunks;
  }

  /// Validates if the identifier is a valid hex string
  bool isValidHexString() {
    final hexRegex = RegExp(r"^(?:[0-9a-fA-F]{2})*$");
    return hexRegex.hasMatch(this);
  }
}

extension MapExtensions<KEY, VALUE> on Map<KEY, VALUE> {
  Map<KEY, T> mapValues<T>(T Function(VALUE value) invoker) => map((key, value) => MapEntry(key, invoker(value)));

  List<T> mapEntries<T>(T Function(KEY key, VALUE value) invoker) =>
      map((key, value) => MapEntry(key, invoker(key, value))) //
          .values
          .toList(growable: false);

  Map<KEY, VALUE> whereKey(bool Function(KEY key) invoker) =>
      Map.fromEntries(entries.where((pair) => invoker(pair.key)));

  Map<KEY, VALUE> whereValue(bool Function(VALUE value) invoker) =>
      Map.fromEntries(entries.where((pair) => invoker(pair.value)));

  Map<NK, VALUE> whereKeyType<NK>() => Map.fromEntries(
    entries //
        .where((entry) => entry.key is NK)
        // ignore: no_slop_linter/avoid_as_cast, type checked one line above
        .map((e) => MapEntry(e.key as NK, e.value)),
  );
}

extension MapEntryExtensions<KEY, VALUE> on MapEntry<KEY, VALUE> {
  (KEY, VALUE) toRecord() => (key, value);
}

extension BoolExtensions on bool {
  bool not() => !this;
}

extension DurationExtension on Duration {
  String formatToString() {
    final minutes = inMinutes;
    final hours = inHours;
    final days = inDays;
    if (minutes < 60) {
      return "$minutes min${minutes == 1 ? "" : "s"}";
    } else if (hours < 24) {
      return "$hours hour${hours == 1 ? "" : "s"}";
    } else {
      return "$days day${days == 1 ? "" : "s"}";
    }
  }
}
