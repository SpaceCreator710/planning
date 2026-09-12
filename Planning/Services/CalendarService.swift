@preconcurrency import EventKit
import Foundation

actor CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()

    func requestCalendarAccess() async -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess { return true }
        if status == .denied || status == .restricted { return false }

        return await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func calendarTasks(from start: Date, to end: Date) -> [PlannerTask]? {
        // Missing permission is not an empty calendar and must never delete cached events.
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            let occurrenceID = "\(event.eventIdentifier ?? event.calendarItemIdentifier)-\(Int(event.startDate.timeIntervalSince1970))"
            let date = DateKey.string(event.startDate)
            let start = event.isAllDay ? nil : Self.hhmm(event.startDate)
            let finish = event.isAllDay ? nil : Self.hhmm(event.endDate)
            return PlannerTask(
                id: "calendar-\(occurrenceID)", title: event.title ?? "Calendar event", note: event.notes,
                startTime: start, endTime: finish, durationMinutes: max(5, Int(event.endDate.timeIntervalSince(event.startDate) / 60)),
                section: Self.section(for: event.startDate), category: .work, status: .pending, priority: 2, planDate: date, source: .calendar,
                recurrence: TaskRecurrence.none, color: .indigo, icon: "calendar", allDay: event.isAllDay, externalSource: .calendar,
                externalId: occurrenceID, externalCalendarName: event.calendar.title,
                externalImportance: event.availability == .busy ? .important : .standard,
                externalLastModified: event.lastModifiedDate.map { ISO8601DateFormatter().string(from: $0) }, shape: .rounded
            )
        }
    }

    private static func hhmm(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func section(for date: Date) -> DaySection {
        let hour = Calendar.current.component(.hour, from: date)
        return hour < 12 ? .morning : hour < 17 ? .day : hour < 22 ? .evening : .night
    }
}
