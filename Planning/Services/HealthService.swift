import Foundation
@preconcurrency import HealthKit

extension Notification.Name {
    static let planningHealthDataDidChange = Notification.Name("planning.health-data-did-change")
}

actor HealthService {
    static let shared = HealthService()

    private let store = HKHealthStore()
    private var observerQueries: [HKObserverQuery] = []
    private var backgroundDeliveryStarted = false
    private var deliveryGeneration = 0

    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    private enum Aggregation: Sendable {
        case cumulativeDay
        case averageDay
        case latest
    }

    private struct QuantityDescriptor: Sendable {
        let rawIdentifier: String
        let title: String
        let section: HealthDataSection
        let symbol: String
        let unitName: String
        let displayUnit: String
        let precision: Int
        let multiplier: Double
        let aggregation: Aggregation
    }

    private struct CategoryDescriptor: Sendable {
        let rawIdentifier: String
        let title: String
        let section: HealthDataSection
        let symbol: String
        let durationUnit: String?
    }

    // Raw-value construction gracefully skips a type when a particular device or region does
    // not expose it, while keeping one broad HealthKit catalog for iPhone and Apple Watch.
    private static let quantityDescriptors: [QuantityDescriptor] = [
        .init(rawIdentifier: "HKQuantityTypeIdentifierStepCount", title: "Steps", section: .activity, symbol: "figure.walk", unitName: "count", displayUnit: "steps", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDistanceWalkingRunning", title: "Walking + Running Distance", section: .activity, symbol: "map.fill", unitName: "m", displayUnit: "km", precision: 2, multiplier: 0.001, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierFlightsClimbed", title: "Flights Climbed", section: .activity, symbol: "figure.stairs", unitName: "count", displayUnit: "flights", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierAppleExerciseTime", title: "Exercise", section: .activity, symbol: "figure.run", unitName: "min", displayUnit: "min", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierAppleStandTime", title: "Stand Time", section: .activity, symbol: "figure.stand", unitName: "min", displayUnit: "min", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDistanceCycling", title: "Cycling Distance", section: .activity, symbol: "figure.outdoor.cycle", unitName: "m", displayUnit: "km", precision: 2, multiplier: 0.001, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDistanceWheelchair", title: "Wheelchair Distance", section: .activity, symbol: "figure.roll", unitName: "m", displayUnit: "km", precision: 2, multiplier: 0.001, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierPushCount", title: "Wheelchair Pushes", section: .activity, symbol: "figure.roll", unitName: "count", displayUnit: "pushes", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDistanceSwimming", title: "Swimming Distance", section: .activity, symbol: "figure.pool.swim", unitName: "m", displayUnit: "km", precision: 2, multiplier: 0.001, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierSwimmingStrokeCount", title: "Swimming Strokes", section: .activity, symbol: "figure.pool.swim", unitName: "count", displayUnit: "strokes", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDistanceDownhillSnowSports", title: "Downhill Snow Distance", section: .activity, symbol: "figure.skiing.downhill", unitName: "m", displayUnit: "km", precision: 2, multiplier: 0.001, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierRunningSpeed", title: "Running Speed", section: .activity, symbol: "figure.run", unitName: "m/s", displayUnit: "m/s", precision: 2, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierRunningPower", title: "Running Power", section: .activity, symbol: "bolt.fill", unitName: "W", displayUnit: "W", precision: 0, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierRunningStrideLength", title: "Running Stride Length", section: .activity, symbol: "ruler", unitName: "m", displayUnit: "cm", precision: 0, multiplier: 100, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierRunningGroundContactTime", title: "Ground Contact Time", section: .activity, symbol: "timer", unitName: "s", displayUnit: "ms", precision: 0, multiplier: 1_000, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierRunningVerticalOscillation", title: "Vertical Oscillation", section: .activity, symbol: "arrow.up.and.down", unitName: "m", displayUnit: "cm", precision: 1, multiplier: 100, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierCyclingCadence", title: "Cycling Cadence", section: .activity, symbol: "figure.outdoor.cycle", unitName: "count/min", displayUnit: "rpm", precision: 0, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierCyclingPower", title: "Cycling Power", section: .activity, symbol: "bolt.fill", unitName: "W", displayUnit: "W", precision: 0, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierCyclingSpeed", title: "Cycling Speed", section: .activity, symbol: "speedometer", unitName: "m/s", displayUnit: "m/s", precision: 2, multiplier: 1, aggregation: .averageDay),

        .init(rawIdentifier: "HKQuantityTypeIdentifierBodyMass", title: "Body Mass", section: .body, symbol: "scalemass.fill", unitName: "kg", displayUnit: "kg", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierHeight", title: "Height", section: .body, symbol: "ruler.fill", unitName: "m", displayUnit: "cm", precision: 0, multiplier: 100, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierBodyMassIndex", title: "Body Mass Index", section: .body, symbol: "number", unitName: "count", displayUnit: "", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierBodyFatPercentage", title: "Body Fat Percentage", section: .body, symbol: "percent", unitName: "%", displayUnit: "%", precision: 1, multiplier: 100, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierLeanBodyMass", title: "Lean Body Mass", section: .body, symbol: "figure.strengthtraining.traditional", unitName: "kg", displayUnit: "kg", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierWaistCircumference", title: "Waist Circumference", section: .body, symbol: "lines.measurement.horizontal", unitName: "m", displayUnit: "cm", precision: 0, multiplier: 100, aggregation: .latest),

        .init(rawIdentifier: "HKQuantityTypeIdentifierHeartRate", title: "Heart Rate", section: .heart, symbol: "heart.fill", unitName: "count/min", displayUnit: "bpm", precision: 0, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierRestingHeartRate", title: "Resting Heart Rate", section: .heart, symbol: "heart.circle.fill", unitName: "count/min", displayUnit: "bpm", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierWalkingHeartRateAverage", title: "Walking Heart Rate", section: .heart, symbol: "figure.walk.circle.fill", unitName: "count/min", displayUnit: "bpm", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN", title: "Heart Rate Variability", section: .heart, symbol: "waveform.path.ecg", unitName: "s", displayUnit: "ms", precision: 0, multiplier: 1_000, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierHeartRateRecoveryOneMinute", title: "Cardio Recovery", section: .heart, symbol: "heart.text.square.fill", unitName: "count/min", displayUnit: "bpm", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierAtrialFibrillationBurden", title: "AFib History", section: .heart, symbol: "waveform.path.ecg.rectangle", unitName: "%", displayUnit: "%", precision: 1, multiplier: 100, aggregation: .latest),

        .init(rawIdentifier: "HKQuantityTypeIdentifierWalkingSpeed", title: "Walking Speed", section: .mobility, symbol: "figure.walk.motion", unitName: "m/s", displayUnit: "m/s", precision: 2, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierWalkingStepLength", title: "Step Length", section: .mobility, symbol: "ruler", unitName: "m", displayUnit: "cm", precision: 0, multiplier: 100, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierWalkingAsymmetryPercentage", title: "Walking Asymmetry", section: .mobility, symbol: "figure.walk.diamond.fill", unitName: "%", displayUnit: "%", precision: 1, multiplier: 100, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierWalkingDoubleSupportPercentage", title: "Double Support Time", section: .mobility, symbol: "figure.walk", unitName: "%", displayUnit: "%", precision: 1, multiplier: 100, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierStairAscentSpeed", title: "Stair Ascent Speed", section: .mobility, symbol: "figure.stairs", unitName: "m/s", displayUnit: "m/s", precision: 2, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierStairDescentSpeed", title: "Stair Descent Speed", section: .mobility, symbol: "figure.stairs", unitName: "m/s", displayUnit: "m/s", precision: 2, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierSixMinuteWalkTestDistance", title: "Six-Minute Walk Distance", section: .mobility, symbol: "figure.walk", unitName: "m", displayUnit: "m", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierNumberOfTimesFallen", title: "Falls", section: .mobility, symbol: "figure.fall", unitName: "count", displayUnit: "records", precision: 0, multiplier: 1, aggregation: .cumulativeDay),

        .init(rawIdentifier: "HKQuantityTypeIdentifierRespiratoryRate", title: "Respiratory Rate", section: .respiratory, symbol: "lungs.fill", unitName: "count/min", displayUnit: "breaths/min", precision: 1, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierOxygenSaturation", title: "Blood Oxygen", section: .respiratory, symbol: "lungs.fill", unitName: "%", displayUnit: "%", precision: 1, multiplier: 100, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierVO2Max", title: "Cardio Fitness", section: .respiratory, symbol: "heart.circle.fill", unitName: "ml/kg*min", displayUnit: "mL/kg/min", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierPeakExpiratoryFlowRate", title: "Peak Expiratory Flow", section: .respiratory, symbol: "wind", unitName: "L/min", displayUnit: "L/min", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierForcedVitalCapacity", title: "Forced Vital Capacity", section: .respiratory, symbol: "lungs", unitName: "L", displayUnit: "L", precision: 2, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierForcedExpiratoryVolume1", title: "FEV1", section: .respiratory, symbol: "lungs", unitName: "L", displayUnit: "L", precision: 2, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierInhalerUsage", title: "Inhaler Usage", section: .respiratory, symbol: "lungs.circle.fill", unitName: "count", displayUnit: "uses", precision: 0, multiplier: 1, aggregation: .cumulativeDay),

        .init(rawIdentifier: "HKQuantityTypeIdentifierBodyTemperature", title: "Body Temperature", section: .vitals, symbol: "thermometer.medium", unitName: "degC", displayUnit: "°C", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierBasalBodyTemperature", title: "Basal Body Temperature", section: .vitals, symbol: "thermometer.low", unitName: "degC", displayUnit: "°C", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierBloodPressureSystolic", title: "Blood Pressure Systolic", section: .vitals, symbol: "heart.text.square", unitName: "mmHg", displayUnit: "mmHg", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierBloodPressureDiastolic", title: "Blood Pressure Diastolic", section: .vitals, symbol: "heart.text.square", unitName: "mmHg", displayUnit: "mmHg", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierBloodGlucose", title: "Blood Glucose", section: .vitals, symbol: "drop.fill", unitName: "mg/dL", displayUnit: "mg/dL", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierPeripheralPerfusionIndex", title: "Peripheral Perfusion Index", section: .vitals, symbol: "waveform.path.ecg", unitName: "%", displayUnit: "%", precision: 1, multiplier: 100, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierInsulinDelivery", title: "Insulin Delivery", section: .vitals, symbol: "cross.vial.fill", unitName: "IU", displayUnit: "IU", precision: 1, multiplier: 1, aggregation: .cumulativeDay),

        .init(rawIdentifier: "HKQuantityTypeIdentifierEnvironmentalAudioExposure", title: "Environmental Sound Levels", section: .hearing, symbol: "ear.badge.waveform", unitName: "dBASPL", displayUnit: "dB", precision: 0, multiplier: 1, aggregation: .averageDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierHeadphoneAudioExposure", title: "Headphone Audio Levels", section: .hearing, symbol: "headphones", unitName: "dBASPL", displayUnit: "dB", precision: 0, multiplier: 1, aggregation: .averageDay),

        .init(rawIdentifier: "HKQuantityTypeIdentifierDietaryWater", title: "Water", section: .nutrition, symbol: "drop.fill", unitName: "L", displayUnit: "L", precision: 2, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDietaryFiber", title: "Fiber", section: .nutrition, symbol: "carrot.fill", unitName: "g", displayUnit: "g", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDietarySodium", title: "Sodium", section: .nutrition, symbol: "circle.grid.cross.fill", unitName: "g", displayUnit: "g", precision: 1, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierDietaryCaffeine", title: "Caffeine", section: .nutrition, symbol: "cup.and.saucer.fill", unitName: "g", displayUnit: "mg", precision: 0, multiplier: 1_000, aggregation: .cumulativeDay),

        .init(rawIdentifier: "HKQuantityTypeIdentifierTimeInDaylight", title: "Time in Daylight", section: .other, symbol: "sun.max.fill", unitName: "min", displayUnit: "min", precision: 0, multiplier: 1, aggregation: .cumulativeDay),
        .init(rawIdentifier: "HKQuantityTypeIdentifierUVExposure", title: "UV Exposure", section: .other, symbol: "sun.max.trianglebadge.exclamationmark", unitName: "count", displayUnit: "index", precision: 0, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierUnderwaterDepth", title: "Underwater Depth", section: .other, symbol: "water.waves", unitName: "m", displayUnit: "m", precision: 1, multiplier: 1, aggregation: .latest),
        .init(rawIdentifier: "HKQuantityTypeIdentifierWaterTemperature", title: "Water Temperature", section: .other, symbol: "thermometer.medium", unitName: "degC", displayUnit: "°C", precision: 1, multiplier: 1, aggregation: .latest)
    ]

    private static let categoryDescriptors: [CategoryDescriptor] = [
        .init(rawIdentifier: "HKCategoryTypeIdentifierSleepAnalysis", title: "Sleep", section: .sleep, symbol: "bed.double.fill", durationUnit: "h"),
        .init(rawIdentifier: "HKCategoryTypeIdentifierMindfulSession", title: "Mindful Minutes", section: .mindfulness, symbol: "brain.head.profile", durationUnit: "min"),
        .init(rawIdentifier: "HKCategoryTypeIdentifierAppleStandHour", title: "Stand Hours", section: .activity, symbol: "figure.stand", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHighHeartRateEvent", title: "High Heart Rate Events", section: .heart, symbol: "heart.circle", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierLowHeartRateEvent", title: "Low Heart Rate Events", section: .heart, symbol: "heart.circle", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierIrregularHeartRhythmEvent", title: "Irregular Rhythm Events", section: .heart, symbol: "waveform.path.ecg", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierLowCardioFitnessEvent", title: "Cardio Fitness Notifications", section: .respiratory, symbol: "heart.circle", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierAppleWalkingSteadinessEvent", title: "Walking Steadiness Notifications", section: .mobility, symbol: "figure.walk.motion", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierEnvironmentalAudioExposureEvent", title: "Environmental Sound Notifications", section: .hearing, symbol: "ear.badge.waveform", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHeadphoneAudioExposureEvent", title: "Headphone Sound Notifications", section: .hearing, symbol: "headphones", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierMenstrualFlow", title: "Menstrual Flow", section: .cycle, symbol: "drop.circle.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierIntermenstrualBleeding", title: "Spotting", section: .cycle, symbol: "drop.circle", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierCervicalMucusQuality", title: "Cervical Mucus Quality", section: .cycle, symbol: "circle.hexagonpath", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierOvulationTestResult", title: "Ovulation Test Result", section: .cycle, symbol: "testtube.2", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierPregnancyTestResult", title: "Pregnancy Test Result", section: .cycle, symbol: "testtube.2", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierProgesteroneTestResult", title: "Progesterone Test Result", section: .cycle, symbol: "testtube.2", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierPersistentIntermenstrualBleeding", title: "Persistent Spotting", section: .cycle, symbol: "drop.circle", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierAbdominalCramps", title: "Abdominal Cramps", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierBloating", title: "Bloating", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierConstipation", title: "Constipation", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierDiarrhea", title: "Diarrhea", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierDizziness", title: "Dizziness", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierFatigue", title: "Fatigue", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierFever", title: "Fever", section: .symptoms, symbol: "thermometer.high", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHeadache", title: "Headache", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHeartburn", title: "Heartburn", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierNausea", title: "Nausea", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierShortnessOfBreath", title: "Shortness of Breath", section: .symptoms, symbol: "lungs.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierSoreThroat", title: "Sore Throat", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierCoughing", title: "Coughing", section: .symptoms, symbol: "lungs.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierWheezing", title: "Wheezing", section: .symptoms, symbol: "lungs.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierChestTightnessOrPain", title: "Chest Tightness", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierChills", title: "Chills", section: .symptoms, symbol: "snowflake", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierSleepChanges", title: "Sleep Changes", section: .symptoms, symbol: "bed.double.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierMoodChanges", title: "Mood Changes", section: .symptoms, symbol: "brain.head.profile", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierAcne", title: "Acne", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierAppetiteChanges", title: "Appetite Changes", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierBladderIncontinence", title: "Bladder Incontinence", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierBreastPain", title: "Breast Pain", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierDrySkin", title: "Dry Skin", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierFainting", title: "Fainting", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierGeneralizedBodyAche", title: "Body Ache", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHairLoss", title: "Hair Loss", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHotFlashes", title: "Hot Flashes", section: .symptoms, symbol: "thermometer.high", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierLossOfSmell", title: "Loss of Smell", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierLossOfTaste", title: "Loss of Taste", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierLowerBackPain", title: "Lower Back Pain", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierMemoryLapse", title: "Memory Lapse", section: .symptoms, symbol: "brain.head.profile", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierRapidPoundingOrFlutteringHeartbeat", title: "Rapid Heartbeat", section: .symptoms, symbol: "heart.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierRunnyNose", title: "Runny Nose", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierSinusCongestion", title: "Sinus Congestion", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierSkippedHeartbeat", title: "Skipped Heartbeat", section: .symptoms, symbol: "heart.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierVomiting", title: "Vomiting", section: .symptoms, symbol: "cross.case.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierToothbrushingEvent", title: "Toothbrushing", section: .other, symbol: "mouth.fill", durationUnit: nil),
        .init(rawIdentifier: "HKCategoryTypeIdentifierHandwashingEvent", title: "Handwashing", section: .other, symbol: "hands.and.sparkles.fill", durationUnit: nil)
    ]

    static var catalog: [HealthMetricSnapshot] {
        quantityDescriptors.map {
            HealthMetricSnapshot(id: $0.rawIdentifier, title: $0.title, section: $0.section, symbol: $0.symbol, value: nil, unit: $0.displayUnit, precision: $0.precision)
        } + categoryDescriptors.map {
            HealthMetricSnapshot(id: $0.rawIdentifier, title: $0.title, section: $0.section, symbol: $0.symbol, value: nil, unit: $0.durationUnit ?? "records", precision: $0.durationUnit == "h" ? 1 : 0)
        } + [
            HealthMetricSnapshot(id: "state-of-mind", title: "State of Mind", section: .mindfulness, symbol: "face.smiling", value: nil, unit: "records"),
            HealthMetricSnapshot(id: "medication-dose-events", title: "Medication Dose Events", section: .medications, symbol: "pills.fill", value: nil, unit: "records")
        ]
    }

    func requestReadAccess() async -> Bool {
        guard available else { return false }
        let types = allReadableTypes()
        guard !types.isEmpty else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: types)
            await startBackgroundDelivery()
            return true
        } catch {
            return false
        }
    }

    func snapshot(for date: Date = .now) async -> HealthSnapshot {
        guard available else { return HealthSnapshot() }
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? date

        async let metrics = metricSnapshots(dayStart: start, dayEnd: end)
        async let rings = activityRings(for: date)
        async let workouts = workoutSummaries(endingAt: end)
        let resolvedMetrics = await metrics
        let resolvedRings = await rings
        let resolvedWorkouts = await workouts

        let metricValue: (String) -> Double = { id in
            resolvedMetrics.first(where: { $0.id == id })?.value ?? 0
        }
        let todayKey = DateKey.string(start)
        let todayWorkouts = resolvedWorkouts.filter {
            guard let startedAt = ISO8601DateFormatter().date(from: $0.startedAt) else { return false }
            return Calendar.current.isDate(startedAt, inSameDayAs: date)
        }

        return HealthSnapshot(
            available: true,
            startDate: todayKey,
            endDate: DateKey.string(end),
            sleepHours: metricValue("HKCategoryTypeIdentifierSleepAnalysis"),
            steps: Int(metricValue("HKQuantityTypeIdentifierStepCount").rounded()),
            exerciseMinutes: Int(metricValue("HKQuantityTypeIdentifierAppleExerciseTime").rounded()),
            standMinutes: Int(metricValue("HKQuantityTypeIdentifierAppleStandTime").rounded()),
            distanceKilometers: metricValue("HKQuantityTypeIdentifierDistanceWalkingRunning"),
            restingHeartRate: resolvedMetrics.first(where: { $0.id == "HKQuantityTypeIdentifierRestingHeartRate" })?.value,
            workoutCount: todayWorkouts.count,
            workoutMinutes: todayWorkouts.reduce(0) { $0 + $1.durationMinutes },
            lastUpdated: ISO8601DateFormatter().string(from: .now),
            metrics: resolvedMetrics,
            fitnessRings: resolvedRings,
            recentWorkouts: resolvedWorkouts
        )
    }

    func startBackgroundDelivery() async {
        guard available, !backgroundDeliveryStarted else { return }
        deliveryGeneration += 1
        let generation = deliveryGeneration
        backgroundDeliveryStarted = true
        for type in allReadableTypes().compactMap({ $0 as? HKSampleType }) {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in
                    continuation.resume()
                }
            }
            guard backgroundDeliveryStarted, generation == deliveryGeneration else { return }
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, _ in
                NotificationCenter.default.post(name: .planningHealthDataDidChange, object: nil)
                completion()
            }
            observerQueries.append(query)
            store.execute(query)
        }
    }

    func stopBackgroundDelivery() async {
        deliveryGeneration += 1
        guard backgroundDeliveryStarted else { return }
        for query in observerQueries { store.stop(query) }
        observerQueries.removeAll()
        backgroundDeliveryStarted = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.disableAllBackgroundDelivery { _, _ in continuation.resume() }
        }
    }

    private func allReadableTypes() -> Set<HKObjectType> {
        var result = Set<HKObjectType>()
        for descriptor in Self.quantityDescriptors {
            let identifier = HKQuantityTypeIdentifier(rawValue: descriptor.rawIdentifier)
            if let type = HKObjectType.quantityType(forIdentifier: identifier) { result.insert(type) }
        }
        for descriptor in Self.categoryDescriptors {
            let identifier = HKCategoryTypeIdentifier(rawValue: descriptor.rawIdentifier)
            if let type = HKObjectType.categoryType(forIdentifier: identifier) { result.insert(type) }
        }
        result.insert(HKObjectType.workoutType())
        result.insert(HKObjectType.activitySummaryType())
        result.insert(HKObjectType.stateOfMindType())
        return result
    }

    private func metricSnapshots(dayStart: Date, dayEnd: Date) async -> [HealthMetricSnapshot] {
        var result: [HealthMetricSnapshot] = []
        for descriptor in Self.quantityDescriptors {
            result.append(await quantitySnapshot(descriptor, dayStart: dayStart, dayEnd: dayEnd))
        }
        for descriptor in Self.categoryDescriptors {
            result.append(await categorySnapshot(descriptor, dayStart: dayStart, dayEnd: dayEnd))
        }
        result.append(await countSnapshot(type: HKObjectType.stateOfMindType(), id: "state-of-mind", title: "State of Mind", section: .mindfulness, symbol: "face.smiling", start: dayStart, end: dayEnd))
        // Medication access is per-object and is requested separately by the Health screen.
        result.append(await countSnapshot(type: HKObjectType.medicationDoseEventType(), id: "medication-dose-events", title: "Medication Dose Events", section: .medications, symbol: "pills.fill", start: dayStart, end: dayEnd))
        return result
    }

    private func countSnapshot(type: HKSampleType, id: String, title: String, section: HealthDataSection, symbol: String, start: Date, end: Date) async -> HealthMetricSnapshot {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let records = samples ?? []
                continuation.resume(returning: HealthMetricSnapshot(id: id, title: title, section: section, symbol: symbol, value: records.isEmpty ? nil : Double(records.count), unit: "records", recordedAt: records.max(by: { $0.endDate < $1.endDate }).map { ISO8601DateFormatter().string(from: $0.endDate) }))
            }
            store.execute(query)
        }
    }

    private func quantitySnapshot(_ descriptor: QuantityDescriptor, dayStart: Date, dayEnd: Date) async -> HealthMetricSnapshot {
        let identifier = HKQuantityTypeIdentifier(rawValue: descriptor.rawIdentifier)
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return Self.emptyMetric(descriptor)
        }
        let unit = Self.unit(named: descriptor.unitName)
        let raw: (Double?, Date?)
        switch descriptor.aggregation {
        case .cumulativeDay:
            raw = (await statistics(type: type, unit: unit, start: dayStart, end: dayEnd, option: .cumulativeSum), nil)
        case .averageDay:
            raw = (await statistics(type: type, unit: unit, start: dayStart, end: dayEnd, option: .discreteAverage), nil)
        case .latest:
            raw = await latest(type: type, unit: unit, start: .distantPast, end: dayEnd)
        }
        return HealthMetricSnapshot(
            id: descriptor.rawIdentifier,
            title: descriptor.title,
            section: descriptor.section,
            symbol: descriptor.symbol,
            value: raw.0.map { $0 * descriptor.multiplier },
            unit: descriptor.displayUnit,
            precision: descriptor.precision,
            recordedAt: raw.1.map { ISO8601DateFormatter().string(from: $0) }
        )
    }

    private func categorySnapshot(_ descriptor: CategoryDescriptor, dayStart: Date, dayEnd: Date) async -> HealthMetricSnapshot {
        let identifier = HKCategoryTypeIdentifier(rawValue: descriptor.rawIdentifier)
        guard let type = HKObjectType.categoryType(forIdentifier: identifier) else {
            return HealthMetricSnapshot(id: descriptor.rawIdentifier, title: descriptor.title, section: descriptor.section, symbol: descriptor.symbol, value: nil, unit: descriptor.durationUnit ?? "records")
        }
        let start = descriptor.section == .sleep
            ? Calendar.current.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
            : descriptor.durationUnit != nil || descriptor.section == .activity ? dayStart
            : Calendar.current.date(byAdding: .day, value: -30, to: dayEnd) ?? dayStart
        let samples = await categorySamples(type: type, start: start, end: dayEnd)
        let value: Double?
        if descriptor.rawIdentifier == "HKCategoryTypeIdentifierSleepAnalysis" {
            let asleep = Set([HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue])
            // Exclude awake/in-bed samples and merge overlaps from multiple recording sources.
            let intervals = samples.filter { asleep.contains($0.value) && $0.endDate > dayStart && $0.endDate <= dayEnd }
                .map { (max(start, $0.startDate), min(dayEnd, $0.endDate)) }
            value = samples.isEmpty ? nil : TimeIntervals.totalDuration(intervals) / 3_600
        } else if descriptor.durationUnit == "min" {
            value = samples.isEmpty ? nil : TimeIntervals.totalDuration(samples.map { (max(start, $0.startDate), min(dayEnd, $0.endDate)) }) / 60
        } else {
            value = samples.isEmpty ? nil : Double(samples.count)
        }
        return HealthMetricSnapshot(
            id: descriptor.rawIdentifier,
            title: descriptor.title,
            section: descriptor.section,
            symbol: descriptor.symbol,
            value: value,
            unit: descriptor.durationUnit ?? "records",
            precision: descriptor.durationUnit == "h" ? 1 : 0,
            recordedAt: samples.max(by: { $0.endDate < $1.endDate }).map { ISO8601DateFormatter().string(from: $0.endDate) }
        )
    }

    private static func emptyMetric(_ descriptor: QuantityDescriptor) -> HealthMetricSnapshot {
        HealthMetricSnapshot(id: descriptor.rawIdentifier, title: descriptor.title, section: descriptor.section, symbol: descriptor.symbol, value: nil, unit: descriptor.displayUnit, precision: descriptor.precision)
    }

    private static func unit(named name: String) -> HKUnit {
        switch name {
        case "count": return .count()
        case "min": return .minute()
        case "s": return .second()
        case "m": return .meter()
        case "m/s": return .meter().unitDivided(by: .second())
        case "kg": return .gramUnit(with: .kilo)
        case "g": return .gram()
        case "L": return .liter()
        case "L/min": return .liter().unitDivided(by: .minute())
        case "count/min": return .count().unitDivided(by: .minute())
        case "%": return .percent()
        case "degC": return .degreeCelsius()
        case "mmHg": return .millimeterOfMercury()
        case "IU": return .internationalUnit()
        case "mg/dL": return .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        case "dBASPL": return .decibelAWeightedSoundPressureLevel()
        case "ml/kg*min":
            return .literUnit(with: .milli)
                .unitDivided(by: .gramUnit(with: .kilo).unitMultiplied(by: .minute()))
        default: return HKUnit(from: name)
        }
    }

    private func statistics(type: HKQuantityType, unit: HKUnit, start: Date, end: Date, option: HKStatisticsOptions) async -> Double? {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: option) { _, result, _ in
                let quantity = option.contains(.cumulativeSum) ? result?.sumQuantity() : result?.averageQuantity()
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func latest(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> (Double?, Date?) {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: (nil, nil))
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            store.execute(query)
        }
    }

    private func categorySamples(type: HKCategoryType, start: Date, end: Date) async -> [HKCategorySample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }
    }

    private func activityRings(for date: Date) async -> FitnessRingSnapshot? {
        var components = Calendar.current.dateComponents([.era, .year, .month, .day], from: date)
        components.calendar = Calendar.current
        let predicate = HKQuery.predicateForActivitySummary(with: components)
        return await withCheckedContinuation { continuation in
            let query = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
                guard let summary = summaries?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let move = summary.activeEnergyBurned.doubleValue(for: .kilocalorie())
                let moveGoal = summary.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
                let exercise = summary.appleExerciseTime.doubleValue(for: .minute())
                let exerciseGoal = summary.appleExerciseTimeGoal.doubleValue(for: .minute())
                let stand = summary.appleStandHours.doubleValue(for: .count())
                let standGoal = summary.appleStandHoursGoal.doubleValue(for: .count())
                continuation.resume(returning: FitnessRingSnapshot(
                    moveProgress: moveGoal > 0 ? move / moveGoal : 0,
                    exerciseProgress: exerciseGoal > 0 ? exercise / exerciseGoal : 0,
                    standProgress: standGoal > 0 ? stand / standGoal : 0
                ))
            }
            store.execute(query)
        }
    }

    private func workoutSummaries(endingAt end: Date) async -> [HealthWorkoutSummary] {
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        return await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 40, sortDescriptors: [sort]) { _, samples, _ in
                let workouts = (samples as? [HKWorkout] ?? []).map { workout in
                    HealthWorkoutSummary(
                        id: workout.uuid.uuidString,
                        title: Self.workoutName(workout.workoutActivityType),
                        symbol: Self.workoutSymbol(workout.workoutActivityType),
                        startedAt: ISO8601DateFormatter().string(from: workout.startDate),
                        durationMinutes: max(1, Int((workout.duration / 60).rounded())),
                        distanceKilometers: workout.totalDistance.map { $0.doubleValue(for: .meter()) / 1_000 }
                    )
                }
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    private static func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .dance: return "Dance"
        case .soccer: return "Football"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .hiking: return "Hiking"
        case .coreTraining: return "Core Training"
        case .mindAndBody: return "Mind & Body"
        default: return "Workout"
        }
    }

    private static func workoutSymbol(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
        case .yoga, .mindAndBody: return "figure.yoga"
        case .dance: return "figure.dance"
        case .soccer: return "figure.soccer"
        case .basketball: return "figure.basketball"
        case .tennis: return "figure.tennis"
        case .hiking: return "figure.hiking"
        default: return "figure.mixed.cardio"
        }
    }
}
