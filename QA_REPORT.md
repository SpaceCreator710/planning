# Planning RELEASE 12 — QA

Текущий отчёт: [RELEASE_12_REPORT_RU.md](RELEASE_12_REPORT_RU.md).

Воспроизводимые результаты: QA/core-last-run.log, QA/store-last-run.log, QA/backend-last-run.log, QA/swift-syntax.json, QA/resources-validation.json.

PASS: 15 core-сценариев; 12 AppStore-сценариев с платформенными тестовыми реализациями; два набора backend-тестов; синтаксис 49 Swift-файлов; структурная проверка ресурсов.

Не выполнены: сборка/проверка типов с Apple SDK, запуск на iPhone/симуляторе, настоящие Apple/облачные интеграции, покупки, UI/performance/accessibility-тестирование и публикация. QA/DEVICE_ACCEPTANCE.md — список для выполнения, не протокол успешного теста.

QA/changes-from-release11.json описывает изменения относительно исходного RELEASE 11. Предыдущие отчёты и changes-from-release10.json являются историческими.
