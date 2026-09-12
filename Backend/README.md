# AI Backend

This folder is deployed separately from the iOS client.

`netlify/functions/ai.mjs` is the protected server boundary used for planning, replanning, profile analysis, horizon planning, Coach actions and AI-generated subtasks.

## Environment variables

Configure provider credentials in the deployment environment, never in the iOS project. The client receives only the public backend base URL through `Config.xcconfig`.

Run the backend's included tests before deployment when changing request schemas or validation.
# RELEASE 11 — актуальная схема

В текущем Config.xcconfig iOS-клиент обращается к Supabase planning-ai. Обновлять нужно всю папку supabase/functions/planning-ai: index.ts, schema.ts, prompt.ts и общие schema.mjs, prompt.mjs, validation.mjs. Один старый index.ts с прежними зависимостями не представляет новый backend.

Внешнее развёртывание этой сборкой не выполнялось. Серверные переменные GEMINI_API_KEY и при необходимости GEMINI_MODEL / GEMINI_INTERACTIONS_URL остаются только на сервере. Клиенту нужны публичный URL и ключ приложения. Публичный ключ не заменяет JWT пользователя и серверные квоты перед платным публичным запуском.

Альтернатива Netlify сохраняет совместимый handler и использует тот же общий контракт из supabase/functions/planning-ai. Копировать только ai.mjs без общих модулей нельзя. Не разворачивайте сразу два варианта без необходимости.

Проверки из корня проекта на Node 24:

```bash
node Backend/qa/server-function.test.mjs
node Backend/qa/ai-contract.test.mjs
```

Эти тесты используют подставные ответы провайдера и не подтверждают реальные серверные ключи, биллинг или развёртывание. Подробные ограничения и приёмка — в RELEASE_11_REPORT_RU.md.

---
