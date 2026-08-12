import "dart:async";

import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "product_analytics_preference_snapshot.dart";
import "product_analytics_state.dart";

sealed class const ProductAnalyticsLogoutState();

final class const ProductAnalyticsLogoutIdle() extends ProductAnalyticsLogoutState;

sealed class const ProductAnalyticsLogoutPreparation({
  required final int generation,
  required final ProductAnalyticsState capturedState,
}) extends ProductAnalyticsLogoutState;

final class const ProductAnalyticsLogoutPreparationClean({required super.generation, required super.capturedState})
    extends ProductAnalyticsLogoutPreparation;

final class const ProductAnalyticsLogoutPreparationRecoveryRequired({
  required super.generation,
  required super.capturedState,
}) extends ProductAnalyticsLogoutPreparation;

final class ProductAnalyticsPreferenceIntent {
  final int sequence;
  final ProductAnalyticsPreference? latestPreference;

  const new idle() : sequence = 0, latestPreference = null;

  const new _({required this.sequence, required this.latestPreference});

  ProductAnalyticsPreferenceIntent begin({required ProductAnalyticsPreference preference}) =>
      ProductAnalyticsPreferenceIntent._(
        sequence: sequence + 1,
        latestPreference: preference,
      );

  ProductAnalyticsPreferenceIntent complete({required int sequence}) =>
      this.sequence == sequence ? ProductAnalyticsPreferenceIntent._(sequence: sequence, latestPreference: null) : this;

  ProductAnalyticsPreferenceIntent reset() => ProductAnalyticsPreferenceIntent._(
    sequence: sequence,
    latestPreference: null,
  );
}

sealed class const ProductAnalyticsAccountSession({
  required final int generation,
  required final ProductAnalyticsPreferenceSnapshot snapshot,
}) {
  String? get userId;
  Future<void>? get hydration;
  bool get reconciled;

  ProductAnalyticsAccountSession withSnapshot({required ProductAnalyticsPreferenceSnapshot snapshot});
  ProductAnalyticsAccountSession markReconciled();
}

final class const ProductAnalyticsSignedOutSession({required super.generation}) extends ProductAnalyticsAccountSession {
  this : super(snapshot: const ProductAnalyticsPreferenceUnresolved());

  @override
  String? get userId => null;

  @override
  Future<void>? get hydration => null;

  @override
  bool get reconciled => false;

  @override
  ProductAnalyticsAccountSession withSnapshot({required ProductAnalyticsPreferenceSnapshot snapshot}) => this;

  @override
  ProductAnalyticsAccountSession markReconciled() => this;
}

final class const ProductAnalyticsHydratingSession({
  @override required final String userId,
  required super.generation,
  required final Completer<void> completion,
  required super.snapshot,
}) extends ProductAnalyticsAccountSession {
  @override
  Future<void> get hydration => completion.future;

  @override
  bool get reconciled => false;

  @override
  ProductAnalyticsHydratingSession withSnapshot({required ProductAnalyticsPreferenceSnapshot snapshot}) =>
      ProductAnalyticsHydratingSession(
        userId: userId,
        generation: generation,
        completion: completion,
        snapshot: snapshot,
      );

  @override
  ProductAnalyticsAccountSession markReconciled() => this;
}

final class const ProductAnalyticsReadySession({
  @override required final String userId,
  required super.generation,
  required super.snapshot,
  @override required final bool reconciled,
}) extends ProductAnalyticsAccountSession {
  @override
  Future<void>? get hydration => null;

  @override
  ProductAnalyticsReadySession withSnapshot({required ProductAnalyticsPreferenceSnapshot snapshot}) =>
      ProductAnalyticsReadySession(
        userId: userId,
        generation: generation,
        snapshot: snapshot,
        reconciled: reconciled,
      );

  @override
  ProductAnalyticsReadySession markReconciled() => ProductAnalyticsReadySession(
    userId: userId,
    generation: generation,
    snapshot: snapshot,
    reconciled: true,
  );
}
