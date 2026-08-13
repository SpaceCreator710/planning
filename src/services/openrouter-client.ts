import { fetch } from 'expo/fetch';

import {
  getPersonalKey,
  removePersonalKey,
  savePersonalKey,
} from '@/services/personal-key-storage';

export const OPENROUTER_MODEL = 'deepseek/deepseek-v4-flash:free';

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

export async function savePersonalOpenRouterKey(value: string) {
  const key = value.trim();
  if (!key) throw new Error('Paste an OpenRouter key first.');
  await savePersonalKey(key);
}

export async function getPersonalOpenRouterKey() {
  return getPersonalKey();
}

export async function removePersonalOpenRouterKey() {
  await removePersonalKey();
}

export async function hasPersonalOpenRouterKey() {
  return Boolean(await getPersonalOpenRouterKey());
}

function errorMessage(status: number, payload: unknown) {
  const source = payload as { error?: { message?: string; code?: string | number } | string };
  const raw = typeof source?.error === 'string' ? source.error : source?.error?.message;
  if (status === 401 || status === 403) return 'OpenRouter rejected this key. Create a new key and try again.';
  if (status === 402) return 'This OpenRouter account has no usable credit or free allocation.';
  if (status === 404) return 'The selected free model is temporarily unavailable on OpenRouter.';
  if (status === 429) return 'OpenRouter free capacity is busy or the rate limit was reached. Try again shortly.';
  if (status >= 500) return 'OpenRouter is temporarily unavailable.';
  return raw?.slice(0, 240) || `OpenRouter request failed (${status}).`;
}

function contentFrom(payload: unknown) {
  const data = payload as { choices?: { message?: { content?: string | { text?: string }[] } }[] };
  const content = data.choices?.[0]?.message?.content;
  if (typeof content === 'string') return content;
  if (Array.isArray(content)) return content.map((part) => part.text ?? '').join('');
  return '';
}

function normalizeJsonText(value: string) {
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

async function callOpenRouter(
  key: string,
  messages: { role: 'system' | 'user'; content: string }[],
  maxTokens: number,
) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 32_000);
  const baseBody = {
    model: OPENROUTER_MODEL,
    messages,
    temperature: 0.3,
    max_tokens: maxTokens,
  };
  const headers = {
    Authorization: `Bearer ${key}`,
    'Content-Type': 'application/json',
    'HTTP-Referer': 'https://ai-plan-your-day.app',
    'X-OpenRouter-Title': 'AI Plan Your Day',
  };

  try {
    let response = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers,
      body: JSON.stringify({ ...baseBody, response_format: { type: 'json_object' } }),
      signal: controller.signal,
    });
    let payload = (await response.json().catch(() => ({}))) as unknown;

    // Free providers do not always expose JSON mode. The system prompt still
    // requires JSON and the result is validated by Zod before it can alter data.
    if (response.status === 400) {
      response = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers,
        body: JSON.stringify(baseBody),
        signal: controller.signal,
      });
      payload = (await response.json().catch(() => ({}))) as unknown;
    }

    if (!response.ok) throw new Error(errorMessage(response.status, payload));
    const content = contentFrom(payload);
    if (!content) throw new Error('OpenRouter returned an empty response.');
    return normalizeJsonText(content);
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') throw new Error('OpenRouter did not answer before the timeout.');
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

export async function requestPersonalOpenRouterJson(system: string, prompt: string, maxTokens = 3200) {
  const key = await getPersonalOpenRouterKey();
  if (!key) throw new Error('No personal OpenRouter test key is connected.');
  return callOpenRouter(
    key,
    [
      { role: 'system', content: system },
      { role: 'user', content: prompt },
    ],
    maxTokens,
  );
}

export async function testPersonalOpenRouterKey(keyOverride?: string) {
  const key = keyOverride?.trim() || (await getPersonalOpenRouterKey());
  if (!key) return { ok: false, message: 'Paste an OpenRouter key first.' };
  try {
    const text = await callOpenRouter(
      key,
      [
        { role: 'system', content: 'Return only the JSON object {"ok":true}.' },
        { role: 'user', content: 'Connection test.' },
      ],
      40,
    );
    const parsed = JSON.parse(text) as { ok?: boolean };
    return { ok: parsed.ok === true, message: parsed.ok === true ? 'Personal test AI is connected.' : 'The model answered, but the test result was invalid.' };
  } catch (error) {
    return { ok: false, message: error instanceof Error ? error.message : 'OpenRouter connection failed.' };
  }
}
