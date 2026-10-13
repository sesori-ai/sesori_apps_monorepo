import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { EventEmitter } from 'node:events';
import { mkdtemp, mkdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

import { formSchema, startHttpFixture, startModelFixture } from './fixture.mjs';

const fixturePath = fileURLToPath(new URL('./fixture.mjs', import.meta.url));
const terminalPath = fileURLToPath(new URL('./terminal.py', import.meta.url));

class Peer {
  frames = [];
  pending = new Map();
  nextId = 1;
  received = new EventEmitter();
  constructor(binary, args, options, protocol) {
    this.protocol = protocol;
    this.child = spawn(binary, args, { ...options, stdio: ['pipe', 'pipe', 'pipe'] });
    this.stderr = '';
    this.child.stderr.on('data', chunk => { this.stderr += chunk; });
    createInterface({ input: this.child.stdout }).on('line', line => {
      let frame; try { frame = JSON.parse(line); } catch { return; }
      this.frames.push(frame);
      this.received.emit('frame', frame);
      const id = protocol === 'claude' ? frame.response?.request_id : frame.id;
      const pending = this.pending.get(id);
      if (pending && (protocol === 'claude' ? frame.type === 'control_response' : !frame.method)) {
        this.pending.delete(id); pending.resolve(frame);
      } else if (frame.method || frame.type === 'control_request') this.onRequest?.(frame);
    });
    this.child.on('error', error => this.fail(error));
    this.child.on('exit', (code, signal) => this.fail(new Error(`Native process exited: ${code}/${signal}`)));
  }
  fail(error) { for (const p of this.pending.values()) p.reject(error); this.pending.clear(); }
  send(frame) { this.child.stdin.write(`${JSON.stringify(frame)}\n`); }
  async waitFor(predicate) {
    return await new Promise((resolve, reject) => {
      const listener = frame => { if (predicate(frame)) { cleanup(); resolve(frame); } };
      const timer = setTimeout(() => { cleanup(); reject(new Error('Timed out waiting for native frame')); }, 20000);
      const cleanup = () => { clearTimeout(timer); this.received.off('frame', listener); };
      this.received.on('frame', listener);
    });
  }
  async request(method, params) {
    const id = this.protocol === 'claude' ? `probe-${this.nextId++}` : this.nextId++;
    let timer;
    try {
      return await new Promise((resolve, reject) => {
        this.pending.set(id, { resolve, reject });
        timer = setTimeout(() => { this.pending.delete(id); reject(new Error(`Timed out: ${method}`)); }, 20000);
        this.send(this.protocol === 'claude'
          ? { type: 'control_request', request_id: id, request: { subtype: method, ...params } }
          : { jsonrpc: '2.0', id, method, params });
      });
    } finally { clearTimeout(timer); }
  }
  async close() {
    if (this.child.exitCode !== null || this.child.signalCode !== null) return;
    this.child.stdin.end();
    const exited = new Promise(resolve => this.child.once('exit', resolve));
    const timer = setTimeout(() => this.child.kill('SIGKILL'), 1000);
    await exited; clearTimeout(timer);
  }
}

// Allow-list child environment: do not inherit provider tokens or harness homes.
function environment(root, harness) {
  return { PATH: process.env.PATH, TMPDIR: tmpdir(), LANG: 'en_US.UTF-8',
    ...(harness === 'claude' ? { CLAUDE_CONFIG_DIR: join(root, 'config'),
      ANTHROPIC_API_KEY: 'fixture-only', CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1' }
      : { CODEX_HOME: join(root, 'config') }) };
}

function version(binary) {
  const result = spawnSync(binary, ['--version'], { encoding: 'utf8' });
  assert.equal(result.status, 0, 'Native executable must run');
  return result.stdout.trim();
}

async function probeClaudeLogin(binary, root, oauth) {
  await writeFile(join(root, '.mcp.json'), JSON.stringify({ mcpServers: {
    oauth_fixture: { type: 'http', url: `${oauth.origin}/mcp` },
  } }));
  await mkdir(join(root, '.claude'));
  await writeFile(join(root, '.claude', 'settings.local.json'),
    JSON.stringify({ enabledMcpjsonServers: ['oauth_fixture'] }));
  const options = { cwd: root, env: environment(root, 'claude'), encoding: 'utf8' };
  const untrusted = spawnSync(binary, ['mcp', 'login', 'oauth_fixture', '--no-browser'],
    { ...options, input: '', timeout: 3000 });
  const add = spawnSync(binary, ['mcp', 'add-json', '--scope', 'local', 'oauth_fixture',
    JSON.stringify({ type: 'http', url: `${oauth.origin}/mcp` })], options);
  assert.equal(add.status, 0, 'Explicit native fixture setup must succeed');
  const piped = spawnSync(binary, ['mcp', 'login', 'oauth_fixture', '--no-browser'],
    { ...options, input: '', timeout: 10000 });
  const child = spawn('python3', [terminalPath, binary, 'mcp', 'login', 'oauth_fixture', '--no-browser'],
    { ...options, stdio: ['pipe', 'pipe', 'pipe'] });
  let stdout = '', stderr = '', callbackSent = false;
  const exited = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', (status, signal) => resolve({ status, signal }));
  });
  child.stdout.on('data', chunk => {
    stdout += chunk;
    const urlText = stdout.match(/https?:\/\/[^\s\x1b]+/g)?.find(text => text.includes('/authorize?'));
    if (!callbackSent && urlText) {
      const auth = new URL(urlText);
      const callback = new URL(auth.searchParams.get('redirect_uri'));
      assert.equal(auth.origin, oauth.origin, 'Only the fixture issuer may be used');
      assert.ok(['localhost', '127.0.0.1'].includes(callback.hostname));
      callback.searchParams.set('code', 'fixture-code');
      callback.searchParams.set('state', auth.searchParams.get('state'));
      callbackSent = true;
      child.stdin.write(`${callback.href}\n`);
    }
  });
  child.stderr.on('data', chunk => { stderr += chunk; });
  const timer = setTimeout(() => child.kill('SIGTERM'), 20000);
  try {
    const result = await exited;
    return { untrusted: { status: untrusted.status, stdout: untrusted.stdout, stderr: untrusted.stderr },
      piped: { status: piped.status, stdout: piped.stdout, stderr: piped.stderr },
      terminal: { ...result, callbackSent, stdout, stderr } };
  } finally { clearTimeout(timer); child.stdin.end(); }
}

