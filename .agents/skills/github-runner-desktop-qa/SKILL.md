---
name: github-runner-desktop-qa
description: >-
  Test Sesori desktop builds on ephemeral GitHub Actions runners using Tailscale,
  private SSH and loopback VNC. Use for native Linux desktop testing, interactive
  runner debugging, tray/accessibility diagnosis and remote QA cleanup.
metadata:
  audience: maintainers
  workflow: github-runner-desktop-qa
---

# GitHub Runner Desktop QA

## When to use

Use a disposable GitHub-hosted runner to inspect an actual native desktop build
without interrupting the operator's installed Sesori app or bridge. Current
interactive support is **Linux x64 and ARM64, KDE/X11, GNOME Keyring Secret
Service**. This does not claim KWallet, macOS or Windows runner access. For local
macOS testing, use [macos-desktop-qa](../macos-desktop-qa/SKILL.md).

Read the repository instructions and these owners before changing the workflow:

- [Desktop Native Qualification](../../../.github/workflows/desktop-qualification.yml)
  selects private builds and owns manual `linux-interactive-debug`.
- [Diagnostic driver](../../../.github/scripts/debug_desktop_linux_session.py)
  verifies signed inputs and owns the disposable desktop/lifetime.
- [Native session workflow](../../../.github/workflows/desktop-linux-session.yml)
  owns automated application qualification; diagnostics do not replace it.
- [Regression contract](../../../docs/regression/desktop-distribution.md)
  defines native, authenticated, upgrade and stable proof boundaries.

Repository paths and CLI commands below are relative to the repository root,
not this skill directory. Use only the operator-approved checkout/worktree.

## Safety and access prerequisites

- The operator's Tailscale client must be running in the intended tailnet.
  Stop for user-owned login/MFA; never request passwords, MFA codes or auth keys.
- Use GitHub environment `desktop-linux-debug`, restricted to `main` and the
  explicitly approved QA branch. Do not broaden its branch policy for convenience.
- Its variables are **non-secret** `TAILSCALE_CLIENT_ID` and `TAILSCALE_AUDIENCE`.
  The federated identity requires subject
  `repo:sesori-ai/sesori_apps_monorepo:environment:desktop-linux-debug`, custom
  claims `workflow=Desktop Native Qualification` and
  `event_name=workflow_dispatch`, Auth Keys write scope and only
  `tag:sesori-ci-debug`. Workflow renames require matching identity changes.
- Preserve existing tailnet rules. The diagnostic tag is admin-owned; permit
  admins to tagged runners on TCP 22 and Tailscale SSH as `runner`, without a
  runner-initiated grant into the operator's Mac or unrelated devices.
- No public SSH/VNC/noVNC endpoint, long-lived auth key, OAuth client secret,
  signing key or QA-account credential belongs in an interactive session.
  Do not log into real accounts or introduce private projects/transcripts.
- Do not launch, replace, stop or clear the operator's installed Sesori/Bridge.
  Never run the diagnostic server or its root package installer on a workstation.
- Screenshots/logs are private until inspected. No interactive artifacts upload
  automatically; never publish paths, code, prompts, transcripts, account names
  or tokens. A private network does not make captured content safe to publish.

If federation or policy is missing, establish the restrictions above before
connecting a runner. Do not replace a custom policy with an allow-all example.

## 1. Select a genuine native build

Prefer an already successful, retained **signed internal Linux producer run**.
Use its Actions run ID, not its build number or a public release object that
may have rolled away. The driver authenticates the original artifacts against
existing producer validation and the independently pinned release key.

When product changes require a new build, use the existing protected main-only
packaging owner, with an exact main-ancestor source:

```bash
: "${SOURCE_SHA:?Set the exact approved main-ancestor commit}"
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref main -f mode=linux-packaging -f channel=internal -f source_sha="$SOURCE_SHA"
```

Wait for its authoritative result through GitHub's live run view or an existing
completion notification; do not add a polling helper. Do not dispatch stores,
create a public release, copy signing credentials into the
runner, change retention or silently substitute another build. Workflow/tooling
revision and compiled product source can differ; record both honestly.

