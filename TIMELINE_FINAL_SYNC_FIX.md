> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Final Timeline Sync Fix

Final device-feedback pass for Today / Live Timeline.

- Day Path / Live Chain connector progress is now always rendered with the app accent color. Task colors remain on task beads only and can no longer recolor the chain.
- Orbit task nodes now use one explicit center for the rotated bead surface and the upright SF Symbol.
- Orbit no longer applies the system Liquid Glass renderer to rotated task capsules, eliminating the displaced backing/frame artifact seen on device. Orbit uses a stable material glass shell with the same tint, live fill, and border geometry.
- Horizontal and Vertical retain native Liquid Glass behavior.
- Orbit live-fill remains tangent-aligned and task icons remain upright.

Validation:
- Swift parser: PASS
- Core regression tests: PASS
- Server AI boundary tests: PASS
