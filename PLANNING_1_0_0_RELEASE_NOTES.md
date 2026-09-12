> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Final Release Package

## Three complete experiences

- **Planner** — the execution-first Planning experience: Today, Calendar, AI, Health and More.
- **Hybrid** — a combined command center where live schedule, projects and workspace knowledge are visible and actionable together.
- **Workspace** — a knowledge/project operating mode with pages, databases, canvas, graph, projects, meetings, automations, forms, publishing, search and agent workflows.
- A single **Memory everywhere** switch controls learned cross-mode AI memory. Turning it off does not delete explicit user content such as tasks, pages, notes or projects.

## Live Timeline and Planning Intelligence

The same underlying day schedule powers Horizontal, Vertical and Orbit, so timeline mutations are layout-independent. Week tools operate across the seven underlying day plans where week semantics are useful.

- Flow Shift, Reality, Gravity, Time Machine and Magnetic Compress.
- Buffer Guard, Auto Lock, Focus Shield, Recovery Buffers, Conflict Sweep and Deadline Radar.
- Energy Fit, Overload Guard, Context Batching, Travel Buffer and Focus Budget.
- Meeting Defrag, Momentum Chain, Deadline Backplan, Habit Rescue and No-Meeting Guard.
- Deep Work Reserve and Context Switch Shield.
- Week-level Reality, Compress, Buffer Guard, Conflict Sweep, Focus protection, Deadline reasoning and Time Machine controls.

## Workspace

- Markdown-style pages/wiki, nested pages, tags, aliases, favorites, verified pages and locked knowledge.
- Wiki links, backlinks, relations and a visual knowledge graph.
- Databases with Table, Board, Calendar, List, Gallery, Timeline, Form, Chart and Map views.
- Custom properties including text, number, select/multi-select, status, people, files, rating, location, relation, rollup, formula and progress.
- Canvas nodes/edges for spatial thinking.
- Projects, milestones, dependencies, roadmaps and auto-scheduling into Planning.
- Forms connected to databases.
- Workspace automations and reusable custom agents.
- Meeting notes, decisions and action-item extraction.
- Scheduling links, Smart Meetings and protected focus-time policies.
- Weekly Autopilot for projects, habits, focus time, meetings and enabled Planning Intelligence rules.
- Web Clipper / Read Later, daily notes, templates and import/export.
- Comments, page version history and restore.
- Sites/presentation flow for publishable page snapshots.
- Time tracking linked to projects/tasks.
- Saved searches, universal search and Command Palette.
- Unified Inbox for planner Inbox, unread clips, comments, project risk and overdue tasks.
- Page AI for improve, summarize, extract actions and convert knowledge into execution.

## Agentic AI

`Planning AI` is an operational agent over represented user data, not only a chat surface. It can create and edit tasks, schedules, goals, habits, notes, Inbox items, workspace objects, projects, databases, forms, meetings, automations, scheduling links, timeline layouts, timeline intelligence and explicitly allowed preferences. Workspace Agent and Page AI bridge knowledge into execution.

Security-sensitive operations remain intentionally outside autonomous AI control: billing/subscription entitlements, sign-in providers, account deletion/recovery, API keys, secrets and backend security configuration require direct user control.

The production iOS client calls the Supabase `planning-ai` Edge Function. Gemini credentials remain only in Supabase Edge Function Secrets; no provider secret is embedded in the app.

## Account and onboarding

- Google, Apple and GitHub entry points plus email verification code flow.
- Profile screen with provider linking/unlinking, full data export/save and account deletion/recovery workflow.
- Seven-day recoverable deletion design with final purge infrastructure.
- Re-runnable Onboarding from More, Required/Optional markers and defer/skip behavior.

## Release boundary

Planning now covers a broad combined planner/workspace/knowledge/automation surface. This package does **not** claim that static source parity proves superiority over every competitor or reproduces every enterprise service feature. Real-time multi-user collaboration, external enterprise identity administration and provider-side services still depend on production backend/platform configuration and real-device acceptance testing.
