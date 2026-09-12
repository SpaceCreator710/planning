# Architecture

Planning 1.0.0 is an Apple-native client with a small protected server boundary for AI inference.

```text
SwiftUI app
├─ SwiftData / local app state
├─ EventKit (Calendar)
├─ HealthKit
├─ UserNotifications
├─ StoreKit 2
├─ WidgetKit / ActivityKit / App Intents
├─ Share Extension
├─ Supabase client boundary
└─ HTTPS → Netlify AI boundary → Groq/provider
```

## Targets

### Planning
The main iPhone/iPad application. It owns navigation, onboarding, planning, task editing, themes, AI Coach, health/capacity views, goals, habits, notes, focus, progress and settings.

### PlanningWidgets
Contains the planner widget, Focus Live Activity and Control Center/App Intent controls. Shared user-visible state crosses the process boundary through the configured App Group snapshot.

### ShareExtension
Accepts text, URLs and supported shared content and writes an import payload through the App Group for the main app to consume safely.

## Product engines

- Reality Engine / Drift Guard detects plan drift and recovery opportunities.
- Capacity Twin estimates practical workload from planned commitments and optional private wellness summaries.
- Plan DNA derives behavioral planning patterns from local history.
- Body Rhythm supplies optional time-of-day context.
- Collision checks protect fixed calendar commitments before replanning.

## AI boundary

The Swift client never contains a Groq/provider secret. Requests go to `Backend/netlify/functions/ai.mjs`, which validates the requested schema/operation and uses a server-held provider key.

## Data migration

The native client retains V7 JSON import/export compatibility so existing Expo-era planning data can be migrated rather than discarded.
