import { schemas } from "../../supabase/functions/planning-ai/schema.mjs";
import { systemFor as sharedSystemFor } from "../../supabase/functions/planning-ai/prompt.mjs";
import { normalizeAndValidate, MAX_REQUEST_BYTES } from "../../supabase/functions/planning-ai/validation.mjs";

const baseHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  Vary: 'Origin',
};

const requestBuckets = new Map();
const healthCache = new Map();

function header(event, name) {
  const entries = Object.entries(event.headers || {});
  return entries.find(([key]) => key.toLowerCase() === name.toLowerCase())?.[1] || '';
}

function configuredOrigins() {
  return new Set(
    [process.env.AI_ALLOWED_ORIGINS, process.env.URL, process.env.DEPLOY_PRIME_URL, process.env.DEPLOY_URL]
      .flatMap((value) => (value || '').split(','))
      .map((value) => value.trim().replace(/\/$/, ''))
      .filter(Boolean),
  );
}

function responseHeaders(event) {
  const origin = header(event, 'origin').replace(/\/$/, '');
  const allowed = configuredOrigins();
  if (!origin) return baseHeaders;
  if (allowed.size === 0 || allowed.has(origin)) {
    return { ...baseHeaders, 'Access-Control-Allow-Origin': origin };
  }
  return baseHeaders;
}

function originAllowed(event) {
  const origin = header(event, 'origin').replace(/\/$/, '');
  const allowed = configuredOrigins();
  return !origin || allowed.size === 0 || allowed.has(origin);
}

function json(event, statusCode, body) {
  return { statusCode, headers: responseHeaders(event), body: JSON.stringify(body) };
}

function withinRateLimit(event) {
  const now = Date.now();
  const windowMs = 60_000;
  const limit = Math.max(5, Number(process.env.AI_REQUESTS_PER_MINUTE || 24));
  const client = header(event, 'x-nf-client-connection-ip') || header(event, 'x-forwarded-for').split(',')[0].trim() || 'unknown';
  const previous = requestBuckets.get(client);
  const bucket = !previous || now - previous.startedAt >= windowMs ? { startedAt: now, count: 0 } : previous;
  bucket.count += 1;
  requestBuckets.set(client, bucket);
  if (requestBuckets.size > 500) {
    for (const [key, value] of requestBuckets) {
      if (now - value.startedAt > windowMs * 2) requestBuckets.delete(key);
    }
  }
  return bucket.count <= limit;
}


async function fetchWithTimeout(url, options = {}, timeoutMs = Number(process.env.AI_PROVIDER_TIMEOUT_MS || 28_000)) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), Math.max(5_000, timeoutMs));
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

function languageInstruction(language) {
  return language === 'ru'
    ? 'Respond in natural Russian unless the latest user message clearly uses another language.'
    : 'Respond in natural English unless the latest user message clearly uses another language.';
}

function coachTone(mode) {
  if (mode === 'strict') {
    return [
      'Act as a strict professional accountability coach.',
      'Be concise, direct and noticeably firm. Point out the exact gap between stated goals and observed behavior.',
      'Do not soothe vague excuses. End with one measurable command and a short deadline.',
    ].join(' ');
  }
  if (mode === 'aggressive') {
    return [
      'Act as an intense AGGRESSIVE accountability coach using controlled confrontation and provocative honesty.',
      'Use short forceful sentences. Interrupt the excuse, name the contradiction between the stated goal and the latest behavior, and expose the concrete cost of repeating it.',
      'Force an honest binary choice: do the smallest action now or admit that avoidance is being chosen. Give a five-minute command with a visible finish line.',
      'You may say that the user is negotiating with the task, protecting comfort, or voting for another zero day. Never insult, humiliate, shame, threaten or attack the person.',
      'Never target identity, intelligence, appearance, worth, health, family or protected traits. End with an immediate measurable action.',
    ].join(' ');
  }
  return [
    'Act as an exceptionally warm, patient and encouraging accountability coach.',
    'Acknowledge the feeling, lower overwhelm, and offer one very small concrete action.',
    'Use gentle language, celebrate honest effort without exaggeration, and guide toward action without guilt.',
  ].join(' ');
}

function accountabilityInstruction(level) {
  if (level === 'high') return 'Use high accountability: narrow the next action, make completion criteria explicit, and avoid vague escape hatches.';
  if (level === 'light') return 'Use light accountability: preserve flexibility, reduce overwhelm, and prefer one small next action over pressure.';
  return 'Use balanced accountability: be clear about commitments while keeping the plan realistic and sustainable.';
}

