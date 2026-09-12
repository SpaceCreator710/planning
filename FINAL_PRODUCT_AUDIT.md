> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Final product audit

> **Current production AI path:** the iOS app is configured for the Supabase `planning-ai` Edge Function using server-side `GEMINI_API_KEY`. Any Groq/OpenRouter/Netlify instructions below are retained only as a legacy optional backend path. Never put provider secrets in the app bundle.


Audit date: 2026-08-20

This is the final code-side audit for the 1.0.0 package. It distinguishes repository completion from Apple/device and external-service checks that cannot be proven in a Linux build environment.

## Product identity

- Main Xcode project: `Planning.xcodeproj`.
- Main scheme/target/product: `Planning` / `Planning.app`.
- Home Screen display name: `Planning`.
- Widget display name: `Planning Widgets`.
- Share extension display name: `Save to Planning`.
- Primary URL scheme: `planning://`.
- Legacy bundle IDs, App Group IDs, widget kind IDs and the legacy `aiplanyourday://` URL alias are intentionally retained only where changing them could break provisioning, installed widgets, data migration or old deep links. They are not user-facing branding.
- Marketing version: `1.0.0`; build: `100`.

## Built-in AI

- There is no API-key/provider-key input field in the iOS app.
- There is no direct Groq/OpenRouter inference path in the iOS client.
- The app sends provider-backed AI requests only to the protected server boundary configured by `AI_API_BASE_URL`.
- Provider secrets belong only in the backend deployment environment (`GROQ_API_KEY` or `OPENROUTER_API_KEY`).
- The client validates HTTPS for release backend URLs; localhost HTTP is permitted only in Debug.
- Deterministic local planning/coach fallbacks remain available when the server is unreachable.
- `More → Built-in AI` is a status/connection screen, not a credential setup screen.

## Registration and payments

The requested 1.0.0 package is intentionally usable before registration and payment are connected.

- `ACCOUNTS_ENABLED = NO` hides and disables account/registration flows even if public Supabase values are accidentally present.
- `SUBSCRIPTIONS_ENABLED = NO` hides subscription UI and leaves product features unlocked.
- Both systems remain implemented behind explicit release flags so they can be connected later without redesigning the product.

## Primary surfaces audited

- Welcome and onboarding.
- Today and Live Timeline, including Day/Week, NOW, NOW Lens, semantic/detail zoom, Time Gravity, Flow Shift, Push The Day, Ghost Future, Reality Layer, Live Task overrun, Open Space, collision handling, buffer nodes and Time Machine.
- Calendar.
- AI Coach and AI planning/replanning.
- Notes and Inbox/Quick Capture.
- Task editor, subtasks, recurrence, reminders and appearance controls.
- Focus and Live Activity flow.
- Goals, Progress, Day Review, Health & Capacity, AI Memory and Horizon Planner.
- Profile/More, Settings and Integrations.
- Widgets, App Intents/Shortcuts, Control Center actions and Share Extension.
- Persistence, App Group snapshot, private CloudKit path and optional account cloud path.
- StoreKit gating and protected server AI boundary.

## Code-side validation completed

- Swift parser pass across production Swift sources.
- Core regression suite pass.
- Backend AI boundary tests pass.
- Xcode project, Info.plists, entitlements and privacy manifests pass `plutil -lint`.
- User-facing API-key entry scan: none found.
- Stale main project/target-name scan: none found in active setup/CI paths.
- No provider secret is intentionally bundled in the iOS source or release configuration.

## What still requires external proof

No source audit can certify that software will never need a future bug fix. Before an App Store submission, run the signed Xcode/device checklist: full Xcode compile/link, launch on supported iPhones, permissions, notifications, widgets/extensions, Live Activity, CloudKit, Dynamic Type/VoiceOver, performance and TestFlight smoke testing.

For real provider-backed built-in AI on a fresh install, the backend must also be deployed, a provider secret must be set in the server environment, and the public HTTPS backend URL must be placed in `AI_API_BASE_URL`. That secret must not be copied into the app.
