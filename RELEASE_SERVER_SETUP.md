> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Built-in AI — one-time server deployment

> **Current production AI path:** the iOS app is configured for the Supabase `planning-ai` Edge Function using server-side `GEMINI_API_KEY`. Any Groq/OpenRouter/Netlify instructions below are retained only as a legacy optional backend path. Never put provider secrets in the app bundle.


Planning's iOS app is server-only for provider inference. There is no user API-key field and no direct provider fallback in the client.

1. Deploy the `Backend/` folder to Netlify.
2. In the deployment environment set either `GROQ_API_KEY` (preferred in the supplied configuration) or `OPENROUTER_API_KEY`. The value must remain server-side.
3. Optionally set the corresponding model environment variable from `Backend/.env.example`.
4. Set `AI_API_BASE_URL = https://<your-deployment>.netlify.app` in `Config.xcconfig`. This public URL is safe to ship; the provider credential is not.
5. Run `node Backend/qa/server-function.test.mjs`.
6. On a device, open More → Built-in AI and run the connection check. A fresh install must work without entering any provider credential.

Registration and StoreKit payment setup are independent from the AI boundary and can be connected later.
