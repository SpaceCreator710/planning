> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Product acceptance matrix

Date: 2026-08-20

`SOURCE PASS` means the behavior is present in the repository and passed the static/regression checks available here. `DEVICE REQUIRED` means Apple runtime validation remains mandatory.

| Area | Acceptance | Status |
|---|---|---|
| Product identity | Planning project/scheme/target/product and visible app branding | SOURCE PASS |
| Welcome/onboarding | Fresh install works without account or provider-key setup | SOURCE PASS / DEVICE REQUIRED |
| Today | Live Day/Week timeline and main daily actions | SOURCE PASS / DEVICE REQUIRED |
| Timeline mechanics | NOW, Lens/zoom, Flow Shift, Push The Day, Ghost Future, Reality Layer, Open Space, collisions, buffers, Time Machine | SOURCE PASS / DEVICE REQUIRED |
| Tasks | Timed/all-day/inbox, subtasks, duplicate/move, recurrence, reminders, appearance | SOURCE PASS / DEVICE REQUIRED |
| Calendar | Day/month navigation and Apple Calendar integration | SOURCE PASS / DEVICE REQUIRED |
| AI | Server-only provider inference, planner/replan/coach/subtasks/profile/horizon, no user API-key field | SOURCE PASS / BACKEND REQUIRED |
| Offline behavior | Deterministic local planning/coach fallbacks when AI backend is unavailable | SOURCE PASS |
| Focus | Multi-round focus/break flow and Live Activity integration | SOURCE PASS / DEVICE REQUIRED |
| Personal planning | Goals, Progress, Day Review, Health & Capacity, AI Memory, Horizon | SOURCE PASS / DEVICE REQUIRED |
| Notes/Inbox | Notes plus quick capture, empty states and deletion | SOURCE PASS / DEVICE REQUIRED |
| Settings/More | Appearance, integrations, Built-in AI status, About | SOURCE PASS / DEVICE REQUIRED |
| Widgets/extensions | Widgets, interactive intents, Live Activity, Share Extension | SOURCE PASS / DEVICE REQUIRED |
| Persistence | Local persistence, App Group snapshot, private CloudKit path | SOURCE PASS / DEVICE REQUIRED |
| Accounts | Explicitly gated with `ACCOUNTS_ENABLED = NO` for current release | SOURCE PASS |
| Payments | Explicitly gated with `SUBSCRIPTIONS_ENABLED = NO`; features unlocked | SOURCE PASS |
| Security | Provider secrets excluded from iOS client; backend-only credential boundary | SOURCE PASS |
| Static validation | Swift parse, core regressions, backend tests, plist/project/entitlement/privacy lint | PASS |
| Signed release build | Xcode compile/link/sign/archive/TestFlight | DEVICE/MAC REQUIRED |
| Accessibility/performance | Dynamic Type, VoiceOver, memory/energy/animation acceptance | DEVICE REQUIRED |

## Acceptance conclusion

The codebase is prepared as the Planning 1.0.0 final code candidate. Registration and payments are deliberately deferred behind release flags. A real built-in AI deployment and the signed Apple-device acceptance pass are the remaining external/runtime gates before an App Store submission.
