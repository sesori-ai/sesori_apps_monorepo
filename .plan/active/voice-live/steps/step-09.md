# Step 9 — Live words in focus and panel

One commit. It came to about 1,550 changed lines including this doc, a little over the soft cap,
with no clean seam: the layer and its tests belong together. `prompt_input.dart` counts 103 of
those, 23 without the re-indent around the new wrapper. No generated files.

## Built

- `widgets/composer_live_words.dart`: `ComposerLiveWords`, an `OverlayPortal` on the composer's
  body, and `LiveWordsText`, the words themselves.
- `PromptInput`: wraps the body when the shell has voice, and selects the voice state with the
  words taken out, so a new word doesn't rebuild the composer.

Sent and edited words fade where they stand. Step 10 replaces that with the glide; the layer
already keeps the rect it last had in `_composerRect` while leaving, so it has a start point.

## Choices the plan left open

| Choice | Decision | Why |
| --- | --- | --- |
| Words reaching the layer | `BlocListener` into a retained `_Layer`, not the plan's `BlocSelector` | The words must outlive the state: `Cancelling`, `Completed` and `Idle` carry none, and they still have to fade |
| Finding the composer | The portal wraps the body and reads its `info`, not `_composerBodyKey` | Same rect with no key lookup, and it follows the body's morph |
| Slide-out fade | The words only; the panel's card stays solid | The mock fades the whole panel. On the simulator the chat then showed through the words at 40%, unreadable. The spec's row says "words" |
| Top fade | On the text only, inside the card | The card's top edge stays crisp |
| Tentative words at the release | All brighten | As the mock does: the user has finished, and these are what's being sent |
| A word the server replaces | Keeps its opacity and index, removed words go at once | As the mock does; only an appended word fades in |
| Panel type and padding | `textMd` 16/24, padding 12/8, `shadows.lg`, composer's surface | Tokens closest to the mock's 15 px, padding 13/10 |
| Focus width | The composer's rect, inset 8 | The composer's 760 cap is the reading width D27 asks for |
| Screen readers | The layer is excluded from semantics | It would talk over the user's own dictation. The words reach it in the box or the bubble |
| Reduced motion | Word fades, the rise and all travel go; the layer's own fade stays | No movement, and no hard cut of a whole screen's dim |
| "Finishing..." | Kept | The words now show above it, and it still says why the pill stopped listening |

## Where the plan needed more

- **A rect ending at the composer's top covers the release hint**, which lives above the body. The
  layer draws its own copy of the hint at the exact same place, in the same column as the words,
  so they reserve its height without measuring. The panel keeps the slot empty, and the
  composer's own hint shows through.
- **A rect ending at the composer's top leaves chat showing beside it on desktop**: the transcript
  is 960 wide, the composer 760. The dim instead covers the whole pane with one hole, from the
  body down to the pane's bottom, where the composer's halo already hides the chat.
- **The pane on a touch shell depends on a wrapper.** The layer measures the nearest `Scaffold`, which
  on a touch shell is the one `prego_glass_scaffold.dart` wraps every page in. That wrapper is marked
  for removal once `liquid_glass_widgets` migrates. Removing it makes the dim cover the sidebar on a
  wide touch layout, so `_paneRect` needs revisiting then.
- **`_composerBodyKey` stays, and step 9 doesn't read it.** Nothing reads it, but it keeps the input and its
  focus when Remove animations changes the tree around it, and a test pins that.

## Known limits, accepted

- A very long dictation lays its text out once per update, measuring included. No slowdown showed
  in the fixture run of about 100 words; the real server's rate and much longer text weren't tried.
- A portal left open under a pushed route can assert on a window resize (flutter/flutter#192030).
  The portal closes when the exit ends, so this takes a route pushed mid-dictation and a resize.

## Verification

Toolchain: Flutter 3.47.8.

| Command | Result |
| --- | --- |
| `module_app_ui`: `flutter test --no-pub` | +1117 passed, 27 of them in `prompt_input_live_words_test.dart` |
| `module_app_ui`: `dart analyze --fatal-infos` | No issues |

`app`, `desktop` and `module_core` have no changed files and were not run.

Mutations, each failing a test: cancel drop 0; cancel treated as a plain leave; a send dropping too;
rect not frozen while leaving; panel opening with no words; focus waiting for words; words rebuilding
the composer; a finish not restoring the slide's fade; the layer taking touches; semantics exposed;
release keeping words tentative; rise snapping; no hole in the dim; dim covering the overlay rather
than the pane; no pointer size; hint baseline off; hint staying after the release; hint showing on the
panel; a fallback staying; six panel lines; new word instant; brightening instant; tentative opacity;
slide fade size; layer never hiding; portal never closing; panel not rising; words top-anchored;
reduced motion travelling; reduced motion fading; replaced word fading again; a voice-less composer
getting the layer.

One survived: `_presence.isDismissed` in `_leave`, for a panel that never opened, and was removed. Review
then named the flow that needs it: a second hold during the first card's fade, ended with no words, left
the portal open. It came back with a test. The top fade's gradient has no test, since a shader can't be read back; it was checked by
eye.

## Feel, on a simulator

Two scratch harness runs, kept out of the commit, on headless simulators created for this and deleted
after: an iPhone 17 with the touch shell, and an iPad Pro 11 with the pointer shell in a sidebar and
pane. Fixture words at 150 ms each with the mock's replaced word, real holds and slides through
synthesized pointer events, light and dark. Debug builds.

- Words and the wrap: a new line comes up from under the clip over about 200 ms and the lines above
  rise with it. Frame by frame from the recording, nothing snaps.
- Long text: the focus words rise well above the chat's halfway point and stay readable. The panel
  holds at five lines with the oldest fading at its top.
- Red slide-out: pill reddens, hint turns red, words dim to 40% in place. With the card solid the panel
  stays readable. The first run had the fade on the whole card, which looked wrong, and was changed.
- Exits: a cancel fades and drops over about 240 ms as the chat returns; a send fades in place.
- Pointer shell: only the chat pane dims, the sidebar stays clear, and the gutters beside the composer
  dim with no seam against its column.

## Not checked

- **No live session and no real microphone.** All the words were fixtures.
- **No real device, no Android, and no macOS, Windows or Linux desktop.** The pointer shell ran on an
  iPad. A debug simulator can't judge smoothness; the frame timing here shows shape, not jank.
- The harness used a stand-in chat, not the session screen. The hole against a real transcript passing
  behind the composer wasn't seen, nor a keyboard up in text-first, RTL, or a large text scale.
- How the real words pace, including a burst after a late `ready`.

## For step 12

Add to the list in `step-07.md`:

1. Dictate a long message on an iPhone and an Android device, with focus and with panel. Watch the
   wrap, and check that a real server's rate stays calm.
2. On a desktop build, check the dim's hole against a real transcript, including a window wider than
   the transcript.
3. Dictate for several minutes in focus and watch for slowdown from laying out the whole text.
