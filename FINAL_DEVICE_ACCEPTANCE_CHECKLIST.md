> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Physical-device acceptance checklist

Run this once on the final signed build before App Store submission.

## Build and identity
- [ ] Open `Planning.xcodeproj` and build the `Planning` scheme in Release configuration.
- [ ] Home Screen name is `Planning`.
- [ ] Version/build shows `1.0.0 (1)` in More → About.
- [ ] Planning Widgets and Save to Planning appear correctly.
- [ ] Main app and extensions use the same valid Developer Team and resolve their capabilities.

## Core product
- [ ] Complete onboarding from a fresh install with no account and no API-key prompt.
- [ ] Today, Calendar, AI, Notes and More tabs all open without crashes.
- [ ] Add/edit/delete/complete/reopen/duplicate tasks and subtasks.
- [ ] Recurrence and reminders behave correctly.
- [ ] Notes, Inbox, Goals, Progress, Review, Health, Memory, Horizon and Focus all handle empty and populated states.

## Live Timeline
- [ ] Day timeline is cardless/full-width and remains readable in Light and Dark mode.
- [ ] Day and Week navigation/swipes select the correct date/week.
- [ ] NOW marker and active-task progress update over time.
- [ ] NOW Lens/detail zoom/semantic zoom behave smoothly.
- [ ] Drag/drop snaps as intended and fixed commitments resist collisions.
- [ ] Flow Shift and Push The Day move only eligible flexible tasks.
- [ ] Ghost Future preview matches the committed change.
- [ ] Reality Layer, task overrun, buffers and Time Machine display correctly.
- [ ] Open Space creates a task at the selected free time.

## Built-in AI
- [ ] No provider/API-key entry field exists anywhere in the client.
- [ ] More → Built-in AI reports Ready against the deployed HTTPS backend.
- [ ] AI plan, replan, coach, subtasks, profile analysis and Horizon calls work on a fresh install.
- [ ] Disconnect the network/server and confirm deterministic fallback behavior stays usable.

## Apple integrations
- [ ] Calendar permissions/import/refresh work.
- [ ] Health permission and empty/partial-data states work.
- [ ] Notifications fire at expected task/reminder times.
- [ ] Widgets refresh and interactive actions work.
- [ ] Focus Live Activity/Dynamic Island starts, updates and finishes.
- [ ] Share Extension captures supported text/URLs.
- [ ] iCloud/CloudKit sync is verified on two signed devices if enabled for release.

## Accessibility and quality
- [ ] Light, Dark and System appearances checked.
- [ ] Dynamic Type does not hide critical controls.
- [ ] VoiceOver labels and action order are usable on primary flows.
- [ ] Keyboard dismissal does not block taps/scrolling.
- [ ] Dense day/week data remains smooth on the oldest supported iPhone.
- [ ] No launch/runtime crash appears in a TestFlight smoke pass.

## Deferred systems
- [ ] `ACCOUNTS_ENABLED` remains `NO` until registration is intentionally launched.
- [ ] `SUBSCRIPTIONS_ENABLED` remains `NO` until StoreKit products are intentionally launched.
