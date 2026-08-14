# AI provider decision — August 2026

## Selected route

Plan Your Day uses Groq's OpenAI-compatible chat completions endpoint with:

```text
model=openai/gpt-oss-120b
```

The key lives in the Netlify server environment as `GROQ_API_KEY`. This gives the app one stable `/api/ai` contract and keeps the key out of browser and mobile bundles.

## One connection mode

- **Built-in AI:** the only product path, with a shared protected server key, quotas and no key field for users.

The client calls the server endpoint, and all returned JSON is validated before it can change a plan.

## Availability truth

Groq can be rate-limited or temporarily unavailable. Public release needs authenticated account quotas, a budget alert and a funded fallback plan. The interface reports understandable provider failures without exposing the key.