function safetyInstruction(safeMode) {
  if (safeMode) return 'Use extra-conservative wellbeing guardrails: do not encourage sleep loss, unsafe overwork, extreme restriction, or ignoring signs that rest is needed.';
  return 'Keep baseline safety guardrails active even when extra-conservative mode is off; never recommend unsafe overwork or harmful behavior.';
}

function trimSlash(value) {
  return value.replace(/\/+$/, '');
}

function providerConfig() {
  if (process.env.GROQ_API_KEY) {
    return {
      id: 'groq',
      apiKey: process.env.GROQ_API_KEY,
      url: `${trimSlash(process.env.GROQ_BASE_URL || 'https://api.groq.com/openai/v1')}/chat/completions`,
      model: process.env.GROQ_MODEL || 'openai/gpt-oss-20b',
      responseFormat: 'json_schema',
    };
  }
  return {
    id: 'openrouter',
    apiKey: process.env.OPENROUTER_API_KEY || '',
    url: `${trimSlash(process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1')}/chat/completions`,
    model: process.env.OPENROUTER_MODEL || 'deepseek/deepseek-v4-flash:free',
    responseFormat: 'json_object',
  };
}

function responseFormat(config, schemaName, schema) {
  if (config.responseFormat === 'json_schema') {
    return {
      type: 'json_schema',
      json_schema: {
        name: `plan_your_day_${schemaName}`,
        strict: true,
        schema,
      },
    };
  }
  return { type: 'json_object' };
}

function normalizeJsonText(value) {
  let candidate = value.trim();
  const fenced = candidate.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  if (fenced) candidate = fenced[1].trim();
  if (!candidate.startsWith('{')) {
    const first = candidate.indexOf('{');
    const last = candidate.lastIndexOf('}');
    if (first >= 0 && last > first) candidate = candidate.slice(first, last + 1);
  }
  return JSON.stringify(JSON.parse(candidate));
}

