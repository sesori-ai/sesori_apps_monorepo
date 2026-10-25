#!/usr/bin/env bash
# Disposable native-CPU Arch container. The session job's prepare step already verified both signed
# producer releases; this row replaces a user-owned AppImage on Arch's own libraries and Plasma 6.
set -euo pipefail

inputs="$1"
probes="$2"
arch="$3"
evidence="$4"

# pacman's download sandbox needs Landlock, which container kernels may not expose.
sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
pacman-key --init
if grep -q '^ID=archarm' /etc/os-release; then
  pacman-key --populate archlinuxarm
else
  pacman-key --populate archlinux
fi
pacman -Syu --noconfirm --needed python python-dbus gnome-keyring libsecret gtk3 mesa fuse3 \
  plasma-workspace kwin procps-ng util-linux
# kwin_wayland's CAP_SYS_NICE file capability exceeds the container bounding set and blocks exec.
setcap -r /usr/bin/kwin_wayland

useradd --create-home qa
# The ordinary user cannot traverse the runner's home; give it private copies instead.
install -d -o qa /tmp/qa-inputs /tmp/qa-evidence
for label in previous current; do
  install -d -o qa "/tmp/qa-inputs/$label"
  install -o qa -m 755 "$inputs/$label"/Sesori-linux-"$arch"-*.AppImage "/tmp/qa-inputs/$label/"
  cp "$inputs/$label/desktop-linux-release.json" "/tmp/qa-inputs/$label/"
done
cp -a "$probes" /tmp/qa-probes
chmod -R a+rX /tmp/qa-inputs /tmp/qa-probes
trap 'mkdir -p "$evidence" && cp -a /tmp/qa-evidence/. "$evidence/"' EXIT

runuser -u qa -- env -i PATH=/usr/bin HOME=/home/qa LC_ALL=C.UTF-8 GITHUB_ACTIONS=true \
  dbus-run-session -- python3 "$(dirname "$0")/qualify_desktop_linux_appimage.py" \
    --inputs /tmp/qa-inputs --probes /tmp/qa-probes --architecture "$arch" --output /tmp/qa-evidence
