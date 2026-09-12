> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Timeline Final

This build is based on the previous Planning 1.0.0 / V12.3 timeline code and focuses on finishing the Today experience.

## Core timeline fixes

- Timed task beads in the expanded horizontal Day view now sit directly on the live chain instead of being distributed above/below it.
- Wake, task, and sleep beads mask the line beneath them, so the chain visually touches the bead edge rather than cutting through the icon.
- Task beads use live progress fill synchronized with the task's scheduled duration.
- Wake and sleep beads use live fill windows around their boundary times.
- Task nodes are larger in Day view and retain compact sizing in Week view.
- The current-time marker is rendered behind beads so it cannot visually slice through icons.

## Timeline layouts

- Horizontal: the main live chain with zoom, drag/drop, Flow Shift, Reality Layer, buffers, Now Lens, Time Gravity and open-space placement.
- Vertical: a large classic time rail with live progress, large liquid-glass task beads, labels, drag/drop rescheduling, and tap-to-add on the rail.
- Orbit: a radial live-day view with wake/sleep endpoints, live day progress, current-time marker and task beads around the ring.
- Day Path: an additional connected chronological task list for Today, enabled by default and independently toggleable in Settings.

The default layout can be changed in Settings > Timeline, and the Day screen also has a fast layout menu.

## Task bead design

- New liquid-glass bead rendering.
- Automatic shape mode assigns a stable circle or oval per task.
- Manual shape override supports Circle or Oval.
- Shape selection is now actually reflected by timeline task beads.
- Larger SF Symbol treatment and active-task glow.
- Timeline progress fills the bead itself instead of only drawing an external progress ring.

## Task editor fixes

- Custom icon selection is now authoritative. Explicitly chosen icons are no longer replaced by semantic auto-repair logic.
- Icon picker access is larger and clearer.
- Automatic icon mode remains available.
- Timeline shape controls are now Auto / Circle / Oval with clear selected states.

## Timeline tools

Existing tools retained and integrated:

- Flow Shift
- Push the Day
- Ghost Future
- Reality Layer
- Now Lens
- Detail Zoom
- Time Gravity
- Time Machine
- Open Space
- Collision avoidance
- Reset buffers
- Fixed/locked anchors
- Week chains

New tools:

- Magnetic Compress: pulls remaining flexible tasks into safe earlier gaps while respecting fixed commitments and reset buffers.
- Direct Anchor Lock/Unlock from a task bead context menu.
- Live Pulse strip: day elapsed, free-time capacity and scheduled-load metrics.
- Smart Density setting for very dense horizontal days.

## Persistence / compatibility

- AppData schema version is now 12.
- New timeline settings and metadata are optional/defaulted so older snapshots remain decodable.
- Existing legacy TaskShape.rounded remains decodable and is treated as an oval on the new timeline.

## Validation performed in this environment

- Swift parser pass across app, widgets, share extension and shared Swift sources.
- Core regression tests: PASS.
- Server AI boundary tests: PASS.
- No user-facing API key input strings or SecureField API-key UI found in the app source.
- Display name remains Planning; marketing version remains 1.0.0, build 100.

A true iOS build and device interaction pass still must be performed in Xcode on macOS because this environment does not contain the Apple SDK/Xcode toolchain.

## Elastic no-overlap device-feedback pass

See `TIMELINE_ELASTIC_FINAL_NOTES.md`. Horizontal now auto-extends and scrolls, Vertical auto-grows, Orbit auto-expands, ovals follow each layout direction, Horizontal's tall NOW line is removed, Day Path is fully live, and Orbit supports direct tap/drag scheduling.
