import assert from 'node:assert/strict';
import { afterEach, describe, it } from 'node:test';

import worker from '../src/index.js';

const REAL_FETCH = globalThis.fetch;

const env = { GEMINI_API_KEY: 'test-key', APP_TOKEN: 'secret-token' };

const validPayload = {
  model: 'gemini-3.5-flash',
  systemInstruction: 'Kamu asisten kasir Bahasa Indonesia.',
  messages: [{ role: 'user', text: 'Berapa omzet hari ini?' }],
};

const sseBody = [
  'event: interaction.created',
  'data: {"event_type":"interaction.created","id":"abc"}',
  '',
  'event: step.delta',
  'data: {"event_type":"step.delta","delta":{"type":"text","text":"Halo"}}',
  '',
  'event: step.stop',
  'data: {"event_type":"step.stop"}',
  '',
].join('\n');

let callCount = 0;
let lastUpstream = null;

function stubUpstream(handler) {
  callCount = 0;
  lastUpstream = null;
  globalThis.fetch = async (url, init) => {
    callCount += 1;
    lastUpstream = { url: String(url), init };
    return handler();
  };
}

function stubOk() {
  stubUpstream(
    () =>
      new Response(sseBody, {
        status: 200,
        headers: { 'Content-Type': 'text/event-stream' },
      }),
  );
}

function stubError(status, body) {
  stubUpstream(
    () =>
      new Response(JSON.stringify(body ?? { error: { message: 'upstream' } }), {
        status,
      }),
  );
}

function post(body, { token = 'secret-token', ip = '10.0.0.1' } = {}) {
  const headers = {
    'Content-Type': 'application/json',
    'CF-Connecting-IP': ip,
  };
  if (token !== null) headers['X-Assistant-Token'] = token;

  return worker.fetch(
    new Request('https://proxy.test/chat', {
      method: 'POST',
      headers,
      body: typeof body === 'string' ? body : JSON.stringify(body),
    }),
    env,
  );
}

afterEach(() => {
  globalThis.fetch = REAL_FETCH;
});

describe('proxy health and routing', () => {
  it('reports health and whether the Gemini secret is present', async () => {
    const response = await worker.fetch(
      new Request('https://proxy.test/health'),
      env,
    );
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.ok, true);
    assert.equal(body.geminiKeyConfigured, true);
  });

  it('answers CORS preflight with 204', async () => {
    const response = await worker.fetch(
      new Request('https://proxy.test/chat', { method: 'OPTIONS' }),
      env,
    );
    assert.equal(response.status, 204);
    assert.match(
      response.headers.get('Access-Control-Allow-Methods') ?? '',
      /POST/,
    );
  });

  it('rejects non-POST methods on /chat', async () => {
    const response = await worker.fetch(
      new Request('https://proxy.test/chat', { method: 'GET' }),
      env,
    );
    assert.equal(response.status, 405);
  });
});

describe('secret handling', () => {
  it('fails loudly with deploy instructions when no secret is set', async () => {
    const response = await worker.fetch(
      new Request('https://proxy.test/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(validPayload),
      }),
      {},
    );
    assert.equal(response.status, 500);
    assert.match((await response.json()).error, /wrangler secret put/);
  });

  it('checks the app token before the Gemini secret is used', async () => {
    stubOk();
    const response = await post(validPayload, { token: 'salah' });
    assert.equal(response.status, 401);
    assert.equal(callCount, 0, 'Gemini must not be called for a bad token');
  });

  it('works without an app token when none is configured', async () => {
    stubOk();
    const response = await worker.fetch(
      new Request('https://proxy.test/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(validPayload),
      }),
      { GEMINI_API_KEY: 'test-key' },
    );
    assert.equal(response.status, 200);
  });
});

