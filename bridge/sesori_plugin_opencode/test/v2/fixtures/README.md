# OpenCode v2 mapper fixtures

`native_2_0_16.json` contains selected REST responses from the official macOS ARM64
OpenCode 2.0.16 CLI, captured on 2026-09-25. The npm archive matched its published
SHA-512 integrity and carried Anomaly Innovations' Developer ID signature.

Capture used `serve --hostname 127.0.0.1 --port 0`, a fresh profile and nested Git
fixture project, dummy Basic authentication, and OpenCode network simulation.
A deny-default macOS sandbox allowed only the fixture state, executable/system
runtime resources, and inbound loopback requests. User-approved narrow additions
allowed OS timezone data, notification shared memory, and exact ancestor-directory
entries; real profiles, unrelated source contents and external networking remained
blocked. The owned process was terminated and reaped.

Responses came from `/api/location`, `/api/project`, `/api/session/{id}`,
`/api/agent`, `/api/provider`, and `/api/model`. The session was created through
`POST /api/session`. Paths and generated IDs are normalized to fixture values;
model settings are omitted so provider credential material is not retained.

These fixtures prove native REST shapes, not authenticated model execution.
Transcript, tool-state, form and forward-compatibility cases in mapper tests are
source-derived fixtures for the pinned 2.0.16 schema, not captured native turns.