async function probeClaude(binary, root, http, oauth, model) {
  const config = join(root, 'mcp.json');
  await writeFile(config, JSON.stringify({ mcpServers: {
    stdio_fixture: { command: process.execPath, args: [fixturePath, '--stdio'] },
    http_fixture: { type: 'http', url: `${http.origin}/mcp` },
  } }));
  const peer = new Peer(binary, ['-p', '--input-format', 'stream-json', '--output-format', 'stream-json',
    '--verbose', '--permission-mode', 'default', '--permission-prompt-tool', 'stdio',
    '--strict-mcp-config', '--mcp-config', config,
    '--setting-sources', '', '--settings', '{}'], { cwd: root, env: { ...environment(root, 'claude'),
      ANTHROPIC_BASE_URL: model.origin, ENABLE_TOOL_SEARCH: 'false' } }, 'claude');
  const captures = [], elicitations = [], approvals = [];
  peer.onRequest = frame => {
    const request = frame.request;
    if (request?.subtype === 'can_use_tool') approvals.push(frame);
    else elicitations.push(frame);
    peer.send({ type: 'control_response', response: { subtype: 'success', request_id: frame.request_id,
      response: request?.subtype === 'can_use_tool' ? { behavior: 'allow', updatedInput: request.input }
        : request?.mode === 'form' ? { action: 'accept', content: { approved: true, count: 2, plan: 'pro', tags: ['b'] } }
          : { action: 'decline' } } });
  };
  try {
    for (const [method, params] of [
      ['initialize', { elicitation: {} }], ['mcp_status', {}],
      ['mcp_toggle', { serverName: 'stdio_fixture', enabled: false }], ['mcp_status', {}],
      ['mcp_toggle', { serverName: 'stdio_fixture', enabled: true }],
      ['mcp_reconnect', { serverName: 'stdio_fixture' }], ['mcp_status', {}],
      ['mcp_reconnect', { serverName: 'unknown_fixture' }], ['mcp_unknown_fixture', {}],
    ]) {
      const frame = await peer.request(method, params);
      captures.push({ method, params, frame: method === 'initialize'
        ? { type: frame.type, response: { subtype: frame.response.subtype, request_id: frame.response.request_id } }
        : frame });
    }
    for (const tool of ['echo', 'form', 'url']) {
      model.select(tool);
      const done = peer.waitFor(frame => frame.type === 'result');
      peer.send({ type: 'user', message: { role: 'user', content: `Run fixture ${tool}` } });
      const frame = await done;
      captures.push({ method: 'fixture_turn', params: { tool }, frame });
    }
    const help = spawnSync(binary, ['mcp', 'login', '--help'], { encoding: 'utf8', cwd: root,
      env: environment(root, 'claude') });
    const toolResults = peer.frames.filter(frame => frame.type === 'user')
      .flatMap(frame => Array.isArray(frame.message?.content) ? frame.message.content : [])
      .filter(block => block.type === 'tool_result');
    const login = await probeClaudeLogin(binary, root, oauth);
    return { version: version(binary), captures, elicitations, approvals, toolResults, login,
      loginHelp: { status: help.status, stdout: help.stdout } };
  } catch (error) {
    await writeFile(join(root, 'failed-probe.json'), JSON.stringify({ captures, frames: peer.frames, stderr: peer.stderr }));
    throw new Error(`Claude probe failed; diagnostics: ${join(root, 'failed-probe.json')}`, { cause: error });
  } finally { await peer.close(); }
}

