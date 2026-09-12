import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var showEditor = false
    @State private var showPlanBuilder = false
    @State private var showRescue = false
    @State private var showDayDetail = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                SwiftUI.TimelineView(.periodic(from: .now, by: 30)) { context in
                    let wake = TimeMath.minutes(store.data.profile.wakeTime) ?? 480
                    let sleep = TimeMath.minutes(store.data.profile.sleepTime) ?? 1380
                    TimelineNowState(day: DateKey.date(store.selectedDate) ?? context.date,
                                     now: context.date, wakeMinute: wake,
                                     sleepMinute: sleep <= wake ? sleep + 1440 : sleep)
                }
                TodayPrimaryActions(
                    onAdd: { showEditor = true },
                    onBuild: { showPlanBuilder = true }
                )
                WeeklyLiveTimeline()
                if let plan = store.activePlan {
                    Button { showDayDetail = true } label: { DayHero(plan: plan) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open the day summary")
                    RealityCard(plan: plan)
                    if plan.tasks.contains(where: { $0.allDay == true }) { AllDayTaskStrip(plan: plan) }
                    if !store.data.habits.isEmpty { HabitStrip() }
                } else {
                    ContentUnavailableView("No plan yet", systemImage: "calendar.badge.plus", description: Text("Build a plan or add your first task."))
                }
                quickActions
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .appCanvas()
        .navigationTitle(store.selectedDate == DateKey.today ? "Today" : formattedSelectedDate)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add task")
            }
        }
        .sheet(isPresented: $showEditor) { NavigationStack { TaskEditorView(task: PlanEngine.manualTask(title: "", date: store.selectedDate), isNew: true) } }
        .sheet(isPresented: $showPlanBuilder) { NavigationStack { PlanBuilderView() } }
        .sheet(isPresented: $showRescue) { NavigationStack { RescueView() } }
        .sheet(isPresented: $showDayDetail) {
            if let plan = store.activePlan {
                DetailedDaySheet(plan: plan)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: store.replanRequested) { _, requested in
            guard requested else { return }
            showRescue = true
            store.replanRequested = false
        }
        .planningFeedback(.impact(weight: .light), trigger: completedTaskCount)
    }

    private var completedTaskCount: Int {
        store.activePlan?.tasks.filter { $0.status == .completed }.count ?? 0
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Make room for what matters")
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    NavigationLink { FocusView() } label: {
                        Label("Focus", systemImage: "scope")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.glassProminent)

                    Button { showRescue = true } label: {
                        Label("Adjust day", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.glass)
                }
            }

            SectionLabel("Plan & reflect")
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    NavigationLink { InboxView() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "tray.full.fill")
                            Text(store.data.inbox.isEmpty ? "Inbox" : "Inbox · \(store.data.inbox.count)")
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.glass)

                    NavigationLink { DayReviewView() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Day review").font(.caption.weight(.semibold)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.glass)

                    NavigationLink { HorizonPlannerView() } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "map.fill")
                            Text("Horizon").font(.caption.weight(.semibold)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var formattedSelectedDate: String {
        guard let date = DateKey.date(store.selectedDate) else { return store.selectedDate }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct RealityCard: View {
    let plan: DayPlan
    var body: some View {
        let signal = InsightsEngine.reality(plan: plan)
        if signal.state == .complete {
            MatteCard {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(signal.title).font(.headline)
                        Text(signal.message).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(signal.score)").font(.title3.bold()).monospacedDigit()
                }
            }
        }
    }
}

private struct TodayPrimaryActions: View {
    let onAdd: () -> Void
    let onBuild: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            PlanningAdaptiveRow(spacing: 10) {
                Button(action: onAdd) {
                    Label("Add task", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glassProminent)

                Button(action: onBuild) {
                    Label("Plan with AI", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Build a plan with AI")
            }
        }
    }
}

private struct DayHero: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var showDuplicateDay = false
    @State private var duplicateTarget = Date()
    let plan: DayPlan
    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let completed = plan.tasks.filter { $0.status == .completed }.count
        let total = plan.tasks.filter { $0.status != .skipped }.count
        MatteCard {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(plan.intention.isEmpty ? "Make the day feel possible." : plan.intention)
                        .font(.title2.weight(.semibold)).foregroundStyle(p.text)
                    Text("\(completed) of \(total) completed")
                        .font(.subheadline).foregroundStyle(p.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(p.border, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: total == 0 ? 0 : CGFloat(completed) / CGFloat(total))
                        .stroke(p.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(total == 0 ? 0 : Int(Double(completed) / Double(total) * 100))")
                        .font(.caption.bold()).monospacedDigit()
                }
                .frame(width: 54, height: 54)
            }
        }
        .contextMenu {
            Button("Duplicate day…", systemImage: "plus.square.on.square") {
                duplicateTarget = Calendar.current.date(byAdding: .day, value: 1, to: DateKey.date(plan.date) ?? .now) ?? .now
                showDuplicateDay = true
            }
        }
        .sheet(isPresented: $showDuplicateDay) {
            NavigationStack {
                Form {
                    DatePicker("Copy to", selection: $duplicateTarget, displayedComponents: .date)
                    Text("All local tasks from this day will be copied as pending tasks. Imported Calendar items are not duplicated.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .scrollContentBackground(.hidden)
                .appCanvas()
                .navigationTitle("Duplicate day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showDuplicateDay = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Duplicate") {
                            store.duplicateDay(from: plan.date, to: DateKey.string(duplicateTarget))
                            showDuplicateDay = false
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
        }
    }
}

private struct AllDayTaskStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let plan: DayPlan

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 9) {
            SectionLabel("All day")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(plan.tasks.filter { $0.allDay == true }) { task in
                        Button { store.toggleTask(task.id) } label: {
                            HStack(spacing: 7) {
                                Image(systemName: IconEngine.symbol(for: task))
                                Text(task.title).lineLimit(1)
                                if task.status == .completed { Image(systemName: "checkmark.circle.fill") }
                            }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 13).padding(.vertical, 9)
                            .premiumGlassCapsule(tint: TaskTint.resolve(task).opacity(scheme == .dark ? 0.20 : 0.12), interactive: true)
                            .foregroundStyle(p.text)
                        }
                        .buttonStyle(.plain)
                        .draggable("task:\(task.id)")
                        .contextMenu {
                            Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicateTask(task.id) }
                            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteTask(task.id) }
                        }
                    }
                }
            }
        }
    }
}



private enum TimelineDisplayMode: String, CaseIterable, Identifiable, Equatable {
    case day = "Day"
    case week = "Week"

    var id: String { rawValue }
}

private enum TimelineLensMode: Equatable {
    case wholeDay
    case gravity
    case now
    case detail
}

private enum TimelineNavigatorLevel: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }
}

private enum TimelineSequenceNodeID: Hashable {
    case wake
    case task(String)
    case sleep
}

private struct TimelineSequenceNode {
    let id: TimelineSequenceNodeID
    let minute: Int
    let fillStart: Int
    let fillEnd: Int
}

private struct TimelineSequenceModel {
    let nodes: [TimelineSequenceNode]

    private let currentMinute: Int
    private let isToday: Bool
    private let isPastDay: Bool

    init(day: Date, now: Date, wakeMinute: Int, sleepMinute: Int, tasks: [PlannerTask]) {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        let todayStart = calendar.startOfDay(for: now)
        isToday = calendar.isDate(day, inSameDayAs: now)
        isPastDay = dayStart < todayStart

        let components = calendar.dateComponents([.hour, .minute], from: now)
        var current = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if sleepMinute > 24 * 60 && current < wakeMinute {
            current += 24 * 60
        }
        currentMinute = current

        struct RawTask {
            let task: PlannerTask
            let start: Int
            let end: Int
        }

        func adjusted(_ minute: Int) -> Int {
            sleepMinute > 24 * 60 && minute < wakeMinute ? minute + 24 * 60 : minute
        }

        let latestTaskMinute = max(wakeMinute + 1, sleepMinute - 1)
        let rawTasks: [RawTask] = tasks.compactMap { task in
            guard task.allDay != true,
                  task.status != .skipped,
                  let rawStart = TimeMath.minutes(task.startTime) else { return nil }

            let start = adjusted(rawStart)
            guard start < sleepMinute else { return nil }

            let rawEnd = TimeMath.minutes(task.endTime) ?? (rawStart + max(1, task.durationMinutes))
            var end = adjusted(rawEnd)
            if end <= start {
                end = start + max(1, task.durationMinutes)
            }

            return RawTask(
                task: task,
                start: max(wakeMinute, min(latestTaskMinute, start)),
                end: max(start + 1, min(sleepMinute, end))
            )
        }
        .sorted {
            if $0.start == $1.start { return $0.task.id < $1.task.id }
            return $0.start < $1.start
        }

        let firstTaskStart = rawTasks.first?.start ?? sleepMinute
        let wakeFillEnd = min(
            max(wakeMinute + 1, sleepMinute - 1),
            max(wakeMinute + 1, min(wakeMinute + 30, firstTaskStart))
        )

        var built: [TimelineSequenceNode] = [
            TimelineSequenceNode(
                id: .wake,
                minute: wakeMinute,
                fillStart: wakeMinute,
                fillEnd: wakeFillEnd
            )
        ]

        var cursor = wakeFillEnd

        for index in rawTasks.indices {
            let raw = rawTasks[index]
            var fillStart = max(raw.start, cursor)
            fillStart = min(fillStart, max(wakeMinute + 1, sleepMinute - 1))

            let nextScheduledStart: Int? = {
                guard rawTasks.indices.contains(index + 1) else { return nil }
                return rawTasks[index + 1].start
            }()

            var fillEnd = max(fillStart + 1, raw.end)
            if let nextScheduledStart, nextScheduledStart > fillStart {
                fillEnd = min(fillEnd, nextScheduledStart)
            }
            fillEnd = min(fillEnd, sleepMinute - 1)

            if fillEnd <= fillStart {
                fillEnd = min(sleepMinute - 1, fillStart + 1)
            }

            guard fillEnd > fillStart else { continue }

            built.append(
                TimelineSequenceNode(
                    id: .task(raw.task.id),
                    minute: raw.start,
                    fillStart: fillStart,
                    fillEnd: fillEnd
                )
            )
            cursor = fillEnd
        }

        let lastFillEnd = min(max(wakeFillEnd, cursor), max(wakeMinute + 1, sleepMinute - 1))
        let availableForSleep = max(1, sleepMinute - lastFillEnd)
        let sleepFillDuration = min(30, availableForSleep)
        let sleepFillStart = max(lastFillEnd, sleepMinute - sleepFillDuration)

        built.append(
            TimelineSequenceNode(
                id: .sleep,
                minute: sleepMinute,
                fillStart: sleepFillStart,
                fillEnd: sleepMinute
            )
        )

        nodes = built
    }

    func nodeProgress(_ id: TimelineSequenceNodeID) -> CGFloat {
        guard let node = nodes.first(where: { $0.id == id }) else { return 0 }
        if isPastDay { return 1 }
        guard isToday else { return 0 }

        if currentMinute <= node.fillStart { return 0 }
        if currentMinute >= node.fillEnd { return 1 }

        return CGFloat(currentMinute - node.fillStart) / CGFloat(max(1, node.fillEnd - node.fillStart))
    }

    func connectorProgress(from: TimelineSequenceNodeID, to: TimelineSequenceNodeID) -> CGFloat {
        guard let fromNode = nodes.first(where: { $0.id == from }),
              let toNode = nodes.first(where: { $0.id == to }) else { return 0 }

        if isPastDay { return 1 }
        guard isToday else { return 0 }

        let start = fromNode.fillEnd
        let end = toNode.fillStart

        if end <= start {
            return currentMinute >= end ? 1 : 0
        }
        if currentMinute <= start { return 0 }
        if currentMinute >= end { return 1 }

        return CGFloat(currentMinute - start) / CGFloat(end - start)
    }

    func minute(for id: TimelineSequenceNodeID) -> Int? {
        nodes.first(where: { $0.id == id })?.minute
    }

    func lineHeadPosition(_ position: (TimelineSequenceNodeID) -> CGFloat) -> CGFloat {
        guard let first = nodes.first, let last = nodes.last else { return 0 }

        if isPastDay { return position(last.id) }
        guard isToday else { return position(first.id) }

        if currentMinute <= first.fillEnd {
            return position(first.id)
        }

        for index in 0..<(nodes.count - 1) {
            let fromNode = nodes[index]
            let toNode = nodes[index + 1]

            if currentMinute < toNode.fillStart {
                let progress = connectorProgress(from: fromNode.id, to: toNode.id)
                let fromPosition = position(fromNode.id)
                let toPosition = position(toNode.id)
                return fromPosition + (toPosition - fromPosition) * progress
            }

            if currentMinute <= toNode.fillEnd {
                return position(toNode.id)
            }
        }

        return position(last.id)
    }
}

