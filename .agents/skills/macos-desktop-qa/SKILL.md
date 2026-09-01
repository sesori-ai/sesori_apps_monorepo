---
name: macos-desktop-qa
description: >-
  Build, launch, inspect, and exercise the Sesori macOS desktop app as a real
  QA target. Use for macOS desktop smoke, exploratory, regression, lifecycle,
  tray/menu-bar, evidence, performance, or end-to-end verification.
metadata:
  audience: maintainers
  workflow: local-macos-qa
---

# Sesori macOS Desktop QA

Use the real macOS app, native helper, relay path, and representative plugin.
Combine semantic app automation with visual/native-system inspection:

- **agent-device** owns repeatable app sessions, accessibility snapshots,
  assertions, logs, screenshots, recordings, network evidence, and replay.
- **Peekaboo** owns macOS-wide visual inspection and native window, menu-bar,
  tray, Dock, browser, dialog, and permission interaction.
- **Flutter/Xcode/Dart CLI tools** own compilation, tests, signing inspection,
  crash diagnostics, and profiling. Do not add an MCP when a first-party CLI is
  clearer and more reliable.

Both automation servers are declared in `.mcp.json`. Their shared launcher
refuses to start versions other than Peekaboo 4.2.2 and agent-device 0.20.10.
Pi accesses them lazily through `pi-mcp-adapter`; use its `mcp` proxy to
search/describe a tool before calling it. Other supported hosts can load the
same servers directly.

The reviewed host setup for this workflow is:

```bash
brew tap steipete/tap
brew trust --formula steipete/tap/peekaboo
brew install steipete/tap/peekaboo
brew pin peekaboo
npm install --global --ignore-scripts agent-device@0.20.10
pi install npm:pi-mcp-adapter@2.31.0
./.agents/skills/macos-desktop-qa/scripts/mcp-server.sh check
```

The Homebrew tap may advance before a fresh install. The final check must report
exactly Peekaboo 4.2.2 and agent-device 0.20.10; if it does not, stop and install
the reviewed formula/package revision rather than changing the expected
version. Restart Pi after installing the adapter. Treat version changes as
executable third-party dependency updates: inspect their source/release
integrity and repeat the MCP handshake plus host preflight before adopting
them.

## Safety first

This app uses real account credentials and can supervise a real bridge. Before
launching, inspect live processes:

```bash
ps ax -o pid=,ppid=,etime=,command= | \
  rg '[s]esori-bridge|/[b]ridge/app/build/cli/bundle/bin/bridge|/[S]esori\.app/Contents/MacOS/' || true
```

If a standalone bridge or another desktop build is active, do not kill it,
take over, turn Bridge Off, sign out, clear state, or replace its helper without
explicit user approval. A normal launch may restore a persisted **On** intent,
so the process check is required even for a smoke run. Never automate a macOS
login password, OAuth credentials, MFA, a destructive account action, or an
externally visible prompt/send action without the user's explicit direction.

Screenshots, logs, recordings, traces, replay files, and network dumps can
contain account data, prompts, transcripts, source code, paths, and tokens.
Keep artifacts in a private temporary directory, inspect before sharing, and do
not commit them.

## Host preflight

Run these once per machine/toolchain change:

```bash
flutter doctor -v
./.agents/skills/macos-desktop-qa/scripts/mcp-server.sh check
peekaboo permissions --json --no-remote
agent-device --version
agent-device doctor --platform macos --json
agent-device capabilities --platform macos --json
```

Required state:

- the repository-pinned Flutter/Dart SDK is active;
- Xcode and its macOS SDK are selected;
- Peekaboo reports Screen Recording, Accessibility, and event synthesis granted;
- agent-device reports the local macOS target and macOS commands.

The active GUI session must be unlocked. If agent-device reports `Timed out
while enabling automation mode` and Peekaboo identifies `loginwindow` as the
frontmost application, ask the user to unlock the Mac and retry. Do not infer a
broken runner and do not attempt to type the password. Once unlocked, warm the
runner:

```bash
agent-device prepare ios-runner --platform macos --timeout 600000 --json
```

Use `caffeinate` around a long attended run when sleep itself is not under test.
Do not leave a permanent keep-awake process behind.

## Build and automated baseline

