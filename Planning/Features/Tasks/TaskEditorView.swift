import SwiftUI

struct TaskEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State var task: PlannerTask
    let isNew: Bool
    @State private var isGeneratingSubtasks = false
    @State private var showIconPicker = false
    @State private var customAlertMinutes = 45

    var body: some View {
        let p = AppPalette.resolve(settings: store.data.settings, scheme: scheme)
        Form {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: resolvedIcon)
                        .font(.title2.weight(.semibold))
                        .frame(width: 52, height: 52)
                        .foregroundStyle(resolvedTint)
                        .premiumGlassRounded(cornerRadius: 18, tint: resolvedTint.opacity(0.18), interactive: true)
                    TextField("Task name", text: $task.title)
                        .font(.title3.weight(.semibold))
                }
                TextField("Notes", text: Binding(get: { task.note ?? "" }, set: { task.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Essentials") {
                DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                Toggle("All day", isOn: Binding(get: { task.allDay ?? false }, set: { task.allDay = $0 }))
                if task.allDay != true {
                    DatePicker("Start", selection: startBinding, displayedComponents: .hourAndMinute)
                    Stepper("Duration · \(task.durationMinutes) min", value: $task.durationMinutes, in: 5...480, step: 5)
                    Stepper(
                        "Reset buffer · \(task.bufferAfterMinutes ?? 5) min",
                        value: Binding(get: { task.bufferAfterMinutes ?? 5 }, set: { task.bufferAfterMinutes = $0 }),
                        in: 0...60,
                        step: 5
                    )
                    Toggle("Lock time on timeline", isOn: Binding(
                        get: { task.timelineLocked == true },
                        set: { task.timelineLocked = $0 }
                    ))
                } else {
                    DatePicker("All-day alert time", selection: allDayAlertTimeBinding, displayedComponents: .hourAndMinute)
                }
                Picker("Priority", selection: $task.priority) {
                    Text("Low").tag(1)
                    Text("Normal").tag(2)
                    Text("High").tag(3)
                }
                .pickerStyle(.segmented)
                Stepper("Energy · \(task.energy ?? 3)/5", value: Binding(get: { task.energy ?? 3 }, set: { task.energy = $0 }), in: 1...5)
                Toggle("Deadline", isOn: deadlineEnabledBinding)
                if task.deadline != nil {
                    DatePicker("Due", selection: deadlineBinding, displayedComponents: [.date,.hourAndMinute])
                }
            }

            Section {
                NavigationLink {
                    Form {
            Section("Icon") {
                Button { showIconPicker = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: resolvedIcon)
                            .font(.title2.weight(.semibold))
                            .frame(width: 54, height: 54)
                            .foregroundStyle(resolvedTint)
                            .premiumGlassRounded(cornerRadius: 19, tint: resolvedTint.opacity(0.18), interactive: true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.iconIsAutomatic == true || task.icon == nil ? "Automatic icon" : "Custom icon")
                                .font(.headline)
                            Text(task.iconIsAutomatic == true || task.icon == nil ? "Follows your task title" : "Chosen by you")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .premiumGlassRounded(cornerRadius: 20, tint: resolvedTint.opacity(0.055), interactive: true)
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button("Browse icons", systemImage: "square.grid.2x2") { showIconPicker = true }
                        .buttonStyle(.glass)
                    if task.iconIsAutomatic == true || task.icon == nil {
                        Button("Automatic", systemImage: "wand.and.stars") {
                            task.icon = nil
                            task.iconIsAutomatic = true
                        }
                        .buttonStyle(.glassProminent)
                    } else {
                        Button("Automatic", systemImage: "wand.and.stars") {
                            task.icon = nil
                            task.iconIsAutomatic = true
                        }
                        .buttonStyle(.glass)
                    }
                }
            }

            Section("Appearance") {
                HStack {
                    Label("Task tint", systemImage: "circle.fill").foregroundStyle(resolvedTint)
                    Spacer()
                    Button("Auto") {
                        task.color = nil
                        task.customTintHue = nil
                        task.customTintSaturation = nil
                        task.customTintLightness = nil
                    }
                    .buttonStyle(.glass)
                }

                Picker("Matte preset", selection: presetColorBinding) {
                    ForEach(TaskColor.allCases) { color in
                        Label(color.rawValue.capitalized, systemImage: "circle.fill").tag(color)
                    }
                }

                if store.hasAccess(.premiumAppearance) {
                    Toggle("Custom matte tint", isOn: customTintEnabled)
                    if customTintEnabled.wrappedValue {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Hue · \(Int(task.customTintHue ?? 350))°")
                            Slider(value: tintHueBinding, in: 0...360, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Saturation · \(Int(task.customTintSaturation ?? 28))%")
                            Slider(value: tintSaturationBinding, in: 5...65, step: 1)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Lightness · \(Int(task.customTintLightness ?? 54))%")
                            Slider(value: tintLightnessBinding, in: 32...76, step: 1)
                        }
                    }
                } else {
                    NavigationLink { PaywallView() } label: { Label("Custom HSL task tint · Pro", systemImage: "lock.fill") }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Timeline shape")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    PlanningAdaptiveRow(spacing: 9) {
                        shapeChoice(title: "Auto", systemName: "wand.and.stars", selected: task.timelineShapeAutomatic != false) {
                            task.timelineShapeAutomatic = true
                        }
                        shapeChoice(title: "Circle", systemName: "circle", selected: task.timelineShapeAutomatic == false && TimelineShapeEngine.resolvedShape(for: task) == .circle) {
                            task.timelineShapeAutomatic = false
                            task.shape = .circle
                        }
                        shapeChoice(title: "Oval", systemName: "capsule", selected: task.timelineShapeAutomatic == false && TimelineShapeEngine.resolvedShape(for: task) != .circle) {
                            task.timelineShapeAutomatic = false
                            task.shape = .capsule
                        }
                    }
                    Text("Auto assigns a stable circle or oval so the timeline stays varied without changing every launch.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("Oval length")
                            Spacer()
                            Text(String(format: "%.2fx", task.timelineOvalLengthScale ?? 1.45))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { task.timelineOvalLengthScale ?? 1.45 },
                                set: { task.timelineOvalLengthScale = $0 }
                            ),
                            in: 1.15...3.50,
                            step: 0.05
                        )
                        .disabled(TimelineShapeEngine.resolvedShape(for: task) == .circle)
                        Text("Longer ovals stay collision-safe and automatically shrink only when a crowded timeline needs the space.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Category", selection: $task.category) {
                    ForEach(TaskCategory.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
            }

                    }.scrollContentBackground(.hidden).appCanvas()
                        .navigationTitle("Task appearance").navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label("Icon, color & shape", systemImage: resolvedIcon)
                        .foregroundStyle(resolvedTint)
                }
            }

            Section {
                HStack {
                    Text("Subtasks")
                    Spacer()
                    Button { generateSubtasks() } label: {
                        if isGeneratingSubtasks { ProgressView() } else { Label("AI", systemImage: "sparkles") }
                    }
                    .buttonStyle(.glass)
                    .disabled(isGeneratingSubtasks || task.title.isEmpty)
                }
                ForEach((task.subtasks ?? []).indices, id: \.self) { index in
                    HStack {
                        Button { task.subtasks?[index].completed.toggle() } label: {
                            Image(systemName: task.subtasks?[index].completed == true ? "checkmark.circle.fill" : "circle")
                        }
                        .accessibilityLabel(task.subtasks?[index].completed == true ? "Mark subtask incomplete" : "Mark subtask complete")
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        TextField("Subtask", text: Binding(get: { task.subtasks?[index].title ?? "" }, set: { task.subtasks?[index].title = $0 }))
                        Button(role: .destructive) { task.subtasks?.remove(at: index) } label: { Image(systemName: "minus.circle") }
                            .accessibilityLabel("Remove subtask")
                            .buttonStyle(.glass)
                            .controlSize(.small)
                    }
                    .draggable("subtask:\(task.subtasks?[index].id ?? "")")
                    .dropDestination(for: String.self) { items, _ in
                        guard let payload = items.first, payload.hasPrefix("subtask:") else { return false }
                        reorderSubtask(String(payload.dropFirst(8)), before: task.subtasks?[index].id ?? "")
                        return true
                    }
                }
                Button("Add subtask", systemImage: "plus") {
                    if task.subtasks == nil { task.subtasks = [] }
                    task.subtasks?.append(TaskSubtask(title: ""))
                }
            } header: { Text("Subtasks") }

            Section {
                NavigationLink {
                    Form {
            Section("Repeat & alerts") {
                if store.hasAccess(.recurrence) {
                    Picker("Repeat", selection: Binding(get: { task.recurrence ?? .none }, set: { task.recurrence = $0 })) {
                        ForEach(TaskRecurrence.allCases) { Text(recurrenceName($0)).tag($0) }
                    }

                    if task.recurrence == .weekly || task.recurrence == .biweekly {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repeat on").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            HStack(spacing: 7) {
                                ForEach(weekdayChoices, id: \.0) { weekday, label in
                                    if (task.recurrenceDays ?? []).contains(weekday) {
                                        Button(label) { toggleWeekday(weekday) }
                                            .buttonStyle(.glassProminent)
                                            .controlSize(.small)
                                    } else {
                                        Button(label) { toggleWeekday(weekday) }
                                            .buttonStyle(.glass)
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                    }

                    if task.recurrence == .custom {
                        Stepper("Every \(max(1, task.recurrenceInterval ?? 1))", value: customRecurrenceInterval, in: 1...99)
                        Picker("Interval", selection: customRecurrenceUnit) {
                            ForEach(RecurrenceUnit.allCases) { unit in
                                Text(unit.rawValue.capitalized).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if (task.recurrence ?? .none) != .none {
                        Toggle("End recurrence", isOn: Binding(
                            get: { task.recurrenceUntil != nil },
                            set: { enabled in task.recurrenceUntil = enabled ? DateKey.string(Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now) : nil }
                        ))
                        if task.recurrenceUntil != nil {
                            DatePicker("Repeat until", selection: recurrenceUntilBinding, displayedComponents: .date)
                        }
                    }
                } else {
                    NavigationLink { PaywallView() } label: { Label("Recurring tasks · Pro", systemImage: "repeat") }
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Alerts").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Spacer()
                        if task.reminderMinutesBefore != nil {
                            Button("Clear") { task.reminderMinutesBefore = nil; task.additionalReminderMinutesBefore = nil }
                                .font(.caption)
                        }
                    }
                    if store.hasAccess(.customAlerts) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(reminderOptions, id: \.0) { offset, label in
                                    if selectedReminderOffsets.contains(offset) {
                                        Button { toggleReminder(offset) } label: { Label(label, systemImage: "bell.fill") }
                                            .buttonStyle(.glassProminent)
                                            .controlSize(.small)
                                    } else {
                                        Button { toggleReminder(offset) } label: { Label(label, systemImage: "bell") }
                                            .buttonStyle(.glass)
                                            .controlSize(.small)
                                    }
                                }
                            }
                        }
                        HStack(spacing: 10) {
                            Stepper("Custom · \(humanReminder(customAlertMinutes)) before", value: $customAlertMinutes, in: 1...10080, step: 5)
                                .font(.footnote)
                            Button("Add") { addCustomReminder() }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                        }
                        Text("Choose several alerts, or add any custom interval up to 7 days before.")
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Picker("Reminder", selection: basicReminderBinding) {
                            Text("None").tag(-1)
                            ForEach(reminderOptions, id: \.0) { offset, label in Text(label).tag(offset) }
                        }
                        NavigationLink { PaywallView() } label: { Label("Multiple alerts · Pro", systemImage: "bell.badge") }
                            .font(.footnote)
                    }
                }
            }

                    }.scrollContentBackground(.hidden).appCanvas()
                        .navigationTitle("Repeat & alerts").navigationBarTitleDisplayMode(.inline)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Repeat & alerts", systemImage: "repeat")
                        Text(recurrenceName(task.recurrence ?? .none) + " · " + (selectedReminderOffsets.isEmpty ? "No custom alerts" : "\(selectedReminderOffsets.count) alerts"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if !isNew {
                Section("Task actions") {
                    Button("Duplicate task", systemImage: "plus.square.on.square") { store.duplicateTask(task.id); dismiss() }
                    Button("Move to Inbox", systemImage: "tray.and.arrow.down") { store.moveTaskToInbox(task.id); dismiss() }
                    Button("Delete task", role: .destructive) { store.deleteTask(task.id); dismiss() }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle(isNew ? "New Task" : "Edit Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .buttonStyle(.glassProminent)
                    .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(selection: Binding(
                get: { task.icon },
                set: { newValue in
                    task.icon = newValue
                    task.iconIsAutomatic = false
                }
            ))
        }
        .onChange(of: task.startTime) { _, _ in syncEnd() }
        .onChange(of: task.durationMinutes) { _, _ in syncEnd() }
    }

    private let weekdayChoices: [(Int, String)] = [(2,"M"),(3,"T"),(4,"W"),(5,"T"),(6,"F"),(7,"S"),(1,"S")]
    private let reminderOptions: [(Int, String)] = [(0,"At time"),(5,"5m"),(15,"15m"),(30,"30m"),(60,"1h"),(120,"2h"),(1440,"1d")]

    private var selectedReminderOffsets: Set<Int> {
        var values = Set(task.additionalReminderMinutesBefore ?? [])
        if let primary = task.reminderMinutesBefore { values.insert(primary) }
        return values
    }

    private func toggleReminder(_ offset: Int) {
        var values = selectedReminderOffsets
        if values.contains(offset) { values.remove(offset) } else { values.insert(offset) }
        applyReminderOffsets(values)
    }

    private func addCustomReminder() {
        var values = selectedReminderOffsets
        values.insert(customAlertMinutes)
        applyReminderOffsets(values)
    }

    private func applyReminderOffsets(_ values: Set<Int>) {
        let sorted = values.sorted()
        task.reminderMinutesBefore = sorted.first
        task.additionalReminderMinutesBefore = sorted.count > 1 ? Array(sorted.dropFirst()) : nil
    }

    private func humanReminder(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes)m" }
        if minutes < 1440 && minutes % 60 == 0 { return "\(minutes / 60)h" }
        if minutes < 1440 { return "\(minutes / 60)h \(minutes % 60)m" }
        if minutes % 1440 == 0 { return "\(minutes / 1440)d" }
        return "\(minutes / 1440)d \((minutes % 1440) / 60)h"
    }

    private func toggleWeekday(_ weekday: Int) {
        var days = Set(task.recurrenceDays ?? [])
        if days.contains(weekday) { days.remove(weekday) } else { days.insert(weekday) }
        task.recurrenceDays = days.sorted()
    }

    private func recurrenceName(_ recurrence: TaskRecurrence) -> String {
        switch recurrence {
        case .none: return "Never"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom interval"
        }
    }

    private var basicReminderBinding: Binding<Int> {
        Binding(
            get: { task.reminderMinutesBefore ?? -1 },
            set: { value in
                task.reminderMinutesBefore = value < 0 ? nil : value
                task.additionalReminderMinutesBefore = nil
            }
        )
    }

    private var customRecurrenceInterval: Binding<Int> {
        Binding(get: { max(1, task.recurrenceInterval ?? 1) }, set: { task.recurrenceInterval = max(1, $0) })
    }

    private var customRecurrenceUnit: Binding<RecurrenceUnit> {
        Binding(get: { task.recurrenceUnit ?? .days }, set: { task.recurrenceUnit = $0 })
    }

    private var recurrenceUntilBinding: Binding<Date> {
        Binding(
            get: { task.recurrenceUntil.flatMap(DateKey.date) ?? Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now },
            set: { task.recurrenceUntil = DateKey.string($0) }
        )
    }

    private var allDayAlertTimeBinding: Binding<Date> {
        Binding(
            get: {
                let time = task.allDayAlertTime ?? "09:00"
                let parts = time.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2 else { return .now }
                return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: .now) ?? .now
            },
            set: { task.allDayAlertTime = timeString($0) }
        )
    }

    private func reorderSubtask(_ sourceID: String, before targetID: String) {
        guard sourceID != targetID, var subtasks = task.subtasks,
              let source = subtasks.firstIndex(where: { $0.id == sourceID }),
              let target = subtasks.firstIndex(where: { $0.id == targetID }) else { return }
        let item = subtasks.remove(at: source)
        let destination = min(target, subtasks.count)
        subtasks.insert(item, at: destination)
        task.subtasks = subtasks
    }

    @ViewBuilder
    private func shapeChoice(title: String, systemName: String, selected: Bool, action: @escaping () -> Void) -> some View {
        if selected {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: systemName).font(.title3.weight(.semibold))
                    Text(title).font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent)
        } else {
            Button(action: action) {
                VStack(spacing: 6) {
                    Image(systemName: systemName).font(.title3.weight(.semibold))
                    Text(title).font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.glass)
        }
    }

    private var resolvedIcon: String { IconEngine.symbol(for: task) }
    private var resolvedTint: Color {
        if task.customTintHue != nil { return TaskTint.resolve(task) }
        if task.color != nil { return TaskTint.resolve(task) }
        return TaskTint.resolve(PlannerTask(title: task.title, category: task.category, color: IconEngine.suggestedColor(for: task.title, category: task.category)))
    }

    private var presetColorBinding: Binding<TaskColor> {
        Binding(
            get: { task.color ?? IconEngine.suggestedColor(for: task.title, category: task.category) },
            set: {
                task.color = $0
                task.customTintHue = nil
                task.customTintSaturation = nil
                task.customTintLightness = nil
            }
        )
    }

    private var customTintEnabled: Binding<Bool> {
        Binding(
            get: { task.customTintHue != nil },
            set: { enabled in
                if enabled {
                    task.customTintHue = task.customTintHue ?? 350
                    task.customTintSaturation = task.customTintSaturation ?? 28
                    task.customTintLightness = task.customTintLightness ?? 54
                } else {
                    task.customTintHue = nil
                    task.customTintSaturation = nil
                    task.customTintLightness = nil
                }
            }
        )
    }

    private var tintHueBinding: Binding<Double> { Binding(get: { task.customTintHue ?? 350 }, set: { task.customTintHue = $0 }) }
    private var tintSaturationBinding: Binding<Double> { Binding(get: { task.customTintSaturation ?? 28 }, set: { task.customTintSaturation = $0 }) }
    private var tintLightnessBinding: Binding<Double> { Binding(get: { task.customTintLightness ?? 54 }, set: { task.customTintLightness = $0 }) }
    private var dateBinding: Binding<Date> { Binding(get: { DateKey.date(task.planDate) ?? .now }, set: { task.planDate = DateKey.string($0) }) }
    private var startBinding: Binding<Date> { Binding(get: { dateForTime(task.startTime) }, set: { task.startTime = timeString($0); syncEnd() }) }
    private var deadlineEnabledBinding: Binding<Bool> {
        Binding(
            get: { task.deadline != nil },
            set: { enabled in
                task.deadline = enabled ? (task.deadline ?? ISO8601DateFormatter().string(from: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now)) : nil
            }
        )
    }
    private var deadlineBinding: Binding<Date> { Binding(get: { task.deadline.flatMap(ISO8601DateFormatter().date) ?? Calendar.current.date(byAdding: .day, value: 1, to: .now)! }, set: { task.deadline = ISO8601DateFormatter().string(from: $0) }) }
    private func dateForTime(_ value: String?) -> Date { let m = TimeMath.minutes(value) ?? TimeMath.nowMinutes; return Calendar.current.date(bySettingHour: m/60, minute: m%60, second: 0, of: .now) ?? .now }
    private func timeString(_ date: Date) -> String { let c = Calendar.current.dateComponents([.hour,.minute], from: date); return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0) }
    private func syncEnd() { guard let start = TimeMath.minutes(task.startTime) else { return }; task.endTime = TimeMath.clockString(start + task.durationMinutes); task.section = start < 720 ? .morning : start < 1020 ? .day : start < 1320 ? .evening : .night }
    private func save() {
        syncEnd()
        var result = task
        result.title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.iconIsAutomatic == true || result.icon == nil {
            result.iconIsAutomatic = true
            result.icon = IconEngine.symbol(for: result.title, category: result.category)
        }
        if result.color == nil && result.customTintHue == nil { result.color = IconEngine.suggestedColor(for: result.title, category: result.category) }
        isNew ? store.addTask(result) : store.updateTask(result)
        dismiss()
    }
    private func generateSubtasks() { isGeneratingSubtasks = true; Task { let value = await store.generateSubtasks(for: task); await MainActor.run { task.subtasks = value; isGeneratingSubtasks = false } } }
}
