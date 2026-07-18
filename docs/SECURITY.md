# Security

Sesori is designed around the idea that your source code, prompts, and AI responses should stay under your control. This page describes how we keep the data path private and what the relay can and cannot see.

## End-to-end encryption

All application data between your phone and the Bridge is encrypted with **XChaCha20-Poly1305**. The relay routes ciphertext but cannot read user content.

## Ephemeral key exchange

Each phone-to-Bridge connection uses an **X25519 Diffie-Hellman** key exchange. The derived secret protects delivery of a per-session room key, and the ephemeral keys are discarded afterward. The room key itself is persisted on the phone so reconnects can resume without renegotiating, but a `rekey_required` signal can force a fresh exchange at any time.

## Local protection

The Bridge protects its localhost connection to the AI assistant with a random 256-bit password. That password is generated locally and is never transmitted over the network.

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

## Account deletion

You can delete your account from the Sesori mobile app. Because we do not store message history, deletion removes account and routing metadata only. You can also email [hello@sesori.com](mailto:hello@sesori.com) for assistance.

## Reporting issues

If you discover a security issue, please email [hello@sesori.com](mailto:hello@sesori.com) before opening a public issue. We will respond as quickly as we can and coordinate a responsible disclosure.

## Work laptop note

If you want to use Sesori on a work laptop, check with your security team first. Some organizations restrict outbound relay connections, even though the relay cannot read your data.
