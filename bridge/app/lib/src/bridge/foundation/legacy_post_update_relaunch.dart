/// Environment variable that pre-stage-and-apply releases set when their
/// (now-removed) auto-updater relaunched the freshly installed binary.
///
/// This build never sets it — the relaunch is gone. It is read only for
/// backwards compatibility on the single upgrade where an *old* binary
/// relaunches this one: if that relaunch is non-interactive and stored tokens
/// are missing, we surface a clear "run again from a terminal" message instead
/// of blocking on a login prompt with no usable terminal.
// COMPATIBILITY 2026-06-22 (v1.1.2): The removed updater can relaunch this binary with its legacy environment marker. Remove this constant and its consumers once pre-v1.1.2 updaters are unsupported.
const String sesoriPostUpdateRestartEnvVar = 'SESORI_POST_UPDATE_RESTART';
