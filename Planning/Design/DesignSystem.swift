import SwiftUI

private struct PlanningFeedbackModifier<Value: Equatable>: ViewModifier {
    @Environment(AppStore.self) private var store
    let feedback: SensoryFeedback
    let trigger: Value
    let condition: (Value, Value) -> Bool
    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { old, new in
            store.data.settings.hapticFeedbackEnabled != false && condition(old, new)
        }
    }
}
import UIKit

struct AppPalette {
    let background: Color
    let surface: Color
    let elevated: Color
    let muted: Color
    let text: Color
    let secondary: Color
    let tertiary: Color
    let border: Color
    let accent: Color
    let accentSoft: Color

    static func resolve(settings: AppSettings, scheme: ColorScheme) -> AppPalette {
        let dark = settings.theme == .dark || (settings.theme == .system && scheme == .dark)
        let canvas = CanvasColors.resolve(settings.canvasTheme, dark: dark)
        let accent = settings.customAccentEnabled
            ? Color.hsl(
                hue: settings.customAccentHue,
                saturation: settings.customAccentSaturation,
                lightness: settings.customAccentLightness
            )
            : AccentColors.resolve(settings.accentTheme, dark: dark)

        return AppPalette(
            background: canvas.background,
            surface: canvas.surface,
            elevated: canvas.elevated,
            muted: dark ? Color.white.opacity(0.075) : Color.black.opacity(0.052),
            text: dark ? Color(red: 0.96, green: 0.95, blue: 0.93) : Color(red: 0.11, green: 0.105, blue: 0.10),
            secondary: dark ? Color.white.opacity(0.68) : Color.black.opacity(0.60),
            tertiary: dark ? Color.white.opacity(0.46) : Color.black.opacity(0.42),
            border: dark ? Color.white.opacity(0.13) : Color.black.opacity(0.095),
            accent: accent,
            accentSoft: accent.opacity(dark ? 0.24 : 0.14)
        )
    }
}

enum CanvasColors {
    static func resolve(_ theme: CanvasTheme, dark: Bool) -> (background: Color, surface: Color, elevated: Color) {
        if theme == .none {
            return dark ? (.black, .black, .black) : (.white, .white, .white)
        }

        let light: (UInt, UInt, UInt, UInt, UInt, UInt, UInt, UInt, UInt)
        switch theme {
        case .none:
            light = (255,255,255,255,255,255,255,255,255)
        case .paper:
            light = (243,240,234,250,248,243,255,253,248)
        case .spring:
            light = (243,239,234,251,246,241,255,251,247)
        case .summer:
            light = (240,241,232,248,248,239,253,253,244)
        case .autumn:
            light = (242,237,228,250,245,235,255,250,241)
        case .winter:
            light = (238,240,241,247,249,249,252,253,253)
        case .botanical:
            light = (238,241,235,246,248,242,251,252,247)
        case .wildlife:
            light = (240,237,231,248,244,237,252,249,243)
        case .midnight:
            light = (236,237,237,245,245,243,249,249,247)
        }

        if dark {
            switch theme {
            case .none: return (.black, .black, .black)
            case .paper: return (.rgb(23,22,20), .rgb(33,31,28), .rgb(39,37,33))
            case .spring: return (.rgb(26,23,22), .rgb(36,31,30), .rgb(42,36,34))
            case .summer: return (.rgb(23,26,22), .rgb(32,36,30), .rgb(38,42,35))
            case .autumn: return (.rgb(27,23,19), .rgb(38,32,25), .rgb(45,38,30))
            case .winter: return (.rgb(21,23,25), .rgb(32,35,38), .rgb(38,41,45))
            case .botanical: return (.rgb(21,25,21), .rgb(31,37,31), .rgb(37,43,36))
            case .wildlife: return (.rgb(25,23,20), .rgb(36,32,27), .rgb(42,38,31))
            case .midnight: return (.rgb(16,17,15), .rgb(28,30,27), .rgb(34,36,32))
            }
        }

        return (
            .rgb(light.0, light.1, light.2),
            .rgb(light.3, light.4, light.5),
            .rgb(light.6, light.7, light.8)
        )
    }
}

