# Founder Call

## Capability

New phone users are invited to book a call with the CEO, so the team can learn
what they need from Sesori. The invitation slides up once, by itself, the first
time the phone sees a connected computer after a fresh sign-in. Settings ›
Support keeps a permanent **Book a call with the CEO** row. Remote Config
switches the whole invitation and each moment, and supplies the booking link
and wording, so the console can block countries and run a wording A/B test.
Desktop does not offer the call yet.

## Required Behavior

- Only an interactive sign-in on a build with this feature arms the device.
  Users already signed in when they update are never armed and never see the
  sheet by itself. A user who signs out and back in, or signs in on a new phone,
  may see it once.
- On an armed device, the first connected computer opens the sheet over
  whichever screen is showing, about 1.2 s later so that screen settles first.
  A raised keyboard closes before it opens.
- The sheet shows the title, the message, **Book a call** (primary), and
  **Not now** (tertiary). **Book a call** closes the sheet and opens the booking
  page in the in-app browser. **Not now** and a swipe down only close it.
- The sheet shows at most once per device. The device is retired before the
  sheet opens, so a relaunch, a reconnect, or a crash never shows it again.
  Opening the booking link from any surface also retires the device.
- Settings › Support leads with **Book a call with the CEO** whenever the
  invitation is enabled, armed or not. It opens the booking page in the in-app
  browser.
- Remote Config keys, each with a built-in default when unset or empty:
  - `founder_call_enabled` (default on). Off hides the sheet and the Settings
    row. A Country/Region condition that sets it off blocks those countries.
  - `founder_call_after_computer` (default on) gates the automatic sheet.
  - `founder_call_url` (default `https://cal.com/vespr/sesori-walkthrough`).
    Only an https link with a host is used; anything else falls back to the
    default and logs a warning.
  - `founder_call_title`, `founder_call_message`, `founder_call_button` replace
    "Talk to the CEO", "Got 15 minutes? Tell me what you need from Sesori.",
    and "Book a call". Values are trimmed.
- Remote Config is fetched once per launch, shared with the feedback prompt
  config, and falls back to the values activated on an earlier launch.
- Analytics events carry only a closed `surface` value:
  - `founder_call_shown` with `computer_connected_sheet` when the automatic
    sheet is claimed (the A/B test's activation event), retained once while the
    analytics preference is still resolving after a fresh sign-in;
  - `founder_call_link_opened` when the booking page opened (the goal event),
    with `computer_connected_sheet` or `settings`;
  - `founder_call_declined` with `computer_connected_sheet` when the sheet
    closed without booking.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Automated. The service suite proves that a fresh sign-in arms the device and the first connected computer shows the sheet once, that an unarmed device never shows it, that a relaunch does not show it again, that opening the link retires it, the per-moment and master switches, the trimmed remote wording, the https-only link with its default, that an unstarted service stores nothing (desktop), and that an unreadable stored value reads as unarmed. The storage suite pins the persisted JSON and reads another version or kind as unarmed. The analytics service suite proves a sheet shown before the preference resolved is delivered afterwards. The login cubit suite proves only a successful sign-in arms the device. The Firebase source suite proves unset values, an empty text and an empty switch read as null and one fetch per launch. The listener suite proves the settle delay, the built-in and remote wording, booking in the in-app browser, and **Not now** recorded as declined. The Settings suites prove the row leads Support only when offered, and that it opens the booking page in the in-app browser and records the `settings` booking. The event suite pins the wire names and values. |
| L2 Routine | On a phone against the dev account: sign in fresh with no computer, then pair one; the sheet slides up over the settled screen; **Book a call** opens the booking page; relaunch and reconnect, and it does not return. Settings › Support shows **Book a call with the CEO** first. |
| L3 Release | With Remote Config setting `founder_call_enabled` off, the Settings row is gone and a fresh sign-in shows no sheet. With custom wording, the sheet shows it. An app updated while signed in shows no sheet on connect. |
| L4 Extended | At accessibility text sizes, the sheet does not clip. |
| L5 Full | No additional coverage. |

## Failure Signals

- The sheet opens for a user who was signed in before updating, opens twice,
  or opens again after a relaunch, reconnect, or booking from Settings.
- The sheet opens during a route transition and vanishes, or appears before the
  connected screen settles.
- The Settings row appears with the master switch off, or the sheet or row
  appears on desktop.
- A console typo opens a non-https page.
- An analytics event carries anything other than the closed surface value.

## Sources

- `client/module_core/lib/src/services/founder_call_service.dart`
- `client/module_core/lib/src/repositories/founder_call_repository.dart`
- `client/module_core/lib/src/api/founder_call_config_api.dart`
- `client/module_core/lib/src/api/storage/founder_call_storage.dart`
- `client/module_core/lib/src/foundation/models/founder_call/`
- `client/module_core/lib/src/cubits/founder_call/`
- `client/module_core/lib/src/cubits/founder_call_prompt/`
- `client/module_core/lib/src/cubits/login/login_cubit.dart`
- `client/module_core/lib/src/foundation/models/product_analytics/product_analytics_event.dart`
- `client/module_app_ui/lib/src/features/founder_call/`
- `client/module_app_ui/lib/src/features/settings/settings_view.dart`
- `client/app/lib/core/platform/firebase_founder_call_config_source.dart`
- `client/app/lib/core/platform/firebase_remote_config_client.dart`
- `client/app/lib/features/settings/settings_screen.dart`
- `client/app/lib/main.dart`
- `client/module_core/test/services/founder_call_service_test.dart`
- `client/module_core/test/services/product_analytics_service_test.dart`
- `client/module_core/test/api/founder_call_storage_test.dart`
- `client/module_core/test/cubits/login/login_cubit_test.dart`
- `client/module_core/test/foundation/product_analytics_event_test.dart`
- `client/module_app_ui/test/features/founder_call/founder_call_prompt_listener_test.dart`
- `client/module_app_ui/test/features/settings/settings_app_info_test.dart`
- `client/app/test/core/platform/firebase_founder_call_config_source_test.dart`
- `client/app/test/features/settings/settings_screen_test.dart`
