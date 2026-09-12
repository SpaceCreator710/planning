> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Final Device Timeline Fix

This pass addresses the final real-device Today/Timeline findings.

## Fixed

- Removed the separate pulsing NOW dot/rings from Vertical Timeline. The rail fill itself is now the live clock.
- Removed the separate pulsing NOW dot/rings from Orbit. The orbit fill itself is now the live clock.
- Added task-aware progress capping in Vertical, Horizontal and Orbit so a live chain does not visually touch a future task bead before the task's real start time merely because the bead has physical size.
- Task beads still fill continuously from 0% at start time to 100% at end time. Vertical fills top-to-bottom, Horizontal fills left-to-right, and Orbit fill follows the ring tangent.
- Added a hard geometry firewall around task beads after Liquid Glass composition. Rotated Orbit ovals are clipped to their true fixed rotated bounds and cannot expand to the Orbit canvas size.
- Orbit circles now rotate only their fill coordinate system along the tangent while keeping their circular appearance and exact hit bounds.

## Validation

- Swift parser: PASS (50 Swift files)
- Core regression tests: PASS
- Server AI boundary tests: PASS
- Marketing version remains 1.0.0 / build 100
