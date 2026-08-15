// Hermes Agent backend for the Sesori bridge.
//
// Drives `hermes acp` over the generic ACP machinery (acp_plugin). Hermes is
// a stock ACP v1 server (protocol version 1), so the plugin core is policy
// only, with no harness-specific protocol extensions.
export "src/hermes_binary.dart";
