<p align="center">
  <a href="https://sesori.com" target="_blank" rel="noopener">
    <strong>Sesori</strong>
  </a>
</p>

<h1 align="center">Run your AI coding agents from your phone.</h1>

<p align="center">
  Sesori is the mobile cockpit for your AI coding sessions — <a href="https://opencode.ai" target="_blank" rel="noopener">OpenCode</a>, <a href="https://github.com/openai/codex" target="_blank" rel="noopener">OpenAI Codex CLI</a>, <a href="https://cursor.com" target="_blank" rel="noopener">Cursor</a>, <a href="https://claude.com" target="_blank" rel="noopener">Claude Code</a>, <a href="https://github.com/badlogic/pi-mono" target="_blank" rel="noopener">Pi</a>, and <a href="https://github.com/can1357/oh-my-pi" target="_blank" rel="noopener">Oh My Pi</a>.<br/>
  Leave your laptop. Take the session.
</p>

<p align="center">
  <img src=".github/assets/banner.png" width="800" alt="Sesori banner" />
</p>

<p align="center">
  <a href="https://apps.apple.com/app/sesori/id6760642500">
    <img src="https://img.shields.io/badge/Download-App%20Store-0D96F6?style=for-the-badge&logo=apple&logoColor=white" alt="Download on the App Store" />
  </a>
  <a href="https://play.google.com/store/apps/details?id=com.sesori.app">
    <img src="https://img.shields.io/badge/Install-Google%20Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Get it on Google Play" />
  </a>
  <a href="https://github.com/sesori-ai/sesori_apps_monorepo/releases">
    <img src="https://img.shields.io/github/v/release/sesori-ai/sesori_apps_monorepo?style=for-the-badge" alt="GitHub release" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-FSL--1.1--ALv2-blue?style=for-the-badge" alt="License" />
  </a>
</p>

<p align="center">
  <a href="https://discord.gg/5KBC8dV9uR">
    <img src="https://img.shields.io/badge/Discord-Join-5865F2?style=for-the-badge&logo=discord&logoColor=white" alt="Join Discord" />
  </a>
  <a href="https://x.com/sesori_ai">
    <img src="https://img.shields.io/badge/Follow-%40sesori__ai-000000?style=for-the-badge&logo=x&logoColor=white" alt="Follow on X" />
  </a>
</p>

<p align="center">
  <a href="#install">Get started</a> ·
  <a href="https://docs.sesori.com" target="_blank" rel="noopener">Docs</a> ·
  <a href="docs/HOW_IT_WORKS.md">How it works</a> ·
  <a href="docs/ARCHITECTURE.md">Architecture</a> ·
  <a href="docs/SECURITY.md">Security</a> ·
  <a href="docs/CONTRIBUTING.md">Contribute</a>
</p>

---

<a id="install"></a>

## Install in 3 steps

### 1. Download the Sesori app

<a href="https://apps.apple.com/app/sesori/id6760642500">
  <img src="https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=apple&logoColor=white" alt="Download on the App Store" />
</a>
<a href="https://play.google.com/store/apps/details?id=com.sesori.app">
  <img src="https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Get it on Google Play" />
</a>

Requires iOS 15 or later, or Android 8.0 or later.

### 2. Install the Bridge CLI on your machine

