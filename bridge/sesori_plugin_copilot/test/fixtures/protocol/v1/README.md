# GitHub Copilot CLI ACP v1 fixture source

Validated on 2026-08-31 against the official macOS arm64 artifact:

- Version: `1.0.80`
- URL: <https://github.com/github/copilot-cli/releases/download/v1.0.80/copilot-darwin-arm64.tar.gz>
- SHA-256: `2346bb691981c2997d65c1c5bc3cef1aeddc9edd37dcb2f970b911aa597e59f6`
- Launch: `copilot --no-auto-update --acp`

An isolated initialize negotiated ACP v1 and advertised HTTP and SSE MCP transports. The fixture retains only the
capability schema and redacted authentication metadata; it contains no credentials, account data, prompts, or local
paths.
