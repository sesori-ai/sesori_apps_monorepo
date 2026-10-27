# Desktop Automatic Updates — Verification

Step 10 record for the matrix in `PLAN.md`. Each run used real signed internal builds from
the public internal feed.

| Platform | Result | Evidence |
|---|---|---|
| macOS arm64 | Passed (2026-10-27) | The user's installed internal build found v1.10.0-internal.1079 through Sesori ▸ Check for Updates…, showed "An update is ready", and relaunched on 1079 through Restart Now. |
| AppImage x64 (Ubuntu) | Passed (2026-10-26) | On a GitHub Ubuntu runner, internal 1065 downloaded 1066 in the background, and the tray offered Restart to Update. Choosing it applied 1066 to the same file (Velopack logged "Package version 1.10.0-internal.1066 applied successfully"; the file's checksum changed) and relaunched. The relaunched app found nothing newer. |
| Adverse | Unit-tested only | A refused feed signature fails the check and applies nothing. An unreachable feed keeps a waiting package Ready (`desktop_update_service_test.dart`). |

Not executed. These stay open and are not dropped:

- macOS x64, and the Quit path and bundled bridge version on macOS.
- Windows x64, which has to pass before the first public Windows release (U10). Windows arm64 also stays blocked: there is no interactive host for it (the desktop-distribution gate).
- AppImage arm64, and AppImage on Fedora and Arch.
- DEB through unattended-upgrades and RPM through dnf-automatic.
