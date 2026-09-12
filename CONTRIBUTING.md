# Contributing

Thanks for helping improve Planning.

## Development setup

1. Use Xcode 26 or newer.
2. Copy `Config.xcconfig.example` to `Config.xcconfig` only when local public service configuration is needed.
3. Never commit provider API secrets or private credentials.
4. Open `Planning.xcodeproj`.
5. Build the `Planning` target for an iOS 26 simulator or signed device.

## Pull requests

- Keep each pull request focused on one feature or fix.
- Explain the user-facing behavior and any migration impact.
- Include screenshots or a short screen recording for UI changes when possible.
- Preserve accessibility labels, Dynamic Type behavior, reduced-motion behavior, and Dark Mode.
- Do not introduce a dependency when a first-party Apple framework reasonably covers the requirement.

## Design principles

- Native SwiftUI first.
- Liquid Glass belongs primarily to navigation and interactive controls; content surfaces remain restrained and matte.
- Prefer circles, capsules, ovals and continuous rounded rectangles.
- Two-Tone mode must remain usable without selecting a decorative theme.
- The horizontal week board is a product distinction and should not be converted into Structured's vertical layout.

## AI and privacy

The client may send task/profile context only through the protected server boundary. HealthKit raw samples and provider keys must never be bundled into or transmitted by the app unless the product explicitly documents and obtains consent for a new behavior.
