#!/usr/bin/env bash
# Disposable native-CPU distro container. The session job's prepare step already verified both
# signed producer releases; this row upgrades between them on the distro's own libraries.
set -euo pipefail

format="$1"
inputs="$2"
probes="$3"
arch="$4"
evidence="$5"

case "$format" in
  deb)
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      python3 xvfb xauth dbus-daemon gnome-keyring procps passwd
    install_package() { DEBIAN_FRONTEND=noninteractive apt-get install -y "$1"; }
    remove_package() { apt-get remove -y sesori-desktop; }
    ;;
  rpm)
    dnf install -y python3 xorg-x11-server-Xvfb dbus-daemon gnome-keyring procps-ng shadow-utils util-linux
    rpmkeys --import "$inputs/current/desktop-linux-public.asc"
    install_package() { dnf --setopt=localpkg_gpgcheck=True install -y "$1"; }
    remove_package() { dnf remove -y sesori-desktop; }
    ;;
  *) echo "Unsupported package format: $format" >&2; exit 2 ;;
esac

[[ ! -e /opt/sesori-desktop ]] || { echo 'Container already has a Sesori installation' >&2; exit 1; }
useradd --create-home qa
# The ordinary user cannot traverse the runner's home; give it private copies instead.
cp -a "$probes" /tmp/qa-probes
chmod -R a+rX /tmp/qa-probes
probes=/tmp/qa-probes
install -d -o qa /tmp/qa-evidence
trap 'mkdir -p "$evidence" && cp -a /tmp/qa-evidence/. "$evidence/"' EXIT

require_identity() {
  python3 - "$inputs/$1/desktop-linux-release.json" <<'PY'
import json, sys
release = json.load(open(sys.argv[1]))
installed = json.load(open("/opt/sesori-desktop/bridge/desktop-bundle.json"))
keys = ("version", "buildNumber", "sourceSha")
if any(installed[key] != release[key] for key in keys):
    raise SystemExit(f"Installed identity differs from the {sys.argv[1]} release")
PY
}

# One ordinary user session per phase. The keyring file and password persist across phases.
as_qa() {
  runuser -u qa -- env -i PATH=/usr/bin:/bin HOME=/home/qa LC_ALL=C.UTF-8 GITHUB_ACTIONS=true \
    PHASE="$1" PROBE="$probes/$2/sesori_desktop" EVIDENCE=/tmp/qa-evidence SECRET_SERVICE="$3" \
    dbus-run-session -- bash -euo pipefail -c '
      mkdir -p -m 700 /tmp/qa-runtime "$HOME/.local/share/dbus-1/services"
      export XDG_RUNTIME_DIR=/tmp/qa-runtime DISPLAY=:96 GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1
      # The user service precedes the distro one, so an absent store cannot be auto-started.
      printf "[D-BUS Service]\nName=org.freedesktop.secrets\nExec=/bin/false\n" \
        > "$HOME/.local/share/dbus-1/services/sesori-qa-absent-secret-service.service"
      if [[ "$SECRET_SERVICE" == present ]]; then
        echo disposable-ci-keyring | gnome-keyring-daemon --unlock --components=secrets >/dev/null
      fi
      Xvfb :96 -screen 0 1280x800x24 -nolisten tcp & xvfb=$!
      for _ in $(seq 50); do [[ -e /tmp/.X11-unix/X96 ]] && break; sleep 0.2; done
      SESORI_PACKAGED_PROBE_PHASE="$PHASE" SESORI_PACKAGED_PROBE_OUTPUT="$EVIDENCE/$PHASE-storage.txt" \
        timeout 120 "$PROBE" > "$EVIDENCE/$PHASE-probe.log" 2>&1
      grep -q "^PASS shared SQLite/Secret Service" "$EVIDENCE/$PHASE-storage.txt"
      if [[ "$PHASE" != write ]]; then
        # Render smoke of the installed signed app on this distro, with the store in this state.
        log="$EVIDENCE/$PHASE-application.log"
        setsid /usr/bin/sesori-desktop > "$log" 2>&1 & app=$!
        for _ in $(seq 120); do grep -q "Desktop startup: rendering the application" "$log" && break; sleep 0.5; done
        grep -q "Desktop startup: rendering the application" "$log"
        kill -0 "$app"
        kill -TERM -- "-$app"
        wait "$app" || true
      fi
      kill "$xvfb"
    '
}

previous="$(echo "$inputs"/previous/Sesori-linux-"$arch"-*."$format")"
current="$(echo "$inputs"/current/Sesori-linux-"$arch"-*."$format")"
install_package "$previous"
require_identity previous
as_qa write previous present
install_package "$current"
require_identity current
as_qa unavailable current absent
as_qa read current present
remove_package
for removed in /opt/sesori-desktop /usr/bin/sesori-desktop /usr/share/applications/sesori-desktop.desktop; do
  [[ ! -e "$removed" && ! -L "$removed" ]] || { echo "Package-owned path remains: $removed" >&2; exit 1; }
done
pgrep -f '^/opt/sesori-desktop/' && { echo 'Sesori process remains after removal' >&2; exit 1; }
echo PASS > /tmp/qa-evidence/result.txt
