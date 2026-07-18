# Getting Started

Go from zero to your first remote OpenCode session in a few minutes.

## What you need

- A laptop or desktop where you can run terminal commands.
- An iPhone or Android phone.
- A GitHub, Google, Apple, or email account to sign in with.
- [OpenCode](https://opencode.ai) installed and working on your machine.

If you are setting up a headless VM or server, see the [headless VM guide](SETUP_HEADLESS_VM.md) after you finish this page.

## 1. Install OpenCode

OpenCode is the AI coding engine that runs on your machine. Sesori is the remote cockpit that talks to it.

```bash
curl -fsSL https://opencode.ai/install | bash
```

Then open it once to confirm it works and connect an AI provider:

```bash
opencode
```

## 2. Download the Sesori app

Install Sesori on your iPhone or Android phone:

- **iOS:** [App Store](https://apps.apple.com/app/sesori/id6760642500)
- **Android:** [Google Play](https://play.google.com/store/apps/details?id=com.sesori.app)

Requires iOS 15 or later, or Android 8.0 or later.

## 3. Install the Sesori Bridge on your machine

The Bridge is a small open-source command-line tool that links the app to OpenCode.

**macOS / Linux:**

```bash
curl -fsSL https://sesori.com/install.sh | bash
```

**Windows (PowerShell):**

```powershell
irm https://sesori.com/install.ps1 | iex
```

The installer puts a `sesori-bridge` command on your PATH. If PATH has not refreshed yet, you can run the binary directly:

- macOS / Linux: `~/.local/share/sesori/bin/sesori-bridge`
- Windows: `%LOCALAPPDATA%\sesori\bin\sesori-bridge.exe`

**Prefer not to install globally?** You can also run `npx @sesori/bridge` or `bunx @sesori/bridge`. You will need to run that exact command every time.

## 4. Run the Bridge

Open a terminal and run:

```bash
sesori-bridge
```

The first run will:

1. Open your browser to sign in with GitHub, Google, Apple, or email.
2. Start or connect to the local OpenCode server.
3. Register the Bridge with the Sesori relay.
4. Start listening for connections from the Sesori app.

You will see something like:

```
Signed in as you@example.com
opencode server started
Registered with relay
Bridge is online — waiting for connections
```

## 5. Connect the app

Open the Sesori app on your phone and sign in with the **same account** you used for the Bridge. If the Bridge is running on your machine, the app takes you straight to your project list.

Tap a project, create or open a session, and send a prompt. You can type, use voice input, choose an agent/model, answer pending questions, and stop a running task from Sesori.

## Keep the Bridge running

The Bridge has to be running for the app to reach OpenCode on your laptop.

For a quick session, leave it open in a terminal. For a longer setup, run it in the background with `nohup`, `tmux`, or a launchd/systemd unit. See the [headless VM guide](SETUP_HEADLESS_VM.md) for a full systemd example.

## Troubleshooting

- **"Port already in use"** — another Bridge is already running. Close the other one, or on macOS/Linux run `pkill sesori-bridge`.
- **"Could not reach relay"** — check your internet connection. The Bridge needs outbound HTTPS (port 443) to the Sesori relay.
- **"OpenCode not responding"** — confirm OpenCode is installed (`opencode --help`), then restart the Bridge.
- **App and Bridge do not pair** — make sure you signed in with the same account on both devices.

Stuck? Reach out on [Discord](https://discord.gg/5KBC8dV9uR) or email [hello@sesori.com](mailto:hello@sesori.com).