private struct WeeklyLiveTimeline: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var displayMode: TimelineDisplayMode = .day
    @State private var weekLayout: TimelineLayoutStyle = .horizontal
    @State private var showNavigator = false
    @State private var showTimelinePaywall = false
    @State private var lensMode: TimelineLensMode = .wholeDay
    @State private var realityEnabled = true

    private var selectedDate: Date {
        DateKey.date(store.selectedDate) ?? .now
    }

    private var weekDates: [Date] {
        let monday = TimelineDateMath.startOfWeek(containing: selectedDate)
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: monday) }
    }

    private var wakeMinute: Int {
        TimeMath.minutes(store.data.profile.wakeTime) ?? 8 * 60
    }

    private var sleepMinute: Int {
        let raw = TimeMath.minutes(store.data.profile.sleepTime) ?? 23 * 60
        return raw <= wakeMinute ? raw + 24 * 60 : raw
    }

    private var baseRulerStart: Int {
        max(0, (wakeMinute / 60) * 60)
    }

    private var baseRulerEnd: Int {
        let dates = displayMode == .week ? weekDates : [selectedDate]
        var latest = sleepMinute
        for date in dates {
            let tasks = store.data.plans.first(where: { $0.date == DateKey.string(date) })?.tasks ?? []
            for task in tasks where task.allDay != true {
                guard let rawStart = TimeMath.minutes(task.startTime) else { continue }
                var start = rawStart
                if sleepMinute > 24 * 60 && start < wakeMinute { start += 24 * 60 }
                var end = TimeMath.minutes(task.endTime) ?? (rawStart + max(5, task.durationMinutes))
                if sleepMinute > 24 * 60 && end < wakeMinute { end += 24 * 60 }
                if end <= start { end = start + max(5, task.durationMinutes) }
                latest = max(latest, end + max(0, task.bufferAfterMinutes ?? 0))
            }
        }
        return min(wakeMinute + 22 * 60, ((latest + 59) / 60) * 60)
    }

    /// Seven vertical day rails share one height so the week reads as a true seven-column
    /// timeline. The canvas grows for dense weeks instead of shrinking nodes into overlaps.
    private var weekVerticalCanvasHeight: CGFloat {
        let busiestDay = weekDates.map { timedTaskCount(on: $0) }.max() ?? 0
        return min(1_100, max(460, 350 + CGFloat(busiestDay) * 28))
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)

        SwiftUI.TimelineView(.periodic(from: .now, by: 30)) { context in
            let range = visibleRange(now: context.date)

            VStack(alignment: .leading, spacing: 14) {
                header(now: context.date, palette: p)
                modeAndNavigation(now: context.date, palette: p)

                ZStack {
                    if displayMode == .day && (store.data.settings.timelineLayout ?? .horizontal) != .vertical {
                        // Horizontal can grow beyond the screen. Its one-finger
                        // horizontal drag belongs to the elastic canvas, not day navigation.
                        Color.clear
                            .contentShape(Rectangle())
                            .simultaneousGesture(semanticZoomGesture(now: context.date))
                    } else {
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(periodSwipeGesture)
                            .simultaneousGesture(semanticZoomGesture(now: context.date))
                    }

                    if displayMode == .week {
                        weekContent(now: context.date, palette: p)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    } else {
                        dayContent(
                            now: context.date,
                            palette: p,
                            rulerStart: range.start,
                            rulerEnd: range.end
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    }
                }
                .animation(.spring(duration: 0.35, bounce: 0.08), value: displayMode)
                .animation(.spring(duration: 0.35, bounce: 0.08), value: store.selectedDate)
                .animation(.spring(duration: 0.35, bounce: 0.08), value: lensMode)
                .onChange(of: Int(context.date.timeIntervalSince1970 / 30)) { _, _ in
                    _ = store.completeElapsedPersonalTasks(now: context.date)
                }
            }
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showNavigator) {
            TimelineNavigatorSheet(initialDate: selectedDate) { date, mode in
                withAnimation(.spring(duration: 0.38, bounce: 0.08)) {
                    store.selectDate(date)
                    displayMode = mode
                    lensMode = .wholeDay
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTimelinePaywall) {
            NavigationStack { PaywallView() }
        }
        .onChange(of: store.selectedDate) { _, _ in
            if !Calendar.current.isDateInToday(selectedDate) {
                lensMode = .wholeDay
            }
        }
        .onAppear {
            let savedWeekLayout = store.data.settings.weekTimelineLayout ?? .horizontal
            weekLayout = savedWeekLayout == .orbit ? .horizontal : savedWeekLayout
            realityEnabled = store.data.settings.timelineRealityEnabled != false
            if store.data.settings.timelineGravityEnabled == true { lensMode = .gravity }
        }
        .onChange(of: realityEnabled) { _, enabled in
            store.data.settings.timelineRealityEnabled = enabled
            store.persist()
        }
        .onChange(of: lensMode) { _, mode in
            store.data.settings.timelineGravityEnabled = (mode == .gravity)
            store.persist()
        }
        .planningFeedback(.selection, trigger: displayMode)
        .planningFeedback(.selection, trigger: lensMode)
    }

    @ViewBuilder
    private func header(now: Date, palette p: AppPalette) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Live timeline")
                .font(.title3.weight(.semibold))
                .foregroundStyle(p.text)

            if displayMode == .day && Calendar.current.isDateInToday(selectedDate) {
                Label("LIVE", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(p.accent)
            }

            Spacer(minLength: 8)

            Text(now.formatted(.dateTime.hour().minute()))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(p.secondary)
        }
    }

    @ViewBuilder
    private func modeAndNavigation(now: Date, palette p: AppPalette) -> some View {
        VStack(spacing: 10) {
            PlanningAdaptiveRow(spacing: 9) {
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(TimelineDisplayMode.allCases) { mode in
                            if displayMode == mode {
                                timelineModeButton(mode)
                                    .buttonStyle(.glassProminent)
                                    .tint(p.accent)
                                    .accessibilityAddTraits(.isSelected)
                            } else {
                                timelineModeButton(mode)
                                    .buttonStyle(.glass)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Menu {
                    ForEach(availableLayoutStyles) { style in
                        let locked = style != .horizontal && !store.hasAccess(.advancedTimelineViews)
                        Button {
                            if locked { showTimelinePaywall = true } else { setActiveLayout(style) }
                        } label: {
                            if locked {
                                Label(style.label + " · Pro", systemImage: "lock.fill")
                            } else {
                                Label(style.label, systemImage: style.symbol)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: activeLayoutStyle.symbol)
                        Text(activeLayoutStyle.label)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 72, minHeight: 32)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Timeline layout")
            }

            HStack(spacing: 8) {
                Button {
                    movePeriod(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(displayMode == .week ? "Previous week" : "Previous day")

                Button {
                    showNavigator = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "calendar")
                        Text(periodTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button {
                    movePeriod(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 30)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(displayMode == .week ? "Next week" : "Next day")

                Button {
                    jumpToToday()
                } label: {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 3)
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Return to today")
            }


        }
    }

    private func timelineOptionButton(
        title: String,
        symbol: String,
        isOn: Bool,
        palette p: AppPalette,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).accessibilityHidden(true)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Text(isOn ? "On" : "Off").font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.glass)
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private func timelineModeButton(_ mode: TimelineDisplayMode) -> some View {
        Button {
            withAnimation(.spring(duration: 0.34, bounce: 0.08)) { displayMode = mode }
        } label: {
            Text(mode.rawValue)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func readingControls(palette p: AppPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Read your schedule", subtitle: "View options · your task times stay unchanged")
            GlassEffectContainer(spacing: 8) {
                PlanningAdaptiveRow(spacing: 8) {
                    timelineOptionButton(title: "Reality", symbol: "square.stack.3d.up", isOn: realityEnabled, palette: p) { realityEnabled.toggle() }
                    timelineOptionButton(title: "Gravity", symbol: "circle.hexagongrid", isOn: lensMode == .gravity, palette: p) {
                        withAnimation(.spring(duration: 0.32, bounce: 0.06)) {
                            lensMode = lensMode == .gravity ? .wholeDay : .gravity
                        }
                    }
                }
            }
        }
    }

    private func weekContent(now: Date, palette p: AppPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if weekLayout == .vertical && store.hasAccess(.advancedTimelineViews) {
                GeometryReader { proxy in
                let columnSpacing: CGFloat = 3
                let columnWidth = max(38, (proxy.size.width - columnSpacing * 6) / 7)

                HStack(alignment: .top, spacing: columnSpacing) {
                    ForEach(weekDates, id: \.self) { day in
                        WeekVerticalDayRail(
                            day: day,
                            now: now,
                            wakeMinute: wakeMinute,
                            sleepMinute: sleepMinute,
                            canvasHeight: weekVerticalCanvasHeight,
                            onOpenDay: {
                                withAnimation(.spring(duration: 0.36, bounce: 0.08)) {
                                    store.selectDate(day)
                                    displayMode = .day
                                    lensMode = .wholeDay
                                }
                            }
                        )
                        .frame(width: columnWidth)
                    }
                }
                .frame(width: proxy.size.width, alignment: .center)
            }
            .frame(height: weekVerticalCanvasHeight + 54)
        } else {
            VStack(spacing: 7) {
                ForEach(weekDates, id: \.self) { day in
                    WeekTimelineDayRow(
                        day: day,
                        now: now,
                        wakeMinute: wakeMinute,
                        sleepMinute: sleepMinute,
                        rulerStart: baseRulerStart,
                        rulerEnd: baseRulerEnd,
                        expanded: false,
                        showDayLabel: true,
                        realityEnabled: realityEnabled,
                        onOpenDay: {
                            withAnimation(.spring(duration: 0.36, bounce: 0.08)) {
                                store.selectDate(day)
                                displayMode = .day
                                lensMode = .wholeDay
                            }
                        }
                    )
                }
                }
            }

            readingControls(palette: p)

            if realityEnabled {
                TimelineRealityOverview(days: weekDates, now: now, title: "Week Reality")
            }
            if lensMode == .gravity {
                TimelineGravityOverview(days: weekDates, now: now, title: "Week Gravity")
            }
            if store.data.settings.timelineDeadlineRadarEnabled != false {
                TimelineDeadlineRadar(days: weekDates, now: now)
            }
            WeekTimelineControlDeck(
                days: weekDates,
                now: now,
                wakeMinute: wakeMinute,
                sleepMinute: sleepMinute,
                onOpenDay: { day in
                    withAnimation(.spring(duration: 0.36, bounce: 0.08)) {
                        store.selectDate(day)
                        displayMode = .day
                        lensMode = .wholeDay
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func dayContent(now: Date, palette p: AppPalette, rulerStart: Int, rulerEnd: Int) -> some View {
        let savedLayout = store.data.settings.timelineLayout ?? .horizontal
        let requestedLayout: TimelineLayoutStyle = savedLayout == .orbit ? .horizontal : savedLayout
        let layout: TimelineLayoutStyle = (requestedLayout == .horizontal || store.hasAccess(.advancedTimelineViews)) ? requestedLayout : .horizontal
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.title3.weight(.semibold))
                    Text("\(timedTaskCount(on: selectedDate)) timed tasks · \(clockLabel(wakeMinute))–\(clockLabel(sleepMinute))")
                        .font(.caption)
                        .foregroundStyle(p.secondary)
                }
                Spacer()
                Button {
                    var task = PlanEngine.manualTask(title: "", date: store.selectedDate)
                    task.startTime = Calendar.current.isDateInToday(selectedDate) ? TimeMath.string(TimeMath.nowMinutes) : nil
                    store.presentedTask = task
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glassProminent)
                .accessibilityLabel("Add task to this timeline")
                if lensMode != .wholeDay && Calendar.current.isDateInToday(selectedDate) {
                    Text(lensMode == .detail ? "DETAIL · 2H" : lensMode == .gravity ? "TIME GRAVITY" : "NOW LENS")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(p.accent)
                }
            }

            if store.canUndoTimelineChange {
                HStack(spacing: 10) {
                    Label(store.timelineUndoLabel ?? "Timeline updated", systemImage: "arrow.uturn.backward.circle")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") { store.undoLastTimelineChange() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.small)
                }
                .padding(12)
                .premiumGlassRounded(cornerRadius: 20, tint: p.accent.opacity(0.045), interactive: true)
            }

            TimelinePulseStrip(
                day: selectedDate,
                now: now,
                wakeMinute: wakeMinute,
                sleepMinute: sleepMinute
            )

            switch layout {
            case .horizontal, .orbit:
                WeekTimelineDayRow(
                    day: selectedDate,
                    now: now,
                    wakeMinute: wakeMinute,
                    sleepMinute: sleepMinute,
                    rulerStart: rulerStart,
                    rulerEnd: rulerEnd,
                    expanded: true,
                    showDayLabel: false,
                    realityEnabled: realityEnabled,
                    onOpenDay: {}
                )
            case .vertical:
                VerticalLiveTimeline(
                    day: selectedDate,
                    now: now,
                    wakeMinute: wakeMinute,
                    sleepMinute: sleepMinute
                )
            }

            readingControls(palette: p)

            if realityEnabled {
                TimelineRealityOverview(days: [selectedDate], now: now, title: "Reality")
            }
            if lensMode == .gravity {
                TimelineGravityOverview(days: [selectedDate], now: now, title: "Gravity Focus")
            }
            if store.data.settings.timelineDeadlineRadarEnabled != false {
                TimelineDeadlineRadar(days: [selectedDate], now: now)
            }

            if store.data.settings.timelineShowDayPath != false {
                TimelineDayPath(day: selectedDate, now: now, wakeMinute: wakeMinute, sleepMinute: sleepMinute)
            }

            TimelineControlDeck(
                day: selectedDate,
                now: now,
                wakeMinute: wakeMinute,
                sleepMinute: sleepMinute,
                rulerEnd: baseRulerEnd
            )

            TimelineOpenSpaceStrip(
                day: selectedDate,
                now: now,
                wakeMinute: wakeMinute,
                sleepMinute: sleepMinute
            )
        }
    }

    private var availableLayoutStyles: [TimelineLayoutStyle] {
        TimelineLayoutStyle.selectableCases
    }

    private var activeLayoutStyle: TimelineLayoutStyle {
        if displayMode == .week {
            return (weekLayout == .horizontal || store.hasAccess(.advancedTimelineViews)) ? weekLayout : .horizontal
        }
        let saved = store.data.settings.timelineLayout ?? .horizontal
        let requested: TimelineLayoutStyle = saved == .orbit ? .horizontal : saved
        return (requested == .horizontal || store.hasAccess(.advancedTimelineViews)) ? requested : .horizontal
    }

    private func setActiveLayout(_ style: TimelineLayoutStyle) {
        guard style == .horizontal || store.hasAccess(.advancedTimelineViews) else {
            showTimelinePaywall = true
            return
        }
        withAnimation(.spring(duration: 0.34, bounce: 0.06)) {
            if displayMode == .week {
                weekLayout = style
                store.data.settings.weekTimelineLayout = style
                store.persist()
            } else {
                store.data.settings.timelineLayout = style
                store.persist()
            }
        }
    }

    private var periodTitle: String {
        if displayMode == .day {
            return selectedDate.formatted(.dateTime.month(.abbreviated).day().year())
        }
        guard let first = weekDates.first, let last = weekDates.last else { return "Week" }
        if Calendar.current.component(.month, from: first) == Calendar.current.component(.month, from: last) {
            return "\(first.formatted(.dateTime.month(.abbreviated))) \(first.formatted(.dateTime.day()))–\(last.formatted(.dateTime.day()))"
        }
        return "\(first.formatted(.dateTime.month(.abbreviated).day()))–\(last.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 28)
            .onEnded { value in
                let x = value.translation.width
                let y = value.translation.height
                guard abs(x) > 85, abs(x) > abs(y) * 1.25 else { return }
                movePeriod(x < 0 ? 1 : -1)
            }
    }

    private func semanticZoomGesture(now: Date) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.08)
            .onEnded { value in
                let zoomIn = value.magnification > 1.08
                let zoomOut = value.magnification < 0.94
                guard zoomIn || zoomOut else { return }
                withAnimation(.spring(duration: 0.34, bounce: 0.06)) {
                    if displayMode == .week { if zoomIn { displayMode = .day; lensMode = .wholeDay }; return }
                    if zoomOut {
                        switch lensMode {
                        case .detail: lensMode = .now
                        case .now, .gravity: lensMode = .wholeDay
                        case .wholeDay: displayMode = .week
                        }
                        return
                    }
                    guard Calendar.current.isDate(selectedDate, inSameDayAs: now) else { return }
                    switch lensMode {
                    case .wholeDay, .gravity: lensMode = .now
                    case .now: lensMode = .detail
                    case .detail: break
                    }
                }
            }
    }

    private func visibleRange(now: Date) -> (start: Int, end: Int) {
        guard displayMode == .day, lensMode != .wholeDay else { return (baseRulerStart, baseRulerEnd) }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        var current = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && current < wakeMinute { current += 24 * 60 }

        var center = current
        if lensMode == .gravity {
            let tasks = store.data.plans.first(where: { $0.date == store.selectedDate })?.tasks ?? []
            let futureStarts = tasks.compactMap { task -> Int? in
                guard task.status != .completed && task.status != .skipped, let raw = TimeMath.minutes(task.startTime) else { return nil }
                var minute = raw
                if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
                return minute
            }.filter { $0 >= current }.sorted()
            if let first = futureStarts.first { center = (current + first) / 2 }
        }

        let desiredSpan = lensMode == .detail ? 2 * 60 : lensMode == .gravity ? 6 * 60 : 4 * 60
        let lead = lensMode == .detail ? 45 : desiredSpan / 3
        var start = max(baseRulerStart, center - lead)
        var end = min(baseRulerEnd, start + desiredSpan)
        if end - start < desiredSpan { start = max(baseRulerStart, end - desiredSpan) }
        let snap = lensMode == .detail ? 15 : 30
        start = (start / snap) * snap
        end = min(baseRulerEnd, max(start + 60, Int(ceil(Double(end) / Double(snap))) * snap))
        return (start, end)
    }

    private func movePeriod(_ direction: Int) {
        let dayDelta = displayMode == .week ? 7 * direction : direction
        guard let next = Calendar.current.date(byAdding: .day, value: dayDelta, to: selectedDate) else { return }
        withAnimation(.spring(duration: 0.38, bounce: 0.08)) {
            store.selectDate(next)
            lensMode = .wholeDay
        }
    }

    private func jumpToToday() {
        withAnimation(.spring(duration: 0.38, bounce: 0.08)) {
            store.selectDate(.now)
        }
    }

    private func timedTaskCount(on date: Date) -> Int {
        let key = DateKey.string(date)
        return (store.data.plans.first(where: { $0.date == key })?.tasks ?? []).filter {
            $0.allDay != true && TimeMath.minutes($0.startTime) != nil
        }.count
    }

    private func clockLabel(_ minute: Int) -> String {
        let wrapped = ((minute % (24 * 60)) + (24 * 60)) % (24 * 60)
        return TimeMath.string(wrapped)
    }
}

private struct TimelineNavigatorSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var draftDate: Date
    @State private var level: TimelineNavigatorLevel = .week

    let onOpen: (Date, TimelineDisplayMode) -> Void

    init(initialDate: Date, onOpen: @escaping (Date, TimelineDisplayMode) -> Void) {
        _draftDate = State(initialValue: initialDate)
        self.onOpen = onOpen
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MatteCard {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Jump through time")
                                        .font(.title3.weight(.semibold))
                                    Text(draftDate.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                                        .font(.subheadline)
                                        .foregroundStyle(p.secondary)
                                }
                                Spacer()
                                Image(systemName: "calendar.badge.clock")
                                    .font(.title2)
                                    .foregroundStyle(p.accent)
                            }

                            DatePicker("Exact date", selection: $draftDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }

                    Picker("Calendar scale", selection: $level) {
                        ForEach(TimelineNavigatorLevel.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch level {
                    case .year:
                        yearGrid(palette: p)
                    case .month:
                        monthGrid(palette: p)
                    case .week:
                        weekList(palette: p)
                    }
                }
                .padding(16)
                .padding(.bottom, 92)
            }
            .appCanvas()
            .navigationTitle("Timeline Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") { draftDate = .now }
                }
            }
            .safeAreaInset(edge: .bottom) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            onOpen(draftDate, .day)
                            dismiss()
                        } label: {
                            Label("Open Day", systemImage: "calendar.day.timeline.left")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button {
                            onOpen(TimelineDateMath.startOfWeek(containing: draftDate), .week)
                            dismiss()
                        } label: {
                            Label("Open Week", systemImage: "calendar")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func yearGrid(palette p: AppPalette) -> some View {
        let selectedYear = Calendar.current.component(.year, from: draftDate)
        let currentYear = Calendar.current.component(.year, from: .now)
        let lowerBound = min(1900, selectedYear - 100)
        let upperBound = max(2200, selectedYear + 100)
        let years = Array(lowerBound...upperBound)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Year")
                    .font(.headline)
                Spacer()
                if selectedYear != currentYear {
                    Button("Current year") {
                        setYear(currentYear)
                    }
                    .font(.caption)
                }
            }

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(years, id: \.self) { year in
                            Button {
                                setYear(year)
                                level = .month
                            } label: {
                                Text(String(year))
                                    .font(.subheadline.weight(year == selectedYear ? .bold : .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .premiumGlassRounded(
                                        cornerRadius: 14,
                                        tint: year == selectedYear ? p.accent.opacity(0.18) : p.accent.opacity(0.02),
                                        interactive: true
                                    )
                            }
                            .buttonStyle(.plain)
                            .id(year)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxHeight: 390)
                .onAppear {
                    DispatchQueue.main.async {
                        proxy.scrollTo(selectedYear, anchor: .center)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func monthGrid(palette p: AppPalette) -> some View {
        let year = Calendar.current.component(.year, from: draftDate)
        let selectedMonth = Calendar.current.component(.month, from: draftDate)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { setYear(year - 1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.glass)
                Spacer()
                Text(String(year)).font(.headline)
                Spacer()
                Button { setYear(year + 1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.glass)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        setMonth(month)
                        level = .week
                    } label: {
                        VStack(spacing: 3) {
                            Text(monthName(month))
                                .font(.subheadline.weight(month == selectedMonth ? .bold : .medium))
                            Text("\(month)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(p.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .premiumGlassRounded(
                            cornerRadius: 14,
                            tint: month == selectedMonth ? p.accent.opacity(0.18) : p.accent.opacity(0.02),
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func weekList(palette p: AppPalette) -> some View {
        let year = Calendar.current.component(.year, from: draftDate)
        let month = Calendar.current.component(.month, from: draftDate)
        let selectedWeek = TimelineDateMath.startOfWeek(containing: draftDate)

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { moveMonth(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.glass)
                Spacer()
                Button {
                    level = .month
                } label: {
                    Text(monthName(month) + " " + String(year))
                        .font(.headline)
                }
                .buttonStyle(.glass)
                Spacer()
                Button { moveMonth(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.glass)
            }

            VStack(spacing: 8) {
                ForEach(weeksInDraftMonth, id: \.self) { monday in
                    let sunday = Calendar.current.date(byAdding: .day, value: 6, to: monday) ?? monday
                    let isSelected = Calendar.current.isDate(monday, inSameDayAs: selectedWeek)

                    Button {
                        draftDate = monday
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Week of \(monday.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(monday.formatted(.dateTime.weekday(.abbreviated))) \(monday.formatted(.dateTime.day())) – \(sunday.formatted(.dateTime.weekday(.abbreviated))) \(sunday.formatted(.dateTime.month(.abbreviated).day()))")
                                    .font(.caption)
                                    .foregroundStyle(p.secondary)
                            }
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(p.accent)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(p.secondary)
                            }
                        }
                        .padding(13)
                        .premiumGlassRounded(
                            cornerRadius: 16,
                            tint: isSelected ? p.accent.opacity(0.16) : p.accent.opacity(0.02),
                            interactive: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var weeksInDraftMonth: [Date] {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: draftDate)
        guard let firstOfMonth = calendar.date(from: comps),
              let monthRange = calendar.range(of: .day, in: .month, for: firstOfMonth),
              let lastOfMonth = calendar.date(byAdding: .day, value: monthRange.count - 1, to: firstOfMonth) else { return [] }

        let firstMonday = TimelineDateMath.startOfWeek(containing: firstOfMonth)
        var result: [Date] = []
        var cursor = firstMonday
        while cursor <= lastOfMonth {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func setYear(_ year: Int) {
        var comps = Calendar.current.dateComponents([.month, .day], from: draftDate)
        comps.year = year
        draftDate = Calendar.current.date(from: comps) ?? draftDate
    }

    private func setMonth(_ month: Int) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: draftDate)
        let currentDay = calendar.component(.day, from: draftDate)
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return }
        comps.day = min(currentDay, range.count)
        draftDate = calendar.date(from: comps) ?? first
    }

    private func moveMonth(_ delta: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: delta, to: draftDate) {
            draftDate = next
        }
    }

    private func monthName(_ month: Int) -> String {
        let symbols = Calendar.current.shortMonthSymbols
        guard symbols.indices.contains(month - 1) else { return "Month" }
        return symbols[month - 1]
    }
}

private struct WeekVerticalDayRail: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int
    let canvasHeight: CGFloat
    let onOpenDay: () -> Void

    @State private var dropPulse = 0
    @State private var moveProposal: TimelineMoveProposal?

    private let verticalInset: CGFloat = 34
    private let gap: CGFloat = 7

    private var key: String { DateKey.string(day) }

    private var tasks: [PlannerTask] {
        TaskTimelineOrder.sorted(store.data.plans.first(where: { $0.date == key })?.tasks ?? []).filter {
            $0.allDay != true && TimeMath.minutes($0.startTime) != nil && $0.status != .skipped
        }
    }

    private var sequence: TimelineSequenceModel {
        TimelineSequenceModel(day: day, now: now, wakeMinute: wakeMinute, sleepMinute: sleepMinute, tasks: tasks)
    }

    private var nodeSize: CGFloat {
        let count = max(1, tasks.count)
        let densityFit = (canvasHeight - verticalInset * 2 - 28) / CGFloat(count + 2)
        // Week Vertical is deliberately larger than the 25pt Week Horizontal beads,
        // while the shared height grows for dense weeks to preserve collision safety.
        return min(38, max(26, densityFit))
    }

    private var requestedMaxScale: CGFloat {
        max(1, tasks.map { task -> CGFloat in
            guard TimelineShapeEngine.resolvedShape(for: task) != .circle else { return 1 }
            return CGFloat(min(3.50, max(1.15, task.timelineOvalLengthScale ?? 1.45)))
        }.max() ?? 1)
    }

    private var weekOvalScaleLimit: CGFloat {
        guard !tasks.isEmpty else { return 3.50 }
        let track = max(1, canvasHeight - verticalInset * 2)
        let endpointReserve = nodeSize * 1.45
        let gaps = CGFloat(tasks.count + 1) * gap
        let availableForTasks = max(nodeSize * CGFloat(tasks.count), track - endpointReserve - gaps)
        let perTask = availableForTasks / CGFloat(max(1, tasks.count))
        return min(3.50, max(1.0, perTask / max(1, nodeSize)))
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)

        VStack(spacing: 7) {
            Button(action: onOpenDay) {
                VStack(spacing: 1) {
                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(.bold))
                    Text(day.formatted(.dateTime.day()))
                        .font(.caption.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(isToday ? p.accent : p.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .premiumGlassCapsule(tint: isToday ? p.accent.opacity(0.10) : p.accent.opacity(0.018), interactive: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))")

            GeometryReader { proxy in
                let railX = proxy.size.width / 2
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(p.border.opacity(0.74))
                        .frame(width: 8, height: max(1, proxy.size.height - verticalInset * 2))
                        .position(x: railX, y: proxy.size.height / 2)

                    let fillHeight = liveFillHeight(height: proxy.size.height)
                    Capsule()
                        .fill(LinearGradient(colors: [p.accent, p.accent.opacity(0.55)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 8, height: fillHeight)
                        .position(x: railX, y: verticalInset + fillHeight / 2)
                        .animation(.linear(duration: 0.35), value: fillHeight)

                    endpointBead(
                        systemName: "sunrise.fill",
                        tint: p.accent,
                        progress: sequence.nodeProgress(.wake)
                    )
                    .position(x: railX, y: verticalInset)

                    endpointBead(
                        systemName: "moon.stars.fill",
                        tint: p.secondary,
                        progress: sequence.nodeProgress(.sleep)
                    )
                    .position(x: railX, y: proxy.size.height - verticalInset)

                    ForEach(tasks) { task in
                        if let raw = TimeMath.minutes(task.startTime) {
                            let start = adjusted(raw)
                            let y = taskY(task, minute: start, height: proxy.size.height)

                            WeekTimelineTaskNode(
                                task: task,
                                day: day,
                                now: now,
                                size: nodeSize,
                                flow: .vertical,
                                ovalScaleLimit: min(requestedMaxScale, weekOvalScaleLimit),
                                progressOverride: sequence.nodeProgress(.task(task.id))
                            )
                            .position(x: railX, y: y)

                        }
                    }
                }
                .contentShape(Rectangle())
                .dropDestination(for: String.self) { items, location in
                    guard let payload = items.first else { return false }
                    let minute = minuteForY(location.y, height: proxy.size.height)
                    let snapped = max(wakeMinute, min(sleepMinute - 5, Int(round(Double(minute) / 15.0)) * 15))
                    let time = clock(snapped)

                    if payload.hasPrefix("task:") {
                        let id = String(payload.dropFirst(5))
                        moveProposal = store.timelineMoveProposal(taskID: id, toDate: key, startTime: time)
                        dropPulse += 1
                        return true
                    }
                    if payload.hasPrefix("inbox:"), let item = store.data.inbox.first(where: { $0.id == String(payload.dropFirst(6)) }) {
                        store.planInbox(item, on: key, at: time)
                        dropPulse += 1
                        return true
                    }
                    return false
                }
            }
            .frame(height: canvasHeight)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
        .planningFeedback(.selection, trigger: dropPulse)
        .sheet(item: $moveProposal) { proposal in
            TimelineMoveConfirmationSheet(proposal: proposal)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func effectiveScale(for task: PlannerTask) -> CGFloat {
        guard TimelineShapeEngine.resolvedShape(for: task) != .circle else { return 1 }
        let requested = CGFloat(min(3.50, max(1.15, task.timelineOvalLengthScale ?? 1.45)))
        return min(requested, weekOvalScaleLimit)
    }

    private func extent(for task: PlannerTask) -> CGFloat {
        TimelineShapeEngine.resolvedShape(for: task) == .circle ? nodeSize : nodeSize * effectiveScale(for: task)
    }

    private func taskY(_ task: PlannerTask, minute: Int, height: CGFloat) -> CGFloat {
        resolvedPositions(height: height)[task.id] ?? yPosition(for: minute, height: height)
    }

    private func resolvedPositions(height: CGFloat) -> [String: CGFloat] {
        let ordered = tasks.compactMap { task -> (PlannerTask, Int)? in
            guard let raw = TimeMath.minutes(task.startTime) else { return nil }
            return (task, adjusted(raw))
        }
        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.id < rhs.0.id : lhs.1 < rhs.1 }
        guard !ordered.isEmpty else { return [:] }

        var positions: [CGFloat] = []
        for (index, entry) in ordered.enumerated() {
            let currentExtent = extent(for: entry.0)
            let target = yPosition(for: entry.1, height: height)
            let minimum: CGFloat
            if index == 0 {
                minimum = verticalInset + nodeSize / 2 + gap + currentExtent / 2
            } else {
                let previousExtent = extent(for: ordered[index - 1].0)
                minimum = positions[index - 1] + previousExtent / 2 + gap + currentExtent / 2
            }
            positions.append(max(target, minimum))
        }

        if let lastIndex = positions.indices.last {
            let lastExtent = extent(for: ordered[lastIndex].0)
            let limit = height - verticalInset - nodeSize / 2 - gap - lastExtent / 2
            if positions[lastIndex] > limit {
                positions[lastIndex] = limit
                if lastIndex > 0 {
                    for index in stride(from: lastIndex - 1, through: 0, by: -1) {
                        let currentExtent = extent(for: ordered[index].0)
                        let nextExtent = extent(for: ordered[index + 1].0)
                        positions[index] = min(positions[index], positions[index + 1] - currentExtent / 2 - gap - nextExtent / 2)
                    }
                }
            }
        }

        return Dictionary(uniqueKeysWithValues: zip(ordered.map { $0.0.id }, positions))
    }

    private var currentMinute: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return adjusted((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    private func liveFillHeight(height: CGFloat) -> CGFloat {
        let wakeY = yPosition(for: wakeMinute, height: height)
        let sleepY = yPosition(for: sleepMinute, height: height)
        let headY = sequence.lineHeadPosition { id in
            switch id {
            case .wake:
                return wakeY
            case .sleep:
                return sleepY
            case .task(let taskID):
                guard let task = tasks.first(where: { $0.id == taskID }),
                      let raw = TimeMath.minutes(task.startTime) else { return wakeY }
                return taskY(task, minute: adjusted(raw), height: height)
            }
        }
        return min(max(0, sleepY - wakeY), max(0, headY - wakeY))
    }

    private func endpointBead(systemName: String, tint: Color, progress: CGFloat) -> some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let diameter = nodeSize
        let fill = min(1, max(0, progress))
        return ZStack {
            Circle().fill(p.background)
            Circle().fill(tint.opacity(scheme == .dark ? 0.075 : 0.050))
            Rectangle()
                .fill(LinearGradient(colors: [tint.opacity(0.50), tint.opacity(0.24)], startPoint: .top, endPoint: .bottom))
                .frame(width: diameter, height: diameter * fill)
                .frame(width: diameter, height: diameter, alignment: .top)
                .clipShape(Circle())
            Circle().stroke(tint.opacity(0.25), lineWidth: 1.2)
            Image(systemName: systemName)
                .font(.system(size: max(12, diameter * 0.40), weight: .bold))
                .foregroundStyle(tint)
        }
        .frame(width: diameter, height: diameter)
        .glassEffect(.regular.tint(tint.opacity(0.05)).interactive(), in: Circle())
    }

    private func adjusted(_ minute: Int) -> Int {
        sleepMinute > 1440 && minute < wakeMinute ? minute + 1440 : minute
    }

    private func yPosition(for minute: Int, height: CGFloat) -> CGFloat {
        let span = max(1, sleepMinute - wakeMinute)
        let clamped = max(wakeMinute, min(sleepMinute, minute))
        let ratio = CGFloat(clamped - wakeMinute) / CGFloat(span)
        return verticalInset + max(1, height - verticalInset * 2) * ratio
    }

    private func minuteForY(_ y: CGFloat, height: CGFloat) -> Int {
        let ratio = min(1, max(0, (y - verticalInset) / max(1, height - verticalInset * 2)))
        return wakeMinute + Int(CGFloat(sleepMinute - wakeMinute) * ratio)
    }

    private func clock(_ minute: Int) -> String {
        TimeMath.string(((minute % 1440) + 1440) % 1440)
    }
}

private struct WeekTimelineDayRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int
    let rulerStart: Int
    let rulerEnd: Int
    let expanded: Bool
    let showDayLabel: Bool
    let realityEnabled: Bool
    let onOpenDay: () -> Void

    @State private var draftTask: PlannerTask?
    @State private var dropPulse = 0
    @State private var moveProposal: TimelineMoveProposal?

    private struct TimedEntry: Identifiable {
        let task: PlannerTask
        let minute: Int
        let lane: Int
        var id: String { task.id }
    }

    private struct Segment {
        let fromMinute: Int
        let toMinute: Int
        let fromTint: Color
        let toTint: Color
    }

    private var key: String { DateKey.string(day) }
    private var rowHeight: CGFloat { expanded ? 304 : 92 }
    private var laneCount: Int { expanded ? 1 : 3 }
    private var centerY: CGFloat { rowHeight / 2 + (expanded ? 12 : 0) }
    private var compactNodeSize: CGFloat { 25 }

    private var dayTasks: [PlannerTask] {
        let tasks = store.data.plans.first(where: { $0.date == key })?.tasks ?? []
        return TaskTimelineOrder.sorted(tasks).filter {
            $0.allDay != true && TimeMath.minutes($0.startTime) != nil && $0.status != .skipped
        }
    }

    private var sequence: TimelineSequenceModel {
        TimelineSequenceModel(day: day, now: now, wakeMinute: wakeMinute, sleepMinute: sleepMinute, tasks: dayTasks)
    }

    private var positionedTasks: [TimedEntry] {
        var laneLastMinute = Array(repeating: -10_000, count: laneCount)
        let minimumSeparation = max(expanded ? 36 : 44, (rulerEnd - rulerStart) / (expanded ? 15 : 11))

        return dayTasks.compactMap { task in
            guard let raw = TimeMath.minutes(task.startTime) else { return nil }
            let minute = adjustedMinute(raw)
            let end = taskEndMinute(task, startMinute: minute)
            guard end >= rulerStart, minute <= rulerEnd else { return nil }

            let preferred = laneLastMinute.indices.first(where: {
                minute - laneLastMinute[$0] >= minimumSeparation
            }) ?? (laneLastMinute.indices.min(by: { laneLastMinute[$0] < laneLastMinute[$1] }) ?? 0)

            laneLastMinute[preferred] = minute
            return TimedEntry(task: task, minute: minute, lane: preferred)
        }
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let isSelected = key == store.selectedDate

        HStack(spacing: 8) {
            if showDayLabel {
                Button(action: onOpenDay) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption2.weight(.semibold))
                        Text(day.formatted(.dateTime.day()))
                            .font(.headline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(isToday ? p.accent : p.text)
                    .frame(width: 50, height: rowHeight, alignment: .leading)
                    .padding(.horizontal, 5)
                    .premiumGlassRounded(cornerRadius: 16, tint: isToday ? p.accent.opacity(0.08) : nil, interactive: true)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(day.formatted(.dateTime.weekday(.wide).month(.wide).day()))")
            }

            if expanded {
                GeometryReader { viewport in
                    let trackWidth = requiredContentWidth(viewportWidth: viewport.size.width)
                    ScrollView(.horizontal, showsIndicators: false) {
                        horizontalTrack(width: trackWidth, palette: p, isToday: isToday, isSelected: isSelected)
                            .frame(width: trackWidth, height: rowHeight)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(height: rowHeight)
            } else {
                GeometryReader { proxy in
                    horizontalTrack(width: proxy.size.width, palette: p, isToday: isToday, isSelected: isSelected)
                }
                .frame(height: rowHeight)
            }
        }
        .padding(.vertical, expanded ? 0 : 2)
        .sheet(item: $draftTask) { task in
            NavigationStack {
                TaskEditorView(task: task, isNew: true)
            }
        }
        .sheet(item: $moveProposal) { proposal in
            TimelineMoveConfirmationSheet(proposal: proposal)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .planningFeedback(.selection, trigger: dropPulse)
    }

    @ViewBuilder
    private func horizontalTrack(width: CGFloat, palette p: AppPalette, isToday: Bool, isSelected: Bool) -> some View {
        let trackNodeSize = horizontalNodeSize(width: width)
        ZStack(alignment: .topLeading) {
            if isSelected && !expanded {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(p.accent.opacity(scheme == .dark ? 0.08 : 0.055))
            }

            chain(width: width, palette: p)

            if realityEnabled {
                ForEach(positionedTasks) { entry in
                    realityRibbon(entry, width: width, palette: p)
                }
            }

            ForEach(positionedTasks) { entry in
                durationRibbon(entry, width: width, palette: p)
                bufferRibbon(entry, width: width, palette: p)
            }

            // The rail itself is the live clock. Do not place a pulse/ripple bead on top
            // of task nodes: it can visually collide with an icon at the exact current time.
            if isToday, expanded, let current = currentMinuteIfVisible {
                let x = xPosition(for: current, width: width)
                Text("NOW \(now.formatted(.dateTime.hour().minute()))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(p.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .premiumGlassCapsule(tint: p.accent.opacity(0.08), interactive: true)
                    .position(x: min(max(x, 56), max(56, width - 56)), y: centerY - 48)
                    .allowsHitTesting(false)
            }

            if wakeMinute >= rulerStart && wakeMinute <= rulerEnd {
                endpoint(
                    systemName: "sunrise.fill",
                    tint: p.accent,
                    progress: sequence.nodeProgress(.wake),
                    x: xPosition(for: wakeMinute, width: width),
                    y: centerY,
                    diameter: trackNodeSize
                )
            }

            if sleepMinute >= rulerStart && sleepMinute <= rulerEnd {
                endpoint(
                    systemName: "moon.stars.fill",
                    tint: p.secondary,
                    progress: sequence.nodeProgress(.sleep),
                    x: xPosition(for: sleepMinute, width: width),
                    y: centerY,
                    diameter: trackNodeSize
                )
            }

            ForEach(positionedTasks) { entry in
                let visualX = taskNodeX(entry, width: width)
                let exactX = xPosition(for: entry.minute, width: width)

                WeekTimelineTaskNode(
                    task: entry.task,
                    day: day,
                    now: now,
                    size: trackNodeSize,
                    flow: .horizontal,
                    ovalScaleLimit: expanded ? nil : compactOvalScaleLimit(for: entry, width: width, nodeSize: trackNodeSize),
                    progressOverride: sequence.nodeProgress(.task(entry.task.id))
                )
                .position(x: visualX, y: laneY(entry.lane))

                if expanded {
                    if abs(visualX - exactX) > 12 {
                        Rectangle()
                            .fill(p.secondary.opacity(0.22))
                            .frame(width: abs(visualX - exactX), height: 1)
                            .position(x: (visualX + exactX) / 2, y: centerY + 48)
                            .allowsHitTesting(false)
                        Circle()
                            .fill(p.secondary.opacity(0.58))
                            .frame(width: 5, height: 5)
                            .position(x: exactX, y: centerY + 48)
                            .allowsHitTesting(false)
                    }

                    Text(entry.task.startTime ?? "")
                        .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(p.secondary)
                        .position(x: visualX, y: centerY + 62)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: width, height: rowHeight)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, location in
            guard let payload = items.first else { return false }
            let minute = minuteForX(location.x, width: width)
            let snapped = max(wakeMinute, min(sleepMinute - 5, Int(round(Double(minute) / 15.0)) * 15))
            let time = clockString(snapped)

            if payload.hasPrefix("task:") {
                let id = String(payload.dropFirst(5))
                moveProposal = store.timelineMoveProposal(taskID: id, toDate: key, startTime: time)
                dropPulse += 1
                return true
            }

            if payload.hasPrefix("inbox:"),
               let item = store.data.inbox.first(where: { $0.id == String(payload.dropFirst(6)) }) {
                store.planInbox(item, on: key, at: time)
                dropPulse += 1
                return true
            }

            return false
        }
        .simultaneousGesture(
            SpatialTapGesture().onEnded { value in
                let hitTask = positionedTasks.contains { entry in
                    abs(taskNodeX(entry, width: width) - value.location.x) < trackNodeSize * maxOvalScale * 0.60 &&
                    abs(laneY(entry.lane) - value.location.y) < trackNodeSize * 0.70
                }
                guard !hitTask else { return }

                if showDayLabel {
                    onOpenDay()
                } else {
                    openDraftTask(at: minuteForX(value.location.x, width: width))
                }
            }
        )
    }

    @ViewBuilder
    private func endpoint(systemName: String, tint: Color, progress: CGFloat, x: CGFloat, y: CGFloat, diameter: CGFloat) -> some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let fill = min(1, max(0, progress))
        ZStack {
            // Opaque chain eraser behind a translucent system-glass shell.
            Circle().fill(p.background)
            Circle().fill(tint.opacity(scheme == .dark ? 0.075 : 0.050))
            Rectangle()
                .fill(LinearGradient(colors: [tint.opacity(0.50), tint.opacity(0.24)], startPoint: .leading, endPoint: .trailing))
                .frame(width: diameter * fill, height: diameter)
                .frame(width: diameter, height: diameter, alignment: .leading)
                .clipShape(Circle())
            Circle().stroke(tint.opacity(0.22), lineWidth: diameter >= 40 ? 1.35 : 0.9)
            Image(systemName: systemName)
                .font(.system(size: max(9, diameter * 0.40), weight: .bold))
                .foregroundStyle(fill > 0.02 ? tint : tint.opacity(0.74))
        }
        .frame(width: diameter, height: diameter)
        .glassEffect(.regular.tint(tint.opacity(0.06)).interactive(), in: Circle())
        .position(x: x, y: y)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func chain(width: CGFloat, palette p: AppPalette) -> some View {
        let x1 = xPosition(for: wakeMinute, width: width)
        let x2 = xPosition(for: sleepMinute, width: width)
        let segmentWidth = max(1, x2 - x1)
        let headX = liveRailHeadX(width: width)
        let fillWidth = min(segmentWidth, max(0, headX - x1))

        ZStack(alignment: .leading) {
            Capsule().fill(p.border.opacity(expanded ? 0.88 : 0.72))
            LinearGradient(colors: [p.accent, p.accent.opacity(0.76)], startPoint: .leading, endPoint: .trailing)
                .frame(width: fillWidth)
                .clipShape(Capsule())
        }
        .frame(width: segmentWidth, height: expanded ? 10 : 5)
        .offset(x: x1, y: centerY - (expanded ? 5 : 2.5))
        .animation(.linear(duration: 0.35), value: fillWidth)
        .allowsHitTesting(false)
    }

    private func liveRailHeadX(width: CGFloat) -> CGFloat {
        sequence.lineHeadPosition { id in
            switch id {
            case .wake:
                return xPosition(for: wakeMinute, width: width)
            case .sleep:
                return xPosition(for: sleepMinute, width: width)
            case .task(let taskID):
                if let entry = positionedTasks.first(where: { $0.task.id == taskID }) {
                    return taskNodeX(entry, width: width)
                }
                if let minute = sequence.minute(for: .task(taskID)) {
                    return xPosition(for: minute, width: width)
                }
                return xPosition(for: wakeMinute, width: width)
            }
        }
    }

    @ViewBuilder
    private func durationRibbon(_ entry: TimedEntry, width: CGFloat, palette p: AppPalette) -> some View {
        let start = entry.minute
        let plannedEnd = taskEndMinute(entry.task, startMinute: start)
        let liveEnd = entry.task.status == .active ? max(plannedEnd, currentTimelineMinute) : plannedEnd
        let end = min(rulerEnd, liveEnd)
        let overrun = max(0, liveEnd - plannedEnd)
        let x1 = taskNodeX(entry, width: width)
        let durationWidth = max(0, xPosition(for: end, width: width) - xPosition(for: start, width: width))
        let ribbonWidth = max(expanded ? 24 : 10, durationWidth)
        let tint = TaskTint.resolve(entry.task)
        let progress = segmentProgress(fromMinute: start, toMinute: end)

        if durationWidth > 1 || expanded {
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(scheme == .dark ? 0.18 : 0.12))
                Capsule().fill(tint.opacity(scheme == .dark ? 0.42 : 0.30))
                    .frame(width: ribbonWidth * progress)

                if expanded && ribbonWidth > 92 {
                    Text(overrun > 0 ? "\(entry.task.title) · +\(overrun)m" : entry.task.title)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(p.text.opacity(entry.task.status == .completed ? 0.60 : 0.92))
                        .lineLimit(1)
                        .padding(.leading, 38)
                        .padding(.trailing, 7)
                        .frame(width: ribbonWidth, alignment: .leading)
                }
            }
            .frame(width: ribbonWidth, height: expanded ? 22 : 10)
            .position(x: x1 + ribbonWidth / 2, y: laneY(entry.lane))
            .opacity(entry.task.status == .skipped ? 0.35 : 1)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func realityRibbon(_ entry: TimedEntry, width: CGFloat, palette p: AppPalette) -> some View {
        if let originalRaw = TimeMath.minutes(entry.task.timelineOriginalStartTime) {
            let originalStart = adjustedMinute(originalRaw)
            let originalEndRaw = TimeMath.minutes(entry.task.timelineOriginalEndTime) ?? (originalRaw + max(5, entry.task.durationMinutes))
            let originalEnd = max(originalStart + 5, adjustedMinute(originalEndRaw))
            if abs(originalStart - entry.minute) >= 5 {
                let x1 = xPosition(for: originalStart, width: width)
                let x2 = xPosition(for: originalEnd, width: width)
                Capsule()
                    .stroke(TaskTint.resolve(entry.task).opacity(0.45), style: StrokeStyle(lineWidth: expanded ? 2 : 1.3, dash: [4, 4]))
                    .frame(width: max(expanded ? 18 : 10, x2 - x1), height: expanded ? 25 : 13)
                    .position(x: x1 + max(expanded ? 18 : 10, x2 - x1) / 2, y: laneY(entry.lane))
                    .allowsHitTesting(false)
            }
        }

        if let started = entry.task.actualStartedAt.flatMap({ ISO8601DateFormatter().date(from: $0) }) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: started)
            let actualStart = adjustedMinute((comps.hour ?? 0) * 60 + (comps.minute ?? 0))
            let actualEnd = entry.task.completedAt
                .flatMap { ISO8601DateFormatter().date(from: $0) }
                .map { completed in
                    let c = Calendar.current.dateComponents([.hour, .minute], from: completed)
                    return adjustedMinute((c.hour ?? 0) * 60 + (c.minute ?? 0))
                } ?? currentTimelineMinute
            if actualEnd > actualStart {
                let x1 = xPosition(for: actualStart, width: width)
                let x2 = xPosition(for: min(rulerEnd, actualEnd), width: width)
                Capsule()
                    .fill(TaskTint.resolve(entry.task).opacity(0.75))
                    .frame(width: max(3, x2 - x1), height: expanded ? 4 : 2)
                    .position(x: x1 + max(3, x2 - x1) / 2, y: laneY(entry.lane) + (expanded ? 18 : 9))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func bufferRibbon(_ entry: TimedEntry, width: CGFloat, palette p: AppPalette) -> some View {
        let buffer = max(0, entry.task.bufferAfterMinutes ?? (isTimelineFixed(entry.task) ? 0 : 5))
        if buffer > 0 {
            let start = taskEndMinute(entry.task, startMinute: entry.minute)
            let end = min(rulerEnd, start + buffer)
            if end > start {
                let startX = taskNodeX(entry, width: width) + max(18, xPosition(for: start, width: width) - xPosition(for: entry.minute, width: width))
                let bufferWidth = max(6, xPosition(for: end, width: width) - xPosition(for: start, width: width))
                Capsule()
                    .stroke(p.secondary.opacity(0.38), style: StrokeStyle(lineWidth: expanded ? 1.7 : 1, dash: [2, 3]))
                    .frame(width: bufferWidth, height: expanded ? 11 : 6)
                    .position(x: startX + bufferWidth / 2, y: laneY(entry.lane))
                    .allowsHitTesting(false)
            }
        }
    }

    private func segments(palette p: AppPalette) -> [Segment] {
        // The live rail is a single brand-accent clock. Task colors belong to task beads,
        // which keeps Horizontal and Vertical layouts visually consistent.
        [Segment(fromMinute: wakeMinute, toMinute: sleepMinute, fromTint: p.accent, toTint: p.accent)]
    }

    private func requiredContentWidth(viewportWidth: CGFloat) -> CGFloat {
        guard expanded, !positionedTasks.isEmpty else { return max(1, viewportWidth) }
        // Never shrink day beads just to fit the phone. If the premium full-size layout
        // needs more room, the time rail becomes naturally horizontally scrollable.
        let inset = horizontalContentInset(width: viewportWidth)
        let separation = horizontalMinimumSeparation(width: viewportWidth)
        let required = inset * 2 + CGFloat(positionedTasks.count + 1) * separation
        return max(viewportWidth, required)
    }

    private func taskNodeX(_ entry: TimedEntry, width: CGFloat) -> CGFloat {
        guard expanded else { return xPosition(for: entry.minute, width: width) }
        return horizontalResolvedPositions(width: width)[entry.id] ?? xPosition(for: entry.minute, width: width)
    }

    private func horizontalResolvedPositions(width: CGFloat) -> [String: CGFloat] {
        let ordered = positionedTasks.sorted {
            if $0.minute == $1.minute { return $0.id < $1.id }
            return $0.minute < $1.minute
        }
        guard !ordered.isEmpty else { return [:] }

        let inset = horizontalContentInset(width: width)
        let separation = horizontalMinimumSeparation(width: width)
        let startLimit = inset + separation
        let endLimit = width - inset - separation
        var positions: [CGFloat] = []
        for entry in ordered {
            let target = xPosition(for: entry.minute, width: width)
            let minimum = positions.last.map { $0 + separation } ?? startLimit
            positions.append(max(target, minimum))
        }

        if let last = positions.last, last > endLimit {
            positions[positions.count - 1] = endLimit
            if positions.count > 1 {
                for index in stride(from: positions.count - 2, through: 0, by: -1) {
                    positions[index] = min(positions[index], positions[index + 1] - separation)
                }
            }
        }

        if positions[0] < startLimit {
            positions[0] = startLimit
            if positions.count > 1 {
                for index in 1..<positions.count {
                    positions[index] = max(positions[index], positions[index - 1] + separation)
                }
            }
        }

        return Dictionary(uniqueKeysWithValues: zip(ordered.map(\.id), positions))
    }

    private func compactOvalScaleLimit(for entry: TimedEntry, width: CGFloat, nodeSize: CGFloat) -> CGFloat? {
        guard !expanded, TimelineShapeEngine.resolvedShape(for: entry.task) != .circle else { return nil }
        let center = xPosition(for: entry.minute, width: width)
        let sameLane = positionedTasks
            .filter { $0.lane == entry.lane && $0.id != entry.id }
            .map { abs(xPosition(for: $0.minute, width: width) - center) }
            .filter { $0 > 0.5 }

        var nearest = sameLane.min() ?? .greatestFiniteMagnitude
        if entry.lane == 1 {
            let wakeDistance = abs(xPosition(for: wakeMinute, width: width) - center)
            let sleepDistance = abs(xPosition(for: sleepMinute, width: width) - center)
            if wakeDistance > 0.5 { nearest = min(nearest, wakeDistance) }
            if sleepDistance > 0.5 { nearest = min(nearest, sleepDistance) }
        }

        guard nearest.isFinite else { return 3.50 }
        let availableScale = (nearest - 7) / max(1, nodeSize)
        return min(3.50, max(1.0, availableScale))
    }

    private func horizontalNodeSize(width: CGFloat) -> CGFloat {
        guard expanded else { return compactNodeSize }
        return 58
    }

    private func horizontalContentInset(width: CGFloat) -> CGFloat {
        guard expanded else { return 0 }
        // Enough breathing room for the endpoint beads while retaining a continuous rail.
        return 54
    }

    private func horizontalMinimumSeparation(width: CGFloat) -> CGFloat {
        guard expanded else { return 42 }
        let size = horizontalNodeSize(width: width)
        return size * maxOvalScale + 8
    }

    private var maxOvalScale: CGFloat {
        let scales = positionedTasks.map { entry -> CGFloat in
            guard TimelineShapeEngine.resolvedShape(for: entry.task) != .circle else { return 1 }
            return CGFloat(min(3.50, max(1.15, entry.task.timelineOvalLengthScale ?? 1.45)))
        }
        return max(1, scales.max() ?? 1.45)
    }

    private var currentTimelineMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        var minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
        return minute
    }

    private func isTimelineFixed(_ task: PlannerTask) -> Bool {
        task.externalSource == .calendar || task.externalImportance == .important || task.timelineLocked == true
    }

    private var currentMinuteIfVisible: Int? {
        let calendar = Calendar.current
        guard calendar.isDate(day, inSameDayAs: now) else { return nil }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        var minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
        guard minute >= max(wakeMinute, rulerStart), minute <= min(sleepMinute, rulerEnd) else { return nil }
        return minute
    }

    private func adjustedMinute(_ minute: Int) -> Int {
        if sleepMinute > 24 * 60 && minute < wakeMinute { return minute + 24 * 60 }
        return minute
    }

    private func taskEndMinute(_ task: PlannerTask, startMinute: Int) -> Int {
        let rawEnd = TimeMath.minutes(task.endTime) ?? ((TimeMath.minutes(task.startTime) ?? startMinute) + max(5, task.durationMinutes))
        var end = rawEnd
        if sleepMinute > 24 * 60 && end < wakeMinute { end += 24 * 60 }
        if end <= startMinute { end = startMinute + max(5, task.durationMinutes) }
        return end
    }

    private func laneY(_ lane: Int) -> CGFloat {
        if expanded { return centerY }
        return CGFloat(lane + 1) * rowHeight / CGFloat(laneCount + 1)
    }

    private func xPosition(for minute: Int, width: CGFloat) -> CGFloat {
        let span = max(1, rulerEnd - rulerStart)
        let clamped = max(rulerStart, min(rulerEnd, minute))
        let inset = expanded ? horizontalContentInset(width: width) : 0
        let usable = max(1, width - inset * 2)
        return inset + usable * CGFloat(clamped - rulerStart) / CGFloat(span)
    }

    private func minuteForX(_ x: CGFloat, width: CGFloat) -> Int {
        guard width > 0 else { return wakeMinute }
        let inset = expanded ? horizontalContentInset(width: width) : 0
        let usable = max(1, width - inset * 2)
        let ratio = min(1, max(0, (x - inset) / usable))
        return rulerStart + Int(CGFloat(rulerEnd - rulerStart) * ratio)
    }

    private func openDraftTask(at minute: Int) {
        let snapped = max(wakeMinute, min(sleepMinute - 5, Int(round(Double(minute) / 15.0)) * 15))
        var task = PlanEngine.manualTask(title: "", date: key)
        task.startTime = clockString(snapped)
        task.durationMinutes = min(30, max(5, sleepMinute - snapped))
        task.endTime = clockString(snapped + task.durationMinutes)
        task.allDay = false
        task.section = snapped < 720 ? .morning : snapped < 1020 ? .day : snapped < 1320 ? .evening : .night
        draftTask = task
    }

    private func clockString(_ minute: Int) -> String {
        let wrapped = ((minute % (24 * 60)) + (24 * 60)) % (24 * 60)
        return TimeMath.string(wrapped)
    }

    private func segmentProgress(fromMinute: Int, toMinute: Int) -> CGFloat {
        guard toMinute > fromMinute else { return 1 }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let fromDate = calendar.date(byAdding: .minute, value: fromMinute, to: dayStart),
              let toDate = calendar.date(byAdding: .minute, value: toMinute, to: dayStart) else { return 0 }

        if now <= fromDate { return 0 }
        if now >= toDate { return 1 }
        return CGFloat(now.timeIntervalSince(fromDate) / toDate.timeIntervalSince(fromDate))
    }

}

private struct TimelinePulseStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int

    private var tasks: [PlannerTask] {
        store.data.plans.first(where: { $0.date == DateKey.string(day) })?.tasks.filter {
            $0.allDay != true && $0.status != .skipped && TimeMath.minutes($0.startTime) != nil
        } ?? []
    }

    private var daySpan: Int { max(60, sleepMinute - wakeMinute) }
    private var scheduledMinutes: Int {
        min(daySpan, tasks.reduce(0) { $0 + max(5, $1.durationMinutes) })
    }
    private var freeMinutes: Int { max(0, daySpan - scheduledMinutes) }
    private var elapsed: CGFloat {
        guard Calendar.current.isDate(day, inSameDayAs: now) else {
            if day < Calendar.current.startOfDay(for: now) { return 1 }
            return 0
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        var minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
        return min(1, max(0, CGFloat(minute - wakeMinute) / CGFloat(daySpan)))
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                metric(title: "DAY", value: "\(Int(elapsed * 100))%", symbol: "waveform.path.ecg", tint: p.accent)
                metric(title: "FREE", value: compactMinutes(freeMinutes), symbol: "circle.dashed", tint: p.secondary)
                metric(title: "LOAD", value: "\(Int((Double(scheduledMinutes) / Double(daySpan) * 100).rounded()))%", symbol: "gauge.with.dots.needle.50percent", tint: p.accent)
            }
        }
    }

    private func metric(title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
                Text(value).font(.caption2.weight(.bold).monospacedDigit())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(tint.opacity(0.07)).interactive(), in: Capsule())
    }

    private func compactMinutes(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}

private struct VerticalLiveTimeline: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int

    @State private var draftTask: PlannerTask?
    @State private var dropPulse = 0
    @State private var moveProposal: TimelineMoveProposal?

    private let railX: CGFloat = 62
    private let nodeSize: CGFloat = 58
    private let verticalGap: CGFloat = 18
    private var verticalInset: CGFloat { 54 }

    private var tasks: [PlannerTask] {
        TaskTimelineOrder.sorted(store.data.plans.first(where: { $0.date == DateKey.string(day) })?.tasks ?? []).filter {
            $0.allDay != true && TimeMath.minutes($0.startTime) != nil && $0.status != .skipped
        }
    }

    private var sequence: TimelineSequenceModel {
        TimelineSequenceModel(day: day, now: now, wakeMinute: wakeMinute, sleepMinute: sleepMinute, tasks: tasks)
    }

    private var canvasHeight: CGFloat {
        let timeBased = max(620.0, CGFloat(max(1, sleepMinute - wakeMinute)) * 0.68)
        let taskExtent = tasks.reduce(CGFloat.zero) { $0 + verticalExtent(for: $1) }
        let collisionFreeDistance = nodeSize + taskExtent + CGFloat(tasks.count + 1) * verticalGap
        return max(timeBased, verticalInset * 2 + collisionFreeDistance)
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Vertical live rail", systemImage: "arrow.up.and.down")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("ELASTIC RAIL · \(tasks.count) tasks")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(p.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(p.border.opacity(0.78))
                        .frame(width: 10, height: max(1, proxy.size.height - verticalInset * 2))
                        .position(x: railX, y: proxy.size.height / 2)

                    let liveRailFillHeight = verticalRailFillHeight(height: proxy.size.height)
                    Capsule()
                        .fill(LinearGradient(colors: [p.accent, p.accent.opacity(0.56)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 10, height: liveRailFillHeight)
                        .position(
                            x: railX,
                            y: verticalInset + liveRailFillHeight / 2
                        )
                        .animation(.linear(duration: 0.35), value: liveRailFillHeight)

                    endpointBead(
                        systemName: "sunrise.fill",
                        tint: p.accent,
                        progress: sequence.nodeProgress(.wake)
                    )
                    .position(x: railX, y: yPosition(for: wakeMinute, height: proxy.size.height))

                    endpointBead(
                        systemName: "moon.stars.fill",
                        tint: p.secondary,
                        progress: sequence.nodeProgress(.sleep)
                    )
                    .position(x: railX, y: yPosition(for: sleepMinute, height: proxy.size.height))

                    ForEach(tasks) { task in
                        if let raw = TimeMath.minutes(task.startTime) {
                            let minute = adjusted(raw)
                            let y = taskY(task, minute: minute, height: proxy.size.height)

                            WeekTimelineTaskNode(
                                task: task,
                                day: day,
                                now: now,
                                size: nodeSize,
                                flow: .vertical,
                                progressOverride: sequence.nodeProgress(.task(task.id))
                            )
                            .position(x: railX, y: y)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title.isEmpty ? "Untitled task" : task.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                HStack(spacing: 5) {
                                    Text(task.startTime ?? "")
                                    Text("·")
                                    Text("\(task.durationMinutes)m")
                                    if isCurrent(task) { Text("· LIVE").foregroundStyle(p.accent) }
                                }
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(p.secondary)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 8)
                            .glassEffect(.regular.tint(TaskTint.resolve(task).opacity(0.07)).interactive(), in: Capsule())
                            .frame(width: max(136, proxy.size.width - 142), alignment: .leading)
                            .position(x: 132 + max(136, proxy.size.width - 142) / 2, y: y)
                        }
                    }

                    // No separate NOW pulse in Vertical. The rail itself is the live clock,
                    // and active task beads communicate the current task through their fill.
                }
                .contentShape(Rectangle())
                .dropDestination(for: String.self) { items, location in
                    guard let payload = items.first else { return false }
                    let minute = minuteForY(location.y, height: proxy.size.height)
                    let snapped = max(wakeMinute, min(sleepMinute - 5, Int(round(Double(minute) / 15.0)) * 15))
                    let time = clock(snapped)

                    if payload.hasPrefix("task:") {
                        let id = String(payload.dropFirst(5))
                        moveProposal = store.timelineMoveProposal(taskID: id, toDate: DateKey.string(day), startTime: time)
                        dropPulse += 1
                        return true
                    }
                    if payload.hasPrefix("inbox:"), let item = store.data.inbox.first(where: { $0.id == String(payload.dropFirst(6)) }) {
                        store.planInbox(item, on: DateKey.string(day), at: time)
                        dropPulse += 1
                        return true
                    }
                    return false
                }
                .simultaneousGesture(
                    SpatialTapGesture().onEnded { value in
                        let hitTask = tasks.contains { task in
                            guard let raw = TimeMath.minutes(task.startTime) else { return false }
                            return abs(taskY(task, minute: adjusted(raw), height: proxy.size.height) - value.location.y) < verticalExtent(for: task) * 0.60
                        }
                        guard !hitTask else { return }
                        if value.location.x < 118 {
                            openDraft(at: minuteForY(value.location.y, height: proxy.size.height))
                        }
                    }
                )
            }
            .frame(height: canvasHeight)
        }
        .sheet(item: $draftTask) { task in NavigationStack { TaskEditorView(task: task, isNew: true) } }
        .sheet(item: $moveProposal) { proposal in
            TimelineMoveConfirmationSheet(proposal: proposal)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .planningFeedback(.selection, trigger: dropPulse)
    }

    @ViewBuilder
    private func endpointBead(systemName: String, tint: Color, progress: CGFloat) -> some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let diameter: CGFloat = 58
        let fill = min(1, max(0, progress))
        return ZStack {
            Circle().fill(p.background)
            Circle().fill(tint.opacity(scheme == .dark ? 0.075 : 0.050))
            Rectangle()
                .fill(LinearGradient(colors: [tint.opacity(0.50), tint.opacity(0.24)], startPoint: .top, endPoint: .bottom))
                .frame(width: diameter, height: diameter * fill)
                .frame(width: diameter, height: diameter, alignment: .top)
                .clipShape(Circle())
            Circle().stroke(tint.opacity(0.30), lineWidth: 2.2)
            Image(systemName: systemName).font(.system(size: 23, weight: .bold)).foregroundStyle(tint)
        }
        .frame(width: diameter, height: diameter)
        .glassEffect(.regular.tint(tint.opacity(0.06)).interactive(), in: Circle())
    }

    private func taskY(_ task: PlannerTask, minute: Int, height: CGFloat) -> CGFloat {
        verticalResolvedPositions(height: height)[task.id] ?? yPosition(for: minute, height: height)
    }

    private func verticalResolvedPositions(height: CGFloat) -> [String: CGFloat] {
        let ordered = tasks.compactMap { candidate -> (PlannerTask, Int)? in
            guard let raw = TimeMath.minutes(candidate.startTime) else { return nil }
            return (candidate, adjusted(raw))
        }
        .sorted {
            if $0.1 == $1.1 { return $0.0.id < $1.0.id }
            return $0.1 < $1.1
        }
        guard !ordered.isEmpty else { return [:] }

        var positions: [CGFloat] = []
        for (index, entry) in ordered.enumerated() {
            let extent = verticalExtent(for: entry.0)
            let target = yPosition(for: entry.1, height: height)
            let minimum: CGFloat
            if index == 0 {
                minimum = verticalInset + nodeSize / 2 + verticalGap + extent / 2
            } else {
                let previousExtent = verticalExtent(for: ordered[index - 1].0)
                minimum = positions[index - 1] + previousExtent / 2 + verticalGap + extent / 2
            }
            positions.append(max(target, minimum))
        }

        if let lastIndex = positions.indices.last {
            let lastExtent = verticalExtent(for: ordered[lastIndex].0)
            let lastLimit = height - verticalInset - nodeSize / 2 - verticalGap - lastExtent / 2
            if positions[lastIndex] > lastLimit {
                positions[lastIndex] = lastLimit
                if lastIndex > 0 {
                    for index in stride(from: lastIndex - 1, through: 0, by: -1) {
                        let currentExtent = verticalExtent(for: ordered[index].0)
                        let nextExtent = verticalExtent(for: ordered[index + 1].0)
                        positions[index] = min(
                            positions[index],
                            positions[index + 1] - currentExtent / 2 - verticalGap - nextExtent / 2
                        )
                    }
                }
            }
        }

        return Dictionary(uniqueKeysWithValues: zip(ordered.map { $0.0.id }, positions))
    }

    private func verticalExtent(for task: PlannerTask) -> CGFloat {
        guard TimelineShapeEngine.resolvedShape(for: task) != .circle else { return nodeSize }
        let scale = CGFloat(min(3.50, max(1.15, task.timelineOvalLengthScale ?? 1.45)))
        return nodeSize * scale
    }

    private func isCurrent(_ task: PlannerTask) -> Bool {
        guard Calendar.current.isDate(day, inSameDayAs: now), let raw = TimeMath.minutes(task.startTime) else { return false }
        let start = adjusted(raw)
        let endRaw = TimeMath.minutes(task.endTime) ?? (raw + max(5, task.durationMinutes))
        let end = max(start + 5, adjusted(endRaw))
        return currentMinute >= start && currentMinute < end
    }

    private var currentMinute: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return adjusted((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    /// Keeps the live rail from visually touching a future task before its actual start.
    /// Task beads are physically larger than a minute tick, so a raw time-proportional line
    /// can otherwise reach the bead edge several minutes early even though the math is correct.
    private func verticalRailFillHeight(height: CGFloat) -> CGFloat {
        let wakeY = yPosition(for: wakeMinute, height: height)
        let sleepY = yPosition(for: sleepMinute, height: height)
        let headY = sequence.lineHeadPosition { id in
            switch id {
            case .wake:
                return wakeY
            case .sleep:
                return sleepY
            case .task(let taskID):
                guard let task = tasks.first(where: { $0.id == taskID }),
                      let raw = TimeMath.minutes(task.startTime) else { return wakeY }
                return taskY(task, minute: adjusted(raw), height: height)
            }
        }
        return min(max(0, sleepY - wakeY), max(0, headY - wakeY))
    }

    private func adjusted(_ minute: Int) -> Int {
        sleepMinute > 24 * 60 && minute < wakeMinute ? minute + 24 * 60 : minute
    }

    private func yPosition(for minute: Int, height: CGFloat) -> CGFloat {
        let span = max(1, sleepMinute - wakeMinute)
        let ratio = CGFloat(max(wakeMinute, min(sleepMinute, minute)) - wakeMinute) / CGFloat(span)
        return verticalInset + max(1, height - verticalInset * 2) * ratio
    }

    private func minuteForY(_ y: CGFloat, height: CGFloat) -> Int {
        let ratio = min(1, max(0, (y - verticalInset) / max(1, height - verticalInset * 2)))
        return wakeMinute + Int(CGFloat(sleepMinute - wakeMinute) * ratio)
    }

    private func clock(_ minute: Int) -> String {
        TimeMath.string(((minute % 1440) + 1440) % 1440)
    }

    private func openDraft(at minute: Int) {
        let snapped = max(wakeMinute, min(sleepMinute - 5, Int(round(Double(minute) / 15.0)) * 15))
        var task = PlanEngine.manualTask(title: "", date: DateKey.string(day))
        task.startTime = clock(snapped)
        task.durationMinutes = min(30, max(5, sleepMinute - snapped))
        task.endTime = clock(snapped + task.durationMinutes)
        task.allDay = false
        draftTask = task
    }
}

private struct TimelineMoveConfirmationSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let proposal: TimelineMoveProposal
    @State private var chosenTime: Date

    init(proposal: TimelineMoveProposal) {
        self.proposal = proposal
        let base = DateKey.date(proposal.targetDate) ?? .now
        let minute = TimeMath.minutes(proposal.requestedTime) ?? 0
        let value = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: base) ?? base
        _chosenTime = State(initialValue: value)
    }

    private var editedTime: String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: chosenTime)
        return TimeMath.string((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    private var liveProposal: TimelineMoveProposal? {
        store.timelineMoveProposal(taskID: proposal.taskID, toDate: proposal.targetDate, startTime: editedTime)
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proposal.taskTitle).font(.title3.bold())
                    Text("\(formattedDate) · \(proposal.durationMinutes) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DatePicker("Start time", selection: $chosenTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)

                if liveProposal?.hasConflict == true {
                    Label("This exact time overlaps another block. Keep the exact time or choose another; a free time is offered when available.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .premiumGlassRounded(cornerRadius: 18, tint: p.accent.opacity(0.05), interactive: false)
                } else {
                    Label("Exact placement is clear.", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(p.accent)
                }

                VStack(spacing: 10) {
                    Button {
                        guard let liveProposal else { return }
                        store.confirmTimelineMove(liveProposal, useSafeTime: false)
                        dismiss()
                    } label: {
                        Label("Place at \(editedTime)", systemImage: "checkmark")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)

                    if let liveProposal, liveProposal.hasConflict, let safeTime = liveProposal.safeTime {
                        Button {
                            store.confirmTimelineMove(liveProposal, useSafeTime: true)
                            dismiss()
                        } label: {
                            Label("Use safe time \(safeTime)", systemImage: "shield.checkered")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.glass)
                    }
                }
                Spacer()
            }
            .padding(20)
            .appCanvas()
            .navigationTitle("Confirm time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private var formattedDate: String {
        (DateKey.date(proposal.targetDate) ?? .now).formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

private struct TimelineDayPath: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int
    @State private var draftTask: PlannerTask?

    private var tasks: [PlannerTask] {
        TaskTimelineOrder.sorted(store.data.plans.first(where: { $0.date == DateKey.string(day) })?.tasks ?? []).filter {
            $0.allDay != true && TimeMath.minutes($0.startTime) != nil && $0.status != .skipped
        }
    }

    private var sequence: TimelineSequenceModel {
        TimelineSequenceModel(day: day, now: now, wakeMinute: wakeMinute, sleepMinute: sleepMinute, tasks: tasks)
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Day Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button { openDraft() } label: {
                    Image(systemName: "plus")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Add task to Day Path")
                Text("LIVE CHAIN")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(p.secondary)
            }

            VStack(spacing: 0) {
                pathEndpoint(
                    systemName: "sunrise.fill",
                    title: "Wake",
                    time: clock(wakeMinute),
                    tint: p.accent,
                    progress: sequence.nodeProgress(.wake)
                )

                if tasks.isEmpty {
                    pathConnector(
                        progress: sequence.connectorProgress(from: .wake, to: .sleep),
                        palette: p
                    )

                    HStack(spacing: 12) {
                        Button { openDraft() } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(p.accent)
                                .frame(width: 58, height: 58)
                        }
                        .buttonStyle(.glass)
                        .clipShape(Circle())
                        .frame(width: 82)
                        .accessibilityLabel("Add first timed task")
                        Text("Timed tasks become large live beads on this chain. The path keeps filling with the real clock.")
                            .font(.caption)
                            .foregroundStyle(p.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 5)
                } else {
                    if let first = tasks.first {
                        pathConnector(
                            progress: sequence.connectorProgress(from: .wake, to: .task(first.id)),
                            palette: p
                        )
                    }

                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        HStack(spacing: 16) {
                            WeekTimelineTaskNode(
                                task: task,
                                day: day,
                                now: now,
                                size: 58,
                                flow: .vertical,
                                progressOverride: sequence.nodeProgress(.task(task.id))
                            )
                            .frame(width: 84)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title.isEmpty ? "Untitled task" : task.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                HStack(spacing: 7) {
                                    Text(task.startTime ?? "")
                                    Text("·")
                                    Text("\(task.durationMinutes)m")
                                    if task.status == .completed { Text("· done") }
                                }
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(p.secondary)
                            }
                            Spacer()
                            if isCurrent(task) {
                                Text("NOW")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(p.accent)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .glassEffect(.regular.tint(p.accent.opacity(0.10)).interactive(), in: Capsule())
                            }
                            Button { store.toggleTask(task.id) } label: {
                                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.glass)
                            .accessibilityLabel(task.status == .completed ? "Mark \(task.title) incomplete" : "Complete \(task.title)")
                        }
                        .padding(.vertical, 5)

                        if index < tasks.count - 1 {
                            let next = tasks[index + 1]
                            pathConnector(
                                progress: sequence.connectorProgress(from: .task(task.id), to: .task(next.id)),
                                palette: p
                            )
                        } else {
                            pathConnector(
                                progress: sequence.connectorProgress(from: .task(task.id), to: .sleep),
                                palette: p
                            )
                        }
                    }
                }

                pathEndpoint(
                    systemName: "moon.stars.fill",
                    title: "Sleep",
                    time: clock(sleepMinute),
                    tint: p.secondary,
                    progress: sequence.nodeProgress(.sleep)
                )
            }
        }
        .padding(.top, 2)
        .sheet(item: $draftTask) { task in
            NavigationStack { TaskEditorView(task: task, isNew: true) }
        }
    }

    @ViewBuilder
    private func pathConnector(progress: CGFloat, palette p: AppPalette) -> some View {
        let fill = min(1, max(0, progress))
        ZStack(alignment: .top) {
            Capsule().fill(p.border.opacity(0.78))
            Capsule().fill(p.accent.opacity(0.82)).frame(height: 30 * fill)
        }
        .frame(width: 8, height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 38)
        .animation(.linear(duration: 0.35), value: fill)
        .allowsHitTesting(false)
    }

    private func pathEndpoint(systemName: String, title: String, time: String, tint: Color, progress: CGFloat) -> some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let diameter: CGFloat = 58
        let fill = min(1, max(0, progress))
        return HStack(spacing: 16) {
            ZStack {
                Circle().fill(p.background)
                Circle().fill(tint.opacity(scheme == .dark ? 0.075 : 0.050))
                Rectangle()
                    .fill(LinearGradient(colors: [tint.opacity(0.50), tint.opacity(0.24)], startPoint: .top, endPoint: .bottom))
                    .frame(width: diameter, height: diameter * fill)
                    .frame(width: diameter, height: diameter, alignment: .top)
                    .clipShape(Circle())
                Circle().stroke(tint.opacity(0.30), lineWidth: 2.2)
                Image(systemName: systemName).font(.system(size: 23, weight: .bold)).foregroundStyle(tint)
            }
            .frame(width: diameter, height: diameter)
            .glassEffect(.regular.tint(tint.opacity(0.06)).interactive(), in: Circle())
            .frame(width: 82)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(time).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func isCurrent(_ task: PlannerTask) -> Bool {
        guard Calendar.current.isDate(day, inSameDayAs: now), let raw = TimeMath.minutes(task.startTime) else { return false }
        let start = adjusted(raw)
        let end = taskEndMinute(task)
        return currentMinute >= start && currentMinute < end
    }

    private func taskEndMinute(_ task: PlannerTask) -> Int {
        guard let rawStart = TimeMath.minutes(task.startTime) else { return wakeMinute }
        let start = adjusted(rawStart)
        let rawEnd = TimeMath.minutes(task.endTime) ?? (rawStart + max(5, task.durationMinutes))
        return max(start + 5, adjusted(rawEnd))
    }

    private var currentMinute: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return adjusted((c.hour ?? 0) * 60 + (c.minute ?? 0))
    }

    private func adjusted(_ minute: Int) -> Int {
        sleepMinute > 1440 && minute < wakeMinute ? minute + 1440 : minute
    }

    private func clock(_ minute: Int) -> String {
        TimeMath.string(((minute % 1440) + 1440) % 1440)
    }

    private func openDraft() {
        var task = PlanEngine.manualTask(title: "", date: DateKey.string(day))
        let suggested = Calendar.current.isDate(day, inSameDayAs: now) ? currentMinute : wakeMinute
        let bounded = max(wakeMinute, min(sleepMinute - 5, suggested))
        task.startTime = clock(bounded)
        task.endTime = clock(bounded + max(5, task.durationMinutes))
        task.allDay = false
        draftTask = task
    }
}

private struct TimelineNowState: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int

    @State private var editorTask: PlannerTask?

    private struct Entry {
        let task: PlannerTask
        let start: Int
        let end: Int
    }

    private var entries: [Entry] {
        let key = DateKey.string(day)
        let tasks = store.data.plans.first(where: { $0.date == key })?.tasks ?? []
        return tasks.compactMap { task in
            guard task.allDay != true, let raw = TimeMath.minutes(task.startTime) else { return nil }
            let start = adjusted(raw)
            let rawEnd = TimeMath.minutes(task.endTime) ?? (raw + max(5, task.durationMinutes))
            var end = adjusted(rawEnd)
            if end <= start { end = start + max(5, task.durationMinutes) }
            return Entry(task: task, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let current = currentMinute
        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let active = isToday ? entries.first(where: { $0.task.status != .completed && $0.task.status != .skipped && current >= $0.start && current < $0.end }) : nil
        let next = entries.first(where: { $0.task.status == .pending && $0.start > (isToday ? current : wakeMinute) })

        HStack(spacing: 11) {
            if let active {
                Button {
                    editorTask = active.task
                } label: {
                    HStack(spacing: 11) {
                        ZStack {
                            Circle().fill(TaskTint.resolve(active.task).opacity(scheme == .dark ? 0.20 : 0.13))
                            Image(systemName: IconEngine.symbol(for: active.task))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(TaskTint.resolve(active.task))
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Right now").font(.caption.weight(.semibold)).foregroundStyle(p.accent)
                            Text(active.task.title)
                                .font(.title3.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(clock(active.start))–\(clock(active.end)) · \(max(1, active.end - current)) min left")
                                .font(.caption)
                                .foregroundStyle(p.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 6)

                Button {
                    store.toggleTask(active.task.id)
                } label: {
                    Image(systemName: "circle")
                        .font(.system(size: 27, weight: .light))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(p.accent)
                .contentShape(Circle())
                .accessibilityLabel("Complete \(active.task.title)")
            } else {
                Image(systemName: isToday ? "clock" : "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(p.accent)
                    .frame(width: 34)

                VStack(alignment: .leading, spacing: 2) {
                    if isToday {
                        if let next {
                            let free = max(0, next.start - current)
                            Text(free > 0 ? "Free for \(free) min" : "Up next")
                                .font(.subheadline.weight(.semibold))
                            Text("Next · \(next.task.title) at \(clock(next.start))")
                                .font(.caption)
                                .foregroundStyle(p.secondary)
                                .lineLimit(1)
                        } else if current < wakeMinute {
                            Text("Day hasn’t started yet")
                                .font(.subheadline.weight(.semibold))
                            Text("Wake at \(clock(wakeMinute))")
                                .font(.caption)
                                .foregroundStyle(p.secondary)
                        } else if current <= sleepMinute {
                            Text("Your time is open")
                                .font(.subheadline.weight(.semibold))
                            Text("No more timed tasks before \(clock(sleepMinute))")
                                .font(.caption)
                                .foregroundStyle(p.secondary)
                        } else {
                            Text("End of your scheduled day")
                                .font(.subheadline.weight(.semibold))
                            Text("Timeline closed at \(clock(sleepMinute))")
                                .font(.caption)
                                .foregroundStyle(p.secondary)
                        }
                    } else if let first = entries.first {
                        Text("Day preview")
                            .font(.subheadline.weight(.semibold))
                        Text("First · \(first.task.title) at \(clock(first.start))")
                            .font(.caption)
                            .foregroundStyle(p.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Open day")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap the timeline to place the first task")
                            .font(.caption)
                            .foregroundStyle(p.secondary)
                    }
                }

                Spacer(minLength: 0)

                if let next {
                    Button {
                        editorTask = next.task
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Open next task")
                }
            }
        }
        .padding(18)
        .premiumGlassRounded(cornerRadius: 28, tint: p.accent.opacity(0.04), interactive: true)
        .sheet(item: $editorTask) { task in
            NavigationStack {
                TaskEditorView(task: task, isNew: false)
            }
        }
    }

    private var currentMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        var minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
        return minute
    }

    private func adjusted(_ minute: Int) -> Int {
        if sleepMinute > 24 * 60 && minute < wakeMinute { return minute + 24 * 60 }
        return minute
    }

    private func clock(_ minute: Int) -> String {
        let wrapped = ((minute % (24 * 60)) + (24 * 60)) % (24 * 60)
        return TimeMath.string(wrapped)
    }
}

private struct TimelineControlDeck: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int
    let rulerEnd: Int

    @State private var pushDelta = 0
    @State private var timeMachineEnabled = false
    @State private var showPaywall = false
    @State private var scrubMinute = 0.0
    @State private var pushPulse = 0
    @State private var compressPulse = 0
    @State private var pendingActionID: String?
    @State private var actionStatus: String?

    private struct DeckAction: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let detail: String
        let requiresPro: Bool
    }

    private let deckActions = [
        DeckAction(id: "compress", title: "Magnetic Compress", symbol: "arrow.down.right.and.arrow.up.left", detail: "Close safe gaps without moving fixed work.", requiresPro: true),
        DeckAction(id: "buffer", title: "Buffer Guard", symbol: "shield.lefthalf.filled", detail: "Keep at least 10 minutes between flexible blocks.", requiresPro: false),
        DeckAction(id: "lock", title: "Auto Lock", symbol: "lock.circle", detail: "Protect work beginning within the next two hours.", requiresPro: false),
        DeckAction(id: "focus", title: "Focus Shield", symbol: "scope", detail: "Protect the strongest uninterrupted focus block.", requiresPro: false),
        DeckAction(id: "recovery", title: "Recovery Space", symbol: "heart.text.square", detail: "Add short recovery space where it safely fits.", requiresPro: false),
        DeckAction(id: "conflicts", title: "Conflict Sweep", symbol: "wand.and.stars", detail: "Repair flexible overlaps while preserving intent.", requiresPro: false)
    ]

    private var key: String { DateKey.string(day) }
    private var tasks: [PlannerTask] { store.data.plans.first(where: { $0.date == key })?.tasks ?? [] }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Adjust this day", subtitle: "Choose an action, review it, then apply. Undo stays available.")

            Group {
                VStack(alignment: .leading, spacing: 9) {
            if Calendar.current.isDate(day, inSameDayAs: now) {
                HStack(spacing: 8) {
                    Label("Shift your day", systemImage: "arrow.left.and.right")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(pushDelta == 0 ? "0m" : signed(pushDelta))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(pushDelta == 0 ? p.secondary : p.accent)
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Shift remaining tasks earlier or later")
                        .font(.caption2)
                        .foregroundStyle(p.secondary)

                    HStack(spacing: 9) {
                        Text("−6h")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(p.secondary)
                        Slider(
                            value: Binding(
                                get: { Double(pushDelta) },
                                set: { pushDelta = Int($0.rounded()) }
                            ),
                            in: -360...360,
                            step: 15
                        )
                        .tint(p.accent)
                        Text("+6h")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(p.secondary)
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .glassEffect(.regular.tint(p.accent.opacity(0.055)).interactive(), in: Capsule())

                    if pushDelta != 0 {
                        HStack {
                            Text("Preview · \(signed(pushDelta))")
                                .font(.caption2.weight(.semibold).monospacedDigit())
                                .foregroundStyle(p.accent)
                            Spacer()
                            Button("Apply") {
                                _ = store.performTimelineTransaction(label: "Shift remaining day") {
                                    store.pushRemainingDay(on: key, fromMinute: currentMinute, byMinutes: pushDelta)
                                }
                                pushDelta = 0
                                pushPulse += 1
                            }
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                        }
                    }
                }

                if pushDelta != 0 {
                    Label(ghostFutureDescription, systemImage: "sparkles.rectangle.stack")
                        .font(.caption2)
                        .foregroundStyle(p.secondary)
                        .lineLimit(2)
                        .transition(.opacity)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Make space & protect time")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.secondary)
                    Spacer()
                    if let actionStatus {
                        Text(actionStatus)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(p.accent)
                            .lineLimit(1)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
                    ForEach(deckActions) { action in
                        Button {
                            if action.requiresPro && !store.hasAccess(.advancedTimelineTools) {
                                showPaywall = true
                            } else {
                                pendingActionID = action.id
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: action.requiresPro && !store.hasAccess(.advancedTimelineTools) ? "lock.fill" : action.symbol)
                                        .foregroundStyle(p.accent)
                                    Text(action.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                Text(action.detail)
                                    .font(.caption2)
                                    .foregroundStyle(p.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
                            .padding(11)
                            .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .premiumGlassRounded(cornerRadius: 19, tint: p.accent.opacity(0.035), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows a confirmation before changing the timeline")
                    }
                }
            }

            TimelineIntelligenceInline(date: key)

            HStack(spacing: 8) {
                Button {
                    guard store.hasAccess(.advancedTimelineTools) else { showPaywall = true; return }
                    timeMachineEnabled.toggle()
                    if scrubMinute == 0 { scrubMinute = Double(currentMinute) }
                } label: {
                    Label(store.hasAccess(.advancedTimelineTools) ? "Time Machine" : "Time Machine · Pro", systemImage: store.hasAccess(.advancedTimelineTools) ? "clock.arrow.circlepath" : "lock.fill")
                }
                .buttonStyle(.glass)
                .controlSize(.small)

                if timeMachineEnabled {
                    Text(clock(Int(scrubMinute == 0 ? Double(currentMinute) : scrubMinute)))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(p.accent)
                }
                Spacer()
            }

            if timeMachineEnabled {
                Slider(value: Binding(
                    get: { scrubMinute == 0 ? Double(currentMinute) : scrubMinute },
                    set: { scrubMinute = $0 }
                ), in: Double(wakeMinute)...Double(max(wakeMinute + 60, rulerEnd)), step: 5)
                Text(timeMachineDescription(at: Int(scrubMinute == 0 ? Double(currentMinute) : scrubMinute)))
                    .font(.caption2)
                    .foregroundStyle(p.secondary)
                    .lineLimit(2)
            }
                }
            }
        }
        .animation(.spring(duration: 0.28, bounce: 0.05), value: pushDelta)
        .animation(.spring(duration: 0.28, bounce: 0.05), value: timeMachineEnabled)
        .planningFeedback(.impact(weight: .medium), trigger: pushPulse)
        .planningFeedback(.impact(weight: .light), trigger: compressPulse)
        .sheet(isPresented: $showPaywall) { NavigationStack { PaywallView() } }
        .confirmationDialog(
            pendingAction.map { "Apply \($0.title)?" } ?? "Adjust this timeline?",
            isPresented: Binding(
                get: { pendingActionID != nil },
                set: { if !$0 { pendingActionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apply and keep Undo") {
                if let pendingActionID { runDeckAction(pendingActionID) }
                pendingActionID = nil
            }
            Button("Cancel", role: .cancel) { pendingActionID = nil }
        } message: {
            Text(pendingAction?.detail ?? "Nothing moves until you confirm.")
        }
    }

    private var pendingAction: DeckAction? { deckActions.first { $0.id == pendingActionID } }

    private func runDeckAction(_ id: String) {
        let label = deckActions.first(where: { $0.id == id })?.title ?? "Timeline adjustment"
        let fromMinute = Calendar.current.isDate(day, inSameDayAs: now) ? currentMinute : wakeMinute
        let changed = store.performTimelineTransaction(label: label) {
            switch id {
            case "compress": store.compressRemainingDay(on: key, fromMinute: fromMinute)
            case "buffer": store.applyBufferGuard(on: key, minimumMinutes: 10)
            case "lock": store.autoLockNearTerm(on: key, withinMinutes: 120)
            case "focus": store.focusShield(on: key)
            case "recovery": store.applyRecoveryBuffers(on: key, minutes: 10)
            case "conflicts": store.repairTimelineConflicts(on: key)
            default: 0
            }
        }
        actionStatus = changed == 0 ? "Already protected" : "\(changed) updated"
        compressPulse += 1
    }

    private var currentMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        var minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
        return minute
    }

    private var flexibleFutureTasks: [PlannerTask] {
        tasks.filter { task in
            guard (task.status == .pending || task.status == .active),
                  task.externalSource != .calendar,
                  task.externalImportance != .important,
                  task.timelineLocked != true,
                  let start = TimeMath.minutes(task.startTime) else { return false }
            return adjusted(start) >= currentMinute
        }
    }

    private var ghostFutureDescription: String {
        let affected = flexibleFutureTasks.count
        let projectedEnd = flexibleFutureTasks.compactMap { task -> Int? in
            guard let start = TimeMath.minutes(task.startTime) else { return nil }
            return adjusted(start) + pushDelta + max(5, task.durationMinutes) + max(0, task.bufferAfterMinutes ?? 5)
        }.max() ?? currentMinute
        let sleepDelta = max(0, projectedEnd - sleepMinute)
        let ending = sleepDelta > 0 ? " · day +\(sleepDelta)m past sleep target" : " · ends about \(clock(projectedEnd))"
        return "Ghost Future · \(affected) flexible task\(affected == 1 ? "" : "s") shift\(ending)"
    }

    private func timeMachineDescription(at minute: Int) -> String {
        let entries = tasks.compactMap { task -> (PlannerTask, Int, Int)? in
            guard task.allDay != true, task.status != .skipped, let raw = TimeMath.minutes(task.startTime) else { return nil }
            let start = adjusted(raw)
            let rawEnd = TimeMath.minutes(task.endTime) ?? (raw + max(5, task.durationMinutes))
            let end = max(start + 5, adjusted(rawEnd))
            return (task, start, end)
        }.sorted { $0.1 < $1.1 }
        if let active = entries.first(where: { minute >= $0.1 && minute < $0.2 }) {
            return "\(active.0.title) · \(clock(active.1))–\(clock(active.2)) · \(max(0, active.2 - minute)) min remain at this point"
        }
        if let next = entries.first(where: { $0.1 > minute }) {
            return "Free · \(max(0, next.1 - minute)) min until \(next.0.title)"
        }
        return minute < sleepMinute ? "Open runway until \(clock(sleepMinute))" : "Past the sleep target · reality overrun"
    }

    private func adjusted(_ minute: Int) -> Int {
        sleepMinute > 24 * 60 && minute < wakeMinute ? minute + 24 * 60 : minute
    }

    private func clock(_ minute: Int) -> String {
        let wrapped = ((minute % (24 * 60)) + (24 * 60)) % (24 * 60)
        return TimeMath.string(wrapped)
    }

    private func signed(_ amount: Int) -> String { amount > 0 ? "+\(amount)m" : "\(amount)m" }
}

private struct TimelineOpenSpaceStrip: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let day: Date
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int

    @State private var draftTask: PlannerTask?

    private struct Gap: Identifiable {
        let start: Int
        let end: Int
        var id: String { "\(start)-\(end)" }
        var duration: Int { max(0, end - start) }
    }

    private var gaps: [Gap] {
        let key = DateKey.string(day)
        let tasks = store.data.plans.first(where: { $0.date == key })?.tasks ?? []
        let intervals = tasks.compactMap { task -> (start: Int, end: Int)? in
            guard task.allDay != true,
                  task.status != .skipped,
                  let rawStart = TimeMath.minutes(task.startTime) else { return nil }
            let start = adjusted(rawStart)
            let rawEnd = TimeMath.minutes(task.endTime) ?? (rawStart + max(5, task.durationMinutes))
            var end = adjusted(rawEnd)
            if end <= start { end = start + max(5, task.durationMinutes) }
            return (start, end)
        }
        .sorted { $0.start < $1.start }

        var result: [Gap] = []
        var cursor = wakeMinute
        for interval in intervals {
            if interval.start - cursor >= 20 {
                result.append(Gap(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }
        if sleepMinute - cursor >= 20 {
            result.append(Gap(start: cursor, end: sleepMinute))
        }

        if Calendar.current.isDate(day, inSameDayAs: now) {
            let current = currentMinute
            return result.compactMap { gap in
                let start = max(gap.start, current)
                guard gap.end - start >= 20 else { return nil }
                return Gap(start: start, end: gap.end)
            }
        }
        return result
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        if !gaps.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Label("Open space", systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(gaps.count) window\(gaps.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(p.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(gaps.prefix(5))) { gap in
                            Button {
                                createDraft(in: gap)
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "plus")
                                        .font(.caption.weight(.bold))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("\(gap.duration) min free")
                                            .font(.caption.weight(.semibold))
                                        Text("\(clock(gap.start))–\(clock(gap.end))")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(p.secondary)
                                    }
                                }
                                .padding(.horizontal, 11)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
            .sheet(item: $draftTask) { task in
                NavigationStack {
                    TaskEditorView(task: task, isNew: true)
                }
            }
        }
    }

    private var currentMinute: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        var minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if sleepMinute > 24 * 60 && minute < wakeMinute { minute += 24 * 60 }
        return minute
    }

    private func adjusted(_ minute: Int) -> Int {
        if sleepMinute > 24 * 60 && minute < wakeMinute { return minute + 24 * 60 }
        return minute
    }

    private func createDraft(in gap: Gap) {
        let rounded = Int(ceil(Double(gap.start) / 5.0)) * 5
        let start = min(gap.end - 5, max(gap.start, rounded))
        let duration = min(45, max(5, gap.end - start))
        var task = PlanEngine.manualTask(title: "", date: DateKey.string(day))
        task.startTime = clock(start)
        task.durationMinutes = duration
        task.endTime = clock(start + duration)
        task.allDay = false
        task.section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night
        draftTask = task
    }

    private func clock(_ minute: Int) -> String {
        let wrapped = ((minute % (24 * 60)) + (24 * 60)) % (24 * 60)
        return TimeMath.string(wrapped)
    }
}


private struct TimelineBeadShape: Shape {
    let circular: Bool
    func path(in rect: CGRect) -> Path {
        if circular { return Circle().path(in: rect) }
        return Capsule().path(in: rect)
    }
}

private enum TimelineNodeFlow {
    case horizontal
    case vertical
}

private struct WeekTimelineTaskNode: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let task: PlannerTask
    let day: Date
    let now: Date
    let size: CGFloat
    var flow: TimelineNodeFlow = .horizontal
    var ovalScaleLimit: CGFloat? = nil
    var progressOverride: CGFloat? = nil

    @State private var showEditor = false

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        let tint = TaskTint.resolve(task)
        let liveProgress = task.status == .completed ? 1 : (progressOverride ?? taskProgress)
        let progress = min(1, max(0, liveProgress))
        let active = progress > 0 && progress < 1
        let symbol = IconEngine.symbol(for: task)
        let resolvedShape = TimelineShapeEngine.resolvedShape(for: task)
        let dimensions = beadDimensions(shape: resolvedShape)
        let rotation = beadRotation(shape: resolvedShape)
        let outer = outerDimensions

        Button {
            showEditor = true
        } label: {
            ZStack {
                beadSurface(
                    palette: p,
                    tint: tint,
                    progress: progress,
                    active: active,
                    resolvedShape: resolvedShape,
                    dimensions: dimensions
                )
                .frame(width: dimensions.width, height: dimensions.height)
                .rotationEffect(.degrees(rotation))

                Image(systemName: symbol)
                    .font(.system(size: size >= 50 ? 23 : 11, weight: .semibold))
                    .foregroundStyle(progress > 0.02 ? tint : p.secondary)
                    .shadow(color: p.background.opacity(0.28), radius: 1)

                if task.externalSource == .calendar || task.externalImportance == .important || task.timelineLocked == true {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: size >= 50 ? 13 : 8, weight: .bold))
                        .foregroundStyle(p.secondary)
                        .padding(1)
                        .glassEffect(.regular.tint(p.accent.opacity(0.055)).interactive(), in: Circle())
                        .offset(x: -outer.width * 0.30, y: -outer.height * 0.30)
                }
            }
            .frame(width: outer.width, height: outer.height)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            Button { store.toggleTask(task.id) } label: {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: size >= 50 ? 16 : 10, weight: .bold))
                    .foregroundStyle(task.status == .completed ? tint : p.secondary)
                    .frame(width: size >= 50 ? 28 : 20, height: size >= 50 ? 28 : 20)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(tint.opacity(0.075)).interactive(), in: Circle())
            .offset(x: 4, y: -4)
            .accessibilityLabel(task.status == .completed ? "Mark \(task.title) incomplete" : "Complete \(task.title)")
        }
        .draggable("task:\(task.id)")
        .contextMenu {
            Button("Edit", systemImage: "slider.horizontal.3") { showEditor = true }
            Button("Complete", systemImage: "checkmark.circle") { store.toggleTask(task.id) }
            if task.externalSource != .calendar {
                Button(task.timelineLocked == true ? "Unlock time" : "Lock as anchor", systemImage: task.timelineLocked == true ? "lock.open" : "lock") {
                    store.setTimelineLocked(task.id, locked: task.timelineLocked != true)
                }
            }
            Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicateTask(task.id) }
            Button("Delete", systemImage: "trash", role: .destructive) { store.deleteTask(task.id) }
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                TaskEditorView(task: task, isNew: false)
            }
        }
        .planningFeedback(.selection, trigger: showEditor)
        .accessibilityLabel("\(task.title), \(task.startTime ?? "any time")")
    }

    @ViewBuilder
    private func beadSurface(
        palette p: AppPalette,
        tint: Color,
        progress: CGFloat,
        active: Bool,
        resolvedShape: TaskShape,
        dimensions: CGSize
    ) -> some View {
        let shape = TimelineBeadShape(circular: resolvedShape == .circle)

        let core = ZStack {
            // Opaque eraser prevents the timeline rail from leaking through the bead.
            shape.fill(p.background.opacity(scheme == .dark ? 0.94 : 0.88))

            if usesVerticalFill {
                ZStack(alignment: .top) {
                    shape.fill(tint.opacity(scheme == .dark ? 0.075 : 0.050))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.50), tint.opacity(0.24)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: dimensions.width, height: dimensions.height * progress)
                }
                .frame(width: dimensions.width, height: dimensions.height, alignment: .top)
                .clipShape(shape)
            } else {
                ZStack(alignment: .leading) {
                    shape.fill(tint.opacity(scheme == .dark ? 0.075 : 0.050))
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.50), tint.opacity(0.24)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: dimensions.width * progress, height: dimensions.height)
                }
                .frame(width: dimensions.width, height: dimensions.height, alignment: .leading)
                .clipShape(shape)
            }

            shape.stroke(tint.opacity(active ? 0.34 : 0.20), lineWidth: size >= 50 ? 1.35 : 0.9)
        }
        .frame(width: dimensions.width, height: dimensions.height)
        .clipShape(shape)
        .compositingGroup()

        core
            .glassEffect(
                .regular.tint(tint.opacity(active ? 0.10 : 0.045)).interactive(),
                in: shape
            )
            .frame(width: dimensions.width, height: dimensions.height)
            .clipShape(shape)
            .compositingGroup()
    }

    private var usesVerticalFill: Bool {
        if case .vertical = flow { return true }
        return false
    }

    private var ovalLengthScale: CGFloat {
        let requested = CGFloat(min(3.50, max(1.15, task.timelineOvalLengthScale ?? 1.45)))
        guard let ovalScaleLimit else { return requested }
        return min(requested, max(1.0, ovalScaleLimit))
    }

    private func beadDimensions(shape: TaskShape) -> CGSize {
        guard shape != .circle else { return CGSize(width: size, height: size) }
        let thickness = size * 0.82
        switch flow {
        case .horizontal:
            return CGSize(width: size * ovalLengthScale, height: thickness)
        case .vertical:
            return CGSize(width: thickness, height: size * ovalLengthScale)
        }
    }

    private func beadRotation(shape: TaskShape) -> Double {
        return 0
    }

    private var outerDimensions: CGSize {
        let shape = TimelineShapeEngine.resolvedShape(for: task)
        let dimensions = beadDimensions(shape: shape)
        // A circle keeps an exact hit region so nearby timeline controls stay reachable.
        if shape == .circle {
            return CGSize(width: dimensions.width + 4, height: dimensions.height + 4)
        }
        let radians = beadRotation(shape: shape) * .pi / 180
        let c = abs(cos(radians))
        let s = abs(sin(radians))
        return CGSize(
            width: dimensions.width * c + dimensions.height * s + 6,
            height: dimensions.width * s + dimensions.height * c + 6
        )
    }

    private var taskProgress: CGFloat {
        if task.status == .completed { return 1 }

        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard let rawStart = TimeMath.minutes(task.startTime) else { return 0 }

        var startMinute = rawStart
        let wake = TimeMath.minutes(store.data.profile.wakeTime) ?? 8 * 60
        let rawSleep = TimeMath.minutes(store.data.profile.sleepTime) ?? 23 * 60
        let sleep = rawSleep <= wake ? rawSleep + 24 * 60 : rawSleep
        if sleep > 24 * 60 && startMinute < wake { startMinute += 24 * 60 }

        let rawEnd = TimeMath.minutes(task.endTime)
        var endMinute = rawEnd ?? (rawStart + max(1, task.durationMinutes))
        if sleep > 24 * 60 && endMinute < wake { endMinute += 24 * 60 }
        if endMinute <= startMinute { endMinute = startMinute + max(1, task.durationMinutes) }

        guard let startDate = calendar.date(byAdding: .minute, value: startMinute, to: dayStart),
              let endDate = calendar.date(byAdding: .minute, value: endMinute, to: dayStart) else { return 0 }

        if now <= startDate { return 0 }
        if now >= endDate { return 1 }
        return CGFloat(now.timeIntervalSince(startDate) / endDate.timeIntervalSince(startDate))
    }
}

private struct DetailedDaySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let plan: DayPlan

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Label(store.data.profile.wakeTime, systemImage: "sunrise.fill")
                        Spacer()
                        Label(store.data.profile.sleepTime, systemImage: "moon.stars.fill")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(p.secondary)

                    ForEach(TaskTimelineOrder.sorted(plan.tasks)) { task in
                        HStack(spacing: 11) {
                            Image(systemName: IconEngine.symbol(for: task))
                                .foregroundStyle(TaskTint.resolve(task))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.headline)
                                HStack(spacing: 6) {
                                    Text(task.startTime ?? "Anytime")
                                    if let subtasks = task.subtasks, !subtasks.isEmpty {
                                        Text("· \(subtasks.filter(\.completed).count)/\(subtasks.count) steps")
                                    }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if task.status == .completed { Image(systemName: "checkmark.circle.fill").foregroundStyle(p.accent) }
                        }
                        .padding(14)
                        .premiumGlassRounded(
                            cornerRadius: 22,
                            tint: TaskTint.resolve(task).opacity(scheme == .dark ? 0.16 : 0.10),
                            interactive: true
                        )
                    }
                }
                .padding(16)
            }
            .appCanvas()
            .navigationTitle("Day details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private struct HabitStrip: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Habits")
            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer(spacing: 10) {
                    HStack {
                        ForEach(store.data.habits) { habit in
                            Button { store.toggleHabit(habit.id) } label: {
                                Label(habit.title, systemImage: habit.completedDates.contains(DateKey.today) ? "checkmark.circle.fill" : habit.icon)
                                    .padding(.horizontal, 4)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Cross-layout timeline intelligence

private struct TimelineRealityOverview: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let days: [Date]
    let now: Date
    let title: String

    private var keys: Set<String> { Set(days.map(DateKey.string)) }
    private var tasks: [PlannerTask] {
        store.data.plans.filter { keys.contains($0.date) }.flatMap(\.tasks).filter { $0.status != .skipped }
    }

    private var completed: Int { tasks.filter { $0.status == .completed }.count }
    private var pending: Int { tasks.filter { $0.status == .pending || $0.status == .active }.count }
    private var shifted: [(PlannerTask, Int)] {
        tasks.compactMap { task in
            guard let original = TimeMath.minutes(task.timelineOriginalStartTime),
                  let current = TimeMath.minutes(task.startTime) else { return nil }
            let delta = current - original
            return abs(delta) >= 5 ? (task, delta) : nil
        }
    }
    private var overdue: Int {
        tasks.filter { task in
            guard (task.status == .pending || task.status == .active),
                  let day = DateKey.date(task.planDate) else { return false }
            if Calendar.current.startOfDay(for: day) < Calendar.current.startOfDay(for: now) { return true }
            guard Calendar.current.isDate(day, inSameDayAs: now), let minute = TimeMath.minutes(task.startTime) else { return false }
            let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
            return minute < (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }.count
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        if shifted.isEmpty && overdue == 0 {
            LiquidGlassCapsule(tint: p.accent.opacity(0.045)) {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(p.accent)
                    Text("Reality · on track").font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(completed) done · \(pending) open")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(p.secondary)
                }
            }
        } else {
            PremiumGlassCard(tint: p.accent.opacity(0.05)) {
                VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Label(title, systemImage: "square.stack.3d.up.fill")
                        .font(.headline)
                    Spacer()
                    Text("PLAN ↔ REAL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.accent)
                }
                HStack(spacing: 8) {
                    realityMetric("DONE", "\(completed)")
                    realityMetric("OPEN", "\(pending)")
                    realityMetric("SHIFTED", "\(shifted.count)")
                    realityMetric("LATE", "\(overdue)")
                }
                if let strongest = shifted.max(by: { abs($0.1) < abs($1.1) }) {
                    Text("Largest drift · \(strongest.0.title) \(strongest.1 >= 0 ? "+" : "")\(strongest.1)m")
                        .font(.caption2)
                        .foregroundStyle(p.secondary)
                        .lineLimit(1)
                } else {
                    Text("No meaningful schedule drift detected in this view.")
                        .font(.caption2)
                        .foregroundStyle(p.secondary)
                }
            }
            }
        }
    }

    private func realityMetric(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.bold()).monospacedDigit()
            Text(label).font(.system(size: 8, weight: .bold, design: .rounded)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineGravityOverview: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let days: [Date]
    let now: Date
    let title: String

    private var keys: Set<String> { Set(days.map(DateKey.string)) }
    private var gravityTasks: [PlannerTask] {
        store.data.plans
            .filter { keys.contains($0.date) }
            .flatMap(\.tasks)
            .filter { $0.status == .pending || $0.status == .active }
            .sorted { lhs, rhs in
                let left = gravityScore(lhs)
                let right = gravityScore(rhs)
                if left == right { return lhs.planDate + (lhs.startTime ?? "99:99") < rhs.planDate + (rhs.startTime ?? "99:99") }
                return left > right
            }
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        MatteCard {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "circle.hexagongrid.fill").font(.headline)
                if gravityTasks.isEmpty {
                    Text("Nothing is pulling for attention right now.").font(.caption).foregroundStyle(p.secondary)
                } else {
                    ForEach(Array(gravityTasks.prefix(4))) { task in
                        HStack(spacing: 8) {
                            Image(systemName: task.mustWin == true ? "star.fill" : IconEngine.symbol(for: task))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(task.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text("\(shortDay(task.planDate)) · \(task.startTime ?? "Any time") · priority \(task.priority)")
                                    .font(.caption2).foregroundStyle(p.secondary)
                            }
                            Spacer()
                            Text("\(gravityScore(task))")
                                .font(.caption2.bold().monospacedDigit())
                                .foregroundStyle(p.accent)
                        }
                    }
                }
            }
        }
    }

    private func gravityScore(_ task: PlannerTask) -> Int {
        var score = max(0, 4 - task.priority) * 20
        if task.mustWin == true { score += 45 }
        if task.deadline?.isEmpty == false { score += 20 }
        if task.category == .focus { score += 10 }
        if task.timelineLocked == true { score += 5 }
        return score
    }

    private func shortDay(_ key: String) -> String {
        DateKey.date(key)?.formatted(.dateTime.weekday(.abbreviated)) ?? key
    }
}

private struct TimelineDeadlineRadar: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let days: [Date]
    let now: Date

    private var keys: Set<String> { Set(days.map(DateKey.string)) }
    private var urgent: [PlannerTask] {
        store.data.plans.filter { keys.contains($0.date) }.flatMap(\.tasks)
            .filter { ($0.status == .pending || $0.status == .active) && ($0.deadline?.isEmpty == false || $0.mustWin == true || $0.priority == 1) }
            .sorted {
                let ld = $0.deadline ?? $0.planDate + "T" + ($0.startTime ?? "23:59")
                let rd = $1.deadline ?? $1.planDate + "T" + ($1.startTime ?? "23:59")
                return ld < rd
            }
    }

    var body: some View {
        if !urgent.isEmpty {
            let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "radar")
                        .foregroundStyle(p.accent)
                    Text("Deadline Radar")
                        .font(.caption.weight(.bold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(Array(urgent.prefix(5))) { task in
                                Text("\(task.title) · \(deadlineLabel(task))")
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 6)
                                    .glassEffect(.regular.tint(p.accent.opacity(0.04)).interactive(), in: Capsule())
                            }
                        }
                    }
                }
            }
        }
    }

    private func deadlineLabel(_ task: PlannerTask) -> String {
        if let deadline = task.deadline, !deadline.isEmpty { return deadline }
        return DateKey.date(task.planDate)?.formatted(.dateTime.weekday(.abbreviated)) ?? task.planDate
    }
}

private struct WeekTimelineControlDeck: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme

    let days: [Date]
    let now: Date
    let wakeMinute: Int
    let sleepMinute: Int
    let onOpenDay: (Date) -> Void

    @State private var showPaywall = false
    @State private var weekScrub = 0.0
    @State private var timeMachineEnabled = false
    @State private var feedbackPulse = 0
    @State private var pendingActionID: String?
    @State private var actionStatus: String?

    private struct WeekAction: Identifiable {
        let id: String
        let title: String
        let symbol: String
        let detail: String
        let requiresPro: Bool
    }

    private let weekActions = [
        WeekAction(id: "compress", title: "Compress Week", symbol: "arrow.down.right.and.arrow.up.left", detail: "Close safe gaps across all seven days.", requiresPro: true),
        WeekAction(id: "buffer", title: "Buffer Guard", symbol: "shield.lefthalf.filled", detail: "Keep transition room on every day.", requiresPro: false),
        WeekAction(id: "focus", title: "Focus Shield", symbol: "scope", detail: "Protect each day's strongest focus block.", requiresPro: false),
        WeekAction(id: "conflicts", title: "Conflict Sweep", symbol: "wand.and.stars", detail: "Repair flexible overlaps without touching fixed events.", requiresPro: false)
    ]

    private var selectedScrubDay: Date {
        guard !days.isEmpty else { return now }
        return days[min(days.count - 1, max(0, Int(weekScrub.rounded())))]
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Shape this week", subtitle: "Changes run once, after your confirmation.")

            Group {
                VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Make space & protect time")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.secondary)
                    Spacer()
                    if let actionStatus {
                        Text(actionStatus)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(p.accent)
                            .lineLimit(1)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 10)], spacing: 10) {
                    ForEach(weekActions) { action in
                        Button {
                            if action.requiresPro && !store.hasAccess(.advancedTimelineTools) {
                                showPaywall = true
                            } else {
                                pendingActionID = action.id
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: action.requiresPro && !store.hasAccess(.advancedTimelineTools) ? "lock.fill" : action.symbol)
                                        .foregroundStyle(p.accent)
                                    Text(action.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                Text(action.detail)
                                    .font(.caption2)
                                    .foregroundStyle(p.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .topLeading)
                            .padding(11)
                            .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .premiumGlassRounded(cornerRadius: 19, tint: p.accent.opacity(0.035), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Shows a confirmation before changing this week")
                    }
                }
            }

            TimelineIntelligenceInline(dates: days.map(DateKey.string))

            HStack(spacing: 8) {
                Button {
                    guard store.hasAccess(.advancedTimelineTools) else { showPaywall = true; return }
                    timeMachineEnabled.toggle()
                } label: {
                    Label(store.hasAccess(.advancedTimelineTools) ? "Week Time Machine" : "Week Time Machine · Pro", systemImage: store.hasAccess(.advancedTimelineTools) ? "clock.arrow.circlepath" : "lock.fill")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                Spacer()
            }

            if timeMachineEnabled, !days.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(selectedScrubDay.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Button("Open day") { onOpenDay(selectedScrubDay) }
                            .buttonStyle(.glassProminent)
                            .controlSize(.small)
                    }
                    Slider(value: $weekScrub, in: 0...Double(max(0, days.count - 1)), step: 1)
                        .tint(p.accent)
                    WeekTimeMachineSnapshot(day: selectedScrubDay, now: now)
                }
            }
                }
            }
        }
        .planningFeedback(.impact(weight: .light), trigger: feedbackPulse)
        .sheet(isPresented: $showPaywall) { NavigationStack { PaywallView() } }
        .confirmationDialog(
            pendingAction.map { "Apply \($0.title)?" } ?? "Adjust this week?",
            isPresented: Binding(
                get: { pendingActionID != nil },
                set: { if !$0 { pendingActionID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apply and keep Undo") {
                if let pendingActionID { runWeekAction(pendingActionID) }
                pendingActionID = nil
            }
            Button("Cancel", role: .cancel) { pendingActionID = nil }
        } message: {
            Text(pendingAction?.detail ?? "Nothing moves until you confirm.")
        }
    }

    private var pendingAction: WeekAction? { weekActions.first { $0.id == pendingActionID } }

    private func runWeekAction(_ id: String) {
        let label = weekActions.first(where: { $0.id == id })?.title ?? "Week adjustment"
        let changed = store.performTimelineTransaction(label: label) {
            switch id {
            case "compress": store.compressWeek(containing: days.first ?? now)
            case "buffer": days.reduce(0) { $0 + store.applyBufferGuard(on: DateKey.string($1), minimumMinutes: 10) }
            case "focus": days.reduce(0) { $0 + store.focusShield(on: DateKey.string($1)) }
            case "conflicts": days.reduce(0) { $0 + store.repairTimelineConflicts(on: DateKey.string($1)) }
            default: 0
            }
        }
        actionStatus = changed == 0 ? "Already protected" : "\(changed) updated"
        feedbackPulse += 1
    }
}


private struct TimelineIntelligenceInline: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let dates: [String]
    @State private var pendingIndex: Int?
    @State private var status: String?
    @State private var selectedGroup = "Optimize"

    private struct Tool: Identifiable {
        let id: Int
        let group: String
        let title: String
        let symbol: String
        let detail: String
    }

    private let tools = [
        Tool(id: 0, group: "Optimize", title: "Energy Fit", symbol: "bolt.heart.fill", detail: "Match flexible work to stronger hours."),
        Tool(id: 1, group: "Optimize", title: "Capacity Balance", symbol: "gauge.with.dots.needle.67percent", detail: "Preview a realistic load across the day."),
        Tool(id: 2, group: "Optimize", title: "Context Batching", symbol: "square.stack.3d.up.fill", detail: "Bring related work closer together."),
        Tool(id: 6, group: "Optimize", title: "Momentum Chain", symbol: "link.circle.fill", detail: "Build a smoother related-work sequence."),
        Tool(id: 3, group: "Protect", title: "Travel Buffer", symbol: "car.fill", detail: "Add room around calendar commitments."),
        Tool(id: 4, group: "Protect", title: "Focus Budget", symbol: "scope", detail: "Reserve enough uninterrupted focus time."),
        Tool(id: 9, group: "Protect", title: "No-Meeting Guard", symbol: "calendar.badge.minus", detail: "Protect configured focus days."),
        Tool(id: 11, group: "Protect", title: "Switch Shield", symbol: "shield.checkered", detail: "Reduce avoidable context switching."),
        Tool(id: 5, group: "Automate", title: "Meeting Defrag", symbol: "person.2.badge.clock.fill", detail: "Turn fragmented gaps into usable time."),
        Tool(id: 7, group: "Automate", title: "Deadline Backplan", symbol: "calendar.badge.exclamationmark", detail: "Place deadline work before it becomes urgent."),
        Tool(id: 8, group: "Automate", title: "Habit Rescue", symbol: "repeat.circle.fill", detail: "Place today's unfinished scheduled habits."),
        Tool(id: 10, group: "Automate", title: "Deep Work Reserve", symbol: "brain.fill", detail: "Create one protected deep-work block.")
    ]

    init(date: String) { dates = [date] }
    init(dates: [String]) { self.dates = dates }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Planning Intelligence").font(.headline)
                    Text("Choose an action · preview its purpose · apply once")
                        .font(.caption2)
                        .foregroundStyle(p.secondary)
                }
                Spacer()
                if let status {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(p.accent)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GlassEffectContainer(spacing: 8) {
                PlanningAdaptiveRow(spacing: 8) {
                    ForEach(["Optimize", "Protect", "Automate"], id: \.self) { group in
                        Button { selectedGroup = group } label: {
                            Text(group).font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.glass)
                        .tint(selectedGroup == group ? p.accent : p.secondary)
                        .accessibilityAddTraits(selectedGroup == group ? .isSelected : [])
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(tools.filter { $0.group == selectedGroup }) { tool in
                    Button { pendingIndex = tool.id } label: {
                        HStack(spacing: 12) {
                            Image(systemName: tool.symbol).font(.title3).foregroundStyle(p.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tool.title).font(.subheadline.weight(.semibold)).foregroundStyle(p.text)
                                Text(tool.detail).font(.subheadline).foregroundStyle(p.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(p.secondary)
                        }
                        .padding(16).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Review and apply once. This is not a background toggle.")
                }
            }.premiumGlassRounded(cornerRadius: 24)
            if store.canUndoTimelineChange {
                Button { store.undoLastTimelineChange(); status = "Last change undone" } label: {
                    Label("Undo last change", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity, minHeight: 30)
                }.buttonStyle(.glass)
            }
        }
        .confirmationDialog(
            pendingTool.map { "Apply \($0.title)?" } ?? "Apply intelligence?",
            isPresented: Binding(
                get: { pendingIndex != nil },
                set: { if !$0 { pendingIndex = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Apply and keep Undo") {
                if let pendingIndex { run(pendingIndex) }
                pendingIndex = nil
            }
            Button("Cancel", role: .cancel) { pendingIndex = nil }
        } message: {
            Text(pendingTool?.detail ?? "Your schedule changes only after confirmation.")
        }
    }

    private var pendingTool: Tool? { tools.first { $0.id == pendingIndex } }

    private func run(_ index: Int) {
        let label = tools.first(where: { $0.id == index })?.title ?? "Planning Intelligence"
        let changed = store.performTimelineTransaction(label: label) {
            var total = 0
            for date in dates {
                switch index {
                case 0: total += store.applyEnergyFit(on: date)
                case 1: total += store.applyOverloadGuard(on: date)
                case 2: total += store.batchContexts(on: date)
                case 3: total += store.applyTravelBuffer(on: date)
                case 4: total += store.protectFocusBudget(on: date)
                case 5: total += store.defragMeetings(on: date)
                case 6: total += store.buildMomentumChain(on: date)
                case 7: total += store.backplanDeadlines(on: date)
                case 8: total += store.rescueHabits(on: date)
                case 9: total += store.applyNoMeetingGuard(on: date)
                case 10: total += store.reserveDeepWork(on: date)
                case 11: total += store.applyContextSwitchShield(on: date)
                default: break
                }
            }
            return total
        }
        status = changed == 0 ? "No changes needed" : "\(changed) updated"
    }
}

private struct WeekTimeMachineSnapshot: View {
    @Environment(AppStore.self) private var store
    let day: Date
    let now: Date

    private var tasks: [PlannerTask] {
        store.data.plans.first(where: { $0.date == DateKey.string(day) })?.tasks.filter { $0.status != .skipped } ?? []
    }

    var body: some View {
        let done = tasks.filter { $0.status == .completed }.count
        let locked = tasks.filter { $0.timelineLocked == true || $0.externalSource == .calendar }.count
        let shifted = tasks.filter { task in
            guard let old = TimeMath.minutes(task.timelineOriginalStartTime), let current = TimeMath.minutes(task.startTime) else { return false }
            return abs(old - current) >= 5
        }.count
        HStack(spacing: 8) {
            Label("\(tasks.count) tasks", systemImage: "list.bullet")
            Spacer()
            Text("\(done) done · \(shifted) shifted · \(locked) fixed")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .premiumGlassCapsule(interactive: true)
    }
}