async function probeCodex(binary, root, http, oauth) {
  await writeFile(join(root, 'config', 'config.toml'),
    `[analytics]\nenabled = false\n[mcp_servers.stdio_fixture]\ncommand = ${JSON.stringify(process.execPath)}\n` +
    `args = [${JSON.stringify(fixturePath)}, "--stdio"]\n[mcp_servers.http_fixture]\nurl = "${http.origin}/mcp"\n` +
    `[mcp_servers.oauth_fixture]\nurl = "${oauth.origin}/mcp"\n`);
  const peer = new Peer(binary, ['app-server'], { cwd: root, env: environment(root, 'codex') }, 'codex');
  const captures = [], elicitations = [];
  peer.onRequest = frame => {
    if (frame.method !== 'mcpServer/elicitation/request') return;
    elicitations.push(frame);
    peer.send({ id: frame.id, result: frame.params.mode === 'form'
      ? { action: 'accept', content: { approved: true, count: 2, plan: 'pro', tags: ['b'] } }
      : { action: 'decline' } });
  };
  async function capture(method, params) {
    const frame = await peer.request(method, params);
    captures.push({ method, params, frame });
    return frame;
  }
  try {
    await capture('initialize', { clientInfo: { name: 'sesori-mcp-contract-fixture', version: '1.0.0' },
      capabilities: { experimentalApi: true } });
    peer.send({ method: 'initialized' });
    const thread = await capture('thread/start', { cwd: root, ephemeral: true, approvalPolicy: 'on-request' });
    const threadId = thread.result?.thread?.id;
    assert.ok(threadId, 'Native thread start must return an id');
    await capture('mcpServerStatus/list', { threadId, limit: 1, detail: 'toolsAndAuthOnly' });
    let cursor = null;
    do {
      const frame = await capture('mcpServerStatus/list', { threadId, limit: 1, cursor });
      assert.ok(frame.result, 'Inventory should succeed');
      cursor = frame.result.nextCursor;
    } while (cursor);
    for (const tool of ['echo', 'form', 'url']) {
      await capture('mcpServer/tool/call', { threadId, server: 'stdio_fixture', tool, arguments: {} });
    }
    await capture('config/mcpServer/reload', null);
    await capture('mcpServer/oauth/login', { name: 'stdio_fixture', timeoutSecs: 1 });
    const login = await capture('mcpServer/oauth/login', { name: 'oauth_fixture', timeoutSecs: 2 });
    if (login.result) {
      const completed = peer.waitFor(frame => frame.method === 'mcpServer/oauthLogin/completed');
      const auth = new URL(login.result.authorizationUrl);
      const callback = new URL(auth.searchParams.get('redirect_uri'));
      assert.equal(auth.origin, oauth.origin, 'Only the fixture issuer may be used');
      assert.ok(['localhost', '127.0.0.1'].includes(callback.hostname));
      callback.searchParams.set('code', 'fixture-code');
      callback.searchParams.set('state', auth.searchParams.get('state'));
      await fetch(callback);
      await completed;
      await capture('mcpServerStatus/list', { threadId, detail: 'toolsAndAuthOnly' });
    }
    await capture('app/list', { threadId, limit: 1, forceRefetch: false });
    await capture('mcp_unknown_fixture', {});
    return { version: version(binary), captures, elicitations,
      notifications: peer.frames.filter(frame => frame.method?.startsWith('mcpServer/') && frame.id === undefined) };
  } finally { await peer.close(); }
}

