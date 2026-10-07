import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/session_launch/session_launch.dart";
import "../../services/models/recent_sessions_entry.dart";
import "../../services/recent_session_inventory_service.dart";
import "../../services/session_launch_service.dart";
import "session_launch_resolvers.dart";

/// Each project's sessions in the slot its launching rows lead.
typedef ProjectLaunchSlots = Map<String, List<Session>> Function({required Map<String, RecentSessionsEntry> entries});

typedef _Update = ({Map<String, RecentSessionsEntry> entries, List<SessionLaunch> launches});

/// One surface's launching rows per project (see [resolveProjectLaunchRows]),
/// carried from one update to the next. Each surface that draws launches per
/// project owns one, because its rows follow its own slots.
///
/// The rows are resolved on every inventory and launch update, so each update
/// is seen once and a launch's session is never missed.
class ProjectLaunchRowsCubit({
  required final RecentSessionInventoryService _inventoryService,
  required final SessionLaunchService _launchService,

  /// Read at every update, so each resolve uses the surface's current slots.
  required final ProjectLaunchSlots _slots,

  /// The rows to continue from. A surface opened from another that already
  /// draws these launches passes that one's rows, so it keeps the launching
  /// rows that one still holds after their launches have left the service.
  required final Map<String, LaunchRows> initialRows,
}) extends Cubit<Map<String, LaunchRows>> {
  late final StreamSubscription<_Update> _updates;

  this : super(initialRows) {
    _resolve(update: (entries: _inventoryService.state.value, launches: _launchService.launches.value));
    // Each update as it came rather than the latest values, so a session a
    // launch names only in passing (before the launch goes) is still seen.
    _updates = Rx.combineLatest2(
      _inventoryService.state,
      _launchService.launches,
      (entries, launches) => (entries: entries, launches: launches),
    ).skip(1).listen((update) => _resolve(update: update));
  }

  void _resolve({required _Update update}) => emit(
    resolveProjectLaunchRows(
      previous: state,
      launches: resolveSessionLaunchState(launches: update.launches),
      entries: update.entries,
      slots: _slots(entries: update.entries),
    ),
  );

  @override
  Future<void> close() async {
    await _updates.cancel();
    await super.close();
  }
}
