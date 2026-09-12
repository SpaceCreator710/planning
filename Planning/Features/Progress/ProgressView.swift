import SwiftUI

struct ProgressViewScreen: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView { VStack(spacing: 16) {
            stats
            planDNACard
            VStack(alignment: .leading, spacing: 10) { SectionLabel("Achievements"); ForEach(store.data.achievements) { item in MatteCard { HStack { Image(systemName: item.icon).font(.title2); VStack(alignment: .leading) { Text(item.title).font(.headline); Text(item.description).font(.caption).foregroundStyle(.secondary); ProgressView(value: Double(item.progress), total: Double(max(1,item.target))) }; Spacer() } } } }
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Recent reviews")
                ForEach(store.data.reviews.sorted { $0.date > $1.date }.prefix(3)) { review in
                    NavigationLink { DayReviewView(date: review.date) } label: {
                        PlanningDestinationRow(title: (DateKey.date(review.date) ?? .now).formatted(date: .abbreviated, time: .omitted), subtitle: review.wins.first ?? "Open your reflection", symbol: "book.closed", detail: "Your rating · \(review.score)%")
                    }.buttonStyle(.plain)
                }
                NavigationLink { ReviewHistoryView() } label: {
                    Label("All reviews", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity, minHeight: 36)
                }.buttonStyle(.glass)
            }
        }.padding(16) }
        .appCanvas()
        .navigationTitle("Progress")
    }
    private var planDNACard: some View {
        let dna = InsightsEngine.planDNA(plans: store.data.plans)
        return MatteCard {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel("Plan DNA", subtitle: "\(dna.sampleSize) observed actions · \(dna.confidence)% confidence")
                if dna.sampleSize == 0 {
                    Text("Patterns appear as you plan and complete tasks. There is no personal estimate yet.").foregroundStyle(.secondary)
                } else {
                HStack { Text("Completion"); Spacer(); Text("\(dna.completionRate)%").bold().monospacedDigit() }
                HStack { Text("Ideal block"); Spacer(); Text("\(dna.idealBlockMinutes) min").bold().monospacedDigit() }
                if let window = dna.strongestWindow { HStack { Text("Strongest window"); Spacer(); Text(window.rawValue.capitalized).bold() } }
                if let category = dna.strongestCategory { HStack { Text("Strongest category"); Spacer(); Text(category.rawValue.capitalized).bold() } }
                Text(dna.experiment).font(.caption).foregroundStyle(.secondary).padding(.top, 2)
                }
            }
        }
    }

    private var stats: some View {
        let completed = store.data.plans.flatMap(\.tasks).filter { $0.status == .completed }.count
        let streak = store.data.habits.map(\.currentStreak).max() ?? 0
        return PlanningAdaptiveRow(spacing: 10) { stat("Done", "\(completed)", "checkmark.circle.fill"); stat("Streak", "\(streak)", "flame.fill"); stat("Reviews", "\(store.data.reviews.count)", "chart.bar.fill") }
    }
    private func stat(_ title: String, _ value: String, _ icon: String) -> some View { MatteCard { VStack(spacing: 5) { Image(systemName: icon); Text(value).font(.title2.bold()).monospacedDigit(); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) } }
}

private struct ReviewHistoryView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        List {
            if store.data.reviews.isEmpty {
                ContentUnavailableView("Your story starts here", systemImage: "book.closed", description: Text("Save a day review to start your reflection history."))
            }
            ForEach(store.data.reviews.sorted { $0.date > $1.date }) { review in
                NavigationLink { DayReviewView(date: review.date) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text((DateKey.date(review.date) ?? .now).formatted(date: .complete, time: .omitted)).font(.headline)
                        Text("Your rating · \(review.score)%").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
                }
            }
        }.scrollContentBackground(.hidden).appCanvas().navigationTitle("Review history")
    }
}
