> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Final Timeline Geometry Pass

This pass closes the last device-test issues found in Today/Live Timeline.

## Fixed
- Orbit no longer drifts to the right: the entire composition is rendered from one exact container center with no hidden horizontal canvas offset.
- Task beads no longer read as a circle-inside-a-circle: outer shadows/strong double rings were removed and Liquid Glass uses a restrained single edge.
- Ovals are longer and slightly thicker by default.
- Every task now has an optional `Oval length` slider in Task Editor (1.15x–3.50x, default 1.45x; crowded timelines visually shrink oversized ovals only as needed).
- Vertical collision spacing accounts for each task's actual oval height, and the rail grows to fit all tasks.
- Horizontal timeline uses adaptive density: 1–9 timed tasks compress to fit one rail; 10+ tasks return to full size and the rail becomes horizontally scrollable.
- Orbit uses adaptive collision-safe density: nodes shrink as the ring gets crowded and remain tangent to the orbit.
- Circle/oval Auto mode remains stable per task; manual Circle/Oval selection remains supported.

## Validation
- Swift parser: PASS for all Swift sources.
- Core regression tests: PASS.
- Server AI boundary tests: PASS.
- Marketing version: 1.0.0, build 100.
- No API-key input UI remains in the iOS app.