Interactive debug **runs existing compiled packages**; it does not compile a
new product or qualify an unsigned branch build. If compilation or unmerged
product testing is needed, inspect the existing build owner and plan that work
explicitly rather than bypassing signed-input validation.

## 2. Dispatch the manual diagnostic job

Choose an environment-allowed ref containing `linux-interactive-debug` and the
intended driver. This may be the approved QA branch while tooling is unmerged;
do not assume a documentation branch is allowed. Use `main` after delivery.

```bash
: "${QA_REF:?Set main or the explicitly approved QA ref}"
: "${PACKAGING_RUN:?Set the successful retained internal producer run ID}"
gh workflow run desktop-qualification.yml --repo sesori-ai/sesori_apps_monorepo \
  --ref "$QA_REF" -f mode=linux-interactive-debug -f debug_arch=arm64 \
  -f packaging_run="$PACKAGING_RUN"
```

Use `debug_arch=x64` for the native x64 runner; do not use CPU emulation.
Record the returned run URL, tooling head, producer/source and CPU. Wait for the
job's ready summary or native Tailscale peer events, not a sleep/status-poll loop.
When a PR monitor owns CI, act on its delivered reports rather than polling it.

The job verifies artifacts before network admission, joins as an ephemeral
`tag:sesori-ci-debug` node, then starts the anonymous desktop in an isolated home.
The summary provides its hostname, exact `session.env` path and stop command.
The ready window is **20 minutes**, with a **40-minute job ceiling**. Do not
extend the session into a persistent or unattended machine.

## 3. Verify SSH identity and connect

Use the generated hostname from that run, not a remembered IP. The following
Bash setup obtains only that peer's public host keys from the authenticated
Tailscale control plane. It neither reads personal SSH identities nor modifies
user SSH configuration. Refuse missing keys; never disable host verification.

```bash
set -euo pipefail
: "${DEBUG_HOST:?Set the hostname from the current diagnostic run summary}"
SSH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sesori-runner-ssh.XXXXXX")"
DEBUG_IP="$(python3 - "$DEBUG_HOST" "$SSH_DIR/known_hosts" <<'PY'
import json
from pathlib import Path
import subprocess
import sys

status = json.loads(subprocess.check_output(["tailscale", "status", "--json"], text=True))
peer = next((p for p in (status.get("Peer") or {}).values()
             if p.get("HostName") == sys.argv[1]), None)
if not peer or not peer.get("Online") or "tag:sesori-ci-debug" not in (peer.get("Tags") or []):
    raise SystemExit("Expected diagnostic peer is not online with its required tag")
keys = peer.get("sshHostKeys") or []
if not keys:
    raise SystemExit("No authenticated SSH host keys; do not bypass verification")
ip = peer["TailscaleIPs"][0]
known_hosts = Path(sys.argv[2])
known_hosts.write_text("".join(f"{ip} {key}\n" for key in keys))
known_hosts.chmod(0o600)
print(ip)
PY
)"
SSH=(ssh -F /dev/null -o "UserKnownHostsFile=$SSH_DIR/known_hosts"
  -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes
  -o BatchMode=yes -o IdentityFile=none -o IdentityAgent=none
  -o PreferredAuthentications=none -o ConnectTimeout=12
  -o ServerAliveInterval=10 -o ServerAliveCountMax=1)
"${SSH[@]}" "runner@$DEBUG_IP" 'id -un; uname -m'
```

Expect `runner` and the selected native CPU (`aarch64` or `x86_64`). Open an
interactive shell with `"${SSH[@]}" "runner@$DEBUG_IP"`. **Inside that remote
shell**, run the exact `source .../session.env` command from the job summary.
Do not source it locally or assume a new SSH shell inherits Actions variables.
Its `HOME`, display and D-Bus address belong only to the disposable fixture.

## 4. Inspect the real desktop

In the remote shell, check `ss -lnt`: VNC port 5900 must bind only to
`127.0.0.1`/`::1`. VNC has no independent password in this fixture; SSH and the
restricted tailnet policy protect it. Never remove that loopback restriction.

