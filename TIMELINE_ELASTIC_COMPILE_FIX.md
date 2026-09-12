> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Timeline Elastic compile fix

Fixed a compiler error in `Planning/Features/Today/TodayView.swift`.

The helper `endpointProgress(from:to:)` accidentally forwarded an undefined identifier named `to`:

`connectorProgress(from: start, to: to)`

It now correctly forwards the function parameter `end`:

`connectorProgress(from: start, to: end)`

This was a source-level typo introduced in the Elastic Timeline pass. Core regression tests and Swift parser checks pass after the correction.
