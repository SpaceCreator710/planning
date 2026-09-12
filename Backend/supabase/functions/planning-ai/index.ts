import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { schemas } from "./schema.ts";
import { systemFor } from "./prompt.ts";
import { acceptedClientKey, normalizeAndValidate, readBoundedBody, MAX_REQUEST_BYTES } from "./validation.mjs";

const headers = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };
const buckets = new Map<string, { startedAt: number; count: number }>();
const reply = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers });
function validClient(req: Request) { return acceptedClientKey(req.headers.get("apikey"), { SUPABASE_PUBLISHABLE_KEYS: Deno.env.get("SUPABASE_PUBLISHABLE_KEYS"), SUPABASE_PUBLISHABLE_KEY: Deno.env.get("SUPABASE_PUBLISHABLE_KEY"), SUPABASE_ANON_KEY: Deno.env.get("SUPABASE_ANON_KEY") }); }
function withinRateLimit(req: Request) { const now = Date.now(), key = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || req.headers.get("cf-connecting-ip") || "unknown"; const old = buckets.get(key), bucket = !old || now - old.startedAt >= 60_000 ? { startedAt: now, count: 0 } : old; bucket.count++; if (buckets.size >= 5000 && !buckets.has(key)) buckets.delete(buckets.keys().next().value!); buckets.set(key, bucket); return bucket.count <= 30; }
function config() { return { apiKey: Deno.env.get("GEMINI_API_KEY") || "", url: (Deno.env.get("GEMINI_INTERACTIONS_URL") || "https://generativelanguage.googleapis.com/v1beta/interactions").replace(/\/+$/, ""), model: Deno.env.get("GEMINI_MODEL") || "gemini-3.7-flash" }; }
const normalizeJSON = normalizeAndValidate;
async function gemini(body: unknown, timeoutMs = 22_000) { const c = config(), controller = new AbortController(), timer = setTimeout(() => controller.abort(), timeoutMs); try { return await fetch(c.url, { method: "POST", headers: { "x-goog-api-key": c.apiKey, "content-type": "application/json" }, body: JSON.stringify(body), signal: controller.signal }); } finally { clearTimeout(timer); } }
function outputText(data: any): string | null { if (typeof data?.output_text === "string" && data.output_text.trim()) return data.output_text; const steps = Array.isArray(data?.steps) ? data.steps : []; for (let i = steps.length - 1; i >= 0; i--) for (const part of Array.isArray(steps[i]?.content) ? [...steps[i].content].reverse() : []) if (typeof part?.text === "string" && part.text.trim()) return part.text; return null; }

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "access-control-allow-headers": "content-type, apikey", "access-control-allow-methods": "GET,POST,OPTIONS" } });
  if (!validClient(req)) return reply(401, { error: "Unauthorized client." });
  if (!withinRateLimit(req)) return reply(429, { error: "Too many AI requests. Try again shortly." });
  const c = config(); if (!c.apiKey) return reply(503, { error: "Built-in AI is not configured on the server." });
  if (req.method === "GET") { try { const r = await gemini({ model: c.model, input: "Reply OK.", generation_config: { thinking_level: "low", max_output_tokens: 32 }, store: false }, 6_000); const d = await r.json().catch(() => ({})); return r.ok && outputText(d) ? reply(200, { ready: true, server: true, message: "Built-in AI is ready." }) : reply(r.status === 429 ? 429 : 502, { ready: false, server: true, message: r.status === 429 ? "AI provider rate limit reached." : "AI provider rejected the connection check." }); } catch { return reply(502, { ready: false, server: true, message: "The AI provider could not be reached." }); } }
  if (req.method !== "POST") return reply(405, { error: "Method not allowed." });
  if (Number(req.headers.get("content-length") || 0) > MAX_REQUEST_BYTES) return reply(413, { error: "Request is too large." });
  let input: any; try { input = JSON.parse(await readBoundedBody(req)); } catch (error) { return reply(error instanceof RangeError ? 413 : 400, { error: "Invalid or oversized JSON." }); }
  if (!input || typeof input !== "object" || Array.isArray(input)) return reply(400, { error: "Invalid AI request." });
  const schemaName = typeof input.schema === "string" ? input.schema : "", schema = Object.hasOwn(schemas,schemaName) ? (schemas as Record<string,unknown>)[schemaName] : null, prompt = typeof input.prompt === "string" ? input.prompt : "";
  if (!schema || !prompt) return reply(400, { error: "Invalid AI request." });
  const system = systemFor(input, schemaName), max = schemaName === "coach" ? 6000 : schemaName === "profile" ? 2200 : schemaName === "subtasks" ? 1000 : 4000;
  try {
    const r = await gemini({ model: c.model, input: prompt, system_instruction: system, generation_config: { thinking_level: schemaName === "coach" ? "low" : "medium", max_output_tokens: max }, response_format: { type: "text", mime_type: "application/json", schema }, store: false });
    const data: any = await r.json().catch(() => ({})), text = outputText(data);
    if (r.ok && text) { try { return reply(200, { text: normalizeJSON(text, schemaName, input.memoryEnabled !== false) }); } catch (e) { console.error("Invalid structured JSON"); } }
    else { console.error("Gemini structured call failed", r.status); if (r.status === 429) return reply(429, { error: "AI is busy. Try again in a moment." }); }
    if (schemaName === "coach") { const fallback = await gemini({ model: c.model, input: prompt, system_instruction: system.replace("Return only the requested JSON object matching the supplied schema.", "For this fallback call return only the natural-language assistant reply; do not output JSON or actions."), generation_config: { thinking_level: "low", max_output_tokens: 2200 }, store: false }, 8_000); const fd: any = await fallback.json().catch(() => ({})), ft = outputText(fd); if (fallback.ok && ft) return reply(200, { text: JSON.stringify({ reply: ft.trim(), memories: [], actions: [] }) }); if (fallback.status === 429) return reply(429, { error: "AI is busy. Try again in a moment." }); }
    return reply(502, { error: "AI could not complete this request." });
  } catch (e) { console.error("Gemini connection failed"); return reply(502, { error: "AI connection failed." }); }
});
