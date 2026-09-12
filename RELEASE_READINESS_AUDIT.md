> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Release readiness

> **Current production AI path:** the iOS app is configured for the Supabase `planning-ai` Edge Function using server-side `GEMINI_API_KEY`. Any Groq/OpenRouter/Netlify instructions below are retained only as a legacy optional backend path. Never put provider secrets in the app bundle.


Audit date: 2026-08-20

## Code-side release state

The active product is branded `Planning`, version `1.0.0` build `100`. The client is local-first, registration and payments are gated off by default, and provider-backed AI uses a protected backend only. No user provider-key flow remains.

The primary product surfaces, timeline mechanics, task system, planner/coach AI flows, focus, notes/inbox, goals/progress/review, integrations, widgets/extensions, persistence and release gating are present in source and pass the static/regression checks available here.

## Required external setup for this release

1. Choose the final Apple Developer Team and resolve the existing App Group/iCloud/Health/associated capabilities in Xcode.
2. Deploy `Backend/` to the chosen server host.
3. Set one provider secret in the server environment (`GROQ_API_KEY` preferred or `OPENROUTER_API_KEY` fallback).
4. Put only the public HTTPS server base URL in `AI_API_BASE_URL`.
5. Keep `ACCOUNTS_ENABLED = NO` and `SUBSCRIPTIONS_ENABLED = NO` until those systems are intentionally launched later.
6. Complete the signed device/TestFlight checklist.

## Release claim boundary

It is not technically honest to promise that any nontrivial app will never require a future fix. This package is the code-side 1.0.0 final candidate; final App Store release confidence requires the Apple runtime/device tests listed in `FINAL_DEVICE_ACCEPTANCE_CHECKLIST.md`.
