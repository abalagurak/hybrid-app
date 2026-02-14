import SwiftUI
import Charts
import CoreLocation
import MapKit
import UIKit

private extension Color {
    static let appAccent = Color(red: 0.8, green: 48.0 / 255.0, blue: 0.0)
}

private enum AppTextRole {
    case hero
    case title
    case headline
    case body
    case caption
    case button
}

private enum AppTypography {
    private static let regularNames = [
        "DieGrotesk-Regular",
        "Die Grotesk Regular",
        "DieGrotesk",
        "Die Grotesk"
    ]

    private static let mediumNames = [
        "DieGrotesk-Medium",
        "Die Grotesk Medium",
        "DieGrotesk-Regular",
        "Die Grotesk Regular"
    ]

    private static let semiboldNames = [
        "DieGrotesk-Semibold",
        "Die Grotesk Semibold",
        "DieGrotesk-Bold",
        "Die Grotesk Bold"
    ]

    private static let boldNames = [
        "DieGrotesk-Bold",
        "Die Grotesk Bold",
        "DieGrotesk-Semibold",
        "Die Grotesk Semibold"
    ]

    static func font(_ role: AppTextRole) -> Font {
        switch role {
        case .hero:
            return resolvedFont(size: 34, textStyle: .largeTitle, names: boldNames, fallbackWeight: .bold)
        case .title:
            return resolvedFont(size: 24, textStyle: .title2, names: semiboldNames, fallbackWeight: .semibold)
        case .headline:
            return resolvedFont(size: 17, textStyle: .headline, names: semiboldNames, fallbackWeight: .semibold)
        case .body:
            return resolvedFont(size: 16, textStyle: .body, names: regularNames, fallbackWeight: .regular)
        case .caption:
            return resolvedFont(size: 12, textStyle: .caption1, names: mediumNames, fallbackWeight: .medium)
        case .button:
            return resolvedFont(size: 17, textStyle: .headline, names: semiboldNames, fallbackWeight: .semibold)
        }
    }

    private static func resolvedFont(
        size: CGFloat,
        textStyle: UIFont.TextStyle,
        names: [String],
        fallbackWeight: UIFont.Weight
    ) -> Font {
        let baseFont = names.lazy.compactMap { UIFont(name: $0, size: size) }.first
            ?? UIFont.systemFont(ofSize: size, weight: fallbackWeight)
        let scaled = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: baseFont)
        return Font(scaled)
    }
}

private extension View {
    func appText(_ role: AppTextRole) -> some View {
        font(AppTypography.font(role))
    }
}

@main
struct TrainingAppApp: App {
    @StateObject private var store = TrainingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.state.theme.colorScheme)
                .tint(.appAccent)
        }
    }
}

// MARK: - Data Models

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }
}

struct UserAccount: Codable, Identifiable {
    var id: UUID = UUID()
    var displayName: String
    var email: String
    var createdAt: Date = Date()
}

enum ExerciseCategory: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case cardio = "Cardio"
    case running = "Running"
    case custom = "Custom"
}

enum ExerciseEquipment: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case dumbbells = "Dumbbells"
    case barbell = "Barbell"
    case machine = "Machine"
    case cable = "Cable"

    var id: String { rawValue }
}

struct ExerciseDefinition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: ExerciseCategory
    var isCustom: Bool = false
    var equipment: ExerciseEquipment = .none
    var defaultSets: Int? = nil
    var defaultReps: Int? = nil
    var defaultWeight: Double? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case isCustom
        case equipment
        case defaultSets
        case defaultReps
        case defaultWeight
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        isCustom: Bool = false,
        equipment: ExerciseEquipment = .none,
        defaultSets: Int? = nil,
        defaultReps: Int? = nil,
        defaultWeight: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isCustom = isCustom
        self.equipment = equipment
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeight = defaultWeight
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(ExerciseCategory.self, forKey: .category)
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? false
        equipment = try container.decodeIfPresent(ExerciseEquipment.self, forKey: .equipment) ?? .none
        defaultSets = try container.decodeIfPresent(Int.self, forKey: .defaultSets)
        defaultReps = try container.decodeIfPresent(Int.self, forKey: .defaultReps)
        defaultWeight = try container.decodeIfPresent(Double.self, forKey: .defaultWeight)
    }
}

enum SetStyle: String, Codable, CaseIterable, Identifiable {
    case warmUp = "Warm-Up"
    case working = "Working"
    case failure = "Failure"
    case dropSet = "Drop Set"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .warmUp:
            return "flame"
        case .working:
            return "bolt"
        case .failure:
            return "xmark.octagon"
        case .dropSet:
            return "arrow.down"
        }
    }

    var tint: Color {
        switch self {
        case .warmUp:
            return .orange
        case .working:
            return Color.appAccent
        case .failure:
            return .red
        case .dropSet:
            return .blue
        }
    }
}

struct LoggedSet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var reps: Int
    var weight: Double
    var style: SetStyle = .working
    var isCompleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case reps
        case weight
        case style
        case isCompleted
    }

    init(
        id: UUID = UUID(),
        reps: Int,
        weight: Double,
        style: SetStyle = .working,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.style = style
        self.isCompleted = isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        reps = try container.decode(Int.self, forKey: .reps)
        weight = try container.decode(Double.self, forKey: .weight)
        style = try container.decodeIfPresent(SetStyle.self, forKey: .style) ?? .working
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(reps, forKey: .reps)
        try container.encode(weight, forKey: .weight)
        try container.encode(style, forKey: .style)
        try container.encode(isCompleted, forKey: .isCompleted)
    }
}

struct LoggedExercise: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var definitionID: UUID?
    var name: String
    var notes: String = ""
    var sets: [LoggedSet]
}

enum MeasurementSystem: String, Codable, CaseIterable, Identifiable {
    case imperial
    case metric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .imperial:
            return "Imperial (lb)"
        case .metric:
            return "Metric (kg)"
        }
    }

    var weightUnit: String {
        switch self {
        case .imperial:
            return "lb"
        case .metric:
            return "kg"
        }
    }

    func displayWeight(fromKilograms kilograms: Double) -> Double {
        switch self {
        case .imperial:
            return kilograms * 2.2046226218
        case .metric:
            return kilograms
        }
    }

    func kilograms(fromDisplayWeight value: Double) -> Double {
        switch self {
        case .imperial:
            return value * 0.45359237
        case .metric:
            return value
        }
    }
}

struct UserPreferences: Codable {
    var measurementSystem: MeasurementSystem = .imperial
    var weekStartsOnMonday: Bool = false
    var defaultRunMode: RunMode = .manual

    static let `default` = UserPreferences()

    enum CodingKeys: String, CodingKey {
        case measurementSystem
        case weekStartsOnMonday
        case defaultRunMode
    }

    init(
        measurementSystem: MeasurementSystem = .imperial,
        weekStartsOnMonday: Bool = false,
        defaultRunMode: RunMode = .manual
    ) {
        self.measurementSystem = measurementSystem
        self.weekStartsOnMonday = weekStartsOnMonday
        self.defaultRunMode = defaultRunMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        measurementSystem = try container.decodeIfPresent(MeasurementSystem.self, forKey: .measurementSystem) ?? .imperial
        weekStartsOnMonday = try container.decodeIfPresent(Bool.self, forKey: .weekStartsOnMonday) ?? false
        defaultRunMode = try container.decodeIfPresent(RunMode.self, forKey: .defaultRunMode) ?? .manual
    }
}

struct BodyWeightEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var recordedAt: Date
    var weightKg: Double
    var note: String = ""

    enum CodingKeys: String, CodingKey {
        case id
        case recordedAt
        case weightKg
        case note
    }

    init(
        id: UUID = UUID(),
        recordedAt: Date,
        weightKg: Double,
        note: String = ""
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.weightKg = max(0, weightKg)
        self.note = note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        recordedAt = try container.decodeIfPresent(Date.self, forKey: .recordedAt) ?? Date()
        weightKg = max(0, try container.decodeIfPresent(Double.self, forKey: .weightKg) ?? 0)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

enum RunMode: String, Codable, CaseIterable, Identifiable {
    case manual = "Manual"
    case gps = "GPS"

    var id: String { rawValue }
}

enum DistanceSource: String, Codable, CaseIterable, Identifiable {
    case manual
    case gps
    case estimated

    var id: String { rawValue }
}

struct CoordinatePoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var altitudeMeters: Double?
    var horizontalAccuracy: Double
    var speedMetersPerSecond: Double?

    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
        case timestamp
        case altitudeMeters
        case horizontalAccuracy
        case speedMetersPerSecond
    }

    init(
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        altitudeMeters: Double? = nil,
        horizontalAccuracy: Double = 20,
        speedMetersPerSecond: Double? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.altitudeMeters = altitudeMeters
        self.horizontalAccuracy = horizontalAccuracy
        self.speedMetersPerSecond = speedMetersPerSecond
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude) ?? 0
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) ?? 0
        timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        altitudeMeters = try container.decodeIfPresent(Double.self, forKey: .altitudeMeters)
        horizontalAccuracy = try container.decodeIfPresent(Double.self, forKey: .horizontalAccuracy) ?? 20
        speedMetersPerSecond = try container.decodeIfPresent(Double.self, forKey: .speedMetersPerSecond)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(altitudeMeters, forKey: .altitudeMeters)
        try container.encode(horizontalAccuracy, forKey: .horizontalAccuracy)
        try container.encodeIfPresent(speedMetersPerSecond, forKey: .speedMetersPerSecond)
    }
}

struct RunElevationPoint: Codable, Hashable {
    var mile: Double
    var elevationFeet: Double
}

struct RunSplit: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var splitIndex: Int
    var startMile: Double
    var endMile: Double
    var splitSeconds: Int
    var splitPaceSecPerMile: Int

    enum CodingKeys: String, CodingKey {
        case id
        case splitIndex
        case startMile
        case endMile
        case splitSeconds
        case splitPaceSecPerMile
        case index
        case distanceMiles
        case durationSeconds
        case paceSecPerMile
    }

    init(
        id: UUID = UUID(),
        splitIndex: Int,
        startMile: Double,
        endMile: Double,
        splitSeconds: Int,
        splitPaceSecPerMile: Int
    ) {
        self.id = id
        self.splitIndex = max(1, splitIndex)
        self.startMile = max(0, startMile)
        self.endMile = max(self.startMile, endMile)
        self.splitSeconds = max(0, splitSeconds)
        self.splitPaceSecPerMile = max(0, splitPaceSecPerMile)
    }

    init(
        id: UUID = UUID(),
        index: Int,
        distanceMiles: Double,
        durationSeconds: Int,
        paceSecPerMile: Int
    ) {
        let normalizedIndex = max(1, index)
        let start = max(0, Double(normalizedIndex - 1))
        let end = start + max(0, distanceMiles)
        self.init(
            id: id,
            splitIndex: normalizedIndex,
            startMile: start,
            endMile: end,
            splitSeconds: durationSeconds,
            splitPaceSecPerMile: paceSecPerMile
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        splitIndex = max(
            1,
            try container.decodeIfPresent(Int.self, forKey: .splitIndex)
                ?? container.decodeIfPresent(Int.self, forKey: .index)
                ?? 1
        )

        if
            let start = try container.decodeIfPresent(Double.self, forKey: .startMile),
            let end = try container.decodeIfPresent(Double.self, forKey: .endMile)
        {
            startMile = max(0, start)
            endMile = max(startMile, end)
        } else {
            let legacyDistance = max(0, try container.decodeIfPresent(Double.self, forKey: .distanceMiles) ?? 1)
            startMile = max(0, Double(splitIndex - 1))
            endMile = startMile + legacyDistance
        }

        splitSeconds = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .splitSeconds)
                ?? container.decodeIfPresent(Int.self, forKey: .durationSeconds)
                ?? 0
        )
        let splitDistance = max(0, endMile - startMile)

        let decodedPace = try container.decodeIfPresent(Int.self, forKey: .splitPaceSecPerMile)
            ?? container.decodeIfPresent(Int.self, forKey: .paceSecPerMile)
        if let decodedPace {
            splitPaceSecPerMile = max(0, decodedPace)
        } else if splitDistance > 0 {
            splitPaceSecPerMile = Int((Double(splitSeconds) / splitDistance).rounded())
        } else {
            splitPaceSecPerMile = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(splitIndex, forKey: .splitIndex)
        try container.encode(startMile, forKey: .startMile)
        try container.encode(endMile, forKey: .endMile)
        try container.encode(splitSeconds, forKey: .splitSeconds)
        try container.encode(splitPaceSecPerMile, forKey: .splitPaceSecPerMile)
    }

    var index: Int {
        get { splitIndex }
        set { splitIndex = max(1, newValue) }
    }

    var distanceMiles: Double {
        get { max(0, endMile - startMile) }
        set { endMile = startMile + max(0, newValue) }
    }

    var durationSeconds: Int {
        get { splitSeconds }
        set { splitSeconds = max(0, newValue) }
    }

    var paceSecPerMile: Int {
        get { splitPaceSecPerMile }
        set { splitPaceSecPerMile = max(0, newValue) }
    }
}

struct RunEntry: Codable, Hashable {
    var mode: RunMode
    var distanceMiles: Double
    var durationSeconds: Int
    var elapsedSeconds: Int
    var movingSeconds: Int
    var notes: String
    var route: [CoordinatePoint]?
    var splits: [RunSplit]
    var elevationSeries: [RunElevationPoint]
    var avgPaceSecPerMile: Int?
    var avgPaceElapsedSecPerMile: Int?
    var avgPaceMovingSecPerMile: Int?
    var elevationGainFeet: Double?
    var elevationLossFeet: Double?
    var minElevationFeet: Double?
    var maxElevationFeet: Double?
    var distanceSource: DistanceSource

    enum CodingKeys: String, CodingKey {
        case mode
        case distanceMiles
        case distanceKm
        case durationSeconds
        case elapsedSeconds
        case movingSeconds
        case notes
        case route
        case splits
        case elevationSeries
        case avgPaceSecPerMile
        case avgPaceElapsedSecPerMile
        case avgPaceMovingSecPerMile
        case elevationGainFeet
        case elevationLossFeet
        case minElevationFeet
        case maxElevationFeet
        case distanceSource
    }

    init(
        mode: RunMode,
        distanceMiles: Double,
        durationSeconds: Int,
        notes: String,
        route: [CoordinatePoint]?,
        splits: [RunSplit] = [],
        avgPaceSecPerMile: Int? = nil,
        elevationGainFeet: Double? = nil,
        distanceSource: DistanceSource? = nil,
        elapsedSeconds: Int? = nil,
        movingSeconds: Int? = nil,
        avgPaceElapsedSecPerMile: Int? = nil,
        avgPaceMovingSecPerMile: Int? = nil,
        elevationLossFeet: Double? = nil,
        minElevationFeet: Double? = nil,
        maxElevationFeet: Double? = nil,
        elevationSeries: [RunElevationPoint] = []
    ) {
        self.mode = mode
        self.distanceMiles = max(0, distanceMiles)
        self.durationSeconds = max(0, durationSeconds)
        self.elapsedSeconds = max(0, elapsedSeconds ?? durationSeconds)
        self.movingSeconds = max(0, movingSeconds ?? self.elapsedSeconds)
        self.notes = notes
        self.route = route
        self.splits = splits
        self.elevationSeries = elevationSeries
        self.avgPaceSecPerMile = avgPaceSecPerMile
        self.avgPaceElapsedSecPerMile = avgPaceElapsedSecPerMile ?? avgPaceSecPerMile
        self.avgPaceMovingSecPerMile = avgPaceMovingSecPerMile
        self.elevationGainFeet = elevationGainFeet
        self.elevationLossFeet = elevationLossFeet
        self.minElevationFeet = minElevationFeet
        self.maxElevationFeet = maxElevationFeet
        self.distanceSource = distanceSource ?? (mode == .gps ? .gps : .manual)
        if self.avgPaceElapsedSecPerMile == nil, self.distanceMiles > 0, self.elapsedSeconds > 0 {
            self.avgPaceElapsedSecPerMile = Int((Double(self.elapsedSeconds) / self.distanceMiles).rounded())
        }
        if self.avgPaceMovingSecPerMile == nil, self.distanceMiles > 0, self.movingSeconds > 0 {
            self.avgPaceMovingSecPerMile = Int((Double(self.movingSeconds) / self.distanceMiles).rounded())
        }
        if self.avgPaceSecPerMile == nil {
            self.avgPaceSecPerMile = self.avgPaceElapsedSecPerMile
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(RunMode.self, forKey: .mode)
        if let miles = try container.decodeIfPresent(Double.self, forKey: .distanceMiles) {
            distanceMiles = miles
        } else if let km = try container.decodeIfPresent(Double.self, forKey: .distanceKm) {
            distanceMiles = km * 0.621371
        } else {
            distanceMiles = 0
        }
        durationSeconds = max(0, try container.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? 0)
        elapsedSeconds = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? durationSeconds
        )
        movingSeconds = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .movingSeconds) ?? elapsedSeconds
        )
        if durationSeconds == 0, elapsedSeconds > 0 {
            durationSeconds = elapsedSeconds
        }
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        route = try container.decodeIfPresent([CoordinatePoint].self, forKey: .route)
        splits = try container.decodeIfPresent([RunSplit].self, forKey: .splits) ?? []
        elevationSeries = try container.decodeIfPresent([RunElevationPoint].self, forKey: .elevationSeries) ?? []
        avgPaceSecPerMile = try container.decodeIfPresent(Int.self, forKey: .avgPaceSecPerMile)
        avgPaceElapsedSecPerMile = try container.decodeIfPresent(Int.self, forKey: .avgPaceElapsedSecPerMile)
            ?? avgPaceSecPerMile
        avgPaceMovingSecPerMile = try container.decodeIfPresent(Int.self, forKey: .avgPaceMovingSecPerMile)

        if avgPaceElapsedSecPerMile == nil, distanceMiles > 0, elapsedSeconds > 0 {
            avgPaceElapsedSecPerMile = Int((Double(elapsedSeconds) / distanceMiles).rounded())
        }
        if avgPaceMovingSecPerMile == nil, distanceMiles > 0, movingSeconds > 0 {
            avgPaceMovingSecPerMile = Int((Double(movingSeconds) / distanceMiles).rounded())
        }
        if avgPaceSecPerMile == nil {
            avgPaceSecPerMile = avgPaceElapsedSecPerMile
        }
        elevationGainFeet = try container.decodeIfPresent(Double.self, forKey: .elevationGainFeet)
        elevationLossFeet = try container.decodeIfPresent(Double.self, forKey: .elevationLossFeet)
        minElevationFeet = try container.decodeIfPresent(Double.self, forKey: .minElevationFeet)
        maxElevationFeet = try container.decodeIfPresent(Double.self, forKey: .maxElevationFeet)
        distanceSource = try container.decodeIfPresent(DistanceSource.self, forKey: .distanceSource)
            ?? (mode == .gps ? .gps : .manual)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(distanceMiles, forKey: .distanceMiles)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
        try container.encode(movingSeconds, forKey: .movingSeconds)
        try container.encode(notes, forKey: .notes)
        try container.encodeIfPresent(route, forKey: .route)
        try container.encode(splits, forKey: .splits)
        try container.encode(elevationSeries, forKey: .elevationSeries)
        try container.encodeIfPresent(avgPaceSecPerMile, forKey: .avgPaceSecPerMile)
        try container.encodeIfPresent(avgPaceElapsedSecPerMile, forKey: .avgPaceElapsedSecPerMile)
        try container.encodeIfPresent(avgPaceMovingSecPerMile, forKey: .avgPaceMovingSecPerMile)
        try container.encodeIfPresent(elevationGainFeet, forKey: .elevationGainFeet)
        try container.encodeIfPresent(elevationLossFeet, forKey: .elevationLossFeet)
        try container.encodeIfPresent(minElevationFeet, forKey: .minElevationFeet)
        try container.encodeIfPresent(maxElevationFeet, forKey: .maxElevationFeet)
        try container.encode(distanceSource, forKey: .distanceSource)
    }
}

