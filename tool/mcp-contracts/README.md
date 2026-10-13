# MCP native contract probes

Run these only against explicit native executables. They create temporary harness
configuration and fixture servers; they never query the developer's MCP inventory.
The commands use no paid model or real provider account. Node's built-in HTTP and
stdio implementations provide MCP, OAuth, and deterministic model responses.

```sh
node tool/mcp-contracts/probe.mjs claude /absolute/path/to/claude /tmp/claude-capture.json
node tool/mcp-contracts/probe.mjs codex /absolute/path/to/codex /tmp/codex-capture.json
```

The probe asserts inventory, pagination where applicable, native failure replies,
typed form round trips, URL decline/unsupported behavior, and fixture OAuth
completion. Both harnesses use allow-listed child environments and explicit
temporary configuration. Claude runs in manual permission mode with a strict
fixture MCP list. Its terminal probe requires POSIX Python 3; the fixture helper
is tooling, not a production dependency. Closing the helper reaps its native
login subprocess.

The local HTTP authorization issuer exists only for native protocol tests. It is
not an exception to the production HTTPS browser-launch policy. The probe sends
only its fixture callback to a native loopback listener and checks both origins
before doing so. It never opens a browser. Native fixture credentials may remain
in the temporary harness configuration. Captures contain fixture authorization
URLs and should stay local; publish the bounded evidence summary instead.

After `dart pub get` in `shared/sesori_shared`, run:

```sh
node tool/mcp-contracts/released-peer.mjs /absolute/path/to/dart
```

This executes the public v1.9.0/build 970 SSE parsing methods directly from Git,
with fixture transport/log sinks. It first checks that the six question/SSE
model and generated codec files are byte-identical to that release, then tests
unknown typed events, additive notice fields, both event orders, legacy
completion/cancellation, and snapshot decoding. It fails on decoder drift rather
than silently testing a current decoder as an older peer. Native mixed-client
ownership and competing-reply tests belong with the production pending owner.

Versioned results and the remaining qualification boundaries are in
[the contract evidence](../../.plan/active/mcp-management/evidence/native-contracts.md).
