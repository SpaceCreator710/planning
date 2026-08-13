# Production setup

## 1. OpenRouter AI

The release path is a protected Netlify function. Set these server-only variables:

```text
OPENROUTER_API_KEY=your_secret_key
OPENROUTER_MODEL=deepseek/deepseek-v4-flash:free
```

Deploy the whole repository so Netlify builds both `dist` and `netlify/functions/ai.mjs`. A drag-and-drop upload of static `dist` cannot run a secret-backed function.

Web automatically calls `/api/ai`. Native builds set only the non-secret endpoint:

```text
EXPO_PUBLIC_AI_ENDPOINT=https://YOUR_SITE.netlify.app/api/ai
```

The personal-key screen is a private testing fallback. It is not the production architecture and the app never saves that key in synced state.

Before public launch, add authenticated per-account quotas, an OpenRouter spending limit, origin restrictions and monitoring. Model availability on a free route is not guaranteed, so production should also support a paid fallback model.

## 2. Apple integrations

Use an iOS development or release build. Expo Go cannot load the custom HealthKit module, widget extension or Share Extension.

```bash
npx expo prebuild --platform ios
npx expo run:ios
```

Test on a physical iPhone:

- Calendar read/write and Reminders read permission;
- important-date import and duplicate prevention;
- Health read permissions for steps, exercise, standing, distance, resting heart rate, sleep and workouts;
- Share Extension receiving text/URLs and share-sheet export to Apple Notes;
- Next Action widget across supported families;
- denied, partial and later-revoked permissions.

The built-in Notes app can share with Apple Notes, but Apple does not expose a public API for mirroring the complete Notes database. Do not market this as two-way Apple Notes sync.

Health is a planning context, not a medical product. Do not diagnose, prescribe, rank bodies, count calories or pressure users to exercise. Raw HealthKit samples stay local; only a coarse capacity signal can influence a plan.

## 3. Authentication and sync

1. Create the production Supabase project and run `supabase/schema.sql`.
2. Set `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` during build.
3. Configure web and `aiplanyourday://auth/callback` redirect URLs.
4. Enable only the sign-in providers that are fully configured and tested.
5. Test Row Level Security with multiple accounts and account deletion.

Never place a service-role key in the app.

## 4. Billing

Local entitlements are only for UI testing. Before release, replace them with signed App Store/Google Play receipts and verified webhooks. Retrieve localized store prices instead of relying on hard-coded display values. Restore Purchases and account-transfer cases must be tested.

## 5. Release checklist

- Publish Privacy Policy, Terms, support contact and account-deletion flow.
- Complete App Store privacy labels for calendar, reminders and health data.
- Validate subscriptions, one-time Lifetime purchase and restore behavior.
- Run TestFlight on iPhone and iPad; run Android closed testing; check responsive Web.
- Verify accessibility, Dynamic Type, reduced motion, dark canvases and localization.
- Remove demo billing from production.
- Have the appropriate account owner control store, hosting, AI and merchant accounts.
