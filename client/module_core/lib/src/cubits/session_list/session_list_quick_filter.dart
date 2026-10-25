/// A chip's narrowing of the active list. The list is fully loaded, so this
/// only narrows what is shown and never reloads anything.
enum SessionListQuickFilter() {
  all,
  running,
  unread,
}
