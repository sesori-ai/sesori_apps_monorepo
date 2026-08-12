import "dart:async";

import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "product_analytics_preference_snapshot.dart";
import "product_analytics_state.dart";

sealed class const ProductAnalyticsLogoutState();

final class const ProductAnalyticsLogoutIdle() extends ProductAnalyticsLogoutState;

sealed class const ProductAnalyticsLogoutPreparation({required this.generation, required this.capturedState}) extends ProductAnalyticsLogoutState {
  final int generation;
  final ProductAnalyticsState capturedState;
}

final class const ProductAnalyticsLogoutPreparationClean({required super.generation, required super.capturedState}) extends ProductAnalyticsLogoutPreparation;

final class const ProductAnalyticsLogoutPreparationRecoveryRequired({
    required super.generation,
    required super.capturedState,
  }) extends ProductAnalyticsLogoutPreparation;

final class ProductAnalyticsPreferenceIntent {
  final int sequence;
  final ProductAnalyticsPreference? latestPreference;

  const ProductAnalyticsPreferenceIntent.idle() : sequence = 0, latestPreference = null;

  const ProductAnalyticsPreferenceIntent._({required this.sequence, required this.latestPreference});

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

sealed class const ProductAnalyticsAccountSession({required this.generation, required this.snapshot}) {
  final int generation;
  final ProductAnalyticsPreferenceSnapshot snapshot;

  String? get userId;
  Future<void>? get hydration;
  bool get reconciled;

  ProductAnalyticsAccountSession withSnapshot({required ProductAnalyticsPreferenceSnapshot snapshot});
  ProductAnalyticsAccountSession markReconciled();
}

final class const ProductAnalyticsSignedOutSession({required super.generation}) extends ProductAnalyticsAccountSession {
  this
    : super(snapshot: const ProductAnalyticsPreferenceUnresolved());

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
    required this.userId,
    required super.generation,
    required this.completion,
    required super.snapshot,
  }) extends ProductAnalyticsAccountSession {
  @override
  final String userId;
  final Completer<void> completion;

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
    required this.userId,
    required super.generation,
    required super.snapshot,
    required this.reconciled,
  }) extends ProductAnalyticsAccountSession {
  @override
  final String userId;
  @override
  final bool reconciled;

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