describe('payload validation', () => {
  const cases = [
    ['a non-Gemini model', { ...validPayload, model: 'gpt-4' }],
    ['a model that is not a string', { ...validPayload, model: 42 }],
    ['an unknown role', { ...validPayload, messages: [{ role: 'system', text: 'x' }] }],
    ['an empty message list', { ...validPayload, messages: [] }],
    ['a blank message', { ...validPayload, messages: [{ role: 'user', text: '  ' }] }],
    ['a missing system instruction', { ...validPayload, systemInstruction: '' }],
    [
      'an oversized message',
      {
        ...validPayload,
        messages: [{ role: 'user', text: 'a'.repeat(8001) }],
      },
    ],
    [
      'an oversized system instruction',
      { ...validPayload, systemInstruction: 'a'.repeat(24001) },
    ],
  ];

  for (const [label, payload] of cases) {
    it(`rejects ${label}`, async () => {
      stubOk();
      const response = await post(payload, { ip: '10.1.0.1' });
      assert.equal(response.status, 400);
      assert.equal(callCount, 0, 'Gemini must not be called for bad input');
    });
  }

  it('rejects malformed JSON', async () => {
    stubOk();
    const response = await post('{bukan json', { ip: '10.1.0.2' });
    assert.equal(response.status, 400);
    assert.equal(callCount, 0);
  });
});

describe('forwarding to Gemini', () => {
  it('passes the stream through untouched', async () => {
    stubOk();
    const response = await post(validPayload, { ip: '10.2.0.1' });

    assert.equal(response.status, 200);
    assert.equal(
      response.headers.get('Content-Type'),
      'text/event-stream; charset=utf-8',
    );
    assert.match(await response.text(), /"text":"Halo"/);
    assert.equal(callCount, 1);
  });

  it('sends the model, system instruction and messages upstream', async () => {
    stubOk();
    await post(validPayload, { ip: '10.2.0.2' });

    assert.match(lastUpstream.url, /generativelanguage\.googleapis\.com/);
    assert.match(lastUpstream.url, /\/v1beta\/interactions\?alt=sse$/);
    assert.equal(lastUpstream.init.headers['x-goog-api-key'], 'test-key');
    assert.equal(lastUpstream.init.body.includes('"stream":true'), true);

    const sent = JSON.parse(lastUpstream.init.body);
    assert.equal(sent.model, 'gemini-3.5-flash');
    assert.equal(sent.system_instruction, validPayload.systemInstruction);
    assert.deepEqual(sent.input, [
      { role: 'user', content: 'Berapa omzet hari ini?' },
    ]);
  });

  it('never leaks the Gemini key back to the caller', async () => {
    stubOk();
    const response = await post(validPayload, { ip: '10.2.0.3' });
    const body = await response.text();
    assert.equal(body.includes('test-key'), false);
    assert.equal(
      [...response.headers.values()].some((v) => v.includes('test-key')),
      false,
    );
  });
});

describe('upstream error translation', () => {
  const cases = [
    [400, /API key proxy/],
    [404, /Model Gemini tidak ditemukan/],
    [429, /Kuota Gemini habis/],
    [503, /Gemini sedang bermasalah/],
  ];

  for (const [status, pattern] of cases) {
    it(`turns upstream ${status} into a readable message`, async () => {
      stubError(status);
      const response = await post(validPayload, { ip: '10.3.0.1' });
      assert.equal(response.status, status);
      assert.match((await response.json()).error, pattern);
    });
  }
});

describe('rate limiting', () => {
  it('allows 20 requests per minute then blocks the rest', async () => {
    stubOk();
    const statuses = [];
    for (let i = 0; i < 25; i += 1) {
      statuses.push((await post(validPayload, { ip: '10.4.0.1' })).status);
    }

    assert.equal(
      statuses.filter((s) => s === 200).length,
      20,
      'exactly 20 requests should pass',
    );
    assert.equal(statuses.filter((s) => s === 429).length, 5);
  });

  it('tells the client how long to wait', async () => {
    stubOk();
    for (let i = 0; i < 21; i += 1) {
      const response = await post(validPayload, { ip: '10.4.0.2' });
      if (i === 20) {
        assert.equal(response.status, 429);
        assert.ok(Number(response.headers.get('Retry-After')) >= 1);
      }
    }
  });

  it('does not let one IP affect another', async () => {
    stubOk();
    for (let i = 0; i < 25; i += 1) {
      await post(validPayload, { ip: '10.4.1.1' });
    }
    const other = await post(validPayload, { ip: '10.4.1.2' });
    assert.equal(other.status, 200);
  });
});
