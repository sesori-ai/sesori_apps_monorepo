# MCP Management

## Capability

Backend-neutral inventory contracts describe configured servers and offered
connectors. The optional plugin read interface and shared wire models are
implemented; native adapters, bridge routes, client views, and management
actions are not yet exposed. Existing permission flows remain separate.

## Required Behavior

- Harness, project, and session scopes are explicit variants. Plugin scope IDs
  are native bindings; shared scope IDs belong to the bridge catalog.
- A configured server and an offered connector have distinct target types,
  including when their opaque keys happen to match.
- Server connection, authorization, configuration origin, and tool discovery
  are separate values. Authentication alone grants no tool permission.
- Unavailable or failed discovery is distinct from a successfully discovered
  empty tool catalog. Connector-catalog unavailability leaves server inventory
  readable; an offer has no invented server status or tool list.
- Wire metadata contains no native commands, arguments, environment, headers,
  credentials, or full endpoint URL. An endpoint origin is presentation metadata.
- An inventory read does not launch or resume an agent, authenticate a server,
  execute a tool, or write configuration. The optional API declares this contract;
  each supporting adapter must prove it when its implementation lands.

## Regression Levels

| Level | Additional coverage |
|---|---|
| L1 Smoke | Not included. |
| L2 Routine | Automated, no plugin: shared codec round trips preserve distinct targets, empty/unavailable/failed tool states, authorization without grants, and partial catalog availability. |
| L3 Release | No additional coverage. |
| L4 Extended | No additional coverage. |
| L5 Full | No additional coverage. |

## Exploration Guidance

Vary scopes, equal server/offer keys, missing nullable metadata, and discovery
states. Verify the decoded type as well as the serialized discriminator. Add
live-plugin and route coverage with the first supporting adapter.

## Failure Signals

- A connector offer becomes a server target or gains server-only state.
- Discovery failure becomes an empty catalog, or an unavailable connector
  catalog hides otherwise readable servers.
- Authorization implies a permission grant or native configuration enters a
  shared inventory payload.

## Evidence

The owning automated coverage is `shared/sesori_shared/test/models/mcp_test.dart`.
Pinned native protocol evidence is recorded in
[HARNESS_CAPABILITIES.md](../HARNESS_CAPABILITIES.md); it does not qualify a
Sesori management flow before an adapter and route are implemented.
