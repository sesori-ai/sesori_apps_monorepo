#!/usr/bin/env bash
# Isolated container fixture. Installs no package and launches no payload on host.
set -euo pipefail

format="$1"
package="$2"
bundle="$3"
arch="$4"
evidence="$5"
script="${6:-$(dirname "$(realpath "$0")")/package_desktop_linux.py}"

mkdir -p /root/.config/sesori /root/.local/share/sesori/{credentials,databases,runtimes} \
  /root/.local/share/sesori-attachments /root/projects/sesori-project
printf 'preserve\n' >/root/.config/sesori/settings
printf 'preserve\n' >/root/.local/share/sesori/credentials/token
printf 'preserve\n' >/root/.local/share/sesori/databases/sesori.db
printf 'preserve\n' >/root/.local/share/sesori/runtimes/runtime
printf 'preserve\n' >/root/.local/share/sesori-attachments/attachment
printf 'preserve\n' >/root/projects/sesori-project/source
sentinel_before="$(find /root/.config/sesori /root/.local/share/sesori /root/.local/share/sesori-attachments \
  /root/projects/sesori-project -type f -print0 | sort -z | xargs -0 sha256sum)"

case "$format" in
  deb)
    control_entries="$(dpkg-deb --ctrl-tarfile "$package" | tar -tf -)"
    if grep -Eq '(^|/)(preinst|postinst|prerm|postrm)$' <<<"$control_entries"; then
      echo 'DEB contains a maintainer script' >&2
      exit 1
    fi
    apt-get update
    apt-get install -y "$package"
    package_paths="$(dpkg-query -L sesori-desktop)"
    ;;
  rpm)
    scripts="$(rpm -qp --scripts "$package")"
    [[ -z "$scripts" ]] || { echo "RPM contains scriptlets: $scripts" >&2; exit 1; }
    dnf install -y "$package"
    package_paths="$(rpm -ql sesori-desktop)"
    ;;
  *) echo "Unsupported package format: $format" >&2; exit 2 ;;
esac

printf '%s\n' "$package_paths" | python3 "$script" verify-owned-paths >"$evidence.ownership.json"
sentinel_after_install="$(find /root/.config/sesori /root/.local/share/sesori \
  /root/.local/share/sesori-attachments /root/projects/sesori-project \
  -type f -print0 | sort -z | xargs -0 sha256sum)"
[[ "$sentinel_before" == "$sentinel_after_install" ]] || { echo 'Install changed shared data sentinel' >&2; exit 1; }

python3 "$script" verify-installed --bundle "$bundle" --arch "$arch" >"$evidence.installed.json"

case "$format" in
  deb)
    apt-get install --reinstall -y "$package"
    python3 "$script" verify-installed --bundle "$bundle" --arch "$arch" >"$evidence.reinstalled.json"
    apt-get remove -y sesori-desktop
    ;;
  rpm)
    dnf reinstall -y "$package"
    python3 "$script" verify-installed --bundle "$bundle" --arch "$arch" >"$evidence.reinstalled.json"
    dnf remove -y sesori-desktop
    ;;
esac

for removed in /opt/sesori-desktop /usr/bin/sesori-desktop \
  /usr/share/applications/sesori-desktop.desktop \
  /usr/share/icons/hicolor/512x512/apps/sesori-desktop.png; do
  [[ ! -e "$removed" && ! -L "$removed" ]] || { echo "Package-owned path remains: $removed" >&2; exit 1; }
done
sentinel_after="$(find /root/.config/sesori /root/.local/share/sesori /root/.local/share/sesori-attachments \
  /root/projects/sesori-project -type f -print0 | sort -z | xargs -0 sha256sum)"
[[ "$sentinel_before" == "$sentinel_after" ]] || { echo 'Shared data sentinel changed' >&2; exit 1; }

python3 - "$format" "$arch" "$evidence" <<'PY'
import json
import platform
import sys
from pathlib import Path

package_format, architecture, output = sys.argv[1:]
installed = json.loads(Path(output + ".installed.json").read_text())
reinstalled = json.loads(Path(output + ".reinstalled.json").read_text())
ownership = json.loads(Path(output + ".ownership.json").read_text())
Path(output).write_text(json.dumps({
    "format": package_format,
    "architecture": architecture,
    "containerMachine": platform.machine(),
    "installedIdentity": installed["identity"],
    "installedPayloadVerified": True,
    "boundedSystemOwnershipVerified": ownership["boundedSystemOwnership"],
    "sameVersionReinstallVerified": installed == reinstalled,
    "removeOwnedPathsVerified": True,
    "sharedDataPreserved": True,
    "proofBoundary": "Native container install, same-version reinstall and removal; not an N-to-N+1 upgrade, GUI, account, signing, repository, or desktop-session proof",
}, indent=2) + "\n")
PY
