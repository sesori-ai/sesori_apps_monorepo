// ignore_for_file: no_slop_linter/prefer_required_named_parameters, no_slop_linter/avoid_as_cast
import "dart:async";

Future<(A, B)> wait2<A, B>(FutureOr<A> a, FutureOr<B> b) => Future.wait([Future.value(a), Future.value(b)]).then(
  (value) => (value[0] as A, value[1] as B),
);
