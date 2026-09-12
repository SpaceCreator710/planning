> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Timeline Final Microfix

Final device-feedback pass for Today / Live Timeline.

- Horizontal live rail now uses the app accent color consistently instead of inheriting task colors.
- Removed the separate moving NOW pulse/ripple bead from Horizontal; the rail itself represents live time.
- Horizontal task beads never shrink to fit. Full-size beads are retained and the rail expands into horizontal scrolling whenever needed.
- No multi-row wrapping: Horizontal remains one continuous time axis.
- Orbit task glass shell, colored edge, and icon now share one transform origin; Orbit rotates the complete bead and counter-rotates the symbol so the shell cannot drift away from its icon.
- Existing Vertical/Orbit no-pulse behavior and live per-task fill remain intact.
