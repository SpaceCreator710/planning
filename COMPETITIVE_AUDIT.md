> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Competitive capability audit

Planning's goal is not to clone one product. The release combines the highest-value patterns from planning, automatic scheduling and knowledge-work tools into a single local-first iOS product model.

## Structured-style execution coverage

- Daily timeline and seven-day week timeline.
- Inbox, tasks, events, all-day work, recurrence, subtasks, notes and semantic icons.
- Calendar-aware scheduling and drag/reflow timeline behaviors.
- Horizontal, Vertical and Orbit day layouts backed by the same schedule state.

## Motion/Reclaim-style automation coverage

- Project and task auto-scheduling.
- Focus protection and focus-time budgets.
- Habits scheduled into the live plan.
- Smart Meetings and scheduling links.
- Buffers, conflict repair, work/meeting windows and no-meeting policy.
- Weekly Autopilot and enabled Planning Intelligence rules.
- Meeting notes/actions, project risk and time tracking.

## Notion-style workspace coverage

- Pages/wiki, nested structure, tags, aliases, backlinks and verification/locks.
- Databases, multiple views, relations, formulas, rollups, forms and charts/map view models.
- Projects/roadmaps, templates, spaces, automations, comments and version history.
- Canvas, search, command palette, web clips/read-later and publishing/presentation flow.
- AI on pages, workspace agent, reusable custom agents and Unified Inbox.

## Obsidian-style knowledge coverage

- Markdown-style content, wiki links/backlinks, aliases and tags.
- Knowledge graph and Canvas-style spatial notes.
- Database/Bases-like structured collections.
- Offline-first app data model with cloud snapshot support when enabled.

## Planning-specific differentiation

- Planner / Hybrid / Workspace as full-app operating modes over one data model.
- Cross-mode memory master switch.
- Knowledge-to-execution bridge: pages/meetings/database work can become real scheduled tasks.
- Timeline Intelligence suite: Flow Shift, Reality, Gravity, Time Machine, Magnetic Compress, buffers, conflict repair, deadline backplanning, energy fit, context batching, deep-work reserve and more.
- One agent action layer spanning planner and workspace content while maintaining explicit security boundaries.

## Audit boundary

Feature names and static source coverage do not prove market superiority. External services such as real-time multi-user collaboration, enterprise SSO/admin, third-party provider reliability, App Store billing and production-scale backend behavior require separate platform setup and real-world validation.