enum RunningPRType: String, Codable, CaseIterable, Identifiable {
    case mile1
    case k5
    case k10

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mile1:
            return "1 Mile"
        case .k5:
            return "5K"
        case .k10:
            return "10K"
        }
    }

    var targetMiles: Double {
        switch self {
        case .mile1:
            return 1.0
        case .k5:
            return 3.106855
        case .k10:
            return 6.21371
        }
    }
}

struct RunningPRRecord: Codable, Hashable {
    var type: RunningPRType
    var bestSeconds: Int
    var achievedAt: Date
    var sessionId: UUID
}

enum PRType: String, Codable, CaseIterable, Identifiable {
    case heaviestSet
    case estimated1RM
    case fastestMile
    case longestRun

    var id: String { rawValue }
}

struct AchievementBadge: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var type: PRType
    var title: String
    var valueText: String
    var occurredAt: Date
}

struct WorkoutSessionDraft: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var startedAt: Date = Date()
    var notes: String = ""
    var exercises: [LoggedExercise]
    var run: RunEntry?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startedAt
        case notes
        case exercises
        case run
    }

    init(
        id: UUID = UUID(),
        name: String,
        startedAt: Date = Date(),
        notes: String = "",
        exercises: [LoggedExercise],
        run: RunEntry? = nil
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.notes = notes
        self.exercises = exercises
        self.run = run
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "New Session"
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        exercises = try container.decodeIfPresent([LoggedExercise].self, forKey: .exercises) ?? []
        run = try container.decodeIfPresent(RunEntry.self, forKey: .run)
    }

    var elapsedSeconds: Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var startedAt: Date
    var completedAt: Date
    var notes: String
    var elapsedSeconds: Int
    var exercises: [LoggedExercise]
    var run: RunEntry?
    var achievements: [AchievementBadge] = []

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startedAt
        case completedAt
        case notes
        case elapsedSeconds
        case exercises
        case run
        case achievements
    }

    init(
        id: UUID = UUID(),
        name: String,
        startedAt: Date,
        completedAt: Date,
        notes: String,
        elapsedSeconds: Int,
        exercises: [LoggedExercise],
        run: RunEntry? = nil,
        achievements: [AchievementBadge] = []
    ) {
        self.id = id
        self.name = name
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.elapsedSeconds = elapsedSeconds
        self.exercises = exercises
        self.run = run
        self.achievements = achievements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Workout"
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt) ?? startedAt
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        elapsedSeconds = try container.decodeIfPresent(Int.self, forKey: .elapsedSeconds) ?? 0
        exercises = try container.decodeIfPresent([LoggedExercise].self, forKey: .exercises) ?? []
        run = try container.decodeIfPresent(RunEntry.self, forKey: .run)
        achievements = try container.decodeIfPresent([AchievementBadge].self, forKey: .achievements) ?? []
    }
}

struct TemplateExercise: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var definitionID: UUID?
    var name: String
    var defaultSets: Int
    var defaultReps: Int
    var defaultWeight: Double? = nil
    var equipment: ExerciseEquipment = .none

    enum CodingKeys: String, CodingKey {
        case id
        case definitionID
        case name
        case defaultSets
        case defaultReps
        case defaultWeight
        case equipment
    }

    init(
        id: UUID = UUID(),
        definitionID: UUID?,
        name: String,
        defaultSets: Int,
        defaultReps: Int,
        defaultWeight: Double? = nil,
        equipment: ExerciseEquipment = .none
    ) {
        self.id = id
        self.definitionID = definitionID
        self.name = name
        self.defaultSets = defaultSets
        self.defaultReps = defaultReps
        self.defaultWeight = defaultWeight
        self.equipment = equipment
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        definitionID = try container.decodeIfPresent(UUID.self, forKey: .definitionID)
        name = try container.decode(String.self, forKey: .name)
        defaultSets = try container.decode(Int.self, forKey: .defaultSets)
        defaultReps = try container.decode(Int.self, forKey: .defaultReps)
        defaultWeight = try container.decodeIfPresent(Double.self, forKey: .defaultWeight)
        equipment = try container.decodeIfPresent(ExerciseEquipment.self, forKey: .equipment) ?? .none
    }
}

struct WorkoutTemplate: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var folderID: UUID?
    var notes: String = ""
    var exercises: [TemplateExercise]
    var createdAt: Date = Date()
}

struct RoutineFolder: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
}

struct SetMemory: Codable {
    var reps: Int
    var weight: Double
    var style: SetStyle
}

struct StoredAppState: Codable {
    var account: UserAccount?
    var theme: AppTheme
    var exerciseLibrary: [ExerciseDefinition]
    var folders: [RoutineFolder]
    var templates: [WorkoutTemplate]
    var sessions: [WorkoutSession]
    var lastSetMemory: [String: SetMemory]
    var activeSession: WorkoutSessionDraft?
    var runningPRs: [RunningPRType: RunningPRRecord]
    var preferences: UserPreferences
    var bodyWeightEntries: [BodyWeightEntry]

    enum CodingKeys: String, CodingKey {
        case account
        case theme
        case exerciseLibrary
        case folders
        case templates
        case sessions
        case lastSetMemory
        case activeSession
        case runningPRs
        case preferences
        case bodyWeightEntries
    }

    init(
        account: UserAccount?,
        theme: AppTheme,
        exerciseLibrary: [ExerciseDefinition],
        folders: [RoutineFolder],
        templates: [WorkoutTemplate],
        sessions: [WorkoutSession],
        lastSetMemory: [String: SetMemory],
        activeSession: WorkoutSessionDraft?,
        runningPRs: [RunningPRType: RunningPRRecord] = [:],
        preferences: UserPreferences = .default,
        bodyWeightEntries: [BodyWeightEntry] = []
    ) {
        self.account = account
        self.theme = theme
        self.exerciseLibrary = exerciseLibrary
        self.folders = folders
        self.templates = templates
        self.sessions = sessions
        self.lastSetMemory = lastSetMemory
        self.activeSession = activeSession
        self.runningPRs = runningPRs
        self.preferences = preferences
        self.bodyWeightEntries = bodyWeightEntries.sorted { $0.recordedAt < $1.recordedAt }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        account = try container.decodeIfPresent(UserAccount.self, forKey: .account)
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .dark
        exerciseLibrary = try container.decodeIfPresent([ExerciseDefinition].self, forKey: .exerciseLibrary) ?? []
        folders = try container.decodeIfPresent([RoutineFolder].self, forKey: .folders) ?? []
        templates = try container.decodeIfPresent([WorkoutTemplate].self, forKey: .templates) ?? []
        sessions = try container.decodeIfPresent([WorkoutSession].self, forKey: .sessions) ?? []
        lastSetMemory = try container.decodeIfPresent([String: SetMemory].self, forKey: .lastSetMemory) ?? [:]
        activeSession = try container.decodeIfPresent(WorkoutSessionDraft.self, forKey: .activeSession)
        if let decodedPRs = try container.decodeIfPresent([String: RunningPRRecord].self, forKey: .runningPRs) {
            runningPRs = decodedPRs.reduce(into: [:]) { partial, pair in
                guard let key = RunningPRType(rawValue: pair.key) else { return }
                partial[key] = pair.value
            }
        } else {
            runningPRs = try container.decodeIfPresent([RunningPRType: RunningPRRecord].self, forKey: .runningPRs) ?? [:]
        }
        preferences = try container.decodeIfPresent(UserPreferences.self, forKey: .preferences) ?? .default
        bodyWeightEntries = (try container.decodeIfPresent([BodyWeightEntry].self, forKey: .bodyWeightEntries) ?? [])
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(account, forKey: .account)
        try container.encode(theme, forKey: .theme)
        try container.encode(exerciseLibrary, forKey: .exerciseLibrary)
        try container.encode(folders, forKey: .folders)
        try container.encode(templates, forKey: .templates)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(lastSetMemory, forKey: .lastSetMemory)
        try container.encodeIfPresent(activeSession, forKey: .activeSession)
        let encodedPRs = runningPRs.reduce(into: [String: RunningPRRecord]()) { partial, pair in
            partial[pair.key.rawValue] = pair.value
        }
        try container.encode(encodedPRs, forKey: .runningPRs)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(bodyWeightEntries, forKey: .bodyWeightEntries)
    }

    static let initial = StoredAppState(
        account: nil,
        theme: .dark,
        exerciseLibrary: [],
        folders: [],
        templates: [],
        sessions: [],
        lastSetMemory: [:],
        activeSession: nil,
        runningPRs: [:],
        preferences: .default,
        bodyWeightEntries: []
    )
}

struct ExerciseProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
    let reps: Int
}

struct BodyWeightProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

// MARK: - Persistence

struct PersistenceController {
    private let filename = "training-state.json"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("TrainingApp", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder.appendingPathComponent(filename)
    }

    func load() -> StoredAppState? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(StoredAppState.self, from: data)
        } catch {
            print("Failed to load app state: \(error)")
            return nil
        }
    }

    func save(_ state: StoredAppState) {
        do {
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save app state: \(error)")
        }
    }
}

// MARK: - Store

@MainActor
final class TrainingStore: ObservableObject {
    @Published var state: StoredAppState {
        didSet {
            persistence.save(state)
            lastSavedAt = Date()
        }
    }
    @Published private(set) var lastSavedAt: Date = Date()

    private let persistence = PersistenceController()
    private let metersToMiles = 0.000621371
    private let milesToMeters = 1609.344
    private let metersToFeet = 3.28084
    private let manualPRDistanceToleranceMiles = 0.02

    private struct RouteDistanceProfile {
        let points: [CoordinatePoint]
        let cumulativeMeters: [Double]

        var totalMeters: Double {
            cumulativeMeters.last ?? 0
        }
    }

    private struct RouteDerivedMetrics {
        let distanceMiles: Double
        let elapsedSeconds: Int
        let movingSeconds: Int
        let splits: [RunSplit]
        let elevationGainFeet: Double?
        let elevationLossFeet: Double?
        let minElevationFeet: Double?
        let maxElevationFeet: Double?
        let elevationSeries: [RunElevationPoint]
        let targetSeconds: [RunningPRType: Int]
    }

    init() {
        if var loaded = persistence.load() {
            if loaded.exerciseLibrary.isEmpty {
                loaded.exerciseLibrary = Self.defaultExerciseLibrary()
            }
            state = loaded
        } else {
            var initial = StoredAppState.initial
            initial.exerciseLibrary = Self.defaultExerciseLibrary()
            state = initial
        }
        persistence.save(state)
    }

    var sessionsNewestFirst: [WorkoutSession] {
        state.sessions.sorted { $0.completedAt > $1.completedAt }
    }

