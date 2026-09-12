# Planning 1.0.0 · RELEASE 12

Нативный проект Swift 6 / SwiftUI для iOS 26+. Сборка 12: приложение Planning, Widgets / Live Activity и Share Extension.

Начните с [отчёта RELEASE 12](RELEASE_12_REPORT_RU.md). В нём перечислены изменения, пройденные проверки, ограничения и действия перед App Store. [Приёмка на iPhone](QA/DEVICE_ACCEPTANCE.md) обязательна: Xcode и Apple SDK в среде подготовки архива отсутствовали.

Откройте Planning.xcodeproj в Xcode, выберите свою команду подписи и проверьте существующие App Group / iCloud / HealthKit capabilities. Идентификаторы проекта сохранены. Соберите Release и установите на iPhone.

В RELEASE 12 переработаны Today, Workspace, редакторы, календарь Week/Month/Year, AI preview, Health/Fitness, More и Settings. Полный перечень — в отчёте. Сохранённая основа: Planner/Workspace через стеклянную панель; добавление в Today и Timeline; точные переносы без автоматического сдвига соседей; Undo; обработка повторений и автозавершения; Workspace с фото и никнеймом; общий контракт ИИ; Fitness и Health; Free/Pro с месячной и годовой покупкой.

Config.xcconfig содержит ACCOUNTS_ENABLED = YES и SUBSCRIPTIONS_ENABLED = YES. Debug допускает доступ к функциям для разработки. Проверять оплату нужно в Release / TestFlight. Серверные ключи провайдеров в приложение не добавлять.

Для актуального ИИ обновите функцию Backend/supabase/functions/planning-ai целиком, включая .mjs-модули. Уже развёрнутый backend автоматически этим архивом не обновляется. Альтернатива Netlify использует тот же контракт. См. Backend/README.md и отчёт.

Проверки:

```bash
bash QA/run-core-tests.sh
bash QA/run-store-tests.sh
node Backend/qa/server-function.test.mjs
node Backend/qa/ai-contract.test.mjs
```

Требуются Swift 6 и Node 24. Тесты AppStore заменяют только платформенные сервисы; сборку с Apple SDK они не заменяют. Логи и состав исходников находятся в QA.

Archive содержит прежний RELEASE 10 только как резервную копию отложенной Orbit. Открывайте Xcode-проект в корне текущего архива. Старые release notes являются историческими документами.
