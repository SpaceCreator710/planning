import { schemas, SETTING_KEYS, PROFILE_KEYS } from './schema.mjs';
export const MAX_REQUEST_BYTES = 256_000;
export function acceptedClientKey(supplied, env) {
  if (typeof supplied !== 'string' || !supplied || supplied.startsWith('sb_secret_')) return false;
  let named = [];
  try { named = Object.values(JSON.parse(env.SUPABASE_PUBLISHABLE_KEYS || '{}')); } catch {}
  return [...named, env.SUPABASE_PUBLISHABLE_KEY, env.SUPABASE_ANON_KEY].some(key => typeof key === 'string' && key.length > 0 && key === supplied);
}
export async function readBoundedBody(request, limit = MAX_REQUEST_BYTES) {
  if (Number(request.headers.get('content-length') || 0) > limit) throw new RangeError('Request is too large');
  if (!request.body) return '';
  const reader = request.body.getReader(), chunks = [];
  let total = 0;
  try {
    while (true) {
      const {value, done} = await reader.read();
      if (done) break;
      total += value.byteLength;
      if (total > limit) { await reader.cancel(); throw new RangeError('Request is too large'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return new TextDecoder('utf-8', {fatal:true}).decode(bytes);
}
function validate(value, schema, path = '$') {
  if (schema.type === 'object') {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(path + ': object required');
    for (const key of schema.required || []) if (!Object.hasOwn(value,key)) throw new Error(path + ': missing field');
    for (const [key, child] of Object.entries(value)) {
      if (!Object.hasOwn(schema.properties || {},key)) {
        if (schema.additionalProperties === false) throw new Error(path + ': unknown field');
      } else validate(child,schema.properties[key],path+'.'+key);
    }
  } else if (schema.type === 'array') {
    if (!Array.isArray(value) || value.length < (schema.minItems || 0) || value.length > (schema.maxItems || 1000)) throw new Error(path + ': invalid array');
    value.forEach((v,i)=>validate(v,schema.items,path+'['+i+']'));
  } else if (schema.type === 'string') {
    if (typeof value !== 'string' || value.length > (schema.maxLength || 32_000)) throw new Error(path + ': invalid text');
  } else if (schema.type === 'boolean') {
    if (typeof value !== 'boolean') throw new Error(path + ': boolean required');
  } else if (schema.type === 'integer' || schema.type === 'number') {
    if (typeof value !== 'number' || !Number.isFinite(value) || (schema.type === 'integer' && !Number.isInteger(value)) || value < (schema.minimum ?? -Infinity) || value > (schema.maximum ?? Infinity)) throw new Error(path + ': invalid number');
  }
  if (schema.enum && !schema.enum.includes(value)) throw new Error(path + ': invalid choice');
}
export function normalizeAndValidate(text,schemaName,memoryEnabled = true) {
  if (!Object.hasOwn(schemas,schemaName)) throw new Error('Unknown schema');
  let candidate = text.trim().replace(/^```(?:json)?\s*/i,'').replace(/\s*```$/,'');
  const first = candidate.indexOf('{'), last = candidate.lastIndexOf('}');
  if (first >= 0 && last >= first) candidate = candidate.slice(first,last+1);
  const value = JSON.parse(candidate);
  if (schemaName === 'coach' && !memoryEnabled && value && typeof value === 'object') value.memories = [];
  validate(value,schemas[schemaName]);
  if (schemaName === 'coach') for (const action of value.actions) {
    if (action.type === 'set_setting' && !SETTING_KEYS.includes(action.key)) throw new Error('Unknown setting');
    if (action.type === 'set_profile' && !PROFILE_KEYS.includes(action.key)) throw new Error('Unknown profile field');
  }
  return JSON.stringify(value);
}
