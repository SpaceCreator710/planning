> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0 — Built-in AI activation + School mode

> **Current production AI path:** the iOS app is configured for the Supabase `planning-ai` Edge Function using server-side `GEMINI_API_KEY`. Any Groq/OpenRouter/Netlify instructions below are retained only as a legacy optional backend path. Never put provider secrets in the app bundle.


## What is now built in

Planning AI has three separate experiences:

- **Planning** — schedule, tasks, goals, replanning and execution.
- **School** — a dedicated tutor, separate from Planning mode.
- **General** — broad questions, explanations, comparisons and brainstorming.

School mode includes:

- Explanation level: **1st–12th grade / College / University / Professional**.
- Optional **interactive one-step replies**. When enabled, the tutor explains one meaningful step and waits before continuing.
- Optional **ASCII/text diagrams** for geometry, graphs, coordinates and processes. The iOS chat renders fenced text diagrams in a monospaced accent-tinted glass block.
- **Check yourself**: the tutor can give a similar unsolved problem, wait for the learner's attempt, then check it and explain the first mistake.
- A quick **Repeat simpler** action for the current step.

The three modes use separate default conversation threads so school tutoring does not get mixed into planning coaching.

## How to activate built-in AI

The iOS app intentionally contains **no provider API key** and no API-key input field. The secret belongs on the server.

1. Deploy the `Backend/` directory as a Netlify site.
2. In Netlify project environment variables, add **one** provider key:
   - `GROQ_API_KEY` (preferred by the supplied server configuration), or
   - `OPENROUTER_API_KEY`.
3. Optional model variables are shown in `Backend/.env.example`.
4. Copy the public HTTPS URL of the deployed site, for example `https://your-planning-ai.netlify.app`.
5. Open `Config.xcconfig` and set:

   `AI_API_BASE_URL = https://your-planning-ai.netlify.app`

   Do **not** append `/api/ai`; the app adds that path itself.
6. Rebuild Planning in Xcode and install it.
7. In Planning open **Profile / Settings → Built-in AI → Check AI connection**.
8. When it shows **Built-in AI is ready**, Planning, School and General AI modes work without the user entering any key.

## Security rule

Never put `GROQ_API_KEY`, `OPENROUTER_API_KEY`, or any other provider secret in `Config.xcconfig`, Swift code, Info.plist, Git, or the app bundle. Only the public backend URL belongs in the iOS project.
