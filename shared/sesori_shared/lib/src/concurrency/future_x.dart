// ignore_for_file: no_slop_linter/prefer_required_named_parameters, no_slop_linter/avoid_as_cast
import "dart:async";

Future<(A, B)> wait2<A, B>(FutureOr<A> a, FutureOr<B> b) => Future.wait([Future.value(a), Future.value(b)]).then(
  (value) => (value[0] as A, value[1] as B),
);

Future<(A, B, C)> wait3<A, B, C>(Future<A> a, Future<B> b, Future<C> c) => Future.wait([a, b, c]).then(
  (value) => (value[0] as A, value[1] as B, value[2] as C),
);

Future<(A, B, C, D)> wait4<A, B, C, D>(Future<A> a, Future<B> b, Future<C> c, Future<D> d) =>
    Future.wait([a, b, c, d]).then(
      (value) => (value[0] as A, value[1] as B, value[2] as C, value[3] as D),
    );

Future<(A, B, C, D, E)> wait5<A, B, C, D, E>(Future<A> a, Future<B> b, Future<C> c, Future<D> d, Future<E> e) =>
    Future.wait([a, b, c, d, e]).then(
      (value) => (value[0] as A, value[1] as B, value[2] as C, value[3] as D, value[4] as E),
    );

extension FutureX<T> on Future<T> {
  Future<OUT> requireType<OUT extends T>() {
    return then(
      (v) =>
          v
              is OUT //
          ? v
          : throw Exception("Expected type ${OUT.toString()}, got ${v.runtimeType.toString()}"),
    );
  }
}