Build the repository helper before launching the desktop app; development
builds resolve this exact host bundle:

```bash
(cd bridge && dart pub get)
(cd bridge/app && make build-host)
(cd client && dart pub get)
(cd client/module_desktop_core && dart analyze --fatal-infos && dart test)
(cd client/desktop && dart analyze --fatal-infos && flutter test)
(cd client/desktop && flutter build macos --debug)
```

Use `flutter build macos --release` when validating release-mode behavior. A
successful build is not GUI evidence. Locate and inspect the actual product:

```bash
app="$PWD/client/desktop/build/macos/Build/Products/Debug/Sesori.app"
test -d "$app"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -d --entitlements :- "$app" 2>/dev/null
```

Run the deterministic native supervised-helper suite when bridge/control/auth
or supervision behavior is in scope:

```bash
(cd bridge/app && \
  SESORI_E2E_REQUIRED=1 \
  SESORI_E2E_ARTIFACT_DIR="$(mktemp -d)/sesori-supervised-e2e" \
  dart test test/integration/supervised_e2e_test.dart)
```

## Real app loop

Create a private artifact root:

```bash
artifact_root="$(mktemp -d)/sesori-macos-qa"
mkdir -p "$artifact_root"
```

After the process-safety check and any required approval, launch the built app
and bind an app session:

```bash
app="$PWD/client/desktop/build/macos/Build/Products/Debug/Sesori.app"
open -na "$app"
agent-device open Sesori --platform macos --surface app --foreground
agent-device snapshot -i
agent-device screenshot "$artifact_root/launch.png"
```

Use `snapshot -i`, selectors, and current `@ref` values to inspect and act.
Refs are invalid after state changes unless the command's settled diff returns
new ones. Prefer `press`, `fill`, `find`, `wait`, and `is` over coordinates.
Use `--settle` on actions when available and verify the resulting state before
continuing.

Use Peekaboo when visual layout or macOS chrome matters:

```bash
peekaboo see --app Sesori --annotate \
  --path "$artifact_root/sesori-annotated.png" --json --no-remote
peekaboo window list --app Sesori --json --no-remote
peekaboo menubar --help
```

Read captured images with the agent's image-capable file reader. Use Peekaboo
for tray primary/secondary clicks, context-menu appearance, close-to-hide,
Dock presence, Open/focus, native dialogs, and browser OAuth. Refresh the
accessibility/visual snapshot after every mutation. Do not silently enable
Chrome remote debugging on the user's primary browser profile; native
Peekaboo interaction is sufficient unless the user approves a dedicated
debuggable QA profile.

For repeatable evidence, arm agent-device recording on `open` with
`--save-script <private-path>`, close cleanly, and replay only after reviewing
the generated script for secrets and destructive actions. End every session:

```bash
agent-device close --json
```

Then verify no unintended GUI-owned helper/backend process remains. Preserve a
helper only when that is the expected persisted-On outcome of the test.

## Regression coverage

Treat `docs/regression/desktop-bridge-supervision.md` as the authoritative
supervision matrix and failure-signal list. For release confidence, cover its
L3 macOS journey with a dev-built helper and representative live plugin:

1. browser login and relaunch restore;
2. healthy control handshake, relay state, and plugin health;
3. phone-to-desktop-helper session round trip;
4. helper crash/backoff and exit-86 immediate restart;
5. login-required behavior;
6. Bridge Off, window close, tray Open, and Quit orphan checks;
7. standalone CLI coexistence and explicit takeover behavior.

Also vary light/dark appearance, reduced motion, window sizes, menu-bar
primary/secondary clicks, network loss/recovery, sleep/wake, second launch,
and accessibility keyboard navigation when relevant to the changed feature.
Do not claim screens that the active desktop plan has not implemented yet.

## Report

Report:

- exact app commit/build mode and macOS/Xcode/Flutter versions;
- whether a real or fake auth/relay/plugin path was used;
- scenarios passed, failed, blocked, and intentionally not run;
- process/orphan checks and any persistent state changed;
- artifact paths and whether they contain sensitive data;
- concrete reproduction steps, expected versus actual behavior, logs, and the
  smallest useful screenshot/trace for every failure.

A visual pass does not replace process, log, lifecycle, or transport evidence.
A deterministic headless pass does not replace real tray/window/system QA.
