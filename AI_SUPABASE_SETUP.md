> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning AI — Supabase Edge Function

Current iOS endpoint is configured through `AI_API_BASE_URL` and points to the Supabase Edge Function `planning-ai`.

## Required server secret

In Supabase Dashboard → Edge Functions → Secrets keep:

- `GEMINI_API_KEY` = Gemini API key

Optional deployment overrides:

- `GEMINI_MODEL` — defaults to `gemini-3.7-flash` in the supplied Edge Function.
- `GEMINI_INTERACTIONS_URL` — normally leave unset.

Never put `GEMINI_API_KEY` in Xcode, Info.plist, Config.xcconfig, Swift source, Git or the app bundle. The iOS application contains only the Supabase public project configuration and calls the Edge Function.

The function validates the Supabase publishable/anon key, applies an in-function request limit and keeps provider credentials server-side. Account/auth hardening can additionally require authenticated user JWTs before a public production launch.
