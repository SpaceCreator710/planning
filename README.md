# Plan Your Day

An adaptive visual planner for iOS, Android and Web. It combines a colorful connected timeline, calendar, tasks, habits, notes, health context and an AI coach without copying Structured's screen layout.

## Product surface

- Day Chain with connected color blocks, long-press drag, free-time windows, subtasks, task notes, icons, recurrence and reminders.
- Flow Calendar with day, week, month and year views plus Apple Calendar and Reminders sync on iOS. Deleted device events are reconciled and local plans can be written back without duplicates.
- Built-in Notes with search, Inbox conversion, incoming Share Extension support and export to the iOS share sheet, including Apple Notes.
- Built-in Health with manual check-ins, saved history, sleep, steps, activity, standing, distance and workout sessions; iOS can read the user's approved Apple Health summaries.
- Capacity Twin adapts workload from the user's schedule and optional private wellness summary. Raw HealthKit samples are never sent to AI.
- Collision Radar protects fixed calendar events and important dates before AI moves unfinished work.
- AI plans, replans and coaching through the protected Groq server using `openai/gpt-oss-120b`.
- Soft, Strict and controlled Aggressive coach modes with distinct language. Aggressive mode is direct and provocative, never insulting, threatening or humiliating.
- Ten accents, six whole-app canvases, colorful task palettes, SF Symbols, rounded controls and spring-based transitions.
- iOS Next Action widget, notifications, Inbox, goals, habits, focus timer, analytics and day reviews.

Apple integrations require an iOS development/release build. They cannot run in Expo Go or a web browser. Android and Web keep the built-in calendar, notes, health log and `.ics` portability.

## Run and verify

```bash
npm install
npm test
npm run export:web
```

For native Apple modules, use a development build rather than Expo Go:

```bash
npx expo prebuild --platform ios
npx expo run:ios
```

## Connect Groq

Production uses one server-held key:

1. Deploy the complete source project to Netlify. Do not upload only `dist`.
2. In Netlify environment variables set:

```text
GROQ_API_KEY=your_secret_key
GROQ_MODEL=openai/gpt-oss-120b
```

3. Redeploy. Web calls `/api/ai`; native builds use `EXPO_PUBLIC_AI_ENDPOINT=https://YOUR_SITE/api/ai`.

People using the app never enter an API key. A key must never be written into source code or an `EXPO_PUBLIC_*` variable because both web and mobile bundles are readable by users.

See `docs/PRODUCTION_SETUP.md` for release requirements and `DEPLOY_AI_RU.md` for the short Russian setup.