For visual interaction, run a foreground tunnel in a local terminal with the
same validated SSH setup:

```bash
"${SSH[@]}" -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:15900:127.0.0.1:5900 "runner@$DEBUG_IP"
```

Connect the local VNC viewer to `vnc://127.0.0.1:15900`. Keep the tunnel terminal
open; Ctrl-C closes that owned tunnel. Do not bind the forwarded port to
`0.0.0.0`, expose noVNC or disable VNC's loopback restriction. If the local port
is occupied, choose another unused loopback port; do not kill unrelated work.

Exercise the visible app: initial rendering, close-to-tray, right-click menu,
normal Quit and relevant anonymous fixture behavior. Identify app/window/menu
ownership before input; use actual visible targets, not copied coordinates.
For KDE, the advertised StatusNotifier Title may be `com.sesori.desktop`, not
`Sesori`. Primary icon Activate and secondary context-menu clicks are distinct.

Use `wmctrl`, `xdotool`, `xprop`, AT-SPI and native screenshots within the
runner session when useful. A menu can be visibly present while absent from an
accessibility query. Capture that discrepancy and diagnose ownership/state;
absence from AT-SPI alone is not evidence that the product menu failed.
Do not replace a failed UI test with hidden DBusMenu events or force-kill a
process and call it normal Quit.

Keep captures/logs in private scratch space and inspect before sharing. For
public evidence use anonymous fixtures only. Do not upload the session home,
raw tailnet state, credentials or an unreviewed recursive artifact directory.

## 5. Stop, clean up and state the proof boundary

1. In the remote session, execute the exact `printf 'stop\n' > .../stop.pipe`
   command from the summary. The driver owns process-group, package and
   disposable-home cleanup; the action logs the ephemeral node out afterward.
2. Close the owned local tunnel and SSH shells. Remove only the generated
   `SSH_DIR` when finished. Never use broad `pkill` or clear personal app data.
3. Confirm completion/logout. If the session is stuck, cancel only its exact
   owned Actions run; do not cancel packaging, release or another user's job.
4. Record observed CPU, build/source, UI actions, partial failures and cleanup.
   A node disappearing or a successful job is not application acceptance.
5. Fix the committed automated scenario and assess its fresh native evidence.
   Keep its PR draft while required results or screenshots fail or remain
   uninspected; never use an interactive pass to override that gate.

SSH proves access; an RFB handshake proves forwarding. A screenshot proves one
visible frame; a manual Quit observation proves that specific interaction.
None alone proves the automated signed-package replacement, real-account/helper
On/Off restoration, OS-login autostart, unavailable Secret Service, remaining
distro matrix, source/schema migration or stable admission. Preserve the
separate qualification and production-approval owners.

## Troubleshooting and workflow changes

- **Duplicate route flag:** the pinned `tailscale/github-action` supplies
  `--accept-routes` itself. Keep action args `--ssh --accept-dns=false`, then
  `sudo tailscale set --accept-routes=false` before desktop startup. Duplicating
  the flag in `args` fails before authentication; do not loosen policy to fix it.
- **Reusable permission admission:** GitHub validates skipped nested jobs too.
  Callers must admit `id-token: write`; ordinary callee jobs keep the read-only
  default. Preserve signing environments, inherited secrets, finalizer ownership
  and `store-production`. Update the exact permission contract tests together.
- **Idle lock:** disable Plasma auto-lock only in the disposable home before
  startup. Never unlock or reconfigure the operator's workstation. A virtual
  desktop without a real logind session cannot prove OS-login behavior.
- **Observer timeout:** when automating native peer-event watches or SSH, own
  the process group and bound teardown/pipe collection. Never perform an
  unbounded pipe read. A timed-out observer is not evidence of SSH failure.
- **Expired build/session:** explicitly select retained signed input or dispatch
  a fresh bounded diagnostic session. Do not reuse stale host keys/IPs or change
  retention, release identity, signing trust or qualification requirements.
