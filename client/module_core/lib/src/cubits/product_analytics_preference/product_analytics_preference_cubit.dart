import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/product_analytics/product_analytics_preference.dart";
import "../../services/models/product_analytics_state.dart";
import "../../services/product_analytics_service.dart";

class ProductAnalyticsPreferenceCubit extends Cubit<ProductAnalyticsState> {
  final ProductAnalyticsService _service;
  late final StreamSubscription<ProductAnalyticsState> _subscription;

  ProductAnalyticsPreferenceCubit({required ProductAnalyticsService service})
    : _service = service,
      super(service.state) {
    _subscription = service.stateStream.skip(1).listen((state) {
      if (isClosed) return;
      emit(state);
    });
  }

  Future<void> setEnabled({required bool enabled}) {
    return _service.setPreference(
      preference: enabled ? ProductAnalyticsPreference.enabled : ProductAnalyticsPreference.disabled,
    );
  }

  Future<void> refresh() => _service.refreshPreference();

  Future<void> retryPendingDisable() => _service.retryPendingDisable();

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
