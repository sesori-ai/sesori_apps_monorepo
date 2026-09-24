import { createAssistantMessageEventStream } from "@earendil-works/pi-ai";

// Synthetic RPC fixture: no credentials, network calls or model usage.
export default function (pi: any) {
  let calls = 0;
  pi.registerProvider("openai-codex", {
    baseUrl: "http://127.0.0.1:1",
    apiKey: "synthetic-no-network",
    api: "quota-probe",
    models: [{
      id: "quota-probe", name: "Quota fixture", reasoning: false,
      input: ["text"], contextWindow: 200000, maxTokens: 100,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    }],
    streamSimple: (model: any) => {
      const stream = createAssistantMessageEventStream();
      // Native client QA waits one minute plus the bridge's two-minute buffer,
      // then accepts Continue in the same resident session without model usage.
      const mode = process.env.QUOTA_PROBE_MODE;
      const continuation = mode === "continuation";
      const recovered = ++calls > 1 && (continuation || mode === "recover");
      const errorMessage = mode === "unknown"
        ? "You have hit your ChatGPT usage limit (pro plan)."
        : continuation || mode === "terminal"
        ? `You have hit your ChatGPT usage limit (pro plan). Try again in ~${continuation ? 1 : 5918} min.`
        : "429 Too many requests";
      const output: any = {
        role: "assistant",
        content: recovered ? [{ type: "text", text: "fixture recovery" }] : [],
        api: model.api, provider: model.provider, model: model.id,
        timestamp: Date.now(),
        usage: {
          input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
        },
        stopReason: recovered ? "stop" : "error",
        ...(!recovered ? { errorMessage } : {}),
      };
      queueMicrotask(() => {
        stream.push(recovered
          ? { type: "done", reason: "stop", message: output }
          : { type: "error", reason: "error", error: output });
        stream.end();
      });
      return stream;
    },
  });
}
