# Step 10 — Glide live words to the bubble or box

Two PRs, step 10.i and 10.ii, about 1,920 changed lines including this doc, over the soft cap, so split
where the seam is clean: 385 for the landing, its hosts and their tests, which does nothing until something
expects a send, and about 1,535 for the glide. About 70 of the first and 65 of the second are re-indents
around new wrappers. No generated files.

## Built

- `widgets/sent_bubble_landing.dart`: `SentBubbleLanding` with its controller, one per screen,
  above both the composer and the list; `SentBubbleSlot` around a user bubble's surface;
  `SentBubbleArrival`, which says whether the bubbles under it can be the one being sent;
  `RenderLandingSlot`, a proxy that hides what it wraps by skipping its paint, and says where it is.
- `widgets/composer_live_words.dart`: the `_Gliding` layer, with a sealed `_Destination` (undecided,
  bubble, box, estimate, in place); `ComposerWordsBox` and `ComposerWordsBoxSlot` around the field.
- `PromptInput` calls `expect()` just before `onSend` on a dictated send, and wraps its field in the
  box slot.
- Session detail and new session wrap their content in the landing. The message list marks new rows
  as arriving, and the launch view marks its bubble as arriving.

Cancel, D20, D32 and D33 are as they were. A dictation with nothing on screen to glide (one that ran
after recording, or an empty one) and reduced motion fade where they stand, dim and all.

## Choices the plan left open

| Choice | Decision | Why |
| --- | --- | --- |
| Where `expect()` is | Inside `_submitComposer`, right before `onSend`, not before `_submitComposer` | A send it refuses then expects nothing |
| Who settles an `expect()` nothing can use | `_land`, which runs after the composer handles the same state | It's the one place that knows there's nothing to glide. An unsettled one would hide the next bubble built |
| Who reports the rect | The bubble's slot claims the landing as it attaches, and the layer reads its rect every frame; the plan has the list reporting it | The list would need the bubble's offset from its row. A row re-building, or moving under the words, needs no new call this way |
| Words during the wait | Stay still up to two frames, then start, rather than start and retarget | Nothing moves until the destination is known, so no glide changes course on its first frames |
| The handover | The bubble shows at the end of the 340 ms flight, and the words fade over it for 90 ms more | The plan's spec has no fade here. A plain paragraph can't match a bubble in every case (images, Markdown); this softens what differs, and with plain text nothing shows |
| Tentative words on the way | They carry on brightening from wherever they were, on the glide's clock, with the normal 280 ms fade | A cut-off lands straight from `LiveRecording`, with no release to brighten them, and a quick finish lands mid-fade. Both would otherwise go bright at once |
| Hiding the bubble | A render-level paint skip, not `Opacity` or a rebuild | Nothing rebuilds or moves when the words arrive |
| Telling a new bubble from an old | `SentBubbleArrival` per list row, as rows not yet known | Scrolling back down after a send also builds rows |
| Marker and box text | They grow in beside the words until the rewrap, then fade in at full size | Keeps the words from shifting on the glide's first frame |
| Destination going away mid-glide | The words finish at the last rect they knew | Nothing to retarget to, and stopping short would look worse |
| Owner going mid-glide | The layer goes and releases the bubble | The launch view swapping for the session is the flow. Its bubble can't stay hidden |

## Where the plan needed more

- **A lerped font weight stays on the heavier face until the last frame.** Flutter 3.47's
  `FontWeight.lerp` gives numeric weights and the static faces match upward, so the words stayed
  medium, 2% wider than the bubble's regular, until t > .995, and popped narrower as they landed.
  A lerped font size also wrapped them to three lines right up to the end, then two. The first
  simulator run showed both as a one-frame spike at the handover. Now the face and the wrap change
  once, at t = .5, while the words move fastest (about 45 ms in), and from there the final paragraph
  only scales, so it can't wrap again.
- **`BoxDecoration.lerp` shrinks a shadow with nothing to lerp to, at full strength.** The panel's
  `shadows.lg` showed as a hard gray plate under the clearing surface on an edit. The shadow now fades
  where it is.
- **"A prompt shows at once" made the panel send jump.** The list's rule jumped the chat up in one
  frame beside the gliding panel, where the agreed mock's `landSend` slides it up by the bubble's
  height. The expected prompt's row now enters with the transcript's own fold, so the list rises as the
  words come down. Typed sends keep the old rule. This is the one movement besides the glide, and it's
  the mock's.
- **An echo swaps the row's bubble mid-glide.** The queued bubble's slot detaches before the
  message's attaches, in the same frame. `_Lost` keeps the words' place, and the new slot takes over
  if it shows the same text.
- **The layer lays out ahead of the list**, as a deferred overlay child, so a row's rect is one frame
  old while it moves. The words catch up as the row stops. Accepted: a 16 ms lag on a settling rise
  doesn't show, and a test pins that they end exactly on the row.
