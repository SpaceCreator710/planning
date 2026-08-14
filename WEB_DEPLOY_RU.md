# Развёртывание готового WEB-NETLIFY архива

Архив содержит полный проект, `package.json` прямо в корне, Netlify Function, `netlify.toml` и уже собранную папку `dist`. Его можно подключать как репозиторий: Netlify выполнит обычную сборку из корня.

## Через Netlify CLI

1. Распакуй архив.
2. В терминале внутри папки выполни:

```bash
npx netlify login
npx netlify deploy --prod --dir dist --functions netlify/functions
```

3. В Netlify добавь server-only переменные:

```text
GROQ_API_KEY=твой_секретный_ключ
GROQ_MODEL=openai/gpt-oss-120b
```

4. Сделай deploy ещё раз после добавления переменных.

Если Netlify снова пишет `/opt/build/repo/package.json not found`, значит в репозиторий была загружена внешняя папка, а не содержимое архива. В корне Git‑репозитория должны одновременно находиться `package.json`, `netlify.toml`, `src`, `netlify` и `app.json`. Base directory оставь пустой или `.`.
