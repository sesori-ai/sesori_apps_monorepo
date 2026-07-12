/// Desktop business logic for Sesori — bridge supervision, control-channel
/// orchestration, and desktop cubits. Pure Dart, no Flutter dependency.
library;

// The signed-in account carried by AuthGateState (move + re-export pattern,
// so shell consumers don't need a direct sesori_shared import for it).
export "package:sesori_shared/sesori_shared.dart" show AuthUser;

export "src/cubits/auth_gate/auth_gate_cubit.dart";
export "src/cubits/auth_gate/auth_gate_state.dart";
export "src/di/injection.dart";