- **The estimate needs a measurement**: the bubble's own width isn't known with no bubble. It lays
  the words out at the bubble's text style and max width, and sits 52 pt above the composer's body,
  past the selectors.

## Known limits, accepted

- The words' line ends clip at the rect's right edge just after the rewrap, for about 100 ms and
  shrinking, as the final paragraph at 1.3 times its size is wider than the rect. Seen frame by frame
  in slow motion on focus sends and edits. In real time they read as the text settling.
- The estimate's ghost passes over the last chat text while it fades: nothing relays out for it, so
  it overlaps what's there.
- Attachments and a queued bubble's outline differ from the glide's surface, softened only by the
  hand-over fade.

## Verification

Toolchain: Flutter 3.47.8. The first commit alone also passes: `module_app_ui` +1121, both screens' `app`
test files +287, and both analyzers.

| Command | Result |
| --- | --- |
| `module_app_ui`: `flutter test --no-pub` | +1144 passed, 23 of them in `composer_live_words_glide_test.dart` |
| `module_app_ui`: `dart analyze --fatal-infos` | No issues |
| `app`: `flutter test --no-pub` | +861 passed |
| `app`: `dart analyze --fatal-infos` | No issues |
| `desktop`: `flutter test --no-pub` | +382 passed |
| `desktop`: `dart analyze --fatal-infos` | No issues |

Mutations, each failing a test: `expect()` removed; slot never hiding; two frames made one, and made
four; no release on the owner going; reduced motion travelling; no hand-over at the flight's end; hand-over
from the start; arriving gate ignored; every list row arriving; `_Lost` takeover removed; composer
rebuilding per tick; box hold removed; `_land` not settling an `expect()`; the estimate keeping the
bubble hidden; tentative words starting bright, and never brightening; a late rewrap, and none at all; a plain shadow lerp; the list's rise removed; session
body and new session without a landing; launch bubble not arriving; bubble with no slot; another hold
not ending the glide; a glide not following its target.

Two survived the first round and got stronger tests: the slot not hiding (the tests read the flag, and
now check that it paints nothing) and two frames made one (a controller's first tick has no time on it).

`architecture-implementation-review`, one pass, rejected on two findings, both applied and not reviewed
again: a landing nullable only for tests is now a non-null `of`, with the test fixtures wrapped, and
`_glideTarget` is now a non-null `target` on `_Gliding`. It found `SentBubbleLanding`'s ownership and
class surface sound.

## Feel, on a simulator

Two scratch harness runs, kept out of the commit, on a headless iPhone 17 created for this and deleted
after, using the real `SessionDetailMessageList`, `PromptInput` and `SessionLaunchSubmissionView` under a
fake voice cubit. Fixture words, real holds and slides through synthesized pointer events, light and
dark, real time and at a sixth of the speed. Debug builds. Run 1 found the three problems above; the
rest is run 2.

- Send, focus: the dim lifts, the words shrink onto the row as it rises, the marker fades in. At the
  handover the last glide frames and the first bubble frames are the same image. A per-frame difference
  over the bubble's crop declines smoothly to 0, with the 18-level spike from run 1 gone.
- Edit, focus and panel: the words land on the field's text in place, with its caret margin, and
  the box comes up around them. No plate on the panel.
- Send, panel: the panel turns into the bubble on the way down and the list rises with it, with no
  jump.
- Fast echo: the row's swap mid-glide doesn't show.
- No row: the words wait, glide right-aligned above the composer and fade. They overlap the chat as
  they go.
- New session: the words land on the launch view's bubble. With the owner gone they just go.
- Reduced motion: no travel; the words fade where they stand over the bubble, with the dim's fade kept.
- "Sending" becoming "Sending to OpenCode..." moves nothing above it.

## Not checked

- **No live session and no real microphone.** All the words were fixtures.
- **No real device, no Android, and no desktop or pointer shell.** A debug simulator can't judge
  smoothness.
- The new session scene was a stand-in for the screen around the real launch view, not `NewSessionView`,
  and its owner going swapped to a screen with no bubble. Both screens' wiring is pinned by widget tests.
- A real session's scroll-to-bottom during the rise, a keyboard up in text-first, RTL, and a large
  text scale.

## For step 12

Add to the list in `step-07.md`:

1. On an iPhone and an Android device, send and edit with focus and with panel, at real speed. Watch
   the handover, and the line ends right after the rewrap.
2. Send from a real session with a long transcript while at its end, and while scrolled away. Watch
   the list's rise and the fallback.
3. Send from a new session and follow the words through the launch view into the session.
4. On a desktop build, send and edit with the pointer shell. The 25 pt focus text has not been seen
   gliding.
