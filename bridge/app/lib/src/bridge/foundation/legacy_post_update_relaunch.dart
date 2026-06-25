/// Environment variable that pre-stage-and-apply releases set when their
/// (now-removed) auto-updater relaunched the freshly installed binary.
///
/// This build never sets it — the relaunch is gone. It is read only for
/// backwards compatibility on the single upgrade where an *old* binary
/// relaunches this one: if that relaunch is non-interactive and stored tokens
/// are missing, we surface a clear "run again from a terminal" message instead
/// of blocking on a login prompt with no usable terminal.
const String sesoriPostUpdateRestartEnvVar = 'SESORI_POST_UPDATE_RESTART';
