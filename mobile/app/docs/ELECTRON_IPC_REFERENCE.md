# Electron IPC Reference — Desktop Feature Parity

These are desktop-only IPC methods (not accessible over the network). Listed here as a reference for what capabilities the desktop app has, so you can plan equivalent mobile features.

Source: `packages/desktop-electron/src/preload/types.ts`

---

## Initialization

| IPC Method            | Signature                                              | Mobile Equivalent                              |
| --------------------- | ------------------------------------------------------ | ---------------------------------------------- |
| `awaitInitialization` | `(onStep: (step) => void) => Promise<{url, password}>` | mDNS discovery + `GET /global/health` polling  |
| `killSidecar`         | `() => Promise<void>`                                  | N/A — server lifecycle managed by host machine |

### InitStep phases:

- `server_waiting` — waiting for OpenCode server to start
- `sqlite_waiting` — waiting for database migration
- `done` — ready

### ServerReadyData:

```typescript
{ url: string, password: string | null }
```

---

## Server Connection

| IPC Method            | Signature                       | Mobile Equivalent                         |
| --------------------- | ------------------------------- | ----------------------------------------- |
| `getDefaultServerUrl` | `() => Promise<string \| null>` | Store in SharedPreferences / UserDefaults |
| `setDefaultServerUrl` | `(url) => Promise<void>`        | Store in SharedPreferences / UserDefaults |

---

## File Operations

| IPC Method            | Signature                                        | Mobile Equivalent                                   |
| --------------------- | ------------------------------------------------ | --------------------------------------------------- |
| `openDirectoryPicker` | `(opts?) => Promise<string \| string[] \| null>` | Use `GET /file?path=...` + custom Flutter picker UI |
| `openFilePicker`      | `(opts?) => Promise<string \| string[] \| null>` | Use `GET /find/file` + custom Flutter picker UI     |
| `saveFilePicker`      | `(opts?) => Promise<string \| null>`             | N/A for remote — files are on the server            |
| `openPath`            | `(path, app?) => Promise<void>`                  | N/A — can't open server files locally               |
| `readClipboardImage`  | `() => Promise<{buffer, width, height} \| null>` | Flutter `Clipboard` + image paste support           |

---

## App Control

| IPC Method              | Signature                   | Mobile Equivalent                                           |
| ----------------------- | --------------------------- | ----------------------------------------------------------- |
| `getWindowFocused`      | `() => Promise<boolean>`    | Flutter `WidgetsBindingObserver.didChangeAppLifecycleState` |
| `setWindowFocus`        | `() => Promise<void>`       | N/A                                                         |
| `showWindow`            | `() => Promise<void>`       | N/A                                                         |
| `relaunch`              | `() => void`                | N/A                                                         |
| `getZoomFactor`         | `() => Promise<number>`     | Flutter `MediaQuery.textScaleFactor`                        |
| `setZoomFactor`         | `(factor) => Promise<void>` | Flutter text scale settings                                 |
| `loadingWindowComplete` | `() => void`                | N/A — use splash screen                                     |

---

## Notifications & Links

| IPC Method         | Signature                | Mobile Equivalent                            |
| ------------------ | ------------------------ | -------------------------------------------- |
| `showNotification` | `(title, body?) => void` | Flutter `flutter_local_notifications` or FCM |
| `openLink`         | `(url) => void`          | Flutter `url_launcher` package               |

---

## Key-Value Store

| IPC Method    | Signature                                | Mobile Equivalent    |
| ------------- | ---------------------------------------- | -------------------- |
| `storeGet`    | `(name, key) => Promise<string \| null>` | `shared_preferences` |
| `storeSet`    | `(name, key, value) => Promise<void>`    | `shared_preferences` |
| `storeDelete` | `(name, key) => Promise<void>`           | `shared_preferences` |
| `storeClear`  | `(name) => Promise<void>`                | `shared_preferences` |
| `storeKeys`   | `(name) => Promise<string[]>`            | `shared_preferences` |
| `storeLength` | `(name) => Promise<number>`              | `shared_preferences` |

---

## Updates

| IPC Method      | Signature                                    | Mobile Equivalent                         |
| --------------- | -------------------------------------------- | ----------------------------------------- |
| `runUpdater`    | `(alertOnFail) => Promise<void>`             | App Store / Play Store updates            |
| `checkUpdate`   | `() => Promise<{updateAvailable, version?}>` | `installation.update-available` SSE event |
| `installUpdate` | `() => Promise<void>`                        | App Store / Play Store                    |
| `installCli`    | `() => Promise<string>`                      | N/A                                       |

---

## Events (Electron-specific)

| IPC Method                  | Signature            | Mobile Equivalent                                         |
| --------------------------- | -------------------- | --------------------------------------------------------- |
| `onSqliteMigrationProgress` | `(cb) => () => void` | N/A                                                       |
| `onMenuCommand`             | `(cb) => () => void` | N/A — no native menu on mobile                            |
| `onDeepLink`                | `(cb) => () => void` | Flutter deep link handling via `go_router` or `uni_links` |

---

## Platform-Specific

| IPC Method             | Signature                                    | Mobile Equivalent          |
| ---------------------- | -------------------------------------------- | -------------------------- |
| `parseMarkdownCommand` | `(md) => Promise<string>`                    | Use a Dart markdown parser |
| `checkAppExists`       | `(appName) => Promise<boolean>`              | N/A                        |
| `wslPath`              | `(path, mode) => Promise<string>`            | N/A — WSL not relevant     |
| `resolveAppPath`       | `(appName) => Promise<string \| null>`       | N/A                        |
| `getWslConfig`         | `() => Promise<{enabled}>`                   | N/A                        |
| `setWslConfig`         | `(config) => Promise<void>`                  | N/A                        |
| `getDisplayBackend`    | `() => Promise<"wayland" \| "auto" \| null>` | N/A                        |
| `setDisplayBackend`    | `(backend) => Promise<void>`                 | N/A                        |
