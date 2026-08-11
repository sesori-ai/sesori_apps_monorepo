# Security

Sesori is designed around the idea that your source code, prompts, and AI responses should stay under your control. This page describes how we keep the data path private and what the relay can and cannot see.

## End-to-end encryption

All application data between your phone and the Bridge is encrypted with **XChaCha20-Poly1305**. The relay sees only opaque binary frames for application data and cannot decrypt them. The X25519 public keys used for the initial key exchange are delivered through the relay unauthenticated, so the design treats the relay as a trusted routing and key-delivery endpoint. A compromised relay could replace both public keys and mount a man-in-the-middle attack; we do not harden against a malicious relay.

## Ephemeral key exchange

Each phone-to-Bridge connection uses an **X25519 Diffie-Hellman** key exchange. The derived secret protects delivery of a per-session room key, and the ephemeral keys are discarded afterward. The room key itself is persisted on the phone so reconnects can resume without renegotiating, but a `rekey_required` signal can force a fresh exchange at any time.

## Local protection

By default, the Bridge protects its localhost connection to the AI assistant with a locally generated random 256-bit password. In the default loopback configuration, that password is injected into local HTTP requests and is not sent over the network.

You can change this behavior:

- `--opencode-password <value>` replaces the generated password with your own.
- `--opencode-no-password` disables authentication entirely (allowed only on loopback in managed mode).

If you configure a non-loopback `--opencode-host`, the password crosses the network as Basic auth headers, and `--opencode-no-password` is rejected in managed mode because it would expose an unauthenticated server.

## What the relay sees

The relay is a stateless WebSocket router. It sees:

- Connection metadata required to route frames (auth tokens, public keys, device identifiers).
- Opaque binary frames whose contents it cannot decrypt.

It does **not** see:

- Your source code.
- Your prompts or AI responses.
- Session contents, diffs, or commits.
- The room key or derived secrets.

## What Sesori stores

Sesori retains the minimum account-level data needed to make the service work while your account is active: your sign-in identity, a small amount of routing metadata, and push notification tokens. We do not store your code, prompts, or AI responses.

## Push notifications

If you enable push notifications, our backend builds a notification payload that may contain a short preview of the event (for example, a question summary or the latest assistant message). That payload is sent to Apple or Google push services, so it leaves the end-to-end encrypted channel between your phone and the Bridge. The full code, prompts, and responses stay on your machine; only the preview needed for the notification travels through the push provider.

## Account deletion

You can delete your account from the Sesori mobile app. Because we do not store message history, deletion removes account and routing metadata only. You can also email [hello@sesori.com](mailto:hello@sesori.com) for assistance.

## Reporting issues

If you discover a security issue, please email [hello@sesori.com](mailto:hello@sesori.com) before opening a public issue. We will respond as quickly as we can and coordinate a responsible disclosure.

## Work laptop note

If you want to use Sesori on a work laptop, check with your security team first. Some organizations restrict outbound relay connections, even though the relay cannot read your data.