    var templatesSorted: [WorkoutTemplate] {
        state.templates.sorted {
            if $0.name == $1.name {
                return $0.createdAt < $1.createdAt
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var foldersSorted: [RoutineFolder] {
        state.folders.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var exerciseNamesWithHistory: [String] {
        let names = Set(
            state.sessions.flatMap { $0.exercises.map(\.name) }
        )
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var totalRunDistanceMiles: Double {
        state.sessions.reduce(0) { partial, session in
            partial + (session.run?.distanceMiles ?? 0)
        }
    }

    var totalVolume: Double {
        state.sessions.reduce(0) { partial, session in
            partial + sessionVolume(session)
        }
    }

    var bodyWeightEntriesNewestFirst: [BodyWeightEntry] {
        state.bodyWeightEntries.sorted { $0.recordedAt > $1.recordedAt }
    }

    var latestBodyWeightEntry: BodyWeightEntry? {
        bodyWeightEntriesNewestFirst.first
    }

    var latestBodyWeightDisplay: String {
        guard let latest = latestBodyWeightEntry else { return "-" }
        return formatWeightMeasurement(
            latest.weightKg,
            as: state.preferences.measurementSystem
        )
    }

    func createAccount(displayName: String, email: String) {
        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        state.account = UserAccount(displayName: cleanName, email: email.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func updateTheme(_ theme: AppTheme) {
        state.theme = theme
    }

    func updatePreferences(_ preferences: UserPreferences) {
        state.preferences = preferences
    }

    func signOutAndResetData() {
        let preservedTheme = state.theme
        let preservedPreferences = state.preferences
        var fresh = StoredAppState.initial
        fresh.theme = preservedTheme
        fresh.preferences = preservedPreferences
        fresh.exerciseLibrary = Self.defaultExerciseLibrary()
        state = fresh
    }

    func startFreshSession(named name: String = "New Session") {
        state.activeSession = WorkoutSessionDraft(
            name: name,
            exercises: []
        )
    }

    func startSession(from template: WorkoutTemplate) {
        var prefilled: [LoggedExercise] = []
        for templateExercise in template.exercises {
            let memory = state.lastSetMemory[memoryKey(for: templateExercise.name)]
            let reps = memory?.reps ?? templateExercise.defaultReps
            let weight = memory?.weight ?? templateExercise.defaultWeight ?? 0
            let style = memory?.style ?? .working
            let sets = (0..<max(1, templateExercise.defaultSets)).map { _ in
                LoggedSet(reps: max(0, reps), weight: max(0, weight), style: style)
            }
            prefilled.append(
                LoggedExercise(
                    definitionID: templateExercise.definitionID,
                    name: templateExercise.name,
                    notes: "",
                    sets: sets
                )
            )
        }
        state.activeSession = WorkoutSessionDraft(
            name: template.name,
            exercises: prefilled
        )
    }

    func discardActiveSession() {
        state.activeSession = nil
    }

    @discardableResult
    func completeActiveSession() -> WorkoutSession? {
        guard let active = state.activeSession else { return nil }
        let completedAt = Date()
        let finalizedRun = active.run.map { finalizeRunEntry($0) }
        if let finalizedRun {
            _ = updateRunningPRsIfNeeded(
                for: finalizedRun,
                sessionID: active.id,
                achievedAt: completedAt
            )
        }
        let finished = WorkoutSession(
            id: active.id,
            name: active.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : active.name,
            startedAt: active.startedAt,
            completedAt: completedAt,
            notes: active.notes,
            elapsedSeconds: max(0, Int(completedAt.timeIntervalSince(active.startedAt))),
            exercises: active.exercises,
            run: finalizedRun,
            achievements: []
        )
        let achievements = detectAchievements(for: finished)
        var completed = finished
        completed.achievements = achievements
        rememberRecentSetData(from: finished.exercises)
        state.sessions.append(completed)
        state.activeSession = nil
        return completed
    }

    func renameActiveSession(_ name: String) {
        withActiveSession { $0.name = name }
    }

    func updateActiveSessionNotes(_ notes: String) {
        withActiveSession { $0.notes = notes }
    }

    func addExerciseToActive(_ definition: ExerciseDefinition) {
        withActiveSession { draft in
            let memory = state.lastSetMemory[memoryKey(for: definition.name)]
            let reps = memory?.reps ?? max(0, definition.defaultReps ?? 8)
            let weight = memory?.weight ?? max(0, definition.defaultWeight ?? 0)
            let style = memory?.style ?? .working
            let setCount = max(1, definition.defaultSets ?? 1)
            let sets = (0..<setCount).map { _ in
                LoggedSet(reps: reps, weight: weight, style: style)
            }
            let exercise = LoggedExercise(
                definitionID: definition.id,
                name: definition.name,
                notes: "",
                sets: sets
            )
            draft.exercises.append(exercise)
        }
    }

    func addCustomExerciseToActive(
        named name: String,
        category: ExerciseCategory? = nil,
        equipment: ExerciseEquipment? = nil,
        defaultSets: Int? = nil,
        defaultReps: Int? = nil,
        defaultWeight: Double? = nil
    ) {
        guard let created = addCustomExerciseIfNeeded(
            named: name,
            category: category,
            equipment: equipment,
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            defaultWeight: defaultWeight
        ) else { return }
        addExerciseToActive(created)
    }

    func removeActiveExercise(id: UUID) {
        withActiveSession { draft in
            draft.exercises.removeAll { $0.id == id }
        }
    }

    func removeActiveExercises(at offsets: IndexSet) {
        withActiveSession { draft in
            draft.exercises.remove(atOffsets: offsets)
        }
    }

    func updateActiveExerciseNotes(exerciseID: UUID, notes: String) {
        withActiveSession { draft in
            guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            draft.exercises[index].notes = notes
        }
    }

    func addSet(to exerciseID: UUID) {
        withActiveSession { draft in
            guard let index = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            let templateSet = draft.exercises[index].sets.last ?? prefilledSet(for: draft.exercises[index].name)
            draft.exercises[index].sets.append(
                LoggedSet(reps: templateSet.reps, weight: templateSet.weight, style: templateSet.style)
            )
        }
    }

    func removeSet(exerciseID: UUID, setID: UUID) {
        withActiveSession { draft in
            guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            draft.exercises[exerciseIndex].sets.removeAll { $0.id == setID }
        }
    }

    func insertSet(exerciseID: UUID, set: LoggedSet, at index: Int) {
        withActiveSession { draft in
            guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            let safeIndex = min(max(0, index), draft.exercises[exerciseIndex].sets.count)
            draft.exercises[exerciseIndex].sets.insert(set, at: safeIndex)
        }
    }

    func insertActiveExercise(_ exercise: LoggedExercise, at index: Int) {
        withActiveSession { draft in
            let safeIndex = min(max(0, index), draft.exercises.count)
            draft.exercises.insert(exercise, at: safeIndex)
        }
    }

    func updateSet(
        exerciseID: UUID,
        setID: UUID,
        reps: Int? = nil,
        weight: Double? = nil,
        style: SetStyle? = nil,
        isCompleted: Bool? = nil
    ) {
        withActiveSession { draft in
            guard let exerciseIndex = draft.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            guard let setIndex = draft.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
            if let reps {
                draft.exercises[exerciseIndex].sets[setIndex].reps = max(0, reps)
            }
            if let weight {
                draft.exercises[exerciseIndex].sets[setIndex].weight = max(0, weight)
            }
            if let style {
                draft.exercises[exerciseIndex].sets[setIndex].style = style
            }
            if let isCompleted {
                draft.exercises[exerciseIndex].sets[setIndex].isCompleted = isCompleted
            }
        }
    }

    @discardableResult
    func setRunEntry(_ run: RunEntry?) -> [RunningPRRecord] {
        var newRunningPRs: [RunningPRRecord] = []
        withActiveSession { draft in
            guard let run else {
                draft.run = nil
                return
            }
            let finalized = finalizeRunEntry(run)
            draft.run = finalized
            newRunningPRs = updateRunningPRsIfNeeded(
                for: finalized,
                sessionID: draft.id,
                achievedAt: Date()
            )
        }
        return newRunningPRs
    }

    func computeRunSplits(route: [CoordinatePoint]?, duration: Int, distanceMiles: Double) -> [RunSplit] {
        let clampedDuration = max(0, duration)
        let clampedDistance = max(0, distanceMiles)
        guard clampedDuration > 0, clampedDistance > 0 else { return [] }

        if let route, let profile = makeRouteDistanceProfile(from: route) {
            let profileMiles = profile.totalMeters * metersToMiles
            let totalMiles = max(clampedDistance, profileMiles)
            return computeFullMileSplits(from: profile, totalMiles: totalMiles)
        }

        let fullMileCount = Int(floor(clampedDistance))
        guard fullMileCount > 0 else { return [] }
        let averagePace = Double(clampedDuration) / clampedDistance
        return (1...fullMileCount).map { splitIndex in
            let splitSeconds = max(1, Int(averagePace.rounded()))
            return RunSplit(
                splitIndex: splitIndex,
                startMile: Double(splitIndex - 1),
                endMile: Double(splitIndex),
                splitSeconds: splitSeconds,
                splitPaceSecPerMile: splitSeconds
            )
        }
    }

    func detectAchievements(for session: WorkoutSession) -> [AchievementBadge] {
        var badges: [AchievementBadge] = []

        for exercise in session.exercises {
            let exerciseName = exercise.name
            let currentHeaviest = exercise.sets.map(\.weight).max() ?? 0
            let currentBest1RM = exercise.sets
                .map { $0.weight * (1 + (Double($0.reps) / 30.0)) }
                .max() ?? 0

            let previousMatching = state.sessions.flatMap { past in
                past.exercises.filter { $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame }
            }
            let previousHeaviest = previousMatching.flatMap(\.sets).map(\.weight).max() ?? 0
            let previousBest1RM = previousMatching
                .flatMap(\.sets)
                .map { $0.weight * (1 + (Double($0.reps) / 30.0)) }
                .max() ?? 0

            if currentHeaviest > previousHeaviest + 0.001 {
                badges.append(
                    AchievementBadge(
                        type: .heaviestSet,
                        title: "\(exerciseName): Heaviest Set PR",
                        valueText: "\(String(format: "%.1f", currentHeaviest)) lb",
                        occurredAt: session.completedAt
                    )
                )
            }

            if currentBest1RM > previousBest1RM + 0.001 {
                badges.append(
                    AchievementBadge(
                        type: .estimated1RM,
                        title: "\(exerciseName): Estimated 1RM PR",
                        valueText: "\(String(format: "%.1f", currentBest1RM)) lb",
                        occurredAt: session.completedAt
                    )
                )
            }
        }

        if let run = session.run {
            let currentLongest = run.distanceMiles
            let previousLongest = state.sessions.compactMap { $0.run?.distanceMiles }.max() ?? 0
            if currentLongest > previousLongest + 0.001 {
                badges.append(
                    AchievementBadge(
                        type: .longestRun,
                        title: "Longest Run PR",
                        valueText: "\(String(format: "%.2f", currentLongest)) mi",
                        occurredAt: session.completedAt
                    )
                )
            }

            let currentFastestMile = fastestMilePace(from: run)
            let previousFastestMile = state.sessions.compactMap { past in
                past.run.flatMap(fastestMilePace(from:))
            }.min() ?? Int.max
            if let currentFastestMile, currentFastestMile < previousFastestMile {
                badges.append(
                    AchievementBadge(
                        type: .fastestMile,
                        title: "Fastest Mile PR",
                        valueText: formatPaceSeconds(currentFastestMile),
                        occurredAt: session.completedAt
                    )
                )
            }
        }

        return badges
    }

    func createFolder(named name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if state.folders.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
            return
        }
        state.folders.append(RoutineFolder(name: clean))
    }

    func deleteFolder(_ folderID: UUID) {
        state.folders.removeAll { $0.id == folderID }
        for index in state.templates.indices {
            if state.templates[index].folderID == folderID {
                state.templates[index].folderID = nil
            }
        }
    }

    func createTemplate(named name: String, folderID: UUID?) -> UUID? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let template = WorkoutTemplate(name: clean, folderID: folderID, notes: "", exercises: [])
        state.templates.append(template)
        return template.id
    }

    func createTemplateFromActiveSession(named name: String, folderID: UUID?) {
        guard let active = state.activeSession else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let converted = active.exercises.map { exercise in
            let definition = exercise.definitionID.flatMap { id in
                state.exerciseLibrary.first(where: { $0.id == id })
            }
            return TemplateExercise(
                definitionID: exercise.definitionID,
                name: exercise.name,
                defaultSets: max(1, exercise.sets.count),
                defaultReps: max(0, exercise.sets.last?.reps ?? 8),
                defaultWeight: max(0, exercise.sets.last?.weight ?? 0),
                equipment: definition?.equipment ?? .none
            )
        }
        let template = WorkoutTemplate(name: clean, folderID: folderID, notes: active.notes, exercises: converted)
        state.templates.append(template)
    }

    func renameTemplate(_ templateID: UUID, name: String) {
        withTemplate(templateID) { template in
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                template.name = clean
            }
        }
    }

    func updateTemplateNotes(_ templateID: UUID, notes: String) {
        withTemplate(templateID) { template in
            template.notes = notes
        }
    }

    func assignTemplate(_ templateID: UUID, to folderID: UUID?) {
        withTemplate(templateID) { template in
            template.folderID = folderID
        }
    }

    func addExerciseToTemplate(_ templateID: UUID, definition: ExerciseDefinition) {
        withTemplate(templateID) { template in
            template.exercises.append(
                TemplateExercise(
                    definitionID: definition.id,
                    name: definition.name,
                    defaultSets: max(1, definition.defaultSets ?? 3),
                    defaultReps: max(0, definition.defaultReps ?? prefilledSet(for: definition.name).reps),
                    defaultWeight: max(0, definition.defaultWeight ?? prefilledSet(for: definition.name).weight),
                    equipment: definition.equipment
                )
            )
        }
    }

    func addCustomExerciseToTemplate(
        _ templateID: UUID,
        name: String,
        category: ExerciseCategory? = nil,
        equipment: ExerciseEquipment? = nil,
        defaultSets: Int? = nil,
        defaultReps: Int? = nil,
        defaultWeight: Double? = nil
    ) {
        guard let definition = addCustomExerciseIfNeeded(
            named: name,
            category: category,
            equipment: equipment,
            defaultSets: defaultSets,
            defaultReps: defaultReps,
            defaultWeight: defaultWeight
        ) else { return }
        addExerciseToTemplate(templateID, definition: definition)
    }

    func updateTemplateExercise(
        templateID: UUID,
        exerciseID: UUID,
        name: String? = nil,
        sets: Int? = nil,
        reps: Int? = nil,
        weight: Double? = nil
    ) {
        withTemplate(templateID) { template in
            guard let index = template.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
            if let name {
                let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !clean.isEmpty {
                    template.exercises[index].name = clean
                }
            }
            if let sets {
                template.exercises[index].defaultSets = max(1, sets)
            }
            if let reps {
                template.exercises[index].defaultReps = max(0, reps)
            }
            if let weight {
                template.exercises[index].defaultWeight = max(0, weight)
            }
        }
    }

    func removeTemplateExercise(templateID: UUID, at offsets: IndexSet) {
        withTemplate(templateID) { template in
            template.exercises.remove(atOffsets: offsets)
        }
    }

    func deleteTemplate(_ templateID: UUID) {
        state.templates.removeAll { $0.id == templateID }
    }

    func deleteSessions(ids: [UUID]) {
        state.sessions.removeAll { ids.contains($0.id) }
    }

    func restoreSessions(_ sessions: [WorkoutSession]) {
        state.sessions.append(contentsOf: sessions)
        state.sessions.sort { $0.completedAt < $1.completedAt }
    }

    func sessions(on day: Date) -> [WorkoutSession] {
        let calendar = Calendar.current
        return sessionsNewestFirst.filter {
            calendar.isDate($0.completedAt, inSameDayAs: day)
        }
    }

    func session(by id: UUID) -> WorkoutSession? {
        state.sessions.first(where: { $0.id == id })
    }

    func previousSets(for exerciseName: String) -> [LoggedSet] {
        for session in sessionsNewestFirst {
            if let matched = session.exercises.first(where: {
                $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame
            }) {
                return matched.sets
            }
        }
        return []
    }

    func sessionVolume(_ session: WorkoutSession) -> Double {
        session.exercises
            .flatMap(\.sets)
            .reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    func progressPoints(for exerciseName: String) -> [ExerciseProgressPoint] {
        guard !exerciseName.isEmpty else { return [] }
        let points: [ExerciseProgressPoint] = state.sessions.compactMap { session in
            let matching = session.exercises.filter {
                $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame
            }
            guard !matching.isEmpty else { return nil }
            let sets = matching.flatMap(\.sets)
            let volume = sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
            let reps = sets.reduce(0) { $0 + $1.reps }
            return ExerciseProgressPoint(date: session.completedAt, volume: volume, reps: reps)
        }
        return points.sorted { $0.date < $1.date }
    }

    func achievementTimeline() -> [AchievementBadge] {
        state.sessions
            .flatMap(\.achievements)
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    func logBodyWeight(value: Double, unit: MeasurementSystem, recordedAt: Date, note: String) {
        let clampedValue = max(0, value)
        guard clampedValue > 0 else { return }
        let entry = BodyWeightEntry(
            recordedAt: recordedAt,
            weightKg: unit.kilograms(fromDisplayWeight: clampedValue),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        state.bodyWeightEntries.append(entry)
        state.bodyWeightEntries.sort { $0.recordedAt < $1.recordedAt }
    }

    func deleteBodyWeight(id: UUID) {
        state.bodyWeightEntries.removeAll { $0.id == id }
    }

    func bodyWeightPoints(days: Int) -> [BodyWeightProgressPoint] {
        guard days > 0 else {
            return state.bodyWeightEntries
                .sorted { $0.recordedAt < $1.recordedAt }
                .map { BodyWeightProgressPoint(date: $0.recordedAt, weightKg: $0.weightKg) }
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return state.bodyWeightEntries
            .filter { $0.recordedAt >= cutoff }
            .sorted { $0.recordedAt < $1.recordedAt }
            .map { BodyWeightProgressPoint(date: $0.recordedAt, weightKg: $0.weightKg) }
    }

    func bodyWeightChange(days: Int) -> Double? {
        guard days > 0 else { return nil }
        let recent = bodyWeightPoints(days: days)
        guard
            let first = recent.first,
            let last = recent.last,
            first.id != last.id
        else {
            return nil
        }
        let unit = state.preferences.measurementSystem
        let firstValue = unit.displayWeight(fromKilograms: first.weightKg)
        let lastValue = unit.displayWeight(fromKilograms: last.weightKg)
        return lastValue - firstValue
    }

    private func addCustomExerciseIfNeeded(
        named rawName: String,
        category: ExerciseCategory?,
        equipment: ExerciseEquipment?,
        defaultSets: Int?,
        defaultReps: Int?,
        defaultWeight: Double?
    ) -> ExerciseDefinition? {
        let clean = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let existing = state.exerciseLibrary.first(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) {
            return existing
        }
        let newExercise = ExerciseDefinition(
            name: clean,
            category: category ?? .custom,
            isCustom: true,
            equipment: equipment ?? .none,
            defaultSets: defaultSets.map { max(1, $0) },
            defaultReps: defaultReps.map { max(0, $0) },
            defaultWeight: defaultWeight.map { max(0, $0) }
        )
        state.exerciseLibrary.append(newExercise)
        return newExercise
    }

    private func rememberRecentSetData(from exercises: [LoggedExercise]) {
        for exercise in exercises {
            guard let last = exercise.sets.last else { continue }
            state.lastSetMemory[memoryKey(for: exercise.name)] = SetMemory(
                reps: last.reps,
                weight: last.weight,
                style: last.style
            )
        }
    }

    private func withActiveSession(_ mutate: (inout WorkoutSessionDraft) -> Void) {
        guard var active = state.activeSession else { return }
        mutate(&active)
        state.activeSession = active
    }

    private func withTemplate(_ templateID: UUID, mutate: (inout WorkoutTemplate) -> Void) {
        guard let index = state.templates.firstIndex(where: { $0.id == templateID }) else { return }
        mutate(&state.templates[index])
    }

    private func prefilledSet(for exerciseName: String) -> LoggedSet {
        if let memory = state.lastSetMemory[memoryKey(for: exerciseName)] {
            return LoggedSet(reps: memory.reps, weight: memory.weight, style: memory.style)
        }
        return LoggedSet(reps: 8, weight: 0, style: .working)
    }

    private func memoryKey(for exerciseName: String) -> String {
        exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func finalizeRunEntry(_ run: RunEntry) -> RunEntry {
        var finalized = run
        finalized.distanceMiles = max(0, finalized.distanceMiles)
        finalized.elapsedSeconds = max(finalized.elapsedSeconds, finalized.durationSeconds)
        finalized.durationSeconds = max(0, finalized.elapsedSeconds)
        finalized.movingSeconds = max(0, finalized.movingSeconds)

        if finalized.mode == .gps, let route = finalized.route, !route.isEmpty {
            let derived = routeDerivedMetrics(
                from: route,
                fallbackElapsedSeconds: finalized.durationSeconds,
                fallbackDistanceMiles: finalized.distanceMiles
            )
            finalized.distanceMiles = derived.distanceMiles
            finalized.elapsedSeconds = derived.elapsedSeconds
            finalized.durationSeconds = derived.elapsedSeconds
            finalized.movingSeconds = max(0, min(derived.movingSeconds, derived.elapsedSeconds))
            finalized.splits = derived.splits
            finalized.elevationGainFeet = derived.elevationGainFeet
            finalized.elevationLossFeet = derived.elevationLossFeet
            finalized.minElevationFeet = derived.minElevationFeet
            finalized.maxElevationFeet = derived.maxElevationFeet
            finalized.elevationSeries = derived.elevationSeries
            finalized.distanceSource = .gps
        } else {
            finalized.distanceMiles = max(0, finalized.distanceMiles)
            finalized.elapsedSeconds = max(0, finalized.durationSeconds)
            finalized.durationSeconds = finalized.elapsedSeconds
            finalized.movingSeconds = finalized.elapsedSeconds
            if finalized.mode == .gps {
                finalized.distanceSource = (finalized.route?.isEmpty == false) ? .gps : .estimated
            } else {
                finalized.distanceSource = .manual
                finalized.splits = []
                finalized.elevationGainFeet = nil
                finalized.elevationLossFeet = nil
                finalized.minElevationFeet = nil
                finalized.maxElevationFeet = nil
                finalized.elevationSeries = []
            }
        }

        if finalized.distanceMiles > 0, finalized.elapsedSeconds > 0 {
            finalized.avgPaceElapsedSecPerMile = Int((Double(finalized.elapsedSeconds) / finalized.distanceMiles).rounded())
        } else {
            finalized.avgPaceElapsedSecPerMile = nil
        }

        if finalized.distanceMiles > 0, finalized.movingSeconds > 0 {
            finalized.avgPaceMovingSecPerMile = Int((Double(finalized.movingSeconds) / finalized.distanceMiles).rounded())
        } else {
            finalized.avgPaceMovingSecPerMile = nil
        }

        finalized.avgPaceSecPerMile = finalized.avgPaceElapsedSecPerMile
        return finalized
    }

    private func makeRouteDistanceProfile(from route: [CoordinatePoint]) -> RouteDistanceProfile? {
        let sorted = route.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 2 else { return nil }

        var cumulativeMeters = Array(repeating: 0.0, count: sorted.count)
        for index in 1..<sorted.count {
            let previous = sorted[index - 1]
            let current = sorted[index]
            let rawDistance = CLLocation(
                latitude: previous.latitude,
                longitude: previous.longitude
            ).distance(
                from: CLLocation(latitude: current.latitude, longitude: current.longitude)
            )
            let filteredDistance = (rawDistance.isFinite && rawDistance > 0.5 && rawDistance < 250) ? rawDistance : 0
            cumulativeMeters[index] = cumulativeMeters[index - 1] + filteredDistance
        }

        return RouteDistanceProfile(points: sorted, cumulativeMeters: cumulativeMeters)
    }

    private func routeDerivedMetrics(
        from route: [CoordinatePoint],
        fallbackElapsedSeconds: Int,
        fallbackDistanceMiles: Double
    ) -> RouteDerivedMetrics {
        guard let profile = makeRouteDistanceProfile(from: route) else {
            let clampedElapsed = max(0, fallbackElapsedSeconds)
            return RouteDerivedMetrics(
                distanceMiles: max(0, fallbackDistanceMiles),
                elapsedSeconds: clampedElapsed,
                movingSeconds: clampedElapsed,
                splits: [],
                elevationGainFeet: nil,
                elevationLossFeet: nil,
                minElevationFeet: nil,
                maxElevationFeet: nil,
                elevationSeries: [],
                targetSeconds: [:]
            )
        }

        let routeElapsedSeconds = max(
            0,
            Int((profile.points.last?.timestamp.timeIntervalSince(profile.points.first?.timestamp ?? Date()) ?? 0).rounded())
        )
        let elapsedSeconds = max(max(0, fallbackElapsedSeconds), routeElapsedSeconds)
        let movingSeconds = min(elapsedSeconds, movingSeconds(from: profile))
        let profileDistanceMiles = profile.totalMeters * metersToMiles
        let distanceMiles = profileDistanceMiles > 0 ? profileDistanceMiles : max(0, fallbackDistanceMiles)
        let splits = computeFullMileSplits(from: profile, totalMiles: distanceMiles)
        let elevation = computeElevationMetrics(from: profile)

        var targetSeconds: [RunningPRType: Int] = [:]
        for prType in RunningPRType.allCases {
            if let seconds = interpolateElapsedSeconds(atMiles: prType.targetMiles, profile: profile) {
                targetSeconds[prType] = seconds
            }
        }

        return RouteDerivedMetrics(
            distanceMiles: distanceMiles,
            elapsedSeconds: elapsedSeconds,
            movingSeconds: movingSeconds,
            splits: splits,
            elevationGainFeet: elevation.gainFeet,
            elevationLossFeet: elevation.lossFeet,
            minElevationFeet: elevation.minFeet,
            maxElevationFeet: elevation.maxFeet,
            elevationSeries: elevation.series,
            targetSeconds: targetSeconds
        )
    }

    private func movingSeconds(from profile: RouteDistanceProfile) -> Int {
        var movingTime: TimeInterval = 0
        for index in 1..<profile.points.count {
            let previous = profile.points[index - 1]
            let current = profile.points[index]
            let deltaSeconds = current.timestamp.timeIntervalSince(previous.timestamp)
            guard deltaSeconds > 0 else { continue }

            let accuracyOK = previous.horizontalAccuracy <= 50 && current.horizontalAccuracy <= 50
            guard accuracyOK else { continue }

            let distanceDelta = profile.cumulativeMeters[index] - profile.cumulativeMeters[index - 1]
            let resolvedSpeed: Double
            if let speed = current.speedMetersPerSecond, speed >= 0 {
                resolvedSpeed = speed
            } else {
                resolvedSpeed = distanceDelta / deltaSeconds
            }

            if resolvedSpeed >= 0.8 || distanceDelta >= 2 {
                movingTime += deltaSeconds
            }
        }
        return max(0, Int(movingTime.rounded()))
    }

    private func computeFullMileSplits(from profile: RouteDistanceProfile, totalMiles: Double) -> [RunSplit] {
        guard let startTime = profile.points.first?.timestamp else { return [] }
        let fullMiles = Int(floor(max(0, totalMiles) + 1e-9))
        guard fullMiles > 0 else { return [] }

        var splits: [RunSplit] = []
        var splitStartTime = startTime

        for splitIndex in 1...fullMiles {
            guard let boundaryTime = interpolateTimestamp(atMiles: Double(splitIndex), profile: profile) else { break }
            let splitSeconds = max(1, Int(boundaryTime.timeIntervalSince(splitStartTime).rounded()))
            splits.append(
                RunSplit(
                    splitIndex: splitIndex,
                    startMile: Double(splitIndex - 1),
                    endMile: Double(splitIndex),
                    splitSeconds: splitSeconds,
                    splitPaceSecPerMile: splitSeconds
                )
            )
            splitStartTime = boundaryTime
        }
        return splits
    }

    private func interpolateTimestamp(atMiles targetMiles: Double, profile: RouteDistanceProfile) -> Date? {
        guard targetMiles >= 0 else { return nil }
        let targetMeters = targetMiles * milesToMeters
        guard targetMeters <= profile.totalMeters + 0.0001 else { return nil }
        if targetMeters <= 0 {
            return profile.points.first?.timestamp
        }

        for index in 1..<profile.cumulativeMeters.count {
            let previousDistance = profile.cumulativeMeters[index - 1]
            let currentDistance = profile.cumulativeMeters[index]
            guard currentDistance + 0.0001 >= targetMeters else { continue }

            let previousTime = profile.points[index - 1].timestamp
            let currentTime = profile.points[index].timestamp
            let segmentDistance = currentDistance - previousDistance
            guard segmentDistance > 0 else { return currentTime }

            let ratio = max(0, min(1, (targetMeters - previousDistance) / segmentDistance))
            let segmentSeconds = currentTime.timeIntervalSince(previousTime)
            return previousTime.addingTimeInterval(segmentSeconds * ratio)
        }

        return profile.points.last?.timestamp
    }

    private func interpolateElapsedSeconds(atMiles targetMiles: Double, profile: RouteDistanceProfile) -> Int? {
        guard
            let start = profile.points.first?.timestamp,
            let boundary = interpolateTimestamp(atMiles: targetMiles, profile: profile)
        else {
            return nil
        }
        return max(1, Int(boundary.timeIntervalSince(start).rounded()))
    }

    private func computeElevationMetrics(
        from profile: RouteDistanceProfile
    ) -> (gainFeet: Double?, lossFeet: Double?, minFeet: Double?, maxFeet: Double?, series: [RunElevationPoint]) {
        var altitudeSamples: [(routeIndex: Int, altitudeMeters: Double)] = []
        altitudeSamples.reserveCapacity(profile.points.count)

        for (index, point) in profile.points.enumerated() {
            guard point.horizontalAccuracy <= 50 else { continue }
            guard let altitude = point.altitudeMeters, altitude.isFinite else { continue }
            altitudeSamples.append((routeIndex: index, altitudeMeters: altitude))
        }

        guard !altitudeSamples.isEmpty else {
            return (nil, nil, nil, nil, [])
        }

        let smoothedMeters = movingAverage(values: altitudeSamples.map(\.altitudeMeters), window: 5)
        var gainMeters: Double = 0
        var lossMeters: Double = 0
        if smoothedMeters.count >= 2 {
            for index in 1..<smoothedMeters.count {
                let delta = smoothedMeters[index] - smoothedMeters[index - 1]
                if delta > 0 {
                    gainMeters += delta
                } else {
                    lossMeters += abs(delta)
                }
            }
        }

        let minFeet = smoothedMeters.min().map { $0 * metersToFeet }
        let maxFeet = smoothedMeters.max().map { $0 * metersToFeet }
        let rawSeries = zip(altitudeSamples, smoothedMeters).map { sample, smoothedAltitude in
            RunElevationPoint(
                mile: profile.cumulativeMeters[sample.routeIndex] * metersToMiles,
                elevationFeet: smoothedAltitude * metersToFeet
            )
        }

        return (
            gainFeet: gainMeters * metersToFeet,
            lossFeet: lossMeters * metersToFeet,
            minFeet: minFeet,
            maxFeet: maxFeet,
            series: downsampleElevationSeries(rawSeries, maxCount: 300)
        )
    }

    private func movingAverage(values: [Double], window: Int) -> [Double] {
        guard !values.isEmpty else { return [] }
        guard window > 1 else { return values }
        let radius = max(1, window / 2)

        return values.indices.map { index in
            let start = max(0, index - radius)
            let end = min(values.count - 1, index + radius)
            let slice = values[start...end]
            let total = slice.reduce(0, +)
            return total / Double(slice.count)
        }
    }

    private func downsampleElevationSeries(_ series: [RunElevationPoint], maxCount: Int) -> [RunElevationPoint] {
        guard series.count > maxCount, maxCount > 1 else { return series }

        let step = Double(series.count - 1) / Double(maxCount - 1)
        var indices: [Int] = []
        indices.reserveCapacity(maxCount)

        for sampleIndex in 0..<maxCount {
            let raw = Int((Double(sampleIndex) * step).rounded())
            let bounded = min(series.count - 1, max(0, raw))
            if indices.last != bounded {
                indices.append(bounded)
            }
        }

        if indices.last != series.count - 1 {
            indices.append(series.count - 1)
        }

        return indices.map { series[$0] }
    }

    private func updateRunningPRsIfNeeded(
        for run: RunEntry,
        sessionID: UUID,
        achievedAt: Date
    ) -> [RunningPRRecord] {
        var newlySet: [RunningPRRecord] = []

        for prType in RunningPRType.allCases {
            guard let candidateSeconds = candidatePRSeconds(for: prType, run: run) else { continue }
            if let existing = state.runningPRs[prType], candidateSeconds >= existing.bestSeconds {
                continue
            }

            let record = RunningPRRecord(
                type: prType,
                bestSeconds: candidateSeconds,
                achievedAt: achievedAt,
                sessionId: sessionID
            )
            state.runningPRs[prType] = record
            newlySet.append(record)
        }

        return newlySet.sorted { $0.type.targetMiles < $1.type.targetMiles }
    }

    private func candidatePRSeconds(for prType: RunningPRType, run: RunEntry) -> Int? {
        let targetMiles = prType.targetMiles
        guard run.distanceMiles + 0.0001 >= targetMiles else { return nil }

        if run.mode == .gps, let route = run.route, let profile = makeRouteDistanceProfile(from: route) {
            return interpolateElapsedSeconds(atMiles: targetMiles, profile: profile)
        }

        guard run.mode == .manual else { return nil }
        let elapsed = max(0, run.elapsedSeconds)
        guard elapsed > 0 else { return nil }
        guard abs(run.distanceMiles - targetMiles) <= manualPRDistanceToleranceMiles else { return nil }
        let scaled = Double(elapsed) * (targetMiles / max(run.distanceMiles, 0.0001))
        return max(1, Int(scaled.rounded()))
    }

    private func fastestMilePace(from run: RunEntry) -> Int? {
        let fullMileSplits = run.splits.filter { $0.distanceMiles >= 0.99 }
        if let minSplitPace = fullMileSplits.map(\.paceSecPerMile).min() {
            return minSplitPace
        }
        if run.distanceMiles >= 1, let avg = run.avgPaceSecPerMile {
            return avg
        }
        return nil
    }

    private func formatPaceSeconds(_ secondsPerMile: Int) -> String {
        let clamped = max(0, secondsPerMile)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    static func defaultExerciseLibrary() -> [ExerciseDefinition] {
        [
            ExerciseDefinition(name: "Bench Press", category: .chest, equipment: .barbell, defaultSets: 3, defaultReps: 8),
            ExerciseDefinition(name: "Incline Dumbbell Press", category: .chest, equipment: .dumbbells, defaultSets: 3, defaultReps: 10),
            ExerciseDefinition(name: "Push-Up", category: .chest, equipment: .none, defaultSets: 3, defaultReps: 12),
            ExerciseDefinition(name: "Pull-Up", category: .back, equipment: .none, defaultSets: 3, defaultReps: 8),
            ExerciseDefinition(name: "Barbell Row", category: .back, equipment: .barbell, defaultSets: 3, defaultReps: 8),
            ExerciseDefinition(name: "Lat Pulldown", category: .back, equipment: .machine, defaultSets: 3, defaultReps: 10),
            ExerciseDefinition(name: "Back Squat", category: .legs, equipment: .barbell, defaultSets: 3, defaultReps: 6),
            ExerciseDefinition(name: "Romanian Deadlift", category: .legs, equipment: .barbell, defaultSets: 3, defaultReps: 8),
            ExerciseDefinition(name: "Walking Lunge", category: .legs, equipment: .dumbbells, defaultSets: 3, defaultReps: 10),
            ExerciseDefinition(name: "Overhead Press", category: .shoulders, equipment: .barbell, defaultSets: 3, defaultReps: 8),
            ExerciseDefinition(name: "Lateral Raise", category: .shoulders, equipment: .dumbbells, defaultSets: 3, defaultReps: 12),
            ExerciseDefinition(name: "Biceps Curl", category: .arms, equipment: .dumbbells, defaultSets: 3, defaultReps: 10),
            ExerciseDefinition(name: "Triceps Pressdown", category: .arms, equipment: .cable, defaultSets: 3, defaultReps: 10),
            ExerciseDefinition(name: "Plank", category: .core, equipment: .none, defaultSets: 3, defaultReps: 1),
            ExerciseDefinition(name: "Cable Crunch", category: .core, equipment: .cable, defaultSets: 3, defaultReps: 12),
            ExerciseDefinition(name: "Treadmill Run", category: .running, equipment: .machine, defaultSets: 1, defaultReps: 1),
            ExerciseDefinition(name: "Outdoor Run", category: .running, equipment: .none, defaultSets: 1, defaultReps: 1)
        ]
    }
}

// MARK: - GPS Tracking

final class GPSRunTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isTracking = false
    @Published var distanceMeters: Double = 0
    @Published var elapsedSeconds: Int = 0
    @Published var route: [CoordinatePoint] = []

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var startDate: Date?
    private var tickTimer: Timer?
    private var pendingStartAfterAuthorization = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.pausesLocationUpdatesAutomatically = false
    }

    var canTrack: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        if authorizationStatus == .notDetermined {
            pendingStartAfterAuthorization = true
            requestPermission()
            return
        }
        guard canTrack else {
            pendingStartAfterAuthorization = false
            return
        }

        pendingStartAfterAuthorization = false

        distanceMeters = 0
        elapsedSeconds = 0
        route = []
        lastLocation = nil
        startDate = Date()
        isTracking = true

        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let started = self.startDate else { return }
            DispatchQueue.main.async {
                self.elapsedSeconds = max(0, Int(Date().timeIntervalSince(started)))
            }
        }

        manager.startUpdatingLocation()
        manager.requestLocation()
    }

    func stopTracking() {
        isTracking = false
        pendingStartAfterAuthorization = false
        manager.stopUpdatingLocation()
        tickTimer?.invalidate()
        tickTimer = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if self.pendingStartAfterAuthorization, self.canTrack {
                self.startTracking()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                self.pendingStartAfterAuthorization = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }

        for location in locations {
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 120 else { continue }
            guard location.timestamp.timeIntervalSinceNow > -30 else { continue }

            if let previous = lastLocation {
                let increment = location.distance(from: previous)
                if increment > 0.5, increment < 250 {
                    DispatchQueue.main.async {
                        self.distanceMeters += increment
                    }
                }
            }

            let point = CoordinatePoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: location.timestamp,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
                horizontalAccuracy: location.horizontalAccuracy,
                speedMetersPerSecond: location.speed >= 0 ? location.speed : nil
            )
            DispatchQueue.main.async {
                self.route.append(point)
            }
            lastLocation = location
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GPS tracking error: \(error.localizedDescription)")
    }

    deinit {
        tickTimer?.invalidate()
    }
}

// MARK: - UI

struct RunRouteMapView: View {
    let route: [CoordinatePoint]

    var body: some View {
        let coordinates = route.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        Group {
            if coordinates.count < 2 {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    Text("Route preview appears after GPS points are captured.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            } else {
                Map(initialPosition: .region(regionForCoordinates(coordinates))) {
                    MapPolyline(coordinates: coordinates)
                        .stroke(Color.appAccent, lineWidth: 4)
                }
            }
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func regionForCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLat = latitudes.min() ?? coordinates[0].latitude
        let maxLat = latitudes.max() ?? coordinates[0].latitude
        let minLon = longitudes.min() ?? coordinates[0].longitude
        let maxLon = longitudes.max() ?? coordinates[0].longitude

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.4)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

struct UndoSnackbar: View {
    let message: String
    var onUndo: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Text(message)
                .font(.footnote.weight(.semibold))
                .lineLimit(2)
            Spacer()
            if let onUndo {
                Button("Undo", action: onUndo)
                    .font(.footnote.weight(.bold))
            }
            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct RootView: View {
    @EnvironmentObject private var store: TrainingStore

    var body: some View {
        ZStack {
            AppBackgroundView()
                .ignoresSafeArea()

            if store.state.account == nil {
                AccountSetupView()
                    .padding()
            } else {
                MainTabsView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.state.account?.id)
    }
}

struct AppBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.14),
                    Color(red: 0.03, green: 0.04, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.appAccent.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 44)
                .offset(x: 170, y: 280)
        }
    }
}

struct AccountSetupView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set up your account")
                .appText(.hero)

            Text("Your sessions, templates, stats, and notes are stored offline on-device and tied to this account.")
                .appText(.body)
                .foregroundStyle(.secondary)

            VStack(spacing: 14) {
                TextField("Name", text: $name)
                    .appText(.body)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .glassField()

                TextField("Email (optional)", text: $email)
                    .appText(.body)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .padding(12)
                    .glassField()
            }

            Button {
                store.createAccount(displayName: name, email: email)
            } label: {
                Text("Create Account")
                    .appText(.button)
                    .frame(maxWidth: .infinity)
                    .padding(14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Text("Default appearance is dark mode. You can switch to light or system in Settings.")
                .appText(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MainTabsView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var selectedTab: MainTab = .workout

    private enum MainTab: Hashable {
        case templates
        case history
        case workout
        case insights
        case progress
        case settings
    }

    private var workoutTabSymbol: String {
        store.state.activeSession == nil
            ? "figure.strengthtraining.traditional.circle"
            : "figure.strengthtraining.traditional.circle.fill"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TemplatesView()
            }
            .tabItem {
                Label("Templates", systemImage: "square.grid.2x2.fill")
            }
            .tag(MainTab.templates)

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            .tag(MainTab.history)

            NavigationStack {
                WorkoutView()
            }
            .tabItem {
                Label("Workout", systemImage: workoutTabSymbol)
            }
            .tag(MainTab.workout)
            .badge(store.state.activeSession == nil ? 0 : 1)

            NavigationStack {
                InsightsView()
            }
            .tabItem {
                Label("Insights", systemImage: "chart.bar")
            }
            .tag(MainTab.insights)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(MainTab.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToWorkoutTab)) { _ in
            selectedTab = .workout
        }
    }
}

struct WorkoutView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var openActiveSession = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                welcomeCard

                if store.state.activeSession != nil {
                    activeSessionCard
                }

                startCard

                if !store.templatesSorted.isEmpty {
                    templatesCard
                }

                quickStatsCard
            }
            .padding()
        }
        .navigationTitle("Workout")
        .navigationDestination(isPresented: $openActiveSession) {
            ActiveSessionView()
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back")
                .appText(.headline)
                .foregroundStyle(.secondary)

            Text(store.state.account?.displayName ?? "Athlete")
                .appText(.hero)

            Text("Start a new lifting session, launch a run, or continue your current workout.")
                .appText(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var activeSessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Session")
                .appText(.headline)

            if let active = store.state.activeSession {
                Text(active.name)
                    .appText(.title)
                Text("Started \(active.startedAt.formatted(date: .abbreviated, time: .shortened))")
                    .appText(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Continue") {
                    openActiveSession = true
                }
                .buttonStyle(.borderedProminent)

                Button("Discard", role: .destructive) {
                    store.discardActiveSession()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start")
                .appText(.headline)

            Button {
                store.startFreshSession(named: "New Session")
                openActiveSession = true
            } label: {
                Label("Start Session", systemImage: "plus.circle.fill")
                    .appText(.button)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var templatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Templates")
                .appText(.headline)

            let columns = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(store.templatesSorted.prefix(4))) { template in
                    Button {
                        store.startSession(from: template)
                        openActiveSession = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(template.name)
                                .appText(.headline)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(template.exercises.count) exercises")
                                .appText(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            HStack {
                                Spacer()
                                Label("Start", systemImage: "play.fill")
                                    .appText(.caption)
                            }
                        }
                        .padding(12)
                        .frame(minHeight: 110)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var quickStatsCard: some View {
        HStack(spacing: 10) {
            StatTile(title: "Sessions", value: "\(store.state.sessions.count)")
            StatTile(title: "Volume", value: shortMass(store.totalVolume))
            StatTile(title: "Run", value: "\(String(format: "%.1f", store.totalRunDistanceMiles)) mi")
        }
        .frame(maxWidth: .infinity)
    }
}

struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appText(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .appText(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ActiveSessionView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss

    @State private var showExercisePicker = false
    @State private var runEditorRoute: RunEditorRoute?
    @StateObject private var gpsTracker = GPSRunTracker()
    @State private var showFinishAlert = false
    @State private var showFinishTemplatePrompt = false
    @State private var showDiscardSessionAlert = false
    @State private var showCompletionAlert = false
    @State private var completionMessage = ""

    @State private var pendingDeletedSet: PendingDeletedSet?
    @State private var pendingDeletedExercise: PendingDeletedExercise?
    @State private var undoMessage: String?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var sessionNotesExpanded = false

    @State private var templateName = ""

    private struct PendingDeletedSet {
        var exerciseID: UUID
        var set: LoggedSet
        var index: Int
    }

    private struct PendingDeletedExercise {
        var exercise: LoggedExercise
        var index: Int
    }

    private enum RunEditorRoute: String, Identifiable {
        case manual
        case gps

        var id: String { rawValue }

        var mode: RunMode {
            switch self {
            case .manual:
                return .manual
            case .gps:
                return .gps
            }
        }
    }

    var body: some View {
        Group {
            if let session = store.state.activeSession {
                List {
                    Section {
                        sessionHeader(startedAt: session.startedAt)

                        TextField(
                            "Workout name",
                            text: Binding(
                                get: { store.state.activeSession?.name ?? "" },
                                set: { store.renameActiveSession($0) }
                            )
                        )
                        .font(.subheadline)

                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    sessionNotesExpanded.toggle()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    let hasSessionNotes = !(store.state.activeSession?.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                                    Image(systemName: hasSessionNotes ? "note.text" : "square.and.pencil")
                                    Text(hasSessionNotes ? "Edit session note" : "Add session note")
                                    Spacer()
                                    Image(systemName: sessionNotesExpanded ? "chevron.up" : "chevron.down")
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            if sessionNotesExpanded {
                                TextEditor(
                                    text: Binding(
                                        get: { store.state.activeSession?.notes ?? "" },
                                        set: { store.updateActiveSessionNotes($0) }
                                    )
                                )
                                .font(.caption2)
                                .frame(minHeight: 44, maxHeight: 80)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }

                            Text("Saved offline \(store.lastSavedAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    Section("Exercises") {
                        ForEach(session.exercises) { exercise in
                            ExerciseCardView(
                                exercise: exercise,
                                previousSets: store.previousSets(for: exercise.name),
                                onUpdateNotes: { store.updateActiveExerciseNotes(exerciseID: exercise.id, notes: $0) },
                                onAddSet: { store.addSet(to: exercise.id) },
                                onDeleteSet: { setID in
                                    guard let setIndex = exercise.sets.firstIndex(where: { $0.id == setID }) else { return }
                                    let set = exercise.sets[setIndex]
                                    Haptics.warning()
                                    pendingDeletedSet = PendingDeletedSet(
                                        exerciseID: exercise.id,
                                        set: set,
                                        index: setIndex
                                    )
                                    pendingDeletedExercise = nil
                                    showUndoMessage("Set deleted")
                                    store.removeSet(exerciseID: exercise.id, setID: setID)
                                },
                                onToggleSetComplete: { setID in
                                    guard let set = exercise.sets.first(where: { $0.id == setID }) else { return }
                                    store.updateSet(
                                        exerciseID: exercise.id,
                                        setID: setID,
                                        isCompleted: !set.isCompleted
                                    )
                                },
                                onUpdateSet: { setID, reps, weight, style in
                                    store.updateSet(exerciseID: exercise.id, setID: setID, reps: reps, weight: weight, style: style)
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    guard let index = session.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
                                    Haptics.warning()
                                    pendingDeletedExercise = PendingDeletedExercise(
                                        exercise: exercise,
                                        index: index
                                    )
                                    pendingDeletedSet = nil
                                    showUndoMessage("Exercise deleted")
                                    store.removeActiveExercise(id: exercise.id)
                                } label: {
                                    Label("Delete Exercise", systemImage: "trash")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                            .listRowBackground(Color.clear)
                        }

                        Button {
                            Haptics.selection()
                            showExercisePicker = true
                        } label: {
                            Text("+ Add Exercise")
                                .font(.headline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.appAccent.opacity(0.95), Color.appAccent.opacity(0.72)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Section("Run") {
                        if let run = session.run {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(run.mode.rawValue) run")
                                    .font(.subheadline.weight(.semibold))
                                Text("Distance: \(run.distanceMiles, specifier: "%.2f") mi")
                                    .font(.footnote)
                                Text("Duration: \(formatDuration(run.durationSeconds))")
                                    .font(.footnote)
                                if let avgPace = run.avgPaceSecPerMile {
                                    Text("Avg pace: \(formatPacePerMile(avgPace))")
                                        .font(.footnote)
                                }
                                if !run.splits.isEmpty {
                                    Text("\(run.splits.count) split\(run.splits.count == 1 ? "" : "s") saved")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if !run.notes.isEmpty {
                                    Text(run.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("No run logged yet")
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            let preferredRunMode = store.state.preferences.defaultRunMode
                            let alternateRunMode: RunMode = preferredRunMode == .manual ? .gps : .manual
                            let preferredRunLabel = preferredRunMode == .manual
                                ? "Add Manual Run"
                                : (gpsTracker.isTracking ? "Resume GPS Run" : "Start GPS Run")
                            let alternateRunLabel = alternateRunMode == .manual
                                ? "Add Manual Run"
                                : (gpsTracker.isTracking ? "Resume GPS Run" : "Start GPS Run")
                            let preferredRunIcon = preferredRunMode == .manual ? "figure.run.circle" : "location.circle.fill"
                            let alternateRunIcon = alternateRunMode == .manual ? "figure.run.circle" : "location.circle.fill"

                            Button {
                                Haptics.selection()
                                runEditorRoute = preferredRunMode == .manual ? .manual : .gps
                            } label: {
                                Label(
                                    preferredRunLabel,
                                    systemImage: preferredRunIcon
                                )
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                Haptics.selection()
                                runEditorRoute = alternateRunMode == .manual ? .manual : .gps
                            } label: {
                                Label(
                                    alternateRunLabel,
                                    systemImage: alternateRunIcon
                                )
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Section {
                        Button {
                            showFinishAlert = true
                        } label: {
                            Text("Finish Session")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showDiscardSessionAlert = true
                        } label: {
                            Text("Discard Session")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let undoMessage {
                        UndoSnackbar(
                            message: undoMessage,
                            onUndo: performUndo,
                            onDismiss: clearUndoState
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    if shouldShowMinimizedGPSRunBar {
                        minimizedGPSRunBar
                            .padding(.horizontal, 10)
                            .padding(.bottom, 6)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle(session.name.isEmpty ? "Session" : session.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            dismissKeyboard()
                        }
                    }
                }
                .sheet(isPresented: $showExercisePicker) {
                    ExercisePickerView(
                        exercises: store.state.exerciseLibrary,
                        onSelect: { store.addExerciseToActive($0) },
                        onCreateCustom: { name, category, equipment, defaultSets, defaultReps, defaultWeight in
                            store.addCustomExerciseToActive(
                                named: name,
                                category: category,
                                equipment: equipment,
                                defaultSets: defaultSets,
                                defaultReps: defaultReps,
                                defaultWeight: defaultWeight
                            )
                        }
                    )
                }
                .sheet(item: $runEditorRoute) { route in
                    RunEntryEditorView(
                        initialRun: store.state.activeSession?.run,
                        preferredMode: route.mode,
                        tracker: gpsTracker,
                        onMinimizeGPS: {
                            guard route.mode == .gps else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                runEditorRoute = nil
                            }
                        }
                    ) {
                        store.setRunEntry($0)
                    }
                    .interactiveDismissDisabled(route.mode == .gps && gpsTracker.isTracking)
                }
                .alert("Confirm Discard", isPresented: $showDiscardSessionAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Discard", role: .destructive) {
                        Haptics.warning()
                        gpsTracker.stopTracking()
                        store.discardActiveSession()
                        dismiss()
                    }
                } message: {
                    Text("This session and all unsaved changes will be removed.")
                }
                .alert("Finish Session", isPresented: $showFinishAlert) {
                    Button("Cancel", role: .cancel) {}
                    Button("Finish Session") {
                        completeSession()
                    }
                    Button("Finish + Save as Template") {
                        templateName = session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "New Template"
                            : session.name
                        showFinishTemplatePrompt = true
                    }
                } message: {
                    Text("Do you want to save this workout as a template before finishing?")
                }
                .alert("Save Template Before Finish", isPresented: $showFinishTemplatePrompt) {
                    TextField("Template name", text: $templateName)
                    Button("Cancel", role: .cancel) {}
                    Button("Save + Finish") {
                        completeSession(templateNameToSave: templateName)
                    }
                } message: {
                    Text("A template will be saved first, then the session will be completed.")
                }
            } else {
                ContentUnavailableView("No Active Session", systemImage: "figure.strengthtraining.traditional")
            }
        }
        .onDisappear {
            undoDismissTask?.cancel()
        }
        .alert("Session Complete", isPresented: $showCompletionAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text(completionMessage)
        }
    }

    private func sessionHeader(startedAt: Date) -> some View {
        VStack(alignment: .center, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = max(0, Int(context.date.timeIntervalSince(startedAt)))
                Text(formatDuration(elapsed))
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Text(startedAt.formatted(date: .complete, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatPacePerMile(_ secondsPerMile: Int) -> String {
        let minutes = secondsPerMile / 60
        let seconds = secondsPerMile % 60
        return String(format: "%d:%02d /mi", minutes, seconds)
    }

    private var shouldShowMinimizedGPSRunBar: Bool {
        gpsTracker.isTracking && runEditorRoute?.mode != .gps
    }

    private var minimizedGPSDistanceMiles: Double {
        gpsTracker.distanceMeters * 0.000621371
    }

    private var minimizedGPSPaceText: String {
        guard minimizedGPSDistanceMiles > 0, gpsTracker.elapsedSeconds > 0 else { return "--:-- /mi" }
        let secondsPerMile = Int((Double(gpsTracker.elapsedSeconds) / minimizedGPSDistanceMiles).rounded())
        return formatPacePerMile(secondsPerMile)
    }

    private var minimizedGPSRunBar: some View {
        Button {
            expandMinimizedGPSRun()
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.appAccent.opacity(0.24))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: "figure.run")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.appAccent)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Run in progress")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(formatDuration(gpsTracker.elapsedSeconds)) · \(minimizedGPSDistanceMiles, specifier: "%.2f") mi · \(minimizedGPSPaceText)")
                        .font(.subheadline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onEnded { value in
                    guard abs(value.translation.width) < 90 else { return }
                    if value.translation.height < -18 {
                        expandMinimizedGPSRun()
                    }
                }
        )
    }

    private func expandMinimizedGPSRun() {
        Haptics.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            runEditorRoute = .gps
        }
    }

    private func completeSession(templateNameToSave: String? = nil) {
        if gpsTracker.isTracking {
            gpsTracker.stopTracking()
        }

        if let templateNameToSave {
            let cleanTemplateName = templateNameToSave.trimmingCharacters(in: .whitespacesAndNewlines)
            store.createTemplateFromActiveSession(
                named: cleanTemplateName.isEmpty ? "New Template" : cleanTemplateName,
                folderID: nil
            )
        }

        guard let completed = store.completeActiveSession() else { return }
        if completed.achievements.isEmpty {
            completionMessage = "Session saved. No new PRs this time."
        } else {
            let lines = completed.achievements.prefix(4).map { "• \($0.title): \($0.valueText)" }
            completionMessage = "Session saved with \(completed.achievements.count) achievement\(completed.achievements.count == 1 ? "" : "s").\n\n" + lines.joined(separator: "\n")
        }
        Haptics.success()
        showCompletionAlert = true
    }

    private func showUndoMessage(_ message: String) {
        undoMessage = message
        undoDismissTask?.cancel()
        undoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                clearUndoState()
            }
        }
    }

    private func performUndo() {
        if let pendingDeletedSet {
            store.insertSet(exerciseID: pendingDeletedSet.exerciseID, set: pendingDeletedSet.set, at: pendingDeletedSet.index)
        } else if let pendingDeletedExercise {
            store.insertActiveExercise(pendingDeletedExercise.exercise, at: pendingDeletedExercise.index)
        }
        Haptics.success()
        clearUndoState()
    }

    private func clearUndoState() {
        undoDismissTask?.cancel()
        undoDismissTask = nil
        undoMessage = nil
        pendingDeletedSet = nil
        pendingDeletedExercise = nil
    }
}

struct ExerciseCardView: View {
    let exercise: LoggedExercise
    let previousSets: [LoggedSet]
    var onUpdateNotes: (String) -> Void
    var onAddSet: () -> Void
    var onDeleteSet: (UUID) -> Void
    var onToggleSetComplete: (UUID) -> Void
    var onUpdateSet: (_ setID: UUID, _ reps: Int?, _ weight: Double?, _ style: SetStyle?) -> Void
    @State private var notesExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .appText(.headline)
                        .foregroundStyle(.white)

                    Text("\(completedSetCount)/\(exercise.sets.count) sets complete")
                        .appText(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("\(exercise.sets.count)", systemImage: "list.number")
                    .appText(.caption)
                    .foregroundStyle(Color.appAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(Color.appAccent.opacity(0.18))
                    )
            }

            Button {
                Haptics.selection()
                withAnimation(.easeInOut(duration: 0.2)) {
                    notesExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: exercise.notes.isEmpty ? "square.and.pencil" : "note.text")
                    Text(exercise.notes.isEmpty ? "Add note" : "Edit note")
                    Spacer()
                    Image(systemName: notesExpanded ? "chevron.up" : "chevron.down")
                }
                .appText(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            exerciseGridHeader

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetRowView(
                    index: index + 1,
                    set: set,
                    previousSet: previousSet(at: index),
                    onStyleChange: { onUpdateSet(set.id, nil, nil, $0) },
                    onRepsChange: { onUpdateSet(set.id, $0, nil, nil) },
                    onWeightChange: { onUpdateSet(set.id, nil, $0, nil) },
                    onToggleComplete: { onToggleSetComplete(set.id) },
                    onDelete: { onDeleteSet(set.id) }
                )
            }

            Button {
                Haptics.impact(.light)
                onAddSet()
            } label: {
                Text("+ Add Set")
                    .appText(.button)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(0.95), Color.appAccent.opacity(0.72)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
            .foregroundStyle(.white)
            .buttonStyle(.plain)

            if notesExpanded {
                TextEditor(
                    text: Binding(
                        get: { exercise.notes },
                        set: { onUpdateNotes($0) }
                    )
                )
                .appText(.caption)
                .frame(minHeight: 36)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Color.appAccent.opacity(0.75))
                .frame(width: 84, height: 4)
                .padding(.top, 10)
                .padding(.leading, 12)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 6)
    }

    private var exerciseGridHeader: some View {
        HStack(spacing: 8) {
            Text("Set")
                .frame(width: 40, alignment: .leading)
            Text("Previous")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("lbs")
                .frame(width: 62, alignment: .center)
            Text("Reps")
                .frame(width: 54, alignment: .center)
            Image(systemName: "checkmark")
                .frame(width: 28)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.75))
    }

    private func previousSet(at index: Int) -> LoggedSet? {
        guard previousSets.indices.contains(index) else { return nil }
        return previousSets[index]
    }

    private var completedSetCount: Int {
        exercise.sets.filter(\.isCompleted).count
    }
}

struct SetRowView: View {
    let index: Int
    let set: LoggedSet
    let previousSet: LoggedSet?
    var onStyleChange: (SetStyle) -> Void
    var onRepsChange: (Int) -> Void
    var onWeightChange: (Double) -> Void
    var onToggleComplete: () -> Void
    var onDelete: () -> Void

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var settledOffset: CGFloat = 0

    private let deleteRevealWidth: CGFloat = 60
    private let fullSwipeDeleteThreshold: CGFloat = 108

    var body: some View {
        ZStack(alignment: .trailing) {
            deleteActionBackground

            rowContent
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                .gesture(deleteDragGesture)
                .onTapGesture {
                    closeSwipeIfNeeded()
                }
        }
        .clipped()
    }

    private var previousText: String {
        guard let previousSet else { return "--" }
        return "\(formatWeight(previousSet.weight)) lb x \(previousSet.reps)"
    }

    private func formatWeight(_ weight: Double) -> String {
        if abs(weight.rounded() - weight) < 0.001 {
            return String(format: "%.0f", weight)
        }
        return String(format: "%.1f", weight)
    }

    private var weightTextBinding: Binding<String> {
        Binding(
            get: {
                guard set.weight > 0 else { return "" }
                return formatWeight(set.weight)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    onWeightChange(0)
                    return
                }
                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                if let parsed = Double(normalized) {
                    onWeightChange(max(0, parsed))
                }
            }
        )
    }

    private var repsTextBinding: Binding<String> {
        Binding(
            get: {
                guard set.reps > 0 else { return "" }
                return "\(set.reps)"
            },
            set: { newValue in
                let digits = newValue.filter(\.isWholeNumber)
                guard !digits.isEmpty else {
                    onRepsChange(0)
                    return
                }
                if let parsed = Int(digits) {
                    onRepsChange(max(0, parsed))
                }
            }
        )
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SetStyle.allCases) { style in
                    Button {
                        Haptics.selection()
                        onStyleChange(style)
                    } label: {
                        Label(style.rawValue, systemImage: style.symbol)
                    }
                }
            } label: {
                Text("\(index)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [set.style.tint.opacity(0.32), set.style.tint.opacity(0.18)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(set.style.tint.opacity(0.88), lineWidth: 1.1)
                    )
            }

            Text(previousText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("0", text: weightTextBinding)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .frame(width: 62, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            TextField("0", text: repsTextBinding)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .frame(width: 54, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            Button {
                Haptics.selection()
                onToggleComplete()
            } label: {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(set.isCompleted ? .white : .white.opacity(0.45))
                    .frame(width: 28, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(set.isCompleted ? Color.appAccent.opacity(0.75) : Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private var deleteActionBackground: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button(role: .destructive) {
                performDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: deleteRevealWidth, height: 32)
                    .background(
                        Color.red,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .frame(width: revealedDeleteWidth, alignment: .trailing)
            .clipped()
            .opacity(revealedDeleteWidth > 0 ? 1 : 0)
            .allowsHitTesting(revealedDeleteWidth >= deleteRevealWidth * 0.9)
        }
    }

    private var deleteDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                let proposed = settledOffset + value.translation.width
                state = clampedOffset(for: proposed) - settledOffset
            }
            .onEnded { value in
                let proposed = settledOffset + value.translation.width
                let clamped = clampedOffset(for: proposed)
                let predicted = settledOffset + value.predictedEndTranslation.width

                if predicted < -fullSwipeDeleteThreshold {
                    performDelete()
                    return
                }

                withAnimation(.easeInOut(duration: 0.18)) {
                    settledOffset = clamped < -deleteRevealWidth * 0.45 ? -deleteRevealWidth : 0
                }
            }
    }

    private func closeSwipeIfNeeded() {
        guard settledOffset != 0 else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            settledOffset = 0
        }
    }

    private func performDelete() {
        withAnimation(.easeInOut(duration: 0.18)) {
            settledOffset = 0
        }
        onDelete()
    }

    private var currentOffset: CGFloat {
        clampedOffset(for: settledOffset + dragTranslation)
    }

    private var revealedDeleteWidth: CGFloat {
        min(deleteRevealWidth, max(0, -currentOffset))
    }

    private func clampedOffset(for proposed: CGFloat) -> CGFloat {
        min(0, max(-deleteRevealWidth, proposed))
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss

    let exercises: [ExerciseDefinition]
    let onSelect: (ExerciseDefinition) -> Void
    var allowsMultiSelect: Bool = false
    let onCreateCustom: (
        _ name: String,
        _ category: ExerciseCategory?,
        _ equipment: ExerciseEquipment?,
        _ defaultSets: Int?,
        _ defaultReps: Int?,
        _ defaultWeight: Double?
    ) -> Void

    @State private var searchText = ""
    @State private var customName = ""
    @State private var selectedCategory: ExerciseCategory? = nil
    @State private var customCategory: ExerciseCategory = .custom
    @State private var customEquipment: ExerciseEquipment = .none
    @State private var customSets: Int = 1
    @State private var customReps: Int = 8
    @State private var customWeight: Double = 0
    @State private var useCustomDefaults = false
    @State private var showCustomCreator = false
    @State private var selectedExerciseIDs: Set<UUID> = []

    private var filtered: [ExerciseDefinition] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return exercises
            .filter { exercise in
                let categoryMatch = selectedCategory == nil || exercise.category == selectedCategory
                let searchMatch = trimmed.isEmpty || exercise.name.localizedCaseInsensitiveContains(trimmed)
                return categoryMatch && searchMatch
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var customWeightTextBinding: Binding<String> {
        Binding(
            get: {
                guard customWeight > 0 else { return "" }
                if abs(customWeight.rounded() - customWeight) < 0.001 {
                    return String(format: "%.0f", customWeight)
                }
                return String(format: "%.1f", customWeight)
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    customWeight = 0
                    return
                }
                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                if let parsed = Double(normalized) {
                    customWeight = max(0, parsed)
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Browse") {
                    Picker("Muscle Group", selection: $selectedCategory) {
                        Text("All").tag(Optional<ExerciseCategory>.none)
                        ForEach(ExerciseCategory.allCases, id: \.rawValue) { category in
                            Text(category.rawValue).tag(Optional(category))
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Showing: \(selectedCategory?.rawValue ?? "All")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Haptics.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showCustomCreator.toggle()
                        }
                    } label: {
                        HStack {
                            Label("Create + Add Exercise", systemImage: "plus.circle.fill")
                            Spacer()
                            Image(systemName: showCustomCreator ? "chevron.up" : "chevron.down")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if showCustomCreator {
                        TextField("Exercise name", text: $customName)

                        Picker("Category", selection: $customCategory) {
                            ForEach(ExerciseCategory.allCases, id: \.rawValue) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Equipment", selection: $customEquipment) {
                            ForEach(ExerciseEquipment.allCases) { equipment in
                                Text(equipment.rawValue).tag(equipment)
                            }
                        }
                        .pickerStyle(.menu)

                        Toggle("Set default set/rep/weight", isOn: $useCustomDefaults)

                        if useCustomDefaults {
                            Stepper("Sets: \(customSets)", value: $customSets, in: 1...12)
                            Stepper("Reps: \(customReps)", value: $customReps, in: 0...50)

                            TextField("Weight (lb)", text: customWeightTextBinding)
                            .keyboardType(.decimalPad)
                        }

                        Button {
                            Haptics.impact(.light)
                            createCustomExercise()
                        } label: {
                            Text("Create and Add Now")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section(selectedCategory?.rawValue ?? "All Exercises") {
                    if filtered.isEmpty {
                        Text("No exercises in this selection")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(filtered) { exercise in
                        Button {
                            if allowsMultiSelect {
                                Haptics.selection()
                                toggleSelection(for: exercise.id)
                            } else {
                                Haptics.selection()
                                onSelect(exercise)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(exercise.name)
                                Spacer()
                                if allowsMultiSelect {
                                    Image(systemName: selectedExerciseIDs.contains(exercise.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedExerciseIDs.contains(exercise.id) ? Color.appAccent : .secondary)
                                }
                                if exercise.isCustom {
                                    Text("Custom")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if allowsMultiSelect {
                    Section {
                        Button {
                            Haptics.impact(.light)
                            addSelectedExercises()
                        } label: {
                            Text("Add Selected (\(selectedExerciseIDs.count))")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedExerciseIDs.isEmpty)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $searchText)
            .navigationTitle("Exercise Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
            .onChange(of: selectedCategory) { _, newValue in
                if let newValue {
                    customCategory = newValue
                }
            }
        }
    }

    private func createCustomExercise() {
        let clean = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        onCreateCustom(
            clean,
            customCategory,
            customEquipment,
            useCustomDefaults ? customSets : nil,
            useCustomDefaults ? customReps : nil,
            useCustomDefaults ? customWeight : nil
        )
        dismiss()
    }

    private func toggleSelection(for id: UUID) {
        if selectedExerciseIDs.contains(id) {
            selectedExerciseIDs.remove(id)
        } else {
            selectedExerciseIDs.insert(id)
        }
    }

    private func addSelectedExercises() {
        let selected = exercises.filter { selectedExerciseIDs.contains($0.id) }
        for exercise in selected {
            onSelect(exercise)
        }
        dismiss()
    }
}

struct RunEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TrainingStore

    let initialRun: RunEntry?
    let preferredMode: RunMode
    @ObservedObject var tracker: GPSRunTracker
    var onMinimizeGPS: () -> Void
    let onSave: (RunEntry) -> [RunningPRRecord]

    @State private var manualDistanceInput = ""
    @State private var manualPaceInput = ""
    @State private var manualTimeInput = ""
    @State private var notes: String = ""
    @State private var showManualDurationPicker = false
    @State private var showGPSSummary = false
    @State private var gpsSummaryDistanceMiles: Double = 0
    @State private var gpsSummaryDurationSeconds: Int = 0
    @State private var gpsSummaryRoute: [CoordinatePoint] = []
    @State private var gpsSummarySplits: [RunSplit] = []
    @State private var showLiveRoutePreview = false
    @State private var gpsSummaryNotesExpanded = false
    @State private var suppressManualRecalc = false
    @State private var showNewPRAnnouncement = false
    @State private var announcedPRTypes: [RunningPRType] = []
    @State private var dismissAfterPRTask: Task<Void, Never>?

    private enum ManualInputField {
        case distance
        case pace
        case time
    }

    var body: some View {
        NavigationStack {
            Group {
                if preferredMode == .manual {
                    manualRunForm
                } else {
                    gpsRunScreen
                }
            }
            .navigationTitle(navigationTitleText)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if preferredMode == .gps {
                            tracker.stopTracking()
                        }
                        dismiss()
                    }
                }

                if preferredMode == .manual {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            saveRun()
                        }
                        .disabled(saveDisabled)
                    }
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
        }
        .sheet(isPresented: $showManualDurationPicker) {
            DurationWheelPickerSheet(initialSeconds: parsedManualTimeSeconds(manualTimeInput) ?? 0) { selectedSeconds in
                manualTimeInput = formatDuration(selectedSeconds)
            }
        }
        .onAppear {
            showLiveRoutePreview = false
            gpsSummaryNotesExpanded = false
            if preferredMode == .gps, tracker.isTracking {
                showGPSSummary = false
            }
            if let initialRun {
                notes = initialRun.notes
                if initialRun.mode == .manual, preferredMode == .manual {
                    if initialRun.distanceMiles > 0 {
                        manualDistanceInput = formatDecimal(initialRun.distanceMiles, maxFraction: 2)
                    }
                    if initialRun.durationSeconds > 0 {
                        manualTimeInput = formatDuration(initialRun.durationSeconds)
                    }
                    if initialRun.distanceMiles > 0, initialRun.durationSeconds > 0 {
                        let pace = Double(initialRun.durationSeconds) / 60 / initialRun.distanceMiles
                        manualPaceInput = formatDecimal(pace, maxFraction: 2)
                    }
                }
                if initialRun.mode == .gps, preferredMode == .gps, !tracker.isTracking {
                    gpsSummaryDistanceMiles = initialRun.distanceMiles
                    gpsSummaryDurationSeconds = initialRun.durationSeconds
                    gpsSummaryRoute = initialRun.route ?? []
                    gpsSummarySplits = initialRun.splits
                    showGPSSummary = initialRun.distanceMiles > 0 || initialRun.durationSeconds > 0
                }
            }
        }
        .onChange(of: manualDistanceInput) { _, _ in
            recalculateManual(from: .distance)
        }
        .onChange(of: manualPaceInput) { _, _ in
            recalculateManual(from: .pace)
        }
        .onChange(of: manualTimeInput) { _, newValue in
            let sanitized = sanitizedManualTimeInput(newValue)
            if sanitized != newValue {
                manualTimeInput = sanitized
                return
            }
            recalculateManual(from: .time)
        }
        .overlay(alignment: .top) {
            if showNewPRAnnouncement {
                newPRAnnouncementView
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onDisappear {
            dismissAfterPRTask?.cancel()
        }
    }

    private var navigationTitleText: String {
        if preferredMode == .manual {
            return "Manual Run"
        }
        return showGPSSummary ? "Run Summary" : "GPS Run"
    }

    private var manualRunForm: some View {
        Form {
            Section {
                Label("Manual treadmill entry", systemImage: "figure.run")
                    .foregroundStyle(.secondary)
            }

            Section("Manual Run Input") {
                TextField("", text: $manualDistanceInput, prompt: Text("Distance (mi), e.g. 3.10"))
                    .keyboardType(.decimalPad)

                TextField("", text: $manualPaceInput, prompt: Text("Pace (min/mi), e.g. 8.50"))
                    .keyboardType(.decimalPad)

                Button {
                    showManualDurationPicker = true
                } label: {
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(manualTimeInput.isEmpty ? "Select HH:MM:SS" : manualTimeInput)
                            .foregroundStyle(manualTimeInput.isEmpty ? .secondary : .primary)
                            .monospacedDigit()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 96)
            }
        }
    }

    private var gpsRunScreen: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.96),
                    Color(red: 0.04, green: 0.05, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showGPSSummary {
                ScrollView {
                    VStack(spacing: 14) {
                        gpsPermissionBanner
                        gpsSummaryCard
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 20) {
                    gpsPermissionBanner

                    if canMinimizeLiveGPSRun {
                        Text("Swipe down to minimize")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Text(formatDuration(tracker.elapsedSeconds))
                        .font(.system(size: 68, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 8) {
                        Text(gpsLivePaceText)
                            .font(.system(size: 76, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                        Text("Avg. pace (/mi)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    VStack(spacing: 8) {
                        Text(String(format: "%.2f", gpsLiveDistanceMiles))
                            .font(.system(size: 88, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)
                        Text("Distance (mi)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.white.opacity(0.24))
                                    .frame(height: 34)
                                    .overlay {
                                        Text(liveSplitText(at: index))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                            }
                        }
                        Text("Splits (mi)")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                    }

                    if showLiveRoutePreview {
                        RunRouteMapView(route: tracker.route)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .safeAreaInset(edge: .bottom) {
                    gpsBottomDock
                }
                .simultaneousGesture(gpsMinimizeGesture)
            }
        }
    }

    private var gpsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Run Complete")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)

            HStack(spacing: 10) {
                gpsMetricTile(title: "Distance", value: String(format: "%.2f", gpsSummaryDistanceMiles), unit: "mi")
                gpsMetricTile(title: "Avg Pace", value: gpsSummaryPaceText, unit: "/mi")
            }

            gpsMetricTile(title: "Duration", value: formatDuration(gpsSummaryDurationSeconds), unit: "")
                .frame(maxWidth: .infinity, alignment: .leading)

            if !gpsSummaryRoute.isEmpty {
                RunRouteMapView(route: gpsSummaryRoute)
            }

            if !gpsSummarySplits.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Splits")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    ForEach(gpsSummarySplits.prefix(8)) { split in
                        HStack {
                            Text("Split \(split.index)")
                                .font(.caption)
                            Spacer()
                            Text("\(split.distanceMiles, specifier: "%.2f") mi")
                                .font(.caption.monospacedDigit())
                            Text(formatDuration(split.durationSeconds))
                                .font(.caption.monospacedDigit())
                                .frame(width: 78, alignment: .trailing)
                            Text(formatPacePerMile(split.paceSecPerMile))
                                .font(.caption.monospacedDigit())
                                .frame(width: 72, alignment: .trailing)
                        }
                    }
                    if gpsSummarySplits.count > 8 {
                        Text("+ \(gpsSummarySplits.count - 8) more splits")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.18)) {
                        gpsSummaryNotesExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.86))
                        Spacer()
                        Image(systemName: gpsSummaryNotesExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.76))
                    }
                }
                .buttonStyle(.plain)

                if gpsSummaryNotesExpanded {
                    TextEditor(text: $notes)
                        .frame(minHeight: 86)
                        .padding(4)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if !trimmedRunNotes.isEmpty {
                    Text(trimmedRunNotes)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.74))
                } else {
                    Text("Add notes")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                saveRun()
            } label: {
                Text("Save Run")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(saveDisabled)

            Button {
                Haptics.selection()
                showGPSSummary = false
            } label: {
                Text("Back to Live Screen")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("Last offline save: \(store.lastSavedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var gpsPermissionBanner: some View {
        if tracker.authorizationStatus == .denied || tracker.authorizationStatus == .restricted {
            VStack(alignment: .leading, spacing: 8) {
                Label("Location Access Needed", systemImage: "location.slash.fill")
                    .font(.subheadline.weight(.semibold))
                Text("Enable location access in iOS Settings to track GPS distance and pace.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else if tracker.authorizationStatus == .notDetermined {
            Button("Allow Location") {
                tracker.requestPermission()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var gpsBottomDock: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 46, height: 5)
                .padding(.top, 8)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(tracker.isTracking ? "Live GPS Run" : "GPS Ready")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.72))
                    Text("\(formatDuration(tracker.elapsedSeconds)) · \(gpsLiveDistanceMiles, specifier: "%.2f") mi · \(gpsLivePaceText) /mi")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(.white)
                }
                Spacer()

                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showLiveRoutePreview.toggle()
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: showLiveRoutePreview ? "map.fill" : "map")
                            .font(.subheadline.weight(.semibold))
                        Text(showLiveRoutePreview ? "Hide" : "Route")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(showLiveRoutePreview ? Color.appAccent : .white.opacity(0.84))
                    .frame(width: 64, height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(showLiveRoutePreview ? Color.appAccent.opacity(0.22) : Color.white.opacity(0.14))
                    )
                }
                .buttonStyle(.plain)
                .disabled(!hasLiveRoute)
                .opacity(hasLiveRoute ? 1 : 0.45)
            }

            Button {
                handleGPSPrimaryAction()
            } label: {
                Label(tracker.isTracking ? "End Run" : "Start Run", systemImage: tracker.isTracking ? "stop.fill" : "play.fill")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tracker.isTracking ? Color.red.opacity(0.96) : Color.appAccent)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!tracker.canTrack && tracker.authorizationStatus != .notDetermined)
            .opacity((!tracker.canTrack && tracker.authorizationStatus != .notDetermined) ? 0.45 : 1)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.78))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
    }

    private var hasLiveRoute: Bool {
        !tracker.route.isEmpty
    }

    private var canMinimizeLiveGPSRun: Bool {
        preferredMode == .gps && tracker.isTracking && !showGPSSummary
    }

    private var gpsMinimizeGesture: some Gesture {
        DragGesture(minimumDistance: 22)
            .onEnded { value in
                guard canMinimizeLiveGPSRun else { return }
                let verticalTravel = value.translation.height
                let horizontalTravel = abs(value.translation.width)
                guard verticalTravel > 100, verticalTravel > horizontalTravel else { return }
                Haptics.selection()
                onMinimizeGPS()
            }
    }

    private var liveSplitPreview: [String] {
        let splits = store.computeRunSplits(
            route: tracker.route,
            duration: tracker.elapsedSeconds,
            distanceMiles: gpsLiveDistanceMiles
        )
        return Array(splits.prefix(3)).map { formatPacePerMile($0.paceSecPerMile) }
    }

    private func liveSplitText(at index: Int) -> String {
        guard liveSplitPreview.indices.contains(index) else {
            return "--:--"
        }
        return liveSplitPreview[index]
    }

    private var trimmedRunNotes: String {
        notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var orderedAnnouncedPRTypes: [RunningPRType] {
        RunningPRType.allCases.filter { announcedPRTypes.contains($0) }
    }

    private var newPRAnnouncementView: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "rosette")
                .font(.headline)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(orderedAnnouncedPRTypes.count > 1 ? "New PRs" : "New PR")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(orderedAnnouncedPRTypes.map(\.title).joined(separator: " • "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.appAccent.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 10, y: 4)
    }

    private func announceNewPRsAndDismiss(_ records: [RunningPRRecord]) {
        dismissAfterPRTask?.cancel()
        announcedPRTypes = records.map(\.type)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showNewPRAnnouncement = true
        }

        dismissAfterPRTask = Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showNewPRAnnouncement = false
                }
                dismiss()
            }
        }
    }

    private func handleGPSPrimaryAction() {
        if tracker.isTracking {
            endGPSRunAndShowSummary()
        } else {
            Haptics.impact(.medium)
            tracker.startTracking()
        }
    }

    private func gpsMetricTile(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title3.weight(.semibold).monospacedDigit())
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var gpsLiveDistanceMiles: Double {
        tracker.distanceMeters * 0.000621371
    }

    private var gpsLivePaceText: String {
        paceText(distanceMiles: gpsLiveDistanceMiles, durationSeconds: tracker.elapsedSeconds)
    }

    private var gpsSummaryPaceText: String {
        paceText(distanceMiles: gpsSummaryDistanceMiles, durationSeconds: gpsSummaryDurationSeconds)
    }

    private func paceText(distanceMiles: Double, durationSeconds: Int) -> String {
        guard distanceMiles > 0, durationSeconds > 0 else { return "--:--" }
        let pace = Double(durationSeconds) / 60 / distanceMiles
        return formatPace(pace)
    }

    private func formatPacePerMile(_ secondsPerMile: Int) -> String {
        let clamped = max(0, secondsPerMile)
        let minutes = clamped / 60
        let seconds = clamped % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func endGPSRunAndShowSummary() {
        if tracker.isTracking {
            Haptics.warning()
            tracker.stopTracking()
        }

        let liveDistance = tracker.distanceMeters * 0.000621371
        let liveDuration = tracker.elapsedSeconds

        if liveDistance > 0 || liveDuration > 0 || !tracker.route.isEmpty {
            gpsSummaryDistanceMiles = liveDistance
            gpsSummaryDurationSeconds = liveDuration
            gpsSummaryRoute = tracker.route
            gpsSummarySplits = store.computeRunSplits(
                route: tracker.route,
                duration: liveDuration,
                distanceMiles: liveDistance
            )
        } else if let initialRun, initialRun.mode == .gps {
            gpsSummaryDistanceMiles = initialRun.distanceMiles
            gpsSummaryDurationSeconds = initialRun.durationSeconds
            gpsSummaryRoute = initialRun.route ?? []
            gpsSummarySplits = initialRun.splits
        }

        showLiveRoutePreview = false
        gpsSummaryNotesExpanded = false
        withAnimation(.easeInOut(duration: 0.2)) {
            showGPSSummary = true
        }
    }

    private var saveDisabled: Bool {
        switch preferredMode {
        case .manual:
            let distance = parsedPositiveDouble(manualDistanceInput) ?? 0
            let time = Double(parsedManualTimeSeconds(manualTimeInput) ?? 0)
            let hasCurrent = distance > 0 || time > 0
            let hasExistingManual = initialRun?.mode == .manual &&
                ((initialRun?.durationSeconds ?? 0) > 0 || (initialRun?.distanceMiles ?? 0) > 0)
            return !(hasCurrent || hasExistingManual)
        case .gps:
            let hasLive = tracker.elapsedSeconds > 0 || tracker.distanceMeters > 0
            let hasSummary = gpsSummaryDurationSeconds > 0 || gpsSummaryDistanceMiles > 0
            let hasInitialGPS = initialRun?.mode == .gps &&
                ((initialRun?.durationSeconds ?? 0) > 0 || (initialRun?.distanceMiles ?? 0) > 0)
            return !(hasSummary || hasLive || hasInitialGPS)
        }
    }

    private func saveRun() {
        var entry: RunEntry
        switch preferredMode {
        case .manual:
            var distance = parsedPositiveDouble(manualDistanceInput) ?? 0
            var duration = parsedManualTimeSeconds(manualTimeInput) ?? 0
            let pace = parsedPositiveDouble(manualPaceInput) ?? 0

            if distance <= 0, duration > 0, pace > 0 {
                distance = Double(duration) / 60 / pace
            }
            if duration <= 0, distance > 0, pace > 0 {
                duration = Int((distance * pace * 60).rounded())
            }

            let averagePace = (distance > 0 && duration > 0) ? Int((Double(duration) / distance).rounded()) : nil

            entry = RunEntry(
                mode: .manual,
                distanceMiles: max(0, distance),
                durationSeconds: max(0, duration),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                route: nil,
                splits: [],
                avgPaceSecPerMile: averagePace,
                elevationGainFeet: nil,
                distanceSource: .manual,
                elapsedSeconds: max(0, duration),
                movingSeconds: max(0, duration),
                avgPaceElapsedSecPerMile: averagePace,
                avgPaceMovingSecPerMile: averagePace,
                elevationLossFeet: nil,
                minElevationFeet: nil,
                maxElevationFeet: nil,
                elevationSeries: []
            )

        case .gps:
            if tracker.isTracking {
                endGPSRunAndShowSummary()
                return
            }

            let liveDistance = tracker.distanceMeters * 0.000621371
            let liveDuration = tracker.elapsedSeconds

            let distance: Double
            if gpsSummaryDistanceMiles > 0 {
                distance = gpsSummaryDistanceMiles
            } else if liveDistance > 0 {
                distance = liveDistance
            } else {
                distance = initialRun?.distanceMiles ?? 0
            }

            let duration: Int
            if gpsSummaryDurationSeconds > 0 {
                duration = gpsSummaryDurationSeconds
            } else if liveDuration > 0 {
                duration = liveDuration
            } else {
                duration = initialRun?.durationSeconds ?? 0
            }

            let route: [CoordinatePoint]?
            if !gpsSummaryRoute.isEmpty {
                route = gpsSummaryRoute
            } else if !tracker.route.isEmpty {
                route = tracker.route
            } else {
                route = initialRun?.route
            }

            let splits: [RunSplit]
            if !gpsSummarySplits.isEmpty {
                splits = gpsSummarySplits
            } else {
                splits = store.computeRunSplits(route: route, duration: max(0, duration), distanceMiles: max(0, distance))
            }
            let averagePace = (distance > 0 && duration > 0) ? Int((Double(duration) / distance).rounded()) : nil
            let source: DistanceSource = (route?.isEmpty == false) ? .gps : .estimated

            entry = RunEntry(
                mode: .gps,
                distanceMiles: max(0, distance),
                durationSeconds: max(0, duration),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                route: route,
                splits: splits,
                avgPaceSecPerMile: averagePace,
                elevationGainFeet: nil,
                distanceSource: source,
                elapsedSeconds: max(0, duration),
                movingSeconds: max(0, duration),
                avgPaceElapsedSecPerMile: averagePace,
                avgPaceMovingSecPerMile: averagePace,
                elevationLossFeet: nil,
                minElevationFeet: nil,
                maxElevationFeet: nil,
                elevationSeries: []
            )
        }

        let newPRs = onSave(entry)
        Haptics.success()
        if preferredMode == .gps, !newPRs.isEmpty {
            announceNewPRsAndDismiss(newPRs)
        } else {
            dismiss()
        }
    }

    private func recalculateManual(from changedField: ManualInputField) {
        guard !suppressManualRecalc else { return }
        suppressManualRecalc = true
        defer { suppressManualRecalc = false }

        let distance = parsedPositiveDouble(manualDistanceInput)
        let pace = parsedPositiveDouble(manualPaceInput)
        let time = parsedManualTimeSeconds(manualTimeInput).map { Double($0) }

        switch changedField {
        case .distance:
            if let distance, let pace {
                manualTimeInput = formatDuration(Int((distance * pace * 60).rounded()))
            } else if let distance, let time {
                manualPaceInput = formatDecimal(time / 60 / distance, maxFraction: 2)
            }

        case .pace:
            if let pace, let distance {
                manualTimeInput = formatDuration(Int((distance * pace * 60).rounded()))
            } else if let pace, let time {
                manualDistanceInput = formatDecimal(time / 60 / pace, maxFraction: 2)
            }

        case .time:
            if let time, let distance {
                manualPaceInput = formatDecimal(time / 60 / distance, maxFraction: 2)
            } else if let time, let pace {
                manualDistanceInput = formatDecimal(time / 60 / pace, maxFraction: 2)
            }
        }
    }

    private func formatPace(_ minutesPerMile: Double) -> String {
        guard minutesPerMile > 0 else { return "--:--" }
        let totalSeconds = Int((minutesPerMile * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func parsedPositiveDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }

    private func formatDecimal(_ value: Double, maxFraction: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFraction
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func sanitizedManualTimeInput(_ text: String) -> String {
        let filtered = text.filter { $0.isNumber || $0 == ":" }
        let parts = filtered.split(separator: ":", omittingEmptySubsequences: false)
        var limited: [String] = []

        for part in parts.prefix(3) {
            limited.append(String(part.prefix(2)))
        }

        return limited.joined(separator: ":")
    }

    private func parsedManualTimeSeconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3 else { return nil }

        guard
            let hours = Int(parts[0]),
            let minutes = Int(parts[1]),
            let seconds = Int(parts[2]),
            hours >= 0,
            minutes >= 0, minutes < 60,
            seconds >= 0, seconds < 60
        else { return nil }

        return hours * 3600 + minutes * 60 + seconds
    }
}

struct DurationWheelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onApply: (Int) -> Void

    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int

    init(initialSeconds: Int, onApply: @escaping (Int) -> Void) {
        let clamped = max(0, initialSeconds)
        _hours = State(initialValue: min(23, clamped / 3600))
        _minutes = State(initialValue: (clamped % 3600) / 60)
        _seconds = State(initialValue: clamped % 60)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    wheelPicker(title: "Hr", selection: $hours, range: 0..<24)
                    wheelPicker(title: "Min", selection: $minutes, range: 0..<60)
                    wheelPicker(title: "Sec", selection: $seconds, range: 0..<60)
                }
                .frame(height: 180)

                Text(formatDuration(totalSeconds))
                    .font(.title2.weight(.semibold).monospacedDigit())

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Select Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onApply(totalSeconds)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(340)])
    }

    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private func wheelPicker(title: String, selection: Binding<Int>, range: Range<Int>) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
    }
}

struct TemplatesView: View {
    @EnvironmentObject private var store: TrainingStore

    @State private var selectedFolderID: UUID?
    @State private var showNewTemplatePrompt = false
    @State private var showNewFolderPrompt = false
    @State private var newTemplateName = ""
    @State private var newFolderName = ""

    private var filteredTemplates: [WorkoutTemplate] {
        store.templatesSorted.filter { template in
            if let selectedFolderID {
                return template.folderID == selectedFolderID
            }
            return true
        }
    }

    var body: some View {
        List {
            if !store.foldersSorted.isEmpty {
                Section("Folders") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            folderChip(title: "All", isSelected: selectedFolderID == nil) {
                                selectedFolderID = nil
                            }

                            ForEach(store.foldersSorted) { folder in
                                folderChip(title: folder.name, isSelected: selectedFolderID == folder.id) {
                                    selectedFolderID = folder.id
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        if selectedFolderID == folder.id {
                                            selectedFolderID = nil
                                        }
                                        store.deleteFolder(folder.id)
                                    } label: {
                                        Label("Delete Folder", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Templates") {
                if filteredTemplates.isEmpty {
                    Text("No templates yet")
                        .foregroundStyle(.secondary)
                }

                ForEach(filteredTemplates) { template in
                    NavigationLink {
                        TemplateEditorView(templateID: template.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.headline)
                            Text("\(template.exercises.count) exercises")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            store.deleteTemplate(template.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("New Template") {
                        newTemplateName = ""
                        showNewTemplatePrompt = true
                    }
                    Button("New Folder") {
                        newFolderName = ""
                        showNewFolderPrompt = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Template", isPresented: $showNewTemplatePrompt) {
            TextField("Template name", text: $newTemplateName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                _ = store.createTemplate(named: newTemplateName, folderID: selectedFolderID)
            }
        }
        .alert("New Folder", isPresented: $showNewFolderPrompt) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                store.createFolder(named: newFolderName)
            }
        }
    }

    private func folderChip(title: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appAccent.opacity(0.25) : Color.secondary.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct TemplateEditorView: View {
    @EnvironmentObject private var store: TrainingStore

    let templateID: UUID

    @State private var showExercisePicker = false
    @State private var showSavedAlert = false

    private var template: WorkoutTemplate? {
        store.state.templates.first(where: { $0.id == templateID })
    }

    var body: some View {
        Group {
            if let template {
                templateContent(template)
            } else {
                ContentUnavailableView("Template not found", systemImage: "doc.badge.gearshape")
            }
        }
    }

    private func templateContent(_ template: WorkoutTemplate) -> some View {
        List {
            templateMetaSection(template)
            templateExercisesSection(template)
        }
        .navigationTitle(template.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showExercisePicker = true
                } label: {
                    Label("Add", systemImage: "plus")
                }

                Button("Save") {
                    showSavedAlert = true
                }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView(
                exercises: store.state.exerciseLibrary,
                onSelect: { store.addExerciseToTemplate(template.id, definition: $0) },
                allowsMultiSelect: true,
                onCreateCustom: { name, category, equipment, defaultSets, defaultReps, defaultWeight in
                    store.addCustomExerciseToTemplate(
                        template.id,
                        name: name,
                        category: category,
                        equipment: equipment,
                        defaultSets: defaultSets,
                        defaultReps: defaultReps,
                        defaultWeight: defaultWeight
                    )
                }
            )
        }
        .alert("Template Saved", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Template changes are saved.")
        }
    }

    private func templateMetaSection(_ template: WorkoutTemplate) -> some View {
        Section("Template") {
            TextField(
                "Name",
                text: Binding(
                    get: { template.name },
                    set: { store.renameTemplate(template.id, name: $0) }
                )
            )

            Picker(
                "Folder",
                selection: Binding(
                    get: { template.folderID },
                    set: { store.assignTemplate(template.id, to: $0) }
                )
            ) {
                Text("None").tag(UUID?.none)
                ForEach(store.foldersSorted) { folder in
                    Text(folder.name).tag(Optional(folder.id))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(
                    text: Binding(
                        get: { template.notes },
                        set: { store.updateTemplateNotes(template.id, notes: $0) }
                    )
                )
                .frame(minHeight: 80)
            }
        }
    }

    private func templateExercisesSection(_ template: WorkoutTemplate) -> some View {
        Section("Exercises") {
            ForEach(template.exercises) { exercise in
                templateExerciseRow(template: template, exercise: exercise)
            }
            .onDelete { offsets in
                store.removeTemplateExercise(templateID: template.id, at: offsets)
            }

            Button {
                showExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
            }
        }
    }

    private func templateExerciseRow(template: WorkoutTemplate, exercise: TemplateExercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(
                "Exercise",
                text: Binding(
                    get: { exercise.name },
                    set: {
                        store.updateTemplateExercise(
                            templateID: template.id,
                            exerciseID: exercise.id,
                            name: $0
                        )
                    }
                )
            )

            templateCounterRow(
                title: "Sets",
                value: exercise.defaultSets,
                onMinus: {
                    store.updateTemplateExercise(
                        templateID: template.id,
                        exerciseID: exercise.id,
                        sets: max(1, exercise.defaultSets - 1)
                    )
                },
                onPlus: {
                    store.updateTemplateExercise(
                        templateID: template.id,
                        exerciseID: exercise.id,
                        sets: exercise.defaultSets + 1
                    )
                }
            )

            templateCounterRow(
                title: "Reps",
                value: exercise.defaultReps,
                onMinus: {
                    store.updateTemplateExercise(
                        templateID: template.id,
                        exerciseID: exercise.id,
                        reps: max(0, exercise.defaultReps - 1)
                    )
                },
                onPlus: {
                    store.updateTemplateExercise(
                        templateID: template.id,
                        exerciseID: exercise.id,
                        reps: exercise.defaultReps + 1
                    )
                }
            )

            HStack {
                Text("Weight (lb)")
                    .font(.subheadline)
                Spacer()
                TextField(
                    "0",
                    value: Binding(
                        get: { exercise.defaultWeight ?? 0 },
                        set: {
                            store.updateTemplateExercise(
                                templateID: template.id,
                                exerciseID: exercise.id,
                                weight: max(0, $0)
                            )
                        }
                    ),
                    format: .number.precision(.fractionLength(0...1))
                )
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            }
        }
        .padding(.vertical, 4)
    }

    private func templateCounterRow(
        title: String,
        value: Int,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
            Spacer()
            Button(action: onMinus) {
                Image(systemName: "minus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)

            Text("\(value)")
                .font(.headline.monospacedDigit())
                .frame(width: 30)

            Button(action: onPlus) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
        }
    }
}

struct HistoryView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case list = "List"
        case calendar = "Calendar"

        var id: String { rawValue }
    }

    @EnvironmentObject private var store: TrainingStore

    @State private var displayMode: DisplayMode = .list
    @State private var selectedDate = Date()
    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var deletedSessionsBuffer: [WorkoutSession] = []
    @State private var showUndoDelete = false
    @State private var undoTask: Task<Void, Never>?

    private var workoutDays: Set<Date> {
        let calendar = Calendar.current
        return Set(store.state.sessions.map { calendar.startOfDay(for: $0.completedAt) })
    }

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch displayMode {
            case .list:
                sessionsSection(title: "All Sessions", sessions: store.sessionsNewestFirst)

            case .calendar:
                Section("Choose Date") {
                    HistoryMonthCalendarView(
                        displayedMonth: displayedMonth,
                        selectedDate: selectedDate,
                        workoutDays: workoutDays,
                        weekStartsOnMonday: store.state.preferences.weekStartsOnMonday,
                        onSelectDate: { date in
                            selectedDate = date
                            displayedMonth = Calendar.current.startOfMonth(for: date)
                        },
                        onPreviousMonth: showPreviousMonth,
                        onNextMonth: showNextMonth
                    )
                }

                sessionsSection(title: "Sessions on \(selectedDate.formatted(date: .abbreviated, time: .omitted))", sessions: store.sessions(on: selectedDate))
            }
        }
        .overlay(alignment: .bottom) {
            if showUndoDelete {
                UndoSnackbar(
                    message: "Session deleted",
                    onUndo: {
                        Haptics.success()
                        store.restoreSessions(deletedSessionsBuffer)
                        clearUndo()
                    },
                    onDismiss: clearUndo
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("History")
        .onAppear {
            displayedMonth = Calendar.current.startOfMonth(for: selectedDate)
        }
        .onChange(of: selectedDate) { _, newValue in
            let targetMonth = Calendar.current.startOfMonth(for: newValue)
            if !Calendar.current.isDate(targetMonth, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = targetMonth
            }
        }
        .onDisappear {
            undoTask?.cancel()
        }
    }

    private func sessionsSection(title: String, sessions: [WorkoutSession]) -> some View {
        Section(title) {
            if sessions.isEmpty {
                Text("No sessions")
                    .foregroundStyle(.secondary)
            }

            ForEach(sessions) { session in
                NavigationLink {
                    SessionDetailView(sessionID: session.id)
                } label: {
                    SessionRowView(session: session)
                }
            }
            .onDelete { offsets in
                let idsToDelete = offsets.compactMap { index in
                    sessions.indices.contains(index) ? sessions[index].id : nil
                }
                if !idsToDelete.isEmpty {
                    Haptics.warning()
                }
                deletedSessionsBuffer = sessions.filter { idsToDelete.contains($0.id) }
                store.deleteSessions(ids: idsToDelete)
                showUndoDelete = !deletedSessionsBuffer.isEmpty
                undoTask?.cancel()
                undoTask = Task {
                    try? await Task.sleep(nanoseconds: 6_000_000_000)
                    await MainActor.run {
                        clearUndo()
                    }
                }
            }
        }
    }

    private func clearUndo() {
        undoTask?.cancel()
        undoTask = nil
        showUndoDelete = false
        deletedSessionsBuffer = []
    }

    private func showPreviousMonth() {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = Calendar.current.startOfMonth(for: previous)
    }

    private func showNextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = Calendar.current.startOfMonth(for: next)
    }
}

struct HistoryMonthCalendarView: View {
    let displayedMonth: Date
    let selectedDate: Date
    let workoutDays: Set<Date>
    let weekStartsOnMonday: Bool
    var onSelectDate: (Date) -> Void
    var onPreviousMonth: () -> Void
    var onNextMonth: () -> Void

    private var calendar: Calendar {
        var updated = Calendar.current
        if weekStartsOnMonday {
            updated.firstWeekday = 2
        }
        return updated
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let pivot = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[pivot...]) + Array(symbols[..<pivot])
    }

    private var dayCells: [Date?] {
        let monthStart = calendar.startOfMonth(for: displayedMonth)
        guard let daysRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekdayOfMonth = calendar.component(.weekday, from: monthStart)
        let leadingEmptyDays = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7

        var cells = Array<Date?>(repeating: nil, count: leadingEmptyDays)
        for day in daysRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                cells.append(calendar.startOfDay(for: date))
            }
        }
        while cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: onPreviousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button(action: onNextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(dayCells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func dayCell(for date: Date) -> some View {
        let normalized = calendar.startOfDay(for: date)
        let isSelected = calendar.isDate(normalized, inSameDayAs: selectedDate)
        let hasWorkout = workoutDays.contains(normalized)

        return Button {
            onSelectDate(normalized)
        } label: {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.appAccent : Color.clear)

                if hasWorkout {
                    Circle()
                        .stroke(
                            isSelected ? Color.white.opacity(0.88) : Color.appAccent.opacity(0.96),
                            lineWidth: isSelected ? 1.7 : 1.8
                        )
                        .scaleEffect(isSelected ? 1.16 : 1.0)
                }

                Text("\(calendar.component(.day, from: normalized))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}

struct SessionRowView: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.name)
                .font(.headline)
            Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("\(session.exercises.count) exercises • \(formatDuration(session.elapsedSeconds))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct RunElevationChartView: View {
    let points: [RunElevationPoint]

    var body: some View {
        Chart(Array(points.enumerated()), id: \.offset) { _, point in
            AreaMark(
                x: .value("Distance", point.mile),
                y: .value("Elevation", point.elevationFeet)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.appAccent.opacity(0.18))

            LineMark(
                x: .value("Distance", point.mile),
                y: .value("Elevation", point.elevationFeet)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.appAccent)
            .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
        .chartYAxis(.hidden)
        .chartXAxisLabel("Miles")
        .frame(height: 170)
    }
}

struct SessionDetailView: View {
    @EnvironmentObject private var store: TrainingStore

    let sessionID: UUID

    private var session: WorkoutSession? {
        store.session(by: sessionID)
    }

    var body: some View {
        Group {
            if let session {
                List {
                    Section {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(formatDuration(session.elapsedSeconds))
                                .monospacedDigit()
                        }

                        HStack {
                            Text("Date")
                            Spacer()
                            Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                        }

                        if !session.notes.isEmpty {
                            Text(session.notes)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Exercises") {
                        ForEach(session.exercises) { exercise in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(exercise.name)
                                    .font(.headline)

                                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                    HStack {
                                        Text("Set \(index + 1)")
                                            .font(.subheadline)
                                        Spacer()
                                        Text(set.style.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(set.style.tint)
                                        Text("\(set.reps) x \(set.weight, specifier: "%.1f") lb")
                                            .monospacedDigit()
                                    }
                                    .font(.footnote)
                                }

                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if !session.achievements.isEmpty {
                        Section("Achievements") {
                            ForEach(session.achievements) { badge in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(badge.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text(badge.valueText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if let run = session.run {
                        let hasSamples = hasSampleRoutePoints(run)
                        let bestSplitPace = run.splits.map(\.paceSecPerMile).min()

                        Section("Run") {
                            Text("\(run.mode.rawValue) run")
                                .font(.headline)
                            if let route = run.route, !route.isEmpty {
                                RunRouteMapView(route: route)
                            }
                            if !run.notes.isEmpty {
                                Text(run.notes)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Metrics") {
                            metricRow(title: "Distance", value: String(format: "%.2f mi", run.distanceMiles))
                            metricRow(title: "Duration (Elapsed)", value: formatDuration(resolvedElapsedSeconds(for: run)))
                            metricRow(title: "Moving Time", value: formatDuration(resolvedMovingSeconds(for: run)))
                            if let movingPace = run.avgPaceMovingSecPerMile {
                                metricRow(title: "Avg Pace (Moving)", value: formatPacePerMile(movingPace))
                            }
                            if let elapsedPace = run.avgPaceElapsedSecPerMile ?? run.avgPaceSecPerMile {
                                metricRow(title: "Avg Pace (Elapsed)", value: formatPacePerMile(elapsedPace))
                            }
                        }

                        if hasSamples, !run.splits.isEmpty {
                            Section("Splits") {
                                ForEach(run.splits) { split in
                                    let isBest = bestSplitPace == split.paceSecPerMile
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Mile \(split.splitIndex)")
                                                .font(.subheadline.weight(.semibold))
                                            if isBest {
                                                Text("Best Split")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(Color.appAccent)
                                            }
                                        }
                                        Spacer()
                                        Text(formatDuration(split.splitSeconds))
                                            .font(.subheadline.monospacedDigit())
                                        Text(formatPacePerMile(split.splitPaceSecPerMile))
                                            .font(.subheadline.monospacedDigit())
                                            .frame(width: 84, alignment: .trailing)
                                    }
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isBest ? Color.appAccent.opacity(0.16) : Color.white.opacity(0.04))
                                    )
                                }
                            }
                        }

                        if hasSamples, runHasElevationData(run) {
                            Section("Elevation") {
                                if let gain = run.elevationGainFeet {
                                    metricRow(title: "Gain", value: formatFeet(gain))
                                }
                                if let loss = run.elevationLossFeet {
                                    metricRow(title: "Loss", value: formatFeet(loss))
                                }
                                if let min = run.minElevationFeet {
                                    metricRow(title: "Min Elevation", value: formatFeet(min))
                                }
                                if let max = run.maxElevationFeet {
                                    metricRow(title: "Max Elevation", value: formatFeet(max))
                                }
                                if run.elevationSeries.count >= 2 {
                                    RunElevationChartView(points: run.elevationSeries)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(session.name)
            } else {
                ContentUnavailableView("Session not found", systemImage: "clock.badge.xmark")
            }
        }
    }

    private func formatPacePerMile(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let minutes = clamped / 60
        let secs = clamped % 60
        return String(format: "%d:%02d /mi", minutes, secs)
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .monospacedDigit()
        }
    }

    private func resolvedElapsedSeconds(for run: RunEntry) -> Int {
        max(run.elapsedSeconds, run.durationSeconds)
    }

    private func resolvedMovingSeconds(for run: RunEntry) -> Int {
        let elapsed = resolvedElapsedSeconds(for: run)
        let moving = run.movingSeconds > 0 ? run.movingSeconds : elapsed
        return max(0, min(elapsed, moving))
    }

    private func hasSampleRoutePoints(_ run: RunEntry) -> Bool {
        (run.route?.count ?? 0) >= 2
    }

    private func runHasElevationData(_ run: RunEntry) -> Bool {
        !run.elevationSeries.isEmpty
            || run.elevationGainFeet != nil
            || run.elevationLossFeet != nil
            || run.minElevationFeet != nil
            || run.maxElevationFeet != nil
    }

    private func formatFeet(_ value: Double) -> String {
        "\(Int(value.rounded())) ft"
    }
}

struct ProgressView: View {
    @EnvironmentObject private var store: TrainingStore

    @State private var selectedExercise = ""
    @State private var showBodyWeightLogSheet = false

    private var points: [ExerciseProgressPoint] {
        store.progressPoints(for: selectedExercise)
    }

    private var achievementTimeline: [AchievementBadge] {
        store.achievementTimeline()
    }

    private var bodyWeightPoints30Days: [BodyWeightProgressPoint] {
        store.bodyWeightPoints(days: 30)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCards

                if store.state.sessions.isEmpty && store.state.bodyWeightEntries.isEmpty {
                    ContentUnavailableView("No data yet", systemImage: "chart.xyaxis.line")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                } else {
                    if !store.state.sessions.isEmpty {
                        if !store.exerciseNamesWithHistory.isEmpty {
                            exerciseProgressCard
                        }
                        runProgressCard
                        prTimelineCard
                    }
                    bodyWeightCard
                }
            }
            .padding()
        }
        .navigationTitle("Progress")
        .sheet(isPresented: $showBodyWeightLogSheet) {
            BodyWeightLogSheet(unit: store.state.preferences.measurementSystem) { value, recordedAt, note in
                store.logBodyWeight(
                    value: value,
                    unit: store.state.preferences.measurementSystem,
                    recordedAt: recordedAt,
                    note: note
                )
            }
        }
        .onAppear {
            if selectedExercise.isEmpty {
                selectedExercise = store.exerciseNamesWithHistory.first ?? ""
            }
        }
        .onChange(of: store.exerciseNamesWithHistory) { _, newValue in
            if !newValue.contains(selectedExercise) {
                selectedExercise = newValue.first ?? ""
            }
        }
    }

    private var summaryCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatTile(title: "Sessions", value: "\(store.state.sessions.count)")
                StatTile(title: "Templates", value: "\(store.state.templates.count)")
            }
            HStack(spacing: 10) {
                StatTile(title: "Total Volume", value: shortMass(store.totalVolume))
                StatTile(title: "Run Distance", value: "\(String(format: "%.1f", store.totalRunDistanceMiles)) mi")
            }
        }
    }

    private var exerciseProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strength Progress")
                .font(.headline)

            Picker("Exercise", selection: $selectedExercise) {
                ForEach(store.exerciseNamesWithHistory, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .pickerStyle(.menu)

            if points.isEmpty {
                Text("No data for this exercise")
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Color.appAccent)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Volume", point.volume)
                    )
                    .foregroundStyle(Color.appAccent)
                }
                .frame(height: 220)
            }
        }
        .glassCard()
    }

    private var runProgressCard: some View {
        let runSessions = store.sessionsNewestFirst.filter { ($0.run?.distanceMiles ?? 0) > 0 }
        return VStack(alignment: .leading, spacing: 10) {
            Text("Running Distance")
                .font(.headline)

            if runSessions.isEmpty {
                Text("Log a run inside a session to see your trend.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(runSessions) { session in
                    if let run = session.run {
                        BarMark(
                            x: .value("Date", session.completedAt),
                            y: .value("Miles", run.distanceMiles)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                }
                .frame(height: 180)
            }
        }
        .glassCard()
    }

    private var prTimelineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PR Timeline")
                .font(.headline)

            if achievementTimeline.isEmpty {
                Text("New PRs will appear here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(achievementTimeline.prefix(12)) { badge in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "rosette")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(badge.title)
                                .font(.subheadline.weight(.semibold))
                            Text("\(badge.valueText) • \(badge.occurredAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .glassCard()
    }

    private var bodyWeightCard: some View {
        let recentEntries = Array(store.bodyWeightEntriesNewestFirst.prefix(6))
        let units = store.state.preferences.measurementSystem
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Body Weight")
                        .font(.headline)
                    Text("Latest: \(store.latestBodyWeightDisplay)")
                        .font(.subheadline.weight(.semibold))
                    if let change = store.bodyWeightChange(days: 7) {
                        Text("7-day: \(formatSignedWeightChange(change, unit: units))")
                            .font(.caption)
                            .foregroundStyle(change > 0 ? .orange : (change < 0 ? Color.appAccent : .secondary))
                    } else {
                        Text("7-day: Not enough data")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    showBodyWeightLogSheet = true
                } label: {
                    Label("Log Weight", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

            if bodyWeightPoints30Days.isEmpty {
                Text("No weight entries yet. Log your first check-in.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                Chart(bodyWeightPoints30Days) { point in
                    let displayWeight = units.displayWeight(fromKilograms: point.weightKg)
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", displayWeight)
                    )
                    .foregroundStyle(.orange.gradient)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", displayWeight)
                    )
                    .foregroundStyle(.orange)
                }
                .frame(height: 200)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Entries")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if recentEntries.isEmpty {
                    Text("No recent check-ins.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentEntries) { entry in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.recordedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline.weight(.semibold))
                                if !entry.note.isEmpty {
                                    Text(entry.note)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            Spacer()
                            Text(formatWeightMeasurement(entry.weightKg, as: units))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                        }
                        .padding(10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteBodyWeight(id: entry.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }
}

struct BodyWeightLogSheet: View {
    @Environment(\.dismiss) private var dismiss

    let unit: MeasurementSystem
    let onSave: (_ value: Double, _ recordedAt: Date, _ note: String) -> Void

    @State private var recordedAt = Date()
    @State private var weightInput = ""
    @State private var note = ""

    private var parsedWeight: Double? {
        let normalized = weightInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private var canSave: Bool {
        guard let parsedWeight else { return false }
        return parsedWeight > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Check-In") {
                    DatePicker("Date", selection: $recordedAt, displayedComponents: .date)
                    TextField("Weight (\(unit.weightUnit))", text: $weightInput)
                        .keyboardType(.decimalPad)
                }

                Section("Notes") {
                    TextEditor(text: $note)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle("Log Weight")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let parsedWeight else { return }
                        onSave(parsedWeight, recordedAt, note)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        dismissKeyboard()
                    }
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var showResetAlert = false
    @State private var locationAuthorizationStatus = CLLocationManager().authorizationStatus

    var body: some View {
        List {
            Section("Appearance") {
                Picker(
                    "Theme",
                    selection: Binding(
                        get: { store.state.theme },
                        set: { store.updateTheme($0) }
                    )
                ) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Preferences") {
                Picker(
                    "Units",
                    selection: Binding(
                        get: { store.state.preferences.measurementSystem },
                        set: { newValue in
                            var updated = store.state.preferences
                            updated.measurementSystem = newValue
                            store.updatePreferences(updated)
                        }
                    )
                ) {
                    ForEach(MeasurementSystem.allCases) { system in
                        Text(system.title).tag(system)
                    }
                }
                .pickerStyle(.segmented)

                Picker(
                    "Default Run Mode",
                    selection: Binding(
                        get: { store.state.preferences.defaultRunMode },
                        set: { newValue in
                            var updated = store.state.preferences
                            updated.defaultRunMode = newValue
                            store.updatePreferences(updated)
                        }
                    )
                ) {
                    ForEach(RunMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(
                    "Week starts on Monday",
                    isOn: Binding(
                        get: { store.state.preferences.weekStartsOnMonday },
                        set: { newValue in
                            var updated = store.state.preferences
                            updated.weekStartsOnMonday = newValue
                            store.updatePreferences(updated)
                        }
                    )
                )
            }

            Section("Permissions") {
                HStack {
                    Text("Location Access")
                    Spacer()
                    Text(locationAuthorizationStatus.settingsTitle)
                        .foregroundStyle(.secondary)
                }

                Button("Open iOS Settings") {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                }
            }

            Section("Account") {
                Text("Name: \(store.state.account?.displayName ?? "-")")
                Text("Email: \(store.state.account?.email.isEmpty == false ? (store.state.account?.email ?? "") : "-")")
                Text("Created: \(store.state.account?.createdAt.formatted(date: .abbreviated, time: .omitted) ?? "-")")
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Text("Offline-first storage is enabled by default.")
                    .foregroundStyle(.secondary)
                Text("Garmin sync is not wired yet. Data models already include running metrics for future integration.")
                    .foregroundStyle(.secondary)

                Button("Sign Out + Reset Data", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .navigationTitle("Settings")
        .alert("Reset all app data?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                store.signOutAndResetData()
            }
        } message: {
            Text("This removes account info, sessions, templates, folders, progress, and body weight check-ins stored on this device.")
        }
        .onAppear {
            locationAuthorizationStatus = CLLocationManager().authorizationStatus
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                locationAuthorizationStatus = CLLocationManager().authorizationStatus
            }
        }
    }
}

// MARK: - View Styling Helpers

extension View {
    func glassCard() -> some View {
        self
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    func glassField() -> some View {
        self
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
}

enum Haptics {
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? startOfDay(for: date)
    }
}

// MARK: - Formatting

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

func formatDuration(_ seconds: Int) -> String {
    let clamped = max(0, seconds)
    let hours = clamped / 3600
    let minutes = (clamped % 3600) / 60
    let secs = clamped % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, secs)
}

func shortMass(_ value: Double) -> String {
    if value >= 1000 {
        return "\(String(format: "%.1f", value / 1000))k"
    }
    return String(format: "%.0f", value)
}

func formatWeightMeasurement(_ kilograms: Double, as units: MeasurementSystem) -> String {
    let displayValue = units.displayWeight(fromKilograms: max(0, kilograms))
    let rounded = displayValue.rounded()
    let valueText: String
    if abs(displayValue - rounded) < 0.05 {
        valueText = String(format: "%.0f", rounded)
    } else {
        valueText = String(format: "%.1f", displayValue)
    }
    return "\(valueText) \(units.weightUnit)"
}

func formatSignedWeightChange(_ value: Double, unit: MeasurementSystem) -> String {
    let rounded = value.rounded()
    let valueText: String
    if abs(value - rounded) < 0.05 {
        valueText = String(format: "%+.0f", rounded)
    } else {
        valueText = String(format: "%+.1f", value)
    }
    return "\(valueText) \(unit.weightUnit)"
}

extension CLAuthorizationStatus {
    var settingsTitle: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }
}
