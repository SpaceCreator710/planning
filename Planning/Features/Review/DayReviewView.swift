import SwiftUI

struct DayReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var score = 50.0
    @State private var reviewDate = DateKey.today
    @State private var wins = ""
    @State private var blocker = ""
    @State private var lesson = ""
    @State private var mood = 3
    @State private var loaded = false
    var date: String? = nil

    var body: some View {
        Form {
            Section {
                Text((DateKey.date(reviewDate) ?? .now).formatted(date: .complete, time: .omitted))
                    .font(.headline)
                Text("How did this day feel?").foregroundStyle(.secondary)
            }
            Section("Your reflection") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Your rating")
                        Spacer()
                        Text("\(Int(score))%")
                            .bold()
                            .monospacedDigit()
                    }
                    Slider(value: $score, in: 0...100, step: 5)
                }
                Stepper("Energy · \(mood)/5", value: $mood, in: 1...5)
            }

            Section("Reflection") {
                TextField("Wins, one per line", text: $wins, axis: .vertical)
                    .lineLimit(2...6)
                TextField("Main blocker", text: $blocker, axis: .vertical)
                    .lineLimit(1...4)
                TextField("Lesson for tomorrow", text: $lesson, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Button("Save review", systemImage: "checkmark") { save() }
                    .buttonStyle(.glassProminent)
            }
        }
        .scrollContentBackground(.hidden)
        .appCanvas()
        .navigationTitle("Day Review")
        .task { loadExistingReview() }
    }

    private func loadExistingReview() {
        guard !loaded else { return }
        loaded = true
        reviewDate = date ?? store.selectedDate
        guard let review = store.data.reviews.last(where: { $0.date == reviewDate }) else { return }
        score = Double(review.score)
        wins = review.wins.joined(separator: "\n")
        blocker = review.blocker ?? ""
        lesson = review.lesson ?? ""
        mood = review.mood
    }

    private func save() {
        let review = DailyReview(
            date: reviewDate,
            score: Int(score),
            wins: wins.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            blocker: normalized(blocker),
            lesson: normalized(lesson),
            mood: mood
        )
        if let index = store.data.reviews.lastIndex(where: { $0.date == reviewDate }) {
            var updated = review
            updated.id = store.data.reviews[index].id
            store.data.reviews[index] = updated
        } else {
            store.data.reviews.append(review)
        }
        store.record("review-saved", reviewDate)
        store.persist()
        dismiss()
    }

    private func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
