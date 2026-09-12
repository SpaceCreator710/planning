import SwiftUI

struct CalendarHomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    @State private var month = Date()
    @State private var scope: CalendarScope = .month
    private enum CalendarScope: String, CaseIterable, Identifiable {
        case week = "Week", month = "Month", year = "Year"
        var id: String { rawValue }
    }
    @State private var showNavigator = false
    @State private var jumpDate = Date()
    @State private var calendarWorking = false
    @State private var calendarError: String?
    @State private var showCalendarPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                scopePicker
                monthHeader
                if !store.data.settings.calendarSyncEnabled { calendarConnectCard }
                switch scope {
                case .week: weekStrip
                case .month: MonthGrid(month: month)
                case .year: yearOverview
                }
                selectedDay
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .appCanvas()
        .navigationTitle("Calendar")
        .onAppear { month = DateKey.date(store.selectedDate) ?? .now }
        .onChange(of: store.selectedDate) { _, key in
            if let date = DateKey.date(key), scope == .week || !Calendar.current.isDate(date, equalTo: month, toGranularity: .month) { month = date }
        }
        .onChange(of: scope) { _, value in
            if value == .week { month = DateKey.date(store.selectedDate) ?? month }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.presentedTask = PlanEngine.manualTask(title: "", date: store.selectedDate)
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add task on selected date")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    NavigationLink("Integrations", destination: IntegrationsView())
                    Button("Today", systemImage: "calendar") {
                        month = .now
                        jumpDate = .now
                        store.selectDate(.now)
                    }
                    Button("Jump to date", systemImage: "calendar.badge.clock") {
                        jumpDate = DateKey.date(store.selectedDate) ?? .now
                        showNavigator = true
                    }
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Calendar options")
            }
        }
        .sheet(isPresented: $showNavigator) {
            NavigationStack {
                VStack(spacing: 22) {
                    DatePicker("Choose any date", selection: $jumpDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(AppPalette.resolve(settings: store.data.settings, scheme: scheme).accent)
                    Text("Pick any year, month and day, then open it directly in your planner.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(18)
                .appCanvas()
                .navigationTitle("Jump to date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showNavigator = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Open") {
                            month = jumpDate
                            store.selectDate(jumpDate)
                            showNavigator = false
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
            }
        }
        .sheet(isPresented: $showCalendarPaywall) {
            NavigationStack { PaywallView() }
        }
        .alert("Calendar couldn't connect", isPresented: Binding(
            get: { calendarError != nil },
            set: { if !$0 { calendarError = nil } }
        )) {
            Button("OK", role: .cancel) { calendarError = nil }
        } message: {
            Text(calendarError ?? "You can change Calendar access later in iOS Settings.")
        }
    }

    private var monthHeader: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 32) }
                    .accessibilityLabel("Previous " + scope.rawValue.lowercased())
                    .buttonStyle(.glass)

                Button {
                    jumpDate = month
                    showNavigator = true
                } label: {
                    HStack(spacing: 6) {
                        Text(scope == .year ? month.formatted(.dateTime.year()) : month.formatted(.dateTime.month(.wide).year())).font(.headline.weight(.semibold))
                        Image(systemName: "chevron.down").font(.caption)
                    }
                    .foregroundStyle(p.accent)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(p.accent.opacity(0.14))

                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 32) }
                    .accessibilityLabel("Next " + scope.rawValue.lowercased())
                    .buttonStyle(.glass)
            }
        }
    }

    private var scopePicker: some View {
        GlassEffectContainer(spacing: 8) {
            PlanningAdaptiveRow(spacing: 8) {
                ForEach(CalendarScope.allCases) { item in
                    if item == scope {
                        scopeButton(item).buttonStyle(.glassProminent).accessibilityAddTraits(.isSelected)
                    } else {
                        scopeButton(item).buttonStyle(.glass)
                    }
                }
            }
        }
    }

    private func scopeButton(_ item: CalendarScope) -> some View {
        Button { withAnimation(.smooth) { scope = item } } label: {
            Text(item.rawValue).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 32)
        }
    }

    private var weekStrip: some View {
        let dates = CalendarProjection.weekDates(containing: month)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(dates, id: \.self) { date in
                    let selected = DateKey.string(date) == store.selectedDate
                    Button { store.selectDate(date) } label: {
                        VStack(spacing: 8) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.caption)
                            Text(date.formatted(.dateTime.day())).font(.title3.weight(.semibold))
                        }
                        .frame(minWidth: 38, minHeight: 62)
                    }
                    .buttonStyle(.glass)
                    .tint(selected ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }.padding(.vertical, 4)
        }
    }

    private var yearOverview: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(1...12, id: \.self) { number in
                if let date = Calendar.current.date(from: DateComponents(year: Calendar.current.component(.year, from: month), month: number, day: 1)) {
                    let prefix = String(DateKey.string(date).prefix(7))
                    let count = store.data.plans.filter { $0.date.hasPrefix(prefix) }.reduce(0) { $0 + $1.tasks.count }
                    Button {
                        month = date
                        store.selectDate(date)
                        scope = .month
                    } label: {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(date.formatted(.dateTime.month(.wide))).font(.headline)
                            Text(count == 0 ? "Open month" : "\(count) scheduled items")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                        .padding(16).premiumGlassRounded(cornerRadius: 24)
                    }.buttonStyle(.plain)
                }
            }
        }
    }

    private var calendarConnectCard: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        return PremiumGlassCard(tint: p.accent.opacity(0.07)) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundStyle(p.accent)
                VStack(alignment: .leading, spacing: 7) {
                    Text("Bring in Apple Calendar")
                        .font(.headline)
                    Text("Protect classes, appointments and other fixed commitments in your Planning timeline.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        if store.hasAccess(.appleIntegrations) { connectCalendar() }
                        else { showCalendarPaywall = true }
                    } label: {
                        if calendarWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(store.hasAccess(.appleIntegrations) ? "Connect Calendar" : "Unlock Calendar", systemImage: store.hasAccess(.appleIntegrations) ? "link" : "lock.fill")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(calendarWorking)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var selectedDay: some View {
        let tasks = TaskTimelineOrder.sorted(store.data.plans.first(where: { $0.date == store.selectedDate })?.tasks ?? [])
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(selectedDateLabel, subtitle: tasks.isEmpty ? "Nothing scheduled" : "\(tasks.count) items")
            if tasks.isEmpty {
                Button {
                    store.presentedTask = PlanEngine.manualTask(title: "", date: store.selectedDate)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus")
                        Text("Add the first task to this day")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(14)
                    .premiumGlassRounded(cornerRadius: 22, tint: .accentColor.opacity(0.045), interactive: true)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(tasks) { task in
                    NavigationLink { TaskEditorView(task: task, isNew: false) } label: {
                        HStack(spacing: 11) {
                            Image(systemName: IconEngine.symbol(for: task))
                                .foregroundStyle(TaskTint.resolve(task))
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.headline)
                                Text(task.startTime ?? "Anytime").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if task.status == .completed {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                            }
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(14)
                        .contentShape(Rectangle())
                        .premiumGlassRounded(cornerRadius: 22, tint: TaskTint.resolve(task).opacity(0.10), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectedDateLabel: String {
        (DateKey.date(store.selectedDate) ?? .now).formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func shiftMonth(_ delta: Int) {
        let component: Calendar.Component = scope == .week ? .weekOfYear : scope == .year ? .year : .month
        month = Calendar.current.date(byAdding: component, value: delta, to: month) ?? month
        store.selectDate(month)
    }

    private func connectCalendar() {
        guard !calendarWorking else { return }
        calendarWorking = true
        Task {
            let granted = await CalendarService.shared.requestCalendarAccess()
            await MainActor.run {
                store.updateSettings { $0.calendarSyncEnabled = granted }
                calendarWorking = false
                if !granted {
                    calendarError = "Calendar access was not granted. Planning still works with its own calendar."
                }
            }
            if granted { await store.refreshExternalSources() }
        }
    }
}

private struct MonthGrid: View {
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var scheme
    let month: Date

    private var dates: [Date?] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap { day -> Date? in
            var components = calendar.dateComponents([.year,.month], from: month)
            components.day = day
            return calendar.date(from: components)
        }
    }

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        VStack(spacing: 9) {
            HStack {
                ForEach(0..<7, id: \.self) { index in
                    let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
                    Text(symbols[(index + Calendar.current.firstWeekday - 1) % 7])
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 6) {
                ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let key = DateKey.string(date)
                        let selected = key == store.selectedDate
                        let plan = store.data.plans.first(where: { $0.date == key })
                        let taskCount = plan?.tasks.count ?? 0
                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.1)) { store.selectDate(date) }
                        } label: {
                            VStack(spacing: 4) {
                                Text(date.formatted(.dateTime.day()))
                                    .font(.subheadline.weight(selected ? .bold : .regular))
                                HStack(spacing: 2) {
                                    ForEach(0..<min(taskCount, 3), id: \.self) { index in
                                        Circle()
                                            .fill(index == 0 && selected ? p.accent : p.secondary.opacity(0.52))
                                            .frame(width: 3.5, height: 3.5)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                if selected {
                                    Capsule().fill(.clear).glassEffect(.regular.tint(p.accent.opacity(0.18)).interactive(), in: Capsule())
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityValue("\(taskCount) items")
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }
}
