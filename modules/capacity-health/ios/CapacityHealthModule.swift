import ExpoModulesCore
import HealthKit

public final class CapacityHealthModule: Module {
  private let healthStore = HKHealthStore()
  private let iso = ISO8601DateFormatter()

  public func definition() -> ModuleDefinition {
    Name("CapacityHealth")

    Function("isAvailable") {
      HKHealthStore.isHealthDataAvailable()
    }

    AsyncFunction("requestAuthorization") { () async throws -> Bool in
      guard HKHealthStore.isHealthDataAvailable() else { return false }
      try await self.healthStore.requestAuthorization(toShare: [], read: self.readTypes())
      return true
    }

    AsyncFunction("readSnapshot") { (startDate: String, endDate: String) async throws -> [String: Any] in
      guard HKHealthStore.isHealthDataAvailable() else {
        return self.emptySnapshot(startDate: startDate, endDate: endDate)
      }
      guard let start = self.iso.date(from: startDate), let end = self.iso.date(from: endDate) else {
        throw InvalidHealthDateException()
      }
      let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

      async let steps = self.sum(.stepCount, unit: .count(), predicate: predicate)
      async let exercise = self.sum(.appleExerciseTime, unit: .minute(), predicate: predicate)
      async let stand = self.sum(.appleStandTime, unit: .minute(), predicate: predicate)
      async let distance = self.sum(.distanceWalkingRunning, unit: .meter(), predicate: predicate)
      async let restingHeartRate = self.latest(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), predicate: predicate)
      async let sleep = self.sleepHours(predicate: predicate)
      async let workouts = self.workoutSummary(predicate: predicate)

      let workoutResult = try await workouts
      var result: [String: Any] = [
        "available": true,
        "startDate": startDate,
        "endDate": endDate,
        "sleepHours": try await sleep,
        "steps": Int((try await steps).rounded()),
        "exerciseMinutes": Int((try await exercise).rounded()),
        "standMinutes": Int((try await stand).rounded()),
        "distanceKilometers": (try await distance) / 1000.0,
        "workoutCount": workoutResult.count,
        "workoutMinutes": Int(workoutResult.minutes.rounded()),
        "lastUpdated": self.iso.string(from: Date())
      ]
      if let heartRate = try await restingHeartRate {
        result["restingHeartRate"] = Int(heartRate.rounded())
      }
      return result
    }
  }

  private func readTypes() -> Set<HKObjectType> {
    let identifiers: [HKQuantityTypeIdentifier] = [
      .stepCount,
      .appleExerciseTime,
      .appleStandTime,
      .distanceWalkingRunning,
      .restingHeartRate
    ]
    var types = Set<HKObjectType>(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
    if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
    types.insert(HKObjectType.workoutType())
    return types
  }

  private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async throws -> Double {
    guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return 0 }
    return try await withCheckedThrowingContinuation { continuation in
      let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
        if let error { continuation.resume(throwing: error); return }
        continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
      }
      self.healthStore.execute(query)
    }
  }

  private func latest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, predicate: NSPredicate) async throws -> Double? {
    guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
    return try await withCheckedThrowingContinuation { continuation in
      let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
      let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, error in
        if let error { continuation.resume(throwing: error); return }
        let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
        continuation.resume(returning: value)
      }
      self.healthStore.execute(query)
    }
  }

  private func sleepHours(predicate: NSPredicate) async throws -> Double {
    guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
    let intervals: [(Date, Date)] = try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
        if let error { continuation.resume(throwing: error); return }
        let asleepValues = Set([1, 3, 4, 5])
        let values = (samples as? [HKCategorySample] ?? [])
          .filter { asleepValues.contains($0.value) }
          .map { ($0.startDate, $0.endDate) }
        continuation.resume(returning: values)
      }
      self.healthStore.execute(query)
    }
    let ordered = intervals.sorted { $0.0 < $1.0 }
    var merged: [(Date, Date)] = []
    for interval in ordered {
      if let last = merged.last, interval.0 <= last.1 {
        merged[merged.count - 1] = (last.0, max(last.1, interval.1))
      } else {
        merged.append(interval)
      }
    }
    return merged.reduce(0) { $0 + $1.1.timeIntervalSince($1.0) } / 3600.0
  }

  private func workoutSummary(predicate: NSPredicate) async throws -> (count: Int, minutes: Double) {
    try await withCheckedThrowingContinuation { continuation in
      let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
        if let error { continuation.resume(throwing: error); return }
        let workouts = samples as? [HKWorkout] ?? []
        continuation.resume(returning: (workouts.count, workouts.reduce(0) { $0 + $1.duration } / 60.0))
      }
      self.healthStore.execute(query)
    }
  }

  private func emptySnapshot(startDate: String, endDate: String) -> [String: Any] {
    [
      "available": false,
      "startDate": startDate,
      "endDate": endDate,
      "sleepHours": 0,
      "steps": 0,
      "exerciseMinutes": 0,
      "standMinutes": 0,
      "distanceKilometers": 0,
      "workoutCount": 0,
      "workoutMinutes": 0,
      "lastUpdated": iso.string(from: Date())
    ]
  }
}

private final class InvalidHealthDateException: Exception {
  override var reason: String { "Health date range must use ISO 8601." }
}