The Bridge is a small source-available command-line tool that connects the app to your AI coding assistants ([OpenCode](https://opencode.ai), [OpenAI Codex CLI](https://github.com/openai/codex), [Cursor](https://cursor.com), [Claude Code](https://claude.com), [Pi](https://github.com/badlogic/pi-mono), and [Oh My Pi](https://github.com/can1357/oh-my-pi)).

**macOS / Linux:**

```bash
curl -fsSL https://sesori.com/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://sesori.com/install.ps1 | iex
```

Prefer npm or bun? You can also bootstrap the Bridge with `npx @sesori/bridge` or `bunx @sesori/bridge`. It installs the same managed runtime under the hood.

### 3. Start the Bridge

```bash
sesori-bridge
```

Sign in with the **same account** on your phone and your machine. The two pair automatically over the encrypted relay, even on different networks.

> **Full walkthrough:** prerequisites, OpenCode setup, headless VM instructions, and troubleshooting are in [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md).

---

## What you can do

| Feature | What it means |
|---|---|
| **Browse projects & sessions** | See projects and active sessions from [OpenCode](https://opencode.ai), [OpenAI Codex CLI](https://github.com/openai/codex), [Cursor](https://cursor.com), [Claude Code](https://claude.com), [Pi](https://github.com/badlogic/pi-mono), and [Oh My Pi](https://github.com/can1357/oh-my-pi) on your phone. |
| **Keep agents moving** | Answer questions, approve steps, and stop or restart tasks without returning to your desk. |
| **Review code and PR status** | Read diffs and keep tabs on pull requests without opening your laptop. |
| **Voice or type** | Talk to your assistant naturally or use the keyboard — whatever works in the moment. |
| **Real-time notifications** | Get pinged the moment your AI needs you back or a long-running task finishes. |
| **End-to-end encrypted** | Your code, prompts, and responses stay between your phone and your machine. |

---

## How it works

A lightweight Bridge runs on your laptop alongside OpenCode. It connects to a relay server over WebSocket, and your phone connects to the same relay. The relay routes encrypted traffic between them — it never sees your application data.

```mermaid
graph LR
  OC["AI Assistant<br/>on your machine"] -- "HTTP + SSE" --> B["Bridge CLI<br/>your laptop"]
  B -- "WSS · E2E encrypted" --> R["Relay Server<br/>cloud router"]
  R -- "WSS · E2E encrypted" --> M["Sesori App<br/>your phone"]
```

Your laptop and phone perform an ephemeral X25519 key exchange, then encrypt every message with XChaCha20-Poly1305. The relay only routes opaque binary frames.

> **Dive deeper:** [docs/HOW_IT_WORKS.md](docs/HOW_IT_WORKS.md)

---

## Why you can trust it

- **End-to-end encryption.** All application data between your phone and laptop is encrypted with XChaCha20-Poly1305.
- **Ephemeral key exchange.** Each connection uses a fresh X25519 Diffie-Hellman keypair; the relay never holds the room key.
- **Local-first.** Your source code, prompts, and AI responses stay on your machine. We only store the account and routing metadata needed to pair your devices. Push notification previews may include a short snippet of an event; see [docs/SECURITY.md](docs/SECURITY.md) for details.
- **Source-available bridge.** The Bridge and the client protocol are in this repo. You can audit the code that runs on your machine.
- **Source-available license.** Released under the Functional Source License, Version 1.1, Apache 2.0 Future License (`FSL-1.1-ALv2`).

> **Security details:** [docs/SECURITY.md](docs/SECURITY.md)

---

## Supported AI assistants

| Assistant | Status | Notes |
|---|---|---|
| [OpenCode](https://opencode.ai) | Available | Deep native integration. |
| [OpenAI Codex CLI](https://github.com/openai/codex) | Beta | Enabled by default in an upcoming release. |
| [Cursor](https://cursor.com) | Beta | ACP-based Cursor plugin; enabled by default in an upcoming release. |
| [Claude Code](https://claude.com) | Beta | Native stream-json integration; enabled by default in an upcoming release. |
| [Pi](https://github.com/badlogic/pi-mono) | Beta | Native JSONL RPC integration; see the notes below. |
| [Oh My Pi](https://github.com/can1357/oh-my-pi) | Beta | ACP-based integration; see the notes below. |

<details>
<summary><strong>Pi notes</strong></summary>

- **Trust model:** Sesori always launches Pi with `--approve` — project-local Pi
  settings, extensions, skills, and prompt templates are trusted and applied
  without prompts. Only open projects whose code you trust.
- **Install:** the Bridge can install a pinned Pi release for you, or it uses a
  suitable `pi` from your PATH. Point `--pi-bin <path>` at a specific binary to
  make it authoritative (managed install is then disabled).
- **Profile:** your normal Pi data and configuration are used —
  `PI_CODING_AGENT_DIR`, session directories, and provider credentials are
  inherited, never replaced with a Sesori-only profile.
- **Login:** provider login happens locally via Pi's `/login`; there is no
  phone-driven provider login.
- **Terminal handoff:** terminal-created sessions can be continued from Sesori,
  but exit the terminal Pi first. Running the same session concurrently from a
  terminal and Sesori is unsupported.

</details>

<details>
<summary><strong>Oh My Pi notes</strong></summary>

- **Approval policy:** Sesori inherits your OMP `tools.approvalMode`. The
  default `yolo` mode asks nothing; configure a stricter mode locally to get
  standard approval prompts.
- **Install:** the Bridge can install a pinned OMP release, or it uses a
  suitable `omp` from your PATH. Point `--omp-bin <path>` at a specific binary
  to make it authoritative (managed install is then disabled).
- **Profile:** your normal OMP profile, models, plugins, and credentials are
  used — `OMP_PROFILE`, legacy `PI_PROFILE`, and XDG roots are inherited.
- **Login:** provider login happens locally; there is no phone-driven provider
  login.
- **Protocol scope:** Sesori talks to OMP over standard ACP (`omp acp`).
  OMP-specific features outside ACP — host tools, subagent frames, terminal
  handoff frames — are not available from Sesori. Parent/child session lineage
  is not shown because ACP session listings do not expose it.
- **Terminal handoff:** as with Pi, exit a terminal OMP session before
  continuing it from Sesori.

</details>

---

## Repository overview

```
sesori_apps_monorepo/
├── bridge/     # Pure Dart workspace — Bridge CLI + backend plugins
├── client/     # Flutter workspace — mobile & desktop shells
├── shared/     # Cross-product crypto & protocol primitives
└── docs/       # Deep-dive guides
```

- `bridge/app` is the headless CLI that runs on your laptop.
- `bridge/sesori_plugin_*` packages implement support for each AI assistant backend.
- `client/app` is the Flutter mobile shell.
- `client/desktop` is the in-development desktop companion.
- `shared/sesori_shared` holds the encryption primitives and wire types used by both sides.

> **Full architecture:** repo structure, dependency graph, and layered design are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## Built for developers

- **Plugin system.** New AI assistant backends live in their own plugin package without touching the mobile app or core bridge.
- **Headless bridge.** The Bridge is usable without a GUI, ideal for remote machines, VMs, and server setups.
- **Cross-platform.** Mobile apps run on iOS and Android. Bridge CLI runs on macOS, Linux, and Windows.
- **Encrypted by default.** No optional VPN, no tunnel setup, no exposed ports on your laptop.

For where the project is headed, see [docs/VISION.md](docs/VISION.md) and [docs/ROADMAP.md](docs/ROADMAP.md).

> **Want to hack on it?** See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md).

---

## License & support

This repository is source-available under the [Functional Source License, Version 1.1, Apache 2.0 Future License](LICENSE) (`FSL-1.1-ALv2`).

- **Docs:** [docs.sesori.com](https://docs.sesori.com)
- **Discord:** [discord.gg/5KBC8dV9uR](https://discord.gg/5KBC8dV9uR)
- **Email:** [hello@sesori.com](mailto:hello@sesori.com)
- **Issues:** [GitHub Issues](https://github.com/sesori-ai/sesori_apps_monorepo/issues)

---

<p align="center">
  <a href="https://apps.apple.com/app/sesori/id6760642500">Download for iOS</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.sesori.app">Download for Android</a> ·
  <a href="https://docs.sesori.com/get-started/quickstart">Read the Quickstart</a>
</p>
