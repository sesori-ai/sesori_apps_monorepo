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
completion. It rejects versions outside the declared minimum/target pins before
opening fixture servers. Claude additionally checks wrong-state rejection with
no token exchange before a fresh valid login. Both harnesses use allow-listed child environments and explicit
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

Focused tooling tests: `node --test tool/mcp-contracts/*.test.mjs`, which Release
Workflow CI runs. HTTP fixtures advertise only the echo tool; form/URL elicitation is
exercised through stdio.

Versioned results and the remaining qualification boundaries are in
[the contract evidence](../../.plan/completed/mcp-management/evidence/native-contracts.md).

Codex App Server intentionally omits the JSON-RPC version marker on JSONL
requests, responses, and notifications, as described in the
[official protocol explanation](https://openai.com/index/unlocking-the-codex-harness/).
The driver follows that framing; fixture MCP servers use their own MCP framing.
