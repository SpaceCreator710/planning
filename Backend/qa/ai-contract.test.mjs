import assert from 'node:assert/strict';
import fs from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { ACTION_TYPES, SETTING_KEYS, PROFILE_KEYS } from '../supabase/functions/planning-ai/schema.mjs';
import { normalizeAndValidate, acceptedClientKey, readBoundedBody } from '../supabase/functions/planning-ai/validation.mjs';
import { handler } from '../netlify/functions/ai.mjs';

const encode = actions => JSON.stringify({reply:'Review these changes.',memories:[],actions});
const source = fs.readFileSync(new URL('../../Planning/Store/AppStore.swift',import.meta.url),'utf8');
for (const type of ACTION_TYPES) assert.ok(source.includes('"'+type+'"'),'Missing action: '+type);
for (const key of SETTING_KEYS) assert.ok(source.includes('"'+key.replace('timePolicy.','')+'"'),'Missing setting: '+key);
for (const key of PROFILE_KEYS) assert.ok(source.includes('"'+key+'"'),'Missing profile field: '+key);
assert.equal(ACTION_TYPES.length,117);
const action = {type:'create_workspace_page',title:'Project',body:'Notes'};
assert.equal(JSON.parse(normalizeAndValidate(encode([action]),'coach')).actions.length,1);
for (const invalid of [
  {type:'unknown'}, {type:'set_setting',key:'subscription',value:'pro'},
  {type:'set_profile',key:'avatarImageData',value:'data'},
  {type:'create_task',durationMinutes:-1}, {type:'create_task',durationMinutes:481},
  {type:'create_task',title:null}, {type:'create_task',unknown:true},
  {type:'set_setting',key:'notificationsEnabled',boolValue:'true'}
]) assert.throws(()=>normalizeAndValidate(encode([invalid]),'coach'));
assert.throws(()=>normalizeAndValidate(encode(Array(41).fill({type:'open_quick_add'})),'coach'));
assert.throws(()=>normalizeAndValidate('{}','__proto__'));
assert.throws(()=>normalizeAndValidate('null','coach'));
assert.equal(JSON.parse(normalizeAndValidate(JSON.stringify({reply:'OK',memories:[{category:'goal',fact:'Remember',confidence:1}],actions:[]}),'coach',false)).memories.length,0);
assert.ok(acceptedClientKey('legacy',{SUPABASE_PUBLISHABLE_KEYS:'{}',SUPABASE_ANON_KEY:'legacy'}));
assert.ok(acceptedClientKey('public',{SUPABASE_PUBLISHABLE_KEYS:'{"default":"public"}'}));
assert.ok(!acceptedClientKey('sb_secret_private',{SUPABASE_ANON_KEY:'sb_secret_private'}));
assert.ok(!acceptedClientKey('',{}));
const request = text => new Request('https://example.test',{method:'POST',body:text});
assert.equal(await readBoundedBody(request('Привет'),12),'Привет');
await assert.rejects(()=>readBoundedBody(request('Привет'),11),RangeError);

process.env.AI_PROVIDER='openrouter'; process.env.OPENROUTER_API_KEY='qa-key-not-real';
let captured;
globalThis.fetch=async (_url,options)=>{
  captured=JSON.parse(options.body);
  return Response.json({choices:[{message:{content:encode([action])}}]});
};
const response=await handler({httpMethod:'POST',headers:{'x-nf-client-connection-ip':'198.51.100.23'},body:JSON.stringify({schema:'coach',assistantMode:'workspace',memoryEnabled:false,prompt:'Create page'})});
assert.equal(response.statusCode,200);
assert.equal(JSON.parse(JSON.parse(response.body).text).actions[0].type,'create_workspace_page');
assert.ok(captured.messages[0].content.includes('WORKSPACE') && captured.messages[0].content.includes('OFF'));
assert.equal(captured.max_tokens,6000);
assert.equal((await handler({httpMethod:'POST',body:'null'})).statusCode,400);
assert.equal((await handler({httpMethod:'POST',body:'💎'.repeat(70_000)})).statusCode,413);

// Execute the actual Supabase handler with only Deno registration/environment and provider I/O replaced.
let supabase;
globalThis.Deno={env:{get:key=>({SUPABASE_ANON_KEY:'public-test',GEMINI_API_KEY:'qa-gemini-not-real'})[key]},serve:fn=>{supabase=fn;}};
let entry=fs.readFileSync(new URL('../supabase/functions/planning-ai/index.ts',import.meta.url),'utf8');
entry=entry.replace(/^import "jsr:.*";\n/m,'').replaceAll('./schema.ts',new URL('../supabase/functions/planning-ai/schema.mjs',import.meta.url).href).replaceAll('./prompt.ts',new URL('../supabase/functions/planning-ai/prompt.mjs',import.meta.url).href).replaceAll('./validation.mjs',new URL('../supabase/functions/planning-ai/validation.mjs',import.meta.url).href);
await import('data:text/javascript;base64,'+Buffer.from(stripTypeScriptTypes(entry)).toString('base64'));
globalThis.fetch=async()=>Response.json({steps:[{type:'model_output',content:[{type:'text',text:encode([action])}]}]});
const supaRequest=(body,key='public-test')=>new Request('https://example.test',{method:'POST',headers:{apikey:key},body});
const supaResult=await supabase(supaRequest(JSON.stringify({schema:'coach',prompt:'Create page',assistantMode:'workspace',memoryEnabled:false})));
assert.equal(supaResult.status,200);
assert.equal(JSON.parse((await supaResult.json()).text).actions[0].type,'create_workspace_page');
assert.equal((await supabase(supaRequest('{}','wrong'))).status,401);
assert.equal((await supabase(supaRequest('null'))).status,400);
assert.equal((await supabase(supaRequest('💎'.repeat(70_000)))).status,413);
delete process.env.AI_PROVIDER; delete process.env.OPENROUTER_API_KEY;
console.log('AI contract tests: PASS ('+ACTION_TYPES.length+' actions, '+SETTING_KEYS.length+' settings, '+PROFILE_KEYS.length+' profile fields; both handlers exercised)');
