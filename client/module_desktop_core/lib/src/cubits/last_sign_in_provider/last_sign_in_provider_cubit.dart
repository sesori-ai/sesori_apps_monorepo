import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// The method this device signed in with last, loaded once for the login
/// screen's "Last used" marker; `null` until loaded or when there is none.
class LastSignInProviderCubit({required final AuthSession _authSession}) extends Cubit<AuthProvider?> {
  this : super(null) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final AuthProvider? provider = await _authSession.lastSignedInProvider();
    if (!isClosed) emit(provider);
  }
}
