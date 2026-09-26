# Feedback preview (PR #1361) — UX review

iPhone 17 simulator, iOS 27, Flutter 3.47.5. Captured 2026-09-26.

## 1 · Entry sheet

**Dark**

<img src="01-rating-dark.png" width="300">

**Light.** Open question: “Could be better” is white on white with only a faint outline.

<img src="08-rating-light.png" width="300">

## 2 · “Yes, love it!” → celebration → native review prompt

**Dark:** the button turns pink, hearts animate, the sheet closes, then the App Store prompt appears.

<img src="02-yes-celebration-dark.gif" width="300">

**Light:** the button goes from its dark fill to pink and back before the sheet closes.

<img src="09-yes-celebration-light.gif" width="300">

**Apple’s real StoreKit prompt** (debug-only hook)

<img src="03-native-review.png" width="300">

In the light run, the prompt appeared about 2 s after the tap. In the dark run, the first StoreKit call took about 3 s longer.

## 3 · “Could be better” → private feedback

**Full flow:** chips → hold to talk → transcript → send → toast

<img src="04-private-feedback-dark.gif" width="300">

**Issue chips selected**

<img src="05-private-chips-dark.png" width="300">

**After the simulated voice transcript**

<img src="06-transcribed-dark.png" width="300">

**Confirmation toast**

<img src="07-submitted-toast-dark.png" width="300">

**Keyboard mode (light), with focus ring**

<img src="10-keyboard-light.png" width="300">
