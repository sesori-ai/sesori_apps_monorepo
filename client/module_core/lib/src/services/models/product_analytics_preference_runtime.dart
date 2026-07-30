import "dart:async";

import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "product_analytics_preference_snapshot.dart";
import "product_analytics_state.dart";

sealed class ProductAnalyticsLogoutState {
  const ProductAnalyticsLogoutState();
}

final class ProductAnalyticsLogoutIdle extends ProductAnalyticsLogoutState {
  const ProductAnalyticsLogoutIdle();
}

sealed class ProductAnalyticsLogoutPreparation extends ProductAnalyticsLogoutState {
  final int generation;
  final ProductAnalyticsState capturedState;

  const ProductAnalyticsLogoutPreparation({required this.generation, required this.capturedState});
}

final class ProductAnalyticsLogoutPreparationClean extends ProductAnalyticsLogoutPreparation {
  const ProductAnalyticsLogoutPreparationClean({required super.generation, required super.capturedState});
}

final class ProductAnalyticsLogoutPreparationRecoveryRequired extends ProductAnalyticsLogoutPreparation {
  const ProductAnalyticsLogoutPreparationRecoveryRequired({
    required super.generation,
    required super.capturedState,
  });
}

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

sealed class ProductAnalyticsAccountSession {
  final int generation;
  final ProductAnalyticsPreferenceSnapshot snapshot;

  const ProductAnalyticsAccountSession({required this.generation, required this.snapshot});

  String? get userId;
  Future<void>? get hydration;
  bool get reconciled;

  ProductAnalyticsAccountSession withSnapshot({required ProductAnalyticsPreferenceSnapshot snapshot});
  ProductAnalyticsAccountSession markReconciled();
}

final class ProductAnalyticsSignedOutSession extends ProductAnalyticsAccountSession {
  const ProductAnalyticsSignedOutSession({required super.generation})
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

final class ProductAnalyticsHydratingSession extends ProductAnalyticsAccountSession {
  @override
  final String userId;
  final Completer<void> completion;

  const ProductAnalyticsHydratingSession({
    required this.userId,
    required super.generation,
    required this.completion,
    required super.snapshot,
  });

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

final class ProductAnalyticsReadySession extends ProductAnalyticsAccountSession {
  @override
  final String userId;
  @override
  final bool reconciled;

  const ProductAnalyticsReadySession({
    required this.userId,
    required super.generation,
    required super.snapshot,
    required this.reconciled,
  });

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