enum AccentColors {
    static func resolve(_ theme: AccentTheme, dark: Bool) -> Color {
        let light: (UInt, UInt, UInt)
        let darkValue: (UInt, UInt, UInt)
        switch theme {
        case .crimson: light = (169,104,104); darkValue = (215,154,153)
        case .ocean: light = (110,127,149); darkValue = (156,170,189)
        case .violet: light = (136,116,142); darkValue = (185,164,191)
        case .forest: light = (111,136,113); darkValue = (157,178,159)
        case .sunset: light = (166,122,87); darkValue = (208,162,124)
        case .blossom: light = (170,116,129); darkValue = (214,162,174)
        case .sky: light = (112,139,150); darkValue = (160,182,191)
        case .lavender: light = (139,125,151); darkValue = (186,173,196)
        case .mint: light = (114,141,130); darkValue = (161,183,173)
        case .amber: light = (164,140,91); darkValue = (204,181,126)
        }
        let value = dark ? darkValue : light
        return .rgb(value.0, value.1, value.2)
    }
}

extension Color {
    static func rgb(_ r: UInt, _ g: UInt, _ b: UInt) -> Color {
        Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    static func hsl(hue: Double, saturation: Double, lightness: Double) -> Color {
        let h = ((hue.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360
        let s = max(0, min(1, saturation / 100))
        let l = max(0, min(1, lightness / 100))
        guard s > 0 else { return Color(white: l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func channel(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2.0 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6 }
            return p
        }
        return Color(red: channel(h + 1.0 / 3.0), green: channel(h), blue: channel(h - 1.0 / 3.0))
    }
}

enum TaskTint {
    static func resolve(_ task: PlannerTask) -> Color {
        if let hue = task.customTintHue,
           let saturation = task.customTintSaturation,
           let lightness = task.customTintLightness {
            return .hsl(hue: hue, saturation: saturation, lightness: lightness)
        }
        switch task.color ?? .gray {
        case .red: return .rgb(169,104,104)
        case .orange: return .rgb(166,122,87)
        case .yellow: return .rgb(164,140,91)
        case .green: return .rgb(111,136,113)
        case .teal: return .rgb(102,133,135)
        case .blue: return .rgb(110,127,149)
        case .indigo: return .rgb(116,117,143)
        case .violet: return .rgb(136,116,142)
        case .pink: return .rgb(170,116,129)
        case .gray: return .rgb(119,118,114)
        }
    }
}

struct AppCanvasBackground: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let settings = store.data.settings
        let p = AppPalette.resolve(settings: settings, scheme: scheme)
        ZStack {
            p.background

            // A restrained accent atmosphere prevents the canvas from reading as a flat black/white void.
            // Liquid Glass then has real color and depth to refract, especially around floating controls.
            RadialGradient(
                colors: [p.accent.opacity(scheme == .dark ? 0.16 : 0.10), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 520
            )
            RadialGradient(
                colors: [p.accent.opacity(scheme == .dark ? 0.08 : 0.055), .clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 620
            )

            if settings.canvasTheme != .none {
                craftAtmosphere(theme: settings.canvasTheme, palette: p)
                CraftGrain(dark: settings.theme == .dark || (settings.theme == .system && scheme == .dark))
                    .opacity(settings.visualEnergy == .calm ? 0.24 : settings.visualEnergy == .vivid ? 0.55 : 0.42)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func craftAtmosphere(theme: CanvasTheme, palette: AppPalette) -> some View {
        let secondary: Color = switch theme {
        case .spring: .rgb(177,148,151)
        case .summer: .rgb(157,150,103)
        case .autumn: .rgb(154,111,78)
        case .winter: .rgb(120,137,151)
        case .botanical: .rgb(101,128,104)
        case .wildlife: .rgb(134,112,87)
        case .paper: .rgb(147,133,113)
        case .midnight: .rgb(110,108,121)
        case .none: palette.accent
        }
        ZStack {
            let atmosphere = store.data.settings.visualEnergy == .calm ? 0.55 : store.data.settings.visualEnergy == .vivid ? 1.25 : 1.0
            RadialGradient(colors: [palette.accent.opacity(0.09 * atmosphere), .clear], center: .topTrailing, startRadius: 20, endRadius: 430)
            RadialGradient(colors: [secondary.opacity(0.075 * atmosphere), .clear], center: .bottomLeading, startRadius: 30, endRadius: 460)
        }
        .blendMode(.softLight)
    }
}

private struct CraftGrain: View {
    let dark: Bool
    var body: some View {
        Canvas { context, size in
            for index in 0..<150 {
                let x = size.width * CGFloat((index * 47 + 13) % 149) / 149
                let y = size.height * CGFloat((index * 83 + 29) % 151) / 151
                let radius = CGFloat(0.45 + Double(index % 5) * 0.12)
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(Path(ellipseIn: rect), with: .color((dark ? Color.white : Color.black).opacity(index % 3 == 0 ? 0.045 : 0.025)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct MatteCard<Content: View>: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        content
            .padding(16)
            .premiumGlassRounded(
                cornerRadius: 26,
                tint: p.accent.opacity(store.data.settings.visualEnergy == .vivid ? 0.12 : 0.065),
                interactive: true
            )
            .contentShape(shape)
    }
}

struct PremiumGlassCard<Content: View>: View {
    let tint: Color?
    let content: Content
    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }
    var body: some View {
        content
            .padding(16)
            .premiumGlassRounded(cornerRadius: 26, tint: tint, interactive: true)
    }
}

struct LiquidGlassCapsule<Content: View>: View {
    let tint: Color?
    let content: Content
    init(tint: Color? = nil, @ViewBuilder content: () -> Content) { self.tint = tint; self.content = content() }
    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .premiumGlassCapsule(tint: tint, interactive: true)
    }
}

extension View {
    func planningFeedback<Value: Equatable>(_ feedback: SensoryFeedback, trigger: Value, condition: @escaping (Value, Value) -> Bool = { _, _ in true }) -> some View {
        modifier(PlanningFeedbackModifier(feedback: feedback, trigger: trigger, condition: condition))
    }
    func premiumGlassRounded(cornerRadius: CGFloat = 24, tint: Color? = nil, interactive: Bool = true) -> some View {
        modifier(PlanningGlassSurface(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), tint: tint, interactive: interactive))
    }

    func premiumGlassCapsule(tint: Color? = nil, interactive: Bool = true) -> some View {
        modifier(PlanningGlassSurface(shape: Capsule(), tint: tint, interactive: interactive))
    }

    func appCanvas() -> some View {
        self.background { AppCanvasBackground() }
    }

    /// Installs a non-blocking window tap recognizer that resigns text input whenever the user
    /// taps outside a text field/text view. Buttons and scrolling keep receiving their touches.
    func keyboardDismissOnBackgroundTap() -> some View {
        self.background {
            KeyboardDismissInstaller()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }

    /// Adds one coherent, silent haptic response to deliberate taps throughout the app.
    /// A tap recognizer fails naturally when a ScrollView starts moving, so scrolling stays quiet.
    func globalInteractionFeedback(hapticsEnabled: Bool) -> some View {
        self.background {
            GlobalInteractionFeedbackInstaller(hapticsEnabled: hapticsEnabled)
            .frame(width: 0, height: 0)
        }
    }
}

@MainActor
private final class GlobalInteractionFeedbackCoordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?
    private var tapRecognizer: UITapGestureRecognizer?
    private var holdRecognizer: UILongPressGestureRecognizer?
    var hapticsEnabled = true

    func install(on window: UIWindow?) {
        guard let window else { return }
        guard installedWindow !== window else { return }
        remove()

        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        hold.minimumPressDuration = 0.32
        hold.cancelsTouchesInView = false
        hold.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        tap.require(toFail: hold)

        window.addGestureRecognizer(hold)
        window.addGestureRecognizer(tap)
        installedWindow = window
        tapRecognizer = tap
        holdRecognizer = hold
    }

    func remove() {
        if let tapRecognizer, let installedWindow { installedWindow.removeGestureRecognizer(tapRecognizer) }
        if let holdRecognizer, let installedWindow { installedWindow.removeGestureRecognizer(holdRecognizer) }
        tapRecognizer = nil
        holdRecognizer = nil
        installedWindow = nil
    }

    @objc private func handleTap() {
        if hapticsEnabled {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }

    @objc private func handleHold(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        if hapticsEnabled {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            generator.impactOccurred(intensity: 0.62)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

}

private final class GlobalInteractionFeedbackHostView: UIView {
    weak var feedbackCoordinator: GlobalInteractionFeedbackCoordinator?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        feedbackCoordinator?.install(on: window)
    }
}

@MainActor
private struct GlobalInteractionFeedbackInstaller: UIViewRepresentable {
    let hapticsEnabled: Bool

    func makeCoordinator() -> GlobalInteractionFeedbackCoordinator { GlobalInteractionFeedbackCoordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = GlobalInteractionFeedbackHostView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.feedbackCoordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hapticsEnabled = hapticsEnabled
        context.coordinator.install(on: uiView.window)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: GlobalInteractionFeedbackCoordinator) {
        coordinator.remove()
    }
}

struct SectionLabel: View {
    let title: String
    let subtitle: String?
    init(_ title: String, subtitle: String? = nil) { self.title = title; self.subtitle = subtitle }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.headline)
            if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private final class KeyboardDismissCoordinator: NSObject, UIGestureRecognizerDelegate {
    private weak var installedWindow: UIWindow?
    private var recognizer: UITapGestureRecognizer?

    func install(on window: UIWindow?) {
        guard let window else { return }
        guard installedWindow !== window else { return }
        remove()
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = self
        window.addGestureRecognizer(recognizer)
        installedWindow = window
        self.recognizer = recognizer
    }

    func remove() {
        if let recognizer, let installedWindow { installedWindow.removeGestureRecognizer(recognizer) }
        recognizer = nil
        installedWindow = nil
    }

    @objc private func handleTap() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view {
            if current is UITextField || current is UITextView { return false }
            view = current.superview
        }
        return true
    }

    deinit { remove() }
}

private final class KeyboardDismissHostView: UIView {
    weak var keyboardCoordinator: KeyboardDismissCoordinator?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        keyboardCoordinator?.install(on: window)
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeCoordinator() -> KeyboardDismissCoordinator { KeyboardDismissCoordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = KeyboardDismissHostView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.keyboardCoordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.install(on: uiView.window)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: KeyboardDismissCoordinator) {
        coordinator.remove()
    }
}

// One surface per content group. Nested decorative glass is transparent, while
// native buttons keep their own control treatment and full hit areas.
private struct PlanningGlassDepthKey: EnvironmentKey {
    static let defaultValue = 0
}
private extension EnvironmentValues {
    var planningGlassDepth: Int {
        get { self[PlanningGlassDepthKey.self] }
        set { self[PlanningGlassDepthKey.self] = newValue }
    }
}
private struct PlanningGlassSurface<S: Shape>: ViewModifier {
    @Environment(\.planningGlassDepth) private var depth
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        Group {
            if depth > 0 {
                content
            } else if reduceTransparency {
                content.background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
            } else {
                content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
            }
        }
        .contentShape(shape)
        .environment(\.planningGlassDepth, depth + 1)
    }
}

/// Two or three related actions stay horizontal until text needs more room.
struct PlanningAdaptiveRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    let spacing: CGFloat
    let content: Content
    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    var body: some View {
        let layout = size >= .xxLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
    }
}

/// Used inside the label of a Button or NavigationLink, never an extra gesture.
struct PlanningDestinationRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    var detail: String? = nil
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(.tint)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .lineLimit(size.isAccessibilitySize ? nil : 2)
                }
                if let detail {
                    Text(detail).font(.caption.weight(.medium)).foregroundStyle(.tint)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(16)
        .premiumGlassRounded(cornerRadius: 24, tint: .accentColor.opacity(0.025))
        .contentShape(Rectangle())
    }
}

struct PlanningEmptyState: View {
    let title: String
    let message: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light))
                .foregroundStyle(.tint).accessibilityHidden(true)
            Text(title).font(.title2.weight(.semibold))
            Text(message).font(.body).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
    }
}
