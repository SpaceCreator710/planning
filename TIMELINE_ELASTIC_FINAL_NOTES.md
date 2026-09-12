> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Elastic Timeline final pass

This pass is focused on the real-device Today/Timeline feedback after the first FINAL TIMELINE build.

## Collision-free layout

- Added an Elastic Timeline spacing engine to Horizontal, Vertical, and Orbit layouts.
- Task beads no longer need to overlap when many tasks are scheduled close together or at the same time.
- Horizontal grows wider with the number of visible tasks and becomes horizontally scrollable.
- Vertical grows taller with task count; it is not capped to the original preset rail height.
- Orbit grows its radius/diameter to preserve bead separation and becomes horizontally scrollable when it exceeds the phone width.
- Wake and Sleep are included in the spacing budget so task beads do not collide with the permanent endpoints.

## Direction-aware Liquid Glass task beads

- Horizontal ovals stay horizontal.
- Vertical ovals stand upright on the rail.
- Orbit ovals rotate tangentially so their long side follows the ring.
- Circles remain circles in every layout.
- The task fill direction follows the layout: horizontal/orbit flow along the bead, vertical fills top-to-bottom.
- Large task icons were retained/increased for the primary Today layouts.

## Live chain behavior

- Removed the tall vertical NOW marker from Horizontal.
- Horizontal time is represented by the chain itself filling in real time, with only a small live point riding on it.
- Vertical rail continues to fill top-to-bottom with the device clock.
- Orbit continues to fill around the ring with the device clock.
- Day Path was rebuilt as a true live chain: every connector fills progressively with time, and Wake/Sleep also live-fill.

## Elastic Time precision

When Horizontal must visually spread tightly packed tasks to prevent overlap, Planning keeps the real start time visible under each bead. A subtle true-time tether appears when the bead has been moved away from its exact proportional position. This preserves both readability and temporal truth.

## Direct manipulation

- Horizontal: tap empty rail space to create a task at that time; drag tasks to reschedule; Flow Shift still applies when enabled.
- Vertical: tap the rail to create; drag tasks to reschedule; dynamic rail height is used for hit mapping.
- Orbit: added tap-the-ring quick create and drag/drop rescheduling directly on the orbit.
- Horizontal and Orbit reserve one-finger horizontal panning for their elastic canvases, avoiding accidental day changes while scrolling overflow. Day navigation remains available through the existing arrows/calendar controls.

## New timeline differentiators

1. **Elastic Timeline** — the timeline physically grows instead of collapsing or stacking task icons.
2. **Directional Morphing** — Liquid Glass ovals align themselves to horizontal, vertical, or orbital flow.
3. **Elastic Time / True-Time Tether** — collision-free visual spacing without hiding the task's real timestamp.
4. **Live Day Path** — the connected list is now a second real-time representation of the day, not a static list.
5. **Orbit Direct Manipulation** — tap or drag directly on the ring to create and reschedule.
6. Existing differentiators remain: NOW Lens, Semantic Zoom, Time Gravity, Reality Layer, Ghost Future, Push The Day, Flow Shift, Time Machine, Magnetic Compress, Smart Open Space, buffers, collision-aware scheduling, and anchor locks.

## Validation performed in this environment

- Swift parser: PASS for all Swift files.
- Core regression tests: PASS.
- Server AI boundary tests: PASS.
- Spacing formulas were checked against dense/same-time task distributions before final packaging.

A real Apple SDK build and final gesture/visual acceptance still need to be verified in Xcode/on iPhone.
