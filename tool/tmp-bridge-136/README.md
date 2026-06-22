# TEMPORARY: pinned Sesori Bridge build `v1.1.2-internal.136` (Windows x64)

Throwaway debugging aid for installing one exact internal build to reproduce/verify
self-updater behavior. **Not** a supported install path; delete this directory and
branch when done.

## What's here

- `payload/bin/sesori-bridge.exe` + `payload/lib/sqlite3.dll` — the win32-x64 build
  produced by the `Release All Platforms` run for commit `faab4154` (tag
  `v1.1.2-internal.136`). Committed here because GitHub Actions artifacts are not
  anonymously downloadable, even on a public repo.
- `install-bridge-136.ps1` — installs the payload into the managed runtime location
  (`%LOCALAPPDATA%\sesori`) exactly like the real installer, writes
  `.managed-runtime.json` = `1.1.2-internal.136`, and puts `sesori-bridge` on PATH.

## Install command (Windows PowerShell)

```powershell
irm https://raw.githubusercontent.com/sesori-ai/sesori_apps_monorepo/sesori-bridge-session-7954da/tool/tmp-bridge-136/install-bridge-136.ps1 | iex
```

Then open a NEW terminal and run `sesori-bridge --version` (reports `1.1.2`; the
`.136` suffix lives in the manifest/tag, not the compiled appVersion).

## Payload SHA256

- `bin/sesori-bridge.exe` — `41a4e615932b93a7f8fb1914e0b4987083ecaccd2bb3ed67ff883788e7a3aa3d`
- `lib/sqlite3.dll` — `563a01a5fbb929844df1a9f6a84f73f7a53b9b183ebda8cb8399d69567adff09`
