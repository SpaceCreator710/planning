> Исторический документ предыдущей версии. Текущее состояние, проверки и ограничения: [RELEASE_11_REPORT_RU.md](RELEASE_11_REPORT_RU.md).

# Planning 1.0.0 — Xcode setup

1. Open `Planning.xcodeproj` in Xcode 26+ and select the `Planning` scheme.
2. Select your Apple Developer team for the Planning app, widget extension and share extension.
3. Keep the existing bundle IDs/App Group unless you deliberately choose final App Store identifiers and update every entitlement consistently.
4. Enable the capabilities already used by the source: App Groups, HealthKit, Sign in with Apple, iCloud/CloudKit, Live Activities and Background Modes as required by the targets.
5. Confirm App Group `group.com.aiplanyourday.app` is available to the app, widgets and share extension, or migrate all three targets together if you change it.
6. Confirm private iCloud container `iCloud.com.aiplanyourday.app` is provisioned, or migrate it consistently before shipping.
7. Built-in AI: deploy `Backend/`, set the provider credential only on the server, then set `AI_API_BASE_URL` in `Config.xcconfig` to the public HTTPS deployment URL. Users never enter provider credentials in the app.
8. Registration is deferred for this build. Keep `ACCOUNTS_ENABLED = NO`. When you are ready, set the public `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, configure `planning://auth/callback`, then set `ACCOUNTS_ENABLED = YES`.
9. Payments are optional for this build. Keep `SUBSCRIPTIONS_ENABLED = NO` until App Store products are ready. In that state, premium product features remain unlocked and subscription UI stays hidden. When ready, configure the StoreKit product IDs in `SubscriptionService.swift` and set the flag to `YES`.
10. Validate alternate app icons on a physical iPhone.
11. Validate Calendar, HealthKit, notifications, widgets, Live Activities, App Shortcuts/Siri, Control Center, Share Extension, CloudKit and data import/export on device.
12. Complete App Store privacy disclosures and final signed Archive/TestFlight validation before submission.

Never put provider secret credentials in `Config.xcconfig`, Info.plist, Swift source, the app bundle or a distributed ZIP.
