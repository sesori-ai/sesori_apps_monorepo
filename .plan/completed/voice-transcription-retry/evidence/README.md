# Simulator UI Evidence

These privacy-safe crops preserve the composer states from the user-approved iPhone 17 simulator matrix on 2026-08-28.
They contain only synthetic test content and omit unrelated session output from the full-screen captures.

| File | Journey |
|---|---|
| [`pending-voice-first.png`](pending-voice-first.png) | Voice-first failure retains the recording and exposes Retry/Discard. |
| [`success-voice-first.png`](success-voice-first.png) | Voice-first Retry succeeds without another recording. |
| [`pending-text-first.png`](pending-text-first.png) | Text-first failure retains both the draft and recording. |
| [`cancel-retained.png`](cancel-retained.png) | Cancelling a hanging manual Retry returns to the retained state. |
| [`success-text-first.png`](success-text-first.png) | Text-first Retry appends the transcription while preserving the draft. |

`pending-text-first.png` and `cancel-retained.png` intentionally show the same final pixels: cancellation must return to the
same retained composer state rather than deleting the artifact or changing the draft.
