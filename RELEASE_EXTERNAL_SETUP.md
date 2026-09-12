> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — External release setup

> **Current production AI path:** the iOS app is configured for the Supabase `planning-ai` Edge Function using server-side `GEMINI_API_KEY`. Any Groq/OpenRouter/Netlify instructions below are retained only as a legacy optional backend path. Never put provider secrets in the app bundle.


Only services that cannot be embedded safely in source belong here.

## Apple signing

Assign the same valid Apple Developer Team to the Planning app, widget extension and share extension. Resolve the existing App Group, iCloud/CloudKit, HealthKit and notification capabilities under that team.

## Built-in AI — required for real provider-backed AI

Deploy `Backend/` to a public HTTPS host. In the server environment, set either:

```text
GROQ_API_KEY=<server secret>
```

or:

```text
OPENROUTER_API_KEY=<server secret>
```

Then set the public endpoint in `Config.xcconfig`:

```text
AI_API_BASE_URL = https://YOUR-PROTECTED-AI-BACKEND.example
```

Never put the provider secret itself in `Config.xcconfig`, Info.plist, Swift source or the app bundle.

## Registration — deferred

Keep:

```text
ACCOUNTS_ENABLED = NO
```

When registration is intentionally launched later, configure the public Supabase URL/publishable key, OAuth providers and `planning://auth/callback`, then switch the flag to `YES`.

## Payments — deferred

Keep:

```text
SUBSCRIPTIONS_ENABLED = NO
```

When monetization is intentionally launched later, create/test the matching App Store products and only then switch the flag to `YES`.
