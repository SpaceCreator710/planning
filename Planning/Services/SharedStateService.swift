import Foundation
import WidgetKit

enum SharedStateService {
    static func publish(_ data: AppData) {
        let plan = data.plans.first(where: { $0.date == DateKey.today })
        let sorted = TaskTimelineOrder.sorted(plan?.tasks ?? []).filter { $0.status != .skipped }
        let next = sorted.first { $0.status == .pending || $0.status == .active }
        let snapshot = SharedPlannerSnapshot(
            date: DateKey.today,
            title: plan?.title ?? "Today",
            nextTaskTitle: next?.title,
            nextTaskTime: next?.startTime,
            nextTaskIcon: next?.icon,
            completed: sorted.filter { $0.status == .completed }.count,
            total: sorted.count,
            updatedAt: .now,
            tasks: sorted.prefix(8).map {
                SharedTaskSummary(
                    id: $0.id,
                    title: $0.title,
                    time: $0.startTime,
                    icon: $0.icon ?? IconEngine.symbol(for: $0.title, category: $0.category),
                    completed: $0.status == .completed,
                    subtasks: ($0.subtasks ?? []).map { SharedSubtaskSummary(id: $0.id, title: $0.title, completed: $0.completed) }
                )
            },
            inboxTitles: data.inbox.prefix(5).map(\.title),
            accentRGB: widgetAccentRGB(for: data.settings)
        )
        guard let raw = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroupID)?.set(raw, forKey: "planner-snapshot")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func widgetAccentRGB(for settings: AppSettings) -> [Double] {
        if settings.customAccentEnabled {
            return hslToRGB(
                hue: settings.customAccentHue,
                saturation: settings.customAccentSaturation,
                lightness: settings.customAccentLightness
            )
        }
        let value: (Double, Double, Double)
        switch settings.accentTheme {
        case .crimson: value = (169, 104, 104)
        case .ocean: value = (110, 127, 149)
        case .violet: value = (136, 116, 142)
        case .forest: value = (111, 136, 113)
        case .sunset: value = (166, 122, 87)
        case .blossom: value = (170, 116, 129)
        case .sky: value = (112, 139, 150)
        case .lavender: value = (139, 125, 151)
        case .mint: value = (114, 141, 130)
        case .amber: value = (164, 140, 91)
        }
        return [value.0 / 255, value.1 / 255, value.2 / 255]
    }

    private static func hslToRGB(hue: Double, saturation: Double, lightness: Double) -> [Double] {
        let h = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360
        let s = max(0, min(1, saturation / 100))
        let l = max(0, min(1, lightness / 100))
        guard s > 0 else { return [l, l, l] }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ input: Double) -> Double {
            var t = input
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2.0 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6 }
            return p
        }
        return [channel(h + 1.0 / 3.0), channel(h), channel(h - 1.0 / 3.0)]
    }

}
