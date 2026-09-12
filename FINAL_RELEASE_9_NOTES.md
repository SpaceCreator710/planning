> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Final Release 9

This build is the complete SwiftUI continuation of Final Release 8. No Expo or web client is included.

## Product changes

- Moved the Planner / Workspace experience switch into a dedicated top Liquid Glass surface.
- Reduced the bottom accessory to Quick Add and date/context so every control fits on iPhone.
- Removed Hybrid from the product UI and migrated old Hybrid state to Workspace without deleting saved data.
- Transferred Hybrid command functions into Workspace: Planner bridge, AI, Weekly Autopilot, Notes, Goals, metrics and shared memory.
- Rebuilt Workspace as a calm hub with seven job-based sections and moved the Built-in capability reference into Workspace Settings.
- Collapsed advanced Day and Week timeline tools by default while preserving every tool and action.
- Replaced custom opaque/material blocks with native interactive iOS 26 Liquid Glass wherever the UI supports it.
- Added app-wide deliberate-tap and hold feedback: native glass deformation, configurable haptics and short original tones that respect Silent Mode.
- Shortened long feature lists and detailed pages with disclosure sections rather than removing content.

## Health, Fitness and Calendar

- Added a main Fitness tab with a Health / Fitness switch.
- Added Activity Ring progress, Apple goals, workout summaries and recent workout history through public HealthKit APIs.
- Added all 14 Apple Health browse sections: Activity, Body Measurements, Cycle Tracking, Hearing, Heart, Medications, Mental Wellbeing, Mobility, Nutrition, Respiratory, Sleep, Symptoms, Vitals and Other Data.
- Added a guarded catalog of 120 HealthKit quantity/category types. Unsupported device, OS and regional types are skipped safely.
- Added HealthKit observer queries, hourly background-delivery registration and the required background-delivery entitlement for authorized sample types.
- Health values remain transient and local; the interface is informational and does not diagnose conditions.
- Added an inline Apple Calendar connection card on the Calendar home screen.
- Fitness+ programs and private Fitness app preferences are not exposed by Apple APIs and are never simulated.

## Compatibility and verification

- Existing snapshots remain decodable because new settings and health fields are optional/defaulted.
- Legacy `hybrid` values remain decode-only and resolve immediately to Workspace.
- Direct custom surface backgrounds were removed from application views; the only material fallback is the pre-iOS-26 branch in the shared glass modifier.
- Server AI boundary tests pass.
- All project property lists, entitlements and privacy manifests parse successfully.
- Swift delimiter/static structure checks pass for all 50 Swift files.
- Final Xcode compilation, signing, HealthKit permissions, widgets and on-device visual acceptance still require Xcode 26 on macOS and a physical iPhone.
