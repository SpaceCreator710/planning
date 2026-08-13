# Architecture

## Cross-platform client

- Expo SDK 57, React Native, Expo Router and Reanimated.
- `AppProvider` owns versioned local state, plans, device imports, notes, health summaries, subscriptions and behavior history.
- Platform-specific adapters keep native APIs out of Web bundles: `device-calendar`, `health-bridge`, personal key storage and widget bridge.
- Completed tasks and protected calendar events survive every AI and offline replan.

## Protected AI path

1. The client sends minimum required planning context to `/api/ai`.
2. Netlify routes it to `netlify/functions/ai.mjs`.
3. The function calls OpenRouter with `model="deepseek/deepseek-v4-flash:free"` and a server-only bearer key.
4. The provider response is normalized and validated before it can alter product state.
5. If remote AI is unavailable, deterministic local planning keeps the app usable.

The private test path sends a personal key directly from one device to OpenRouter. Native stores it in Keychain; Web uses session storage. It is deliberately separate from synced app state.

## Apple data path

- Expo Calendar requests explicit Calendar and Reminders permissions, imports a bounded date range and upserts by external identifiers.
- Important all-day dates and fixed events are marked protected for replanning.
- The local `capacity-health` Expo module requests read-only HealthKit types and returns day summaries.
- Raw HealthKit objects stay on device. The AI receives only an optional coarse capacity context.
- Expo Sharing provides incoming text/URL sharing and system share-sheet export. It does not read the Apple Notes database.
- Expo Widgets publishes a compact next-action snapshot through the shared app group.

## Privacy and safety

- No provider, Supabase service-role, billing or webhook secret is present in the client bundle.
- Calendar and health sync are opt-in and remain useful when disabled.
- Health features do not diagnose, count calories, set weight targets or pressure exercise.
- Aggressive coaching remains action-focused and cannot insult, shame, threaten or target a person's identity or health.
