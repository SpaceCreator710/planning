import SwiftUI
import WidgetKit

@main
struct PlanningWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PlannerWidget()
        TimelineOverviewWidget()
        InboxOverviewWidget()
        CurrentTaskWidget()
        FocusLiveActivity()
        StartFocusControl()
        QuickCaptureControl()
        NewTaskControl()
        NewRecurringTaskControl()
        CompleteNextControl()
        OpenTodayControl()
        RealityReplanControl()
        OpenCoachControl()
    }
}