async function providerIsReachable(config) {
  const cacheKey = `${config.id}:${config.model}:${config.apiKey.slice(-6)}`;
  const cached = healthCache.get(cacheKey);
  if (cached && Date.now() - cached.checkedAt < 30_000) return cached;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 6_000);
  try {
    const body = {
      model: config.model,
      messages: [{ role: 'user', content: 'Reply OK.' }],
      temperature: 0,
      max_tokens: 8,
    };
    const response = await fetch(config.url, {
      method: 'POST',
      headers: providerHeaders(config),
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const result = {
      checkedAt: Date.now(),
      ready: response.ok,
      status: response.status,
      message: response.ok ? 'Built-in AI is ready.' : healthMessage(response.status),
    };
    healthCache.set(cacheKey, result);
    return result;
  } catch {
    const result = { checkedAt: Date.now(), ready: false, status: 502, message: 'The AI provider could not be reached.' };
    healthCache.set(cacheKey, result);
    return result;
  } finally {
    clearTimeout(timeout);
  }
}

function providerHeaders(config) {
  const headers = {
    Authorization: `Bearer ${config.apiKey}`,
    'Content-Type': 'application/json',
  };
  if (config.id === 'openrouter') {
    headers['HTTP-Referer'] = process.env.URL || 'https://planning.app';
    headers['X-OpenRouter-Title'] = 'Planning';
  }
  return headers;
}

function healthMessage(status) {
  if (status === 401 || status === 403) return 'The private AI key is invalid or unauthorized.';
  if (status === 402) return 'The AI account has no usable credit or free allocation.';
  if (status === 404) return 'The configured AI model is unavailable.';
  if (status === 429) return 'The AI provider rate limit or free-capacity limit was reached.';
  return 'The AI provider rejected the connection check.';
}

export async function handler(event) {
  if (!originAllowed(event)) return json(event, 403, { error: 'Origin not allowed.' });
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: responseHeaders(event), body: '' };
  const healthConfig = providerConfig('coach');
  if (event.httpMethod === 'GET') {
    if (!withinRateLimit(event)) return json(event,429,{error:'Too many AI requests.'});
    if (!healthConfig.apiKey) return json(event, 503, { ready: false, server: true, message: 'Built-in AI is not configured on the server.' });
    const health = await providerIsReachable(healthConfig);
    return json(event, health.ready ? 200 : health.status >= 400 && health.status < 500 ? health.status : 502, {
      ready: health.ready,
      server: true,
      message: health.message,
    });
  }
  if (event.httpMethod !== 'POST') return json(event, 405, { error: 'Method not allowed.' });
  if (!healthConfig.apiKey) return json(event, 503, { error: 'Built-in AI is not configured on the server.' });
  if (!withinRateLimit(event)) return json(event, 429, { error: 'Too many AI requests. Try again shortly.' });
  if (new TextEncoder().encode(event.body || '').byteLength > MAX_REQUEST_BYTES) return json(event, 413, { error: 'Request is too large.' });

  let input;
  try {
    input = JSON.parse(event.body || '{}');
  } catch {
    return json(event, 400, { error: 'Invalid JSON.' });
  }

  if (!input || typeof input !== 'object' || Array.isArray(input)) return json(event,400,{error:'Invalid AI request.'});
  const schemaName = typeof input.schema === 'string' ? input.schema : '';
  const schema = Object.hasOwn(schemas,schemaName) ? schemas[schemaName] : null;
  const prompt = typeof input.prompt === 'string' ? input.prompt : '';
  const mode = ['soft', 'strict', 'aggressive'].includes(input.mode) ? input.mode : 'soft';
  const accountability = ['light', 'balanced', 'high'].includes(input.accountability) ? input.accountability : 'balanced';
  const safeMode = input.safeMode !== false;
  const language = input.language === 'ru' ? 'ru' : 'en';
  const assistantMode = ['planning', 'school', 'general', 'workspace'].includes(input.assistantMode) ? input.assistantMode : 'planning';
  const studyLevel = ['grade-1', 'grade-2', 'grade-3', 'grade-4', 'grade-5', 'grade-6', 'grade-7', 'grade-8', 'grade-9', 'grade-10', 'grade-11', 'grade-12', 'student', 'university', 'professional'].includes(input.studyLevel) ? input.studyLevel : 'grade-9';
  const interactiveSteps = input.interactiveSteps !== false;
  const visualizations = input.visualizations !== false;
  const checkYourself = input.checkYourself !== false;
  const operation = input.operation === 'replan' ? 'replan' : 'build';
  const horizon = ['day', 'week', 'month', 'year'].includes(input.horizon) ? input.horizon : 'day';
  if (!schema || !prompt) return json(event, 400, { error: 'Invalid AI request.' });
  const config = providerConfig(schemaName);
  if (!config.apiKey) return json(event, 503, { error: 'Built-in AI is not configured on the server.' });
  const schemaInstruction = config.responseFormat === 'json_object'
    ? `The JSON object must match this schema exactly: ${JSON.stringify(schema)}`
    : '';
  const system = `${sharedSystemFor({ ...input, mode, accountability, safeMode, language, assistantMode, studyLevel, interactiveSteps, visualizations, checkYourself, operation, horizon }, schemaName)} ${schemaInstruction}`.trim();

  const requestBody = {
    model: config.model,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: prompt },
    ],
    temperature: schemaName === 'coach' ? 0.55 : 0.25,
    max_tokens: schemaName === 'coach' ? 6000 : schemaName === 'profile' ? 1800 : schemaName === 'subtasks' ? 800 : 3200,
    response_format: responseFormat(config, schemaName, schema),
  };
  try {
    let response = await fetchWithTimeout(config.url, {
      method: 'POST',
      headers: providerHeaders(config),
      body: JSON.stringify(requestBody),
    });
    let result = await response.json().catch(() => ({}));
    if (response.status === 400) {
      const { response_format: _responseFormat, ...compatibleBody } = requestBody;
      response = await fetchWithTimeout(config.url, {
        method: 'POST',
        headers: providerHeaders(config),
        body: JSON.stringify(compatibleBody),
      }, 8_000);
      result = await response.json().catch(() => ({}));
    }
    const text = result?.choices?.[0]?.message?.content;
    if (!response.ok || typeof text !== 'string') {
      const safeMessage = response.status === 429 ? 'AI is busy. Try again in a moment.' : 'AI could not complete this request.';
      return json(event, response.status === 429 ? 429 : 502, { error: safeMessage });
    }
    try {
      return json(event, 200, { text: normalizeAndValidate(text,schemaName,input.memoryEnabled !== false) });
    } catch {
      return json(event, 502, { error: 'AI returned an invalid structured response.' });
    }
  } catch {
    return json(event, 502, { error: 'AI connection failed.' });
  }
}
