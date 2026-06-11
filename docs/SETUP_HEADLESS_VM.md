# VM Setup Guide: OpenCode + Sesori Bridge

## 1. Create a fresh Linux VM

- Recommended: Debian or Ubuntu
- Minimum: 1 vCPU, 512 MB RAM (works with swap, but tight)
- SSH into the machine as root

---

## 2. Update system

```bash
apt update && apt upgrade -y
```

---

## 3. Install Git

```bash
apt install git -y
```

---

## 4. Install GitHub CLI (`gh`)

```bash
(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
```

---

## 5. Install OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
```

Verify:

```bash
command -v opencode
```

Expected path example:

```
/root/.opencode/bin/opencode
```

---

## 5.5. Login OpenCode

At least one provider needs to be logged in for it to work.

```bash
opencode auth login
```

---

## 6. Install Sesori Bridge
```bash
curl -fsSL https://sesori.com/install | bash
````

Verify:

```bash
command -v sesori-bridge
```

Expected path example:

```
/root/.local/bin/sesori-bridge
```

---

## 6.5 Login Sesori Bridge

Run `sesori-bridge` once and login. After this, stop it.

---

## 7. (Recommended) Add Swap (for 512MB VMs)

```bash
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

Optional tuning:

```bash
sysctl vm.swappiness=10
echo 'vm.swappiness=10' >> /etc/sysctl.conf
```

---

## 8. Setup OpenCode systemd service

```bash
nano /etc/systemd/system/opencode.service
```

```ini
[Unit]
Description=OpenCode Server
After=network.target

[Service]
ExecStart=/root/.opencode/bin/opencode serve --port 9921
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
```

Enable + start:

```bash
systemctl daemon-reload
systemctl enable --now opencode
```

---

## 9. Setup Sesori Bridge systemd service

```bash
nano /etc/systemd/system/sesori-bridge.service
```

```ini
[Unit]
Description=Sesori Bridge
After=opencode.service
Requires=opencode.service

[Service]
ExecStart=/root/.local/bin/sesori-bridge --no-auto-start --port 9921 --log-level debug
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
```

Enable + start:

```bash
systemctl daemon-reload
systemctl enable --now sesori-bridge
```

---

## 10. Verify services

```bash
systemctl status opencode --no-pager
systemctl status sesori-bridge --no-pager
```

---

## Updating

### Sesori Bridge

The bridge auto-updates, but only **at process startup**. While running it polls for new releases every 4 hours and logs `A new bridge version (vX.Y.Z) is available. Restart to update.` — it never swaps the binary mid-run. A long-running systemd service therefore stays on its current version until it restarts.

To force an update, restart the service:

```bash
systemctl restart sesori-bridge
```

On startup the bridge checks GitHub releases, downloads and installs the newest version into `~/.local/share/sesori/bin/`, and relaunches. With `Restart=always` in the unit, the service ends up running the new binary.

If the startup check is not picking up the update, re-run the installer and restart:

```bash
curl -fsSL https://sesori.com/install | bash
systemctl restart sesori-bridge
```

Verify via the logs — you should see `Updating to vX.Y.Z...`, or a clean start on the current version:

```bash
journalctl -u sesori-bridge -n 50
```

Note: the startup update check is skipped when `SESORI_NO_UPDATE` is set or a CI environment variable (`CI`, `GITHUB_ACTIONS`, ...) is present in the service environment. The stock unit above has neither, so updates apply by default.

### OpenCode

OpenCode does not auto-update in this setup. Update it manually, then restart its service:

```bash
opencode upgrade
systemctl restart opencode
```

---

## Logs and Debugging

### Follow OpenCode logs

```bash
journalctl -u opencode -f
```

### Follow Sesori logs

```bash
journalctl -u sesori-bridge -f
```

### View recent logs (non-streaming)

```bash
journalctl -u opencode -n 100
journalctl -u sesori-bridge -n 100
```

### Check if services are restarting/crashing

```bash
systemctl status opencode
systemctl status sesori-bridge
```

Look for:

- `Active: active (running)` → healthy
- `Restarting` or `failed` → issue

---

## Notes / Gotchas

- OpenCode binds to `127.0.0.1:9921` by default (local only)
- Sesori connects to OpenCode via that port
- If either binary path differs, update `ExecStart`
- On low-memory machines, expect slower performance due to swap
- If processes are killed, check:

```bash
dmesg -T | grep -i oom
```

---

## Summary

- OpenCode runs as a systemd service on port 9921
- Sesori Bridge depends on it and connects to that port
- Both auto-start on boot
- Bridge updates apply on service restart; OpenCode updates via `opencode upgrade`
- Logs are accessible via `journalctl`
- Swap prevents crashes on low-memory instances
