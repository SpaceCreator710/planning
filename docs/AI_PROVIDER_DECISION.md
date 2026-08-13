# AI provider decision — August 2026

## Selected route

AI Plan Your Day uses OpenRouter's OpenAI-compatible chat completions endpoint with:

```text
model=deepseek/deepseek-v4-flash:free
```

The primary key lives in the Netlify server environment as `OPENROUTER_API_KEY`. This gives the app one stable `/api/ai` contract and keeps the key out of browser and mobile bundles.

## Why there are two connection modes

- **Built-in AI:** the production path, shared server key, quotas and no key field for normal users.
- **Personal test AI:** a troubleshooting path for the owner before server deployment. Native uses Keychain and Web uses session-only storage.

The client first tries the server endpoint and can fall back to the connected personal test key. Both paths use the same exact model slug and validate returned JSON.

## Availability truth

A free route can be rate-limited, changed or temporarily unavailable. Public release needs authenticated account quotas, an OpenRouter budget alert and a configured paid fallback model. The interface reports understandable 401/403, 402, 404, 429 and provider failures without exposing the key.
