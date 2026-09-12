> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Timeline Polish Final Pass

This pass applies the final device-test findings for Today / Live Timeline.

## Fixed

- Orbit task ovals are hard-capped to endpoint scale. The task node no longer uses a GeometryReader internally, preventing an Orbit canvas from inflating an oval into a giant glass pill.
- Wake/Sleep are now the visual size reference. User-created task nodes use the same maximum visible size in expanded Horizontal, Vertical, Orbit, and Day Path modes. Compact Week nodes match compact endpoints.
- Oval orientation is preserved by mode: horizontal in Horizontal, upright in Vertical/Day Path, tangent-aligned in Orbit.
- Vertical Timeline no longer draws the extra travelling cross-line. The live rail itself fills with time; only a compact NOW bead remains.
- Vertical task nodes fill from top to bottom during the task interval.
- Liquid Glass task nodes were rebuilt around fixed geometry: low-opacity tint under system glass, live color fill clipped to the bead, chain masking behind the glass, and no active-state scale growth.
- Endpoint beads were also normalized to the same glass/live-fill treatment and fixed geometry.
- Elastic behavior remains intact: crowded Horizontal scrolls wider, Vertical grows taller, and Orbit increases radius rather than allowing task-node overlap.

## Validation

- Swift parser: PASS (50 Swift files)
- Core regression tests: PASS
- Backend AI boundary tests: PASS

A full Xcode/iPhone runtime test is still required for Apple SDK rendering and gesture behavior.
