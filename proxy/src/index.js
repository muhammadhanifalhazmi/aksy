const GEMINI_HOST = 'generativelanguage.googleapis.com';
const GEMINI_PATH = '/v1beta/interactions';

const ALLOWED_MODEL = /^gemini-[a-z0-9.-]{1,64}$/;
const MAX_MESSAGES = 20;
const MAX_SYSTEM_INSTRUCTION_CHARS = 24000;
const MAX_MESSAGE_CHARS = 8000;
const MAX_BODY_BYTES = 512 * 1024;

const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX_REQUESTS = 20;

const ipBuckets = new Map();

function corsHeaders(request) {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Assistant-Token',
    'Access-Control-Max-Age': '86400',
  };
}

function json(request, status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(request),
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

function clientIp(request) {
  return request.headers.get('CF-Connecting-IP') || 'unknown';
}

function checkRateLimit(ip) {
  const now = Date.now();
  const bucket = ipBuckets.get(ip);

  if (!bucket || now - bucket.startedAt > RATE_LIMIT_WINDOW_MS) {
    ipBuckets.set(ip, { startedAt: now, count: 1 });
    pruneBuckets(now);
    return { allowed: true, remaining: RATE_LIMIT_MAX_REQUESTS - 1 };
  }

  bucket.count += 1;
  if (bucket.count > RATE_LIMIT_MAX_REQUESTS) {
    const retryAfter = Math.ceil(
      (RATE_LIMIT_WINDOW_MS - (now - bucket.startedAt)) / 1000,
    );
    return { allowed: false, retryAfter: Math.max(retryAfter, 1) };
  }

  return { allowed: true, remaining: RATE_LIMIT_MAX_REQUESTS - bucket.count };
}

function pruneBuckets(now) {
  if (ipBuckets.size < 512) return;
  for (const [key, bucket] of ipBuckets) {
    if (now - bucket.startedAt > RATE_LIMIT_WINDOW_MS) ipBuckets.delete(key);
  }
}

function constantTimeEquals(a, b) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i += 1) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

function validatePayload(payload) {
  if (!payload || typeof payload !== 'object') {
    return { error: 'Body harus berupa JSON object.' };
  }

  const model = typeof payload.model === 'string' ? payload.model : '';
  if (!ALLOWED_MODEL.test(model)) {
    return { error: 'Model tidak valid.' };
  }

  const systemInstruction =
    typeof payload.systemInstruction === 'string'
      ? payload.systemInstruction
      : '';
  if (systemInstruction.length === 0) {
    return { error: 'systemInstruction wajib diisi.' };
  }
  if (systemInstruction.length > MAX_SYSTEM_INSTRUCTION_CHARS) {
    return { error: 'systemInstruction terlalu panjang.' };
  }

  const messages = Array.isArray(payload.messages) ? payload.messages : [];
  if (messages.length === 0) {
    return { error: 'messages tidak boleh kosong.' };
  }
  if (messages.length > MAX_MESSAGES) {
    return { error: 'Terlalu banyak pesan.' };
  }

  const input = [];
  for (const message of messages) {
    if (!message || typeof message !== 'object') {
      return { error: 'Format pesan tidak valid.' };
    }
    const role = message.role;
    if (role !== 'user' && role !== 'model') {
      return { error: 'Role harus user atau model.' };
    }
    const text = typeof message.text === 'string' ? message.text.trim() : '';
    if (text.length === 0) {
      return { error: 'Pesan kosong tidak dikirim.' };
    }
    if (text.length > MAX_MESSAGE_CHARS) {
      return { error: 'Pesan terlalu panjang.' };
    }
    input.push({ role, content: text });
  }

  return {
    value: {
      model,
      systemInstruction,
      input,
    },
  };
}

function describeUpstreamError(status, body) {
  let detail = null;
  try {
    const parsed = JSON.parse(body);
    detail =
      parsed?.error?.message ||
      parsed?.message ||
      null;
  } catch {
    detail = null;
  }

  if (status === 400 || status === 401 || status === 403) {
    return 'Gemini menolak API key proxy. Cek secret GEMINI_API_KEY di Worker.';
  }
  if (status === 404) {
    return 'Model Gemini tidak ditemukan.';
  }
  if (status === 429) {
    return 'Kuota Gemini habis, proxy sedang menunggu kuota berikutnya.';
  }
  if (status >= 500) {
    return 'Gemini sedang bermasalah. Coba lagi sebentar.';
  }
  return detail
    ? `Gemini gagal merespons: ${detail}`
    : `Gemini gagal merespons (HTTP ${status}).`;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (request.method === 'GET' && new URL(request.url).pathname === '/health') {
      return json(request, 200, {
        ok: true,
        geminiKeyConfigured: Boolean(env.GEMINI_API_KEY),
        rateLimitPerMinute: RATE_LIMIT_MAX_REQUESTS,
      });
    }

    if (request.method !== 'POST') {
      return json(request, 405, { error: 'Method tidak diizinkan.' });
    }

    if (!env.GEMINI_API_KEY) {
      return json(request, 500, {
        error: 'Worker belum dikonfigurasi. Jalankan: wrangler secret put GEMINI_API_KEY',
      });
    }

    if (env.APP_TOKEN) {
      const provided = request.headers.get('X-Assistant-Token') || '';
      if (!constantTimeEquals(provided, env.APP_TOKEN)) {
        return json(request, 401, { error: 'Token aplikasi tidak valid.' });
      }
    }

    const ip = clientIp(request);
    const limit = checkRateLimit(ip);
    if (!limit.allowed) {
      return new Response(
        JSON.stringify({
          error: 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders(request),
            'Content-Type': 'application/json; charset=utf-8',
            'Retry-After': String(limit.retryAfter),
          },
        },
      );
    }

    let raw;
    try {
      raw = await request.text();
    } catch {
      return json(request, 413, { error: 'Body terlalu besar.' });
    }
    if (raw.length > MAX_BODY_BYTES) {
      return json(request, 413, { error: 'Body terlalu besar.' });
    }

    let payload;
    try {
      payload = JSON.parse(raw);
    } catch {
      return json(request, 400, { error: 'JSON tidak valid.' });
    }

    const validated = validatePayload(payload);
    if (validated.error) {
      return json(request, 400, { error: validated.error });
    }

    const upstream = await fetch(
      `https://${GEMINI_HOST}${GEMINI_PATH}?alt=sse`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          'x-goog-api-key': env.GEMINI_API_KEY,
        },
        body: JSON.stringify({
          model: validated.value.model,
          system_instruction: validated.value.systemInstruction,
          input: validated.value.input,
          stream: true,
        }),
      },
    );

    if (!upstream.ok) {
      const body = await upstream.text();
      return json(request, upstream.status, {
        error: describeUpstreamError(upstream.status, body),
      });
    }

    return new Response(upstream.body, {
      status: 200,
      headers: {
        ...corsHeaders(request),
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-store',
        'X-RateLimit-Remaining': String(limit.remaining),
      },
    });
  },
};