async function main() {
  const [harness, binary, output] = process.argv.slice(2);
  assert.ok(['claude', 'codex'].includes(harness) && binary && output,
    'Usage: node probe.mjs <claude|codex> <absolute-binary> <output.json>');
  const root = await mkdtemp(join(tmpdir(), 'sesori-mcp-contract-'));
  await mkdir(join(root, 'config'));
  const http = await startHttpFixture();
  const oauth = await startHttpFixture({ oauth: true });
  const model = await startModelFixture();
  try {
    const result = await (harness === 'claude' ? probeClaude : probeCodex)(resolve(binary), root, http, oauth, model);
    assertContracts(harness, result);
    // All input is fixture-owned. Replace temporary paths, ports and native thread ids in captures.
    let text = JSON.stringify(result, null, 2).replaceAll(root, '<fixture-root>')
      .replaceAll(fixturePath, '<fixture-server>').replaceAll(process.execPath, '<fixture-node>')
      .replaceAll(http.origin, 'http://127.0.0.1:<fixture-port>')
      .replaceAll(oauth.origin, 'http://127.0.0.1:<oauth-fixture-port>');
    for (const frame of result.captures.filter(x => x.method === 'thread/start')) {
      text = text.replaceAll(frame.frame.result.thread.id, '<fixture-thread>');
    }
    await writeFile(output, `${text}\n`);
    console.log(`${harness}: ${result.version}; ${result.captures.length} native exchanges captured`);
  } finally { await Promise.all([http.close(), oauth.close(), model.close()]); }
}

function assertContracts(harness, result) {
  const exchanges = result.captures;
  if (harness === 'claude') {
    const statuses = exchanges.filter(x => x.method === 'mcp_status');
    assert.equal(statuses[1].frame.response.response.mcpServers[0].status, 'disabled');
    const connected = statuses.at(-1).frame.response.response.mcpServers;
    assert.deepEqual(connected.map(x => x.status), ['connected', 'connected']);
    assert.deepEqual(connected[0].tools.map(x => x.name), ['echo', 'form', 'url']);
    assert.equal(exchanges.find(x => x.method === 'mcp_unknown_fixture').frame.response.subtype, 'error');
    assert.equal(result.approvals.length, 3, 'Each tool needs native permission');
    const form = result.elicitations.find(x => x.request.mode === 'form');
    assert.deepEqual(form.request.requested_schema, formSchema);
    const formReply = JSON.parse(result.toolResults[1].content[0].text).result;
    assert.deepEqual(formReply, { action: 'accept', content: { approved: true, count: 2, plan: 'pro', tags: ['b'] } });
    const urlReply = JSON.parse(result.toolResults[2].content[0].text);
    if (result.elicitations.some(x => x.request.mode === 'url')) {
      assert.equal(urlReply.result.action, 'decline');
    } else {
      assert.equal(urlReply.error.code, -32602);
      assert.match(urlReply.error.message, /does not support URL-mode/);
    }
    assert.match(result.login.untrusted.stderr, /awaiting approval/);
    assert.equal(result.login.terminal.status, 0, 'Terminal OAuth must complete');
    assert.equal(result.login.terminal.callbackSent, true);
  } else {
    const inventory = exchanges.filter(x => x.method === 'mcpServerStatus/list' && x.params.limit === 1);
    assert.ok(inventory.some(x => x.frame.result.nextCursor), 'Pagination must be exercised');
    const names = inventory.slice(1).flatMap(x => x.frame.result.data.map(server => server.name));
    assert.deepEqual(names, ['http_fixture', 'oauth_fixture', 'stdio_fixture']);
    assert.equal(exchanges.find(x => x.method === 'mcp_unknown_fixture').frame.error.code, -32600);
    assert.equal(result.elicitations.length, 2, 'Form and URL requests must reach the client');
    assert.deepEqual(result.elicitations[0].params.requestedSchema, formSchema);
    const returned = exchanges.filter(x => x.method === 'mcpServer/tool/call');
    const formReply = JSON.parse(returned[1].frame.result.content[0].text).result;
    assert.deepEqual(formReply, { action: 'accept', content: { approved: true, count: 2, plan: 'pro', tags: ['b'] } });
    assert.equal(JSON.parse(returned[2].frame.result.content[0].text).result.action, 'decline');
    assert.equal(result.notifications.find(x => x.method === 'mcpServer/oauthLogin/completed').params.success, true);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
