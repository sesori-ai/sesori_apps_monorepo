import { createServer } from 'node:http';
import { createInterface } from 'node:readline';

export const formSchema = {
  type: 'object',
  required: ['approved', 'count', 'plan'],
  properties: {
    approved: { type: 'boolean', title: 'Approve fixture' },
    count: { type: 'integer', minimum: 1, maximum: 3 },
    plan: { type: 'string', oneOf: [{ const: 'basic', title: 'Basic plan' }, { const: 'pro', title: 'Pro plan' }] },
    tags: { type: 'array', minItems: 1, maxItems: 2, items: { type: 'string', enum: ['a', 'b'] } },
    note: { type: 'string', minLength: 1, maxLength: 20 },
  },
};

const tools = ['echo', 'form', 'url'].map(name => ({
  name, description: `Harmless ${name} contract fixture`,
  inputSchema: { type: 'object', properties: {} },
}));

// This fixture never reads the host environment, launches tools, or contacts a provider.
function createMcpPeer(send, { elicitations = true } = {}) {
  const pending = new Map();
  let nextId = 1000;
  return async frame => {
    if (frame.method === undefined) {
      const complete = pending.get(frame.id);
      pending.delete(frame.id);
      complete?.(frame);
      return;
    }
    if (frame.id === undefined) return;
    const reply = result => send({ jsonrpc: '2.0', id: frame.id, result });
    switch (frame.method) {
      case 'initialize':
        reply({ protocolVersion: frame.params.protocolVersion, capabilities: { tools: {} },
          serverInfo: { name: 'sesori-contract-fixture', version: '1.0.0', title: 'Sesori MCP fixture' } });
        break;
      case 'ping': reply({}); break;
      case 'tools/list': reply({ tools: elicitations ? tools : tools.filter(tool => tool.name === 'echo') }); break;
      case 'resources/list': reply({ resources: [] }); break;
      case 'resources/templates/list': reply({ resourceTemplates: [] }); break;
      case 'prompts/list': reply({ prompts: [] }); break;
      case 'tools/call': {
        if (!elicitations && frame.params.name !== 'echo') {
          send({ jsonrpc: '2.0', id: frame.id, error: { code: -32601, message: 'Fixture tool unavailable' } });
          break;
        }
        let value = { fixture: 'echo' };
        if (frame.params.name !== 'echo') {
          const id = nextId++;
          const result = new Promise(resolve => pending.set(id, resolve));
          send({ jsonrpc: '2.0', id, method: 'elicitation/create', params: frame.params.name === 'form'
            ? { mode: 'form', message: 'Complete the fixture form', requestedSchema: formSchema }
            : { mode: 'url', message: 'Open the fixture setup', url: 'https://fixture.example/setup',
              elicitationId: 'fixture-url' } });
          value = await result;
        }
        reply({ content: [{ type: 'text', text: JSON.stringify(value) }] });
        break;
      }
      default: send({ jsonrpc: '2.0', id: frame.id, error: { code: -32601, message: 'Fixture method unavailable' } });
    }
  };
}

export async function startHttpFixture({ oauth = false } = {}) {
  let origin;
  const server = createServer(async (req, res) => {
    const url = new URL(req.url, origin);
    if (oauth && url.pathname.startsWith('/.well-known/')) {
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify(url.pathname.includes('oauth-protected-resource')
        ? { resource: `${origin}/mcp`, authorization_servers: [origin] }
        : { issuer: origin, authorization_endpoint: `${origin}/authorize`, token_endpoint: `${origin}/token`,
          registration_endpoint: `${origin}/register`, response_types_supported: ['code'],
          grant_types_supported: ['authorization_code', 'refresh_token'], code_challenge_methods_supported: ['S256'],
          token_endpoint_auth_methods_supported: ['none'] }));
      return;
    }
    if (oauth && url.pathname === '/register') {
      let body = ''; for await (const chunk of req) body += chunk;
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ ...JSON.parse(body), client_id: 'fixture-client', client_id_issued_at: 0 }));
      return;
    }
    if (oauth && url.pathname === '/token') {
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify({ access_token: 'fixture-access', token_type: 'Bearer', expires_in: 3600,
        refresh_token: 'fixture-refresh' }));
      return;
    }
    if (url.pathname !== '/mcp') { res.writeHead(404).end(); return; }
    if (oauth && req.headers.authorization !== 'Bearer fixture-access') {
      res.setHeader('WWW-Authenticate', `Bearer resource_metadata="${origin}/.well-known/oauth-protected-resource"`);
      res.writeHead(401).end(); return;
    }
    if (req.method === 'DELETE') { res.writeHead(200).end(); return; }
    if (req.method === 'GET') { res.writeHead(405).end(); return; }
    let body = ''; for await (const chunk of req) body += chunk;
    const frame = JSON.parse(body);
    if (frame.id === undefined && frame.method) { res.writeHead(202).end(); return; }
    const session = req.headers['mcp-session-id'] ?? 'fixture-session';
    res.setHeader('mcp-session-id', session);
    res.setHeader('Content-Type', 'application/json');
    const receive = createMcpPeer(result => res.end(JSON.stringify(result)), { elicitations: false });
    await receive(frame);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  origin = `http://127.0.0.1:${server.address().port}`;
  return { origin, close: () => new Promise(resolve => server.close(resolve)) };
}

// Deterministic local Anthropic protocol fixture. No model or provider account is used.
export async function startModelFixture() {
  let tool = 'echo';
  let issued = false;
  const server = createServer(async (req, res) => {
    let body = ''; for await (const chunk of req) body += chunk;
    if (!body) { res.writeHead(404).end(); return; }
    const request = JSON.parse(body);
    if (req.url.includes('count_tokens')) {
      res.setHeader('Content-Type', 'application/json'); res.end('{"input_tokens":1}'); return;
    }
    const complete = issued;
    const name = request.tools?.find(candidate => candidate.name === `mcp__stdio_fixture__${tool}`)?.name;
    if (!complete && !name) { res.writeHead(400).end('Fixture tool absent'); return; }
    issued = true;
    res.setHeader('Content-Type', 'text/event-stream');
    const emit = (type, data) => res.write(`event: ${type}\ndata: ${JSON.stringify({ type, ...data })}\n\n`);
    emit('message_start', { message: { id: 'msg_fixture', type: 'message', role: 'assistant',
      content: [], model: 'fixture-model', stop_reason: null, stop_sequence: null,
      usage: { input_tokens: 1, output_tokens: 0 } } });
    emit('content_block_start', { index: 0, content_block: complete
      ? { type: 'text', text: '' } : { type: 'tool_use', id: 'tool_fixture', name, input: {} } });
    emit('content_block_delta', { index: 0, delta: complete
      ? { type: 'text_delta', text: 'Fixture complete' } : { type: 'input_json_delta', partial_json: '{}' } });
    emit('content_block_stop', { index: 0 });
    emit('message_delta', { delta: { stop_reason: complete ? 'end_turn' : 'tool_use', stop_sequence: null },
      usage: { output_tokens: 1 } });
    emit('message_stop', {});
    res.end();
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  return { origin: `http://127.0.0.1:${server.address().port}`, select: name => { tool = name; issued = false; },
    close: () => new Promise(resolve => server.close(resolve)) };
}

if (process.argv.includes('--stdio')) {
  const receive = createMcpPeer(frame => process.stdout.write(`${JSON.stringify(frame)}\n`));
  createInterface({ input: process.stdin }).on('line', line => { void receive(JSON.parse(line)); });
}
