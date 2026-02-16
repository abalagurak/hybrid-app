import Foundation

enum MuscleGroup: String, CaseIterable, Identifiable, Hashable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case other = "Other"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct GlobalHighlightsSummary {
    struct HighestE1RMRecord: Hashable {
        let exerciseName: String
        let e1RM: Double
        let date: Date
    }

    struct E1RMImprovementRecord: Hashable {
        let exerciseName: String
        let delta: Double
        let firstDate: Date
        let lastDate: Date
        let firstE1RM: Double
        let lastE1RM: Double
    }

    struct SessionVolumeRecord: Hashable {
        let sessionID: UUID
        let workoutName: String
        let date: Date
        let volume: Double
    }

    struct WeeklyVolumeRecord: Hashable {
        let weekStart: Date
        let volume: Double
    }

    let hasUsableSets: Bool
    let highestE1RM: HighestE1RMRecord?
    let biggestE1RMImprovement: E1RMImprovementRecord?
    let highestSessionVolume: SessionVolumeRecord?
    let highestWeeklyVolume: WeeklyVolumeRecord?
    let exercisesWithAtLeastTwoSessions: Int
}

struct MuscleGroupSummary {
    struct WeeklyGroupVolume: Identifiable, Hashable {
        let weekStart: Date
        let muscleGroup: MuscleGroup
        let volume: Double

        var id: String {
            "\(weekStart.timeIntervalSinceReferenceDate)-\(muscleGroup.rawValue)"
        }
    }

    let hasUsableSets: Bool
    let weeklyVolumes: [WeeklyGroupVolume]
    let totalVolume: Double
    let volumeByGroup: [MuscleGroup: Double]
    let pushVolume: Double
    let pullVolume: Double
    let torsoFocusScore: Double

    var pushPullRatio: Double? {
        guard pullVolume > 0 else { return nil }
        return pushVolume / pullVolume
    }
}

struct ConsistencySummary {
    struct WeeklyWorkoutCount: Identifiable, Hashable {
        let weekStart: Date
        let workouts: Int

        var id: Date { weekStart }
    }

    struct MuscleGroupSpacingRow: Identifiable, Hashable {
        let muscleGroup: MuscleGroup
        let averageDaysBetween: Double?
        let sessionsCount: Int

        var id: MuscleGroup { muscleGroup }
    }

    let hasWorkoutDays: Bool
    let weeklyWorkoutCounts: [WeeklyWorkoutCount]
    let currentStreakDays: Int
    let longestStreakDays: Int
    let averageRestDaysBetweenSessions: Double?
    let muscleGroupSpacing: [MuscleGroupSpacingRow]
}

struct LiftingInsightsSnapshot {
    let globalHighlights: GlobalHighlightsSummary
    let muscleGroupSummary: MuscleGroupSummary
    let consistencySummary: ConsistencySummary
}

struct ExerciseMuscleMapper {
    private static let explicitMappings: [String: MuscleGroup] = [
        "bench press": .chest,
        "incline bench press": .chest,
        "decline bench press": .chest,
        "db bench press": .chest,
        "dumbbell bench press": .chest,
        "chest press": .chest,
        "barbell squat": .legs,
        "back squat": .legs,
        "front squat": .legs,
        "goblet squat": .legs,
        "deadlift": .back,
        "romanian deadlift": .legs,
        "rdl": .legs,
        "overhead press": .shoulders,
        "ohp": .shoulders,
        "shoulder press": .shoulders,
        "barbell row": .back,
        "dumbbell row": .back,
        "bent over row": .back,
        "lat pulldown": .back,
        "pull up": .back,
        "chin up": .back,
        "bicep curl": .arms,
        "hammer curl": .arms,
        "triceps pushdown": .arms,
        "tricep pushdown": .arms,
        "lateral raise": .shoulders,
        "side lateral raise": .shoulders,
        "ab wheel": .core,
        "plank": .core
    ]

    func muscleGroup(for exerciseName: String) -> MuscleGroup {
        let normalized = normalize(exerciseName)
        guard !normalized.isEmpty else { return .other }

        if let group = Self.explicitMappings[normalized] {
            return group
        }

        if containsAny(["overhead", "shoulder press", "military press", "arnold press"], in: normalized) {
            return .shoulders
        }
        if containsAny(["bench", "chest press", "pec", "fly", "dip"], in: normalized) {
            return .chest
        }
        if containsAny(["row", "pulldown", "pull up", "pullup", "chin up", "chinup", "lat", "face pull"], in: normalized) {
            return .back
        }
        if normalized.contains("deadlift") {
            if containsAny(["romanian", "rdl", "stiff leg", "stiff-leg", "sumo"], in: normalized) {
                return .legs
            }
            return .back
        }
        if containsAny(["squat", "lunge", "leg press", "leg extension", "leg curl", "calf", "hip thrust"], in: normalized) {
            return .legs
        }
        if containsAny(["lateral raise", "rear delt", "front raise"], in: normalized) {
            return .shoulders
        }
        if containsAny(["curl", "tricep", "triceps", "bicep", "biceps", "pushdown", "skullcrusher"], in: normalized) {
            return .arms
        }
        if containsAny(["plank", "crunch", "sit up", "sit-up", "hanging leg raise", "ab ", "core"], in: normalized) {
            return .core
        }
        if normalized.contains("press") {
            return normalized.contains("overhead") ? .shoulders : .chest
        }
        return .other
    }

    private func containsAny(_ terms: [String], in value: String) -> Bool {
        terms.contains { value.contains($0) }
    }

    private func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
}

struct LiftingInsightsAggregator {
    private struct ExerciseSessionData {
        let exerciseName: String
        let bestE1RM: Double
        let maxWeight: Double
        let volume: Double
        let muscleGroup: MuscleGroup
    }

    private struct AnalyzedSession {
        let sessionID: UUID
        let workoutName: String
        let date: Date
        let day: Date
        let weekStart: Date
        let totalVolume: Double
        let exerciseData: [ExerciseSessionData]
        let volumeByGroup: [MuscleGroup: Double]
        let muscleGroupsHit: Set<MuscleGroup>
    }

    private let calendar: Calendar
    private let mapper: ExerciseMuscleMapper

    init(calendar: Calendar = .current, mapper: ExerciseMuscleMapper = ExerciseMuscleMapper()) {
        self.calendar = calendar
        self.mapper = mapper
    }

    func summarize(sessions: [WorkoutSession], rangeStart: Date?, rangeEnd: Date = Date()) -> LiftingInsightsSnapshot {
        let analyzedSessions = analyzeSessions(sessions)
        return LiftingInsightsSnapshot(
            globalHighlights: buildGlobalHighlights(from: analyzedSessions),
            muscleGroupSummary: buildMuscleGroupSummary(
                from: analyzedSessions,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            ),
            consistencySummary: buildConsistencySummary(
                from: analyzedSessions,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )
        )
    }

    private func analyzeSessions(_ sessions: [WorkoutSession]) -> [AnalyzedSession] {
        sessions
            .sorted { $0.completedAt < $1.completedAt }
            .compactMap { session in
                var displayNamesByExercise: [String: String] = [:]
                var setsByExercise: [String: [LoggedSet]] = [:]

                for exercise in session.exercises {
                    let key = normalizedExerciseName(exercise.name)
                    displayNamesByExercise[key] = displayNamesByExercise[key] ?? exercise.name
                    setsByExercise[key, default: []].append(contentsOf: exercise.sets)
                }

                var exerciseData: [ExerciseSessionData] = []
                var volumeByGroup: [MuscleGroup: Double] = [:]
                var muscleGroupsHit: Set<MuscleGroup> = []
                var totalVolume = 0.0

                for (key, rawSets) in setsByExercise {
                    let usable = Self.usableSets(from: rawSets)
                    guard !usable.isEmpty else { continue }

                    let displayName = displayNamesByExercise[key] ?? key
                    let volume = usable.reduce(0) { partial, set in
                        partial + (set.weight * Double(set.reps))
                    }
                    let bestE1RM = usable.map { Self.estimateOneRM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                    let maxWeight = usable.map(\.weight).max() ?? 0
                    let group = mapper.muscleGroup(for: displayName)

                    exerciseData.append(
                        ExerciseSessionData(
                            exerciseName: displayName,
                            bestE1RM: bestE1RM,
                            maxWeight: maxWeight,
                            volume: volume,
                            muscleGroup: group
                        )
                    )
                    volumeByGroup[group, default: 0] += volume
                    muscleGroupsHit.insert(group)
                    totalVolume += volume
                }

                guard totalVolume > 0 else { return nil }
                return AnalyzedSession(
                    sessionID: session.id,
                    workoutName: session.name,
                    date: session.completedAt,
                    day: calendar.startOfDay(for: session.completedAt),
                    weekStart: startOfWeek(for: session.completedAt),
                    totalVolume: totalVolume,
                    exerciseData: exerciseData,
                    volumeByGroup: volumeByGroup,
                    muscleGroupsHit: muscleGroupsHit
                )
            }
    }

    private func buildGlobalHighlights(from sessions: [AnalyzedSession]) -> GlobalHighlightsSummary {
        let hasUsableSets = !sessions.isEmpty
        guard hasUsableSets else {
            return GlobalHighlightsSummary(
                hasUsableSets: false,
                highestE1RM: nil,
                biggestE1RMImprovement: nil,
                highestSessionVolume: nil,
                highestWeeklyVolume: nil,
                exercisesWithAtLeastTwoSessions: 0
            )
        }

        var highestE1RM: GlobalHighlightsSummary.HighestE1RMRecord?
        var exerciseTimeline: [String: [(date: Date, e1RM: Double, displayName: String)]] = [:]
        var highestSessionVolume: GlobalHighlightsSummary.SessionVolumeRecord?
        var weeklyVolumeByWeek: [Date: Double] = [:]

        for session in sessions {
            if let current = highestSessionVolume {
                if session.totalVolume > current.volume {
                    highestSessionVolume = GlobalHighlightsSummary.SessionVolumeRecord(
                        sessionID: session.sessionID,
                        workoutName: session.workoutName,
                        date: session.date,
                        volume: session.totalVolume
                    )
                }
            } else {
                highestSessionVolume = GlobalHighlightsSummary.SessionVolumeRecord(
                    sessionID: session.sessionID,
                    workoutName: session.workoutName,
                    date: session.date,
                    volume: session.totalVolume
                )
            }

            weeklyVolumeByWeek[session.weekStart, default: 0] += session.totalVolume

            for exercise in session.exerciseData {
                if let record = highestE1RM {
                    if exercise.bestE1RM > record.e1RM {
                        highestE1RM = GlobalHighlightsSummary.HighestE1RMRecord(
                            exerciseName: exercise.exerciseName,
                            e1RM: exercise.bestE1RM,
                            date: session.date
                        )
                    }
                } else {
                    highestE1RM = GlobalHighlightsSummary.HighestE1RMRecord(
                        exerciseName: exercise.exerciseName,
                        e1RM: exercise.bestE1RM,
                        date: session.date
                    )
                }

                let key = normalizedExerciseName(exercise.exerciseName)
                exerciseTimeline[key, default: []].append(
                    (date: session.date, e1RM: exercise.bestE1RM, displayName: exercise.exerciseName)
                )
            }
        }

        var exercisesWithAtLeastTwoSessions = 0
        var biggestImprovement: GlobalHighlightsSummary.E1RMImprovementRecord?

        for entries in exerciseTimeline.values {
            let sorted = entries.sorted { $0.date < $1.date }
            guard sorted.count >= 2 else { continue }

            exercisesWithAtLeastTwoSessions += 1
            guard let first = sorted.first, let last = sorted.last else { continue }
            let delta = last.e1RM - first.e1RM

            if let current = biggestImprovement {
                if delta > current.delta {
                    biggestImprovement = GlobalHighlightsSummary.E1RMImprovementRecord(
                        exerciseName: last.displayName,
                        delta: delta,
                        firstDate: first.date,
                        lastDate: last.date,
                        firstE1RM: first.e1RM,
                        lastE1RM: last.e1RM
                    )
                }
            } else {
                biggestImprovement = GlobalHighlightsSummary.E1RMImprovementRecord(
                    exerciseName: last.displayName,
                    delta: delta,
                    firstDate: first.date,
                    lastDate: last.date,
                    firstE1RM: first.e1RM,
                    lastE1RM: last.e1RM
                )
            }
        }

        let highestWeeklyVolume = weeklyVolumeByWeek
            .max { lhs, rhs in lhs.value < rhs.value }
            .map { week, volume in
                GlobalHighlightsSummary.WeeklyVolumeRecord(weekStart: week, volume: volume)
            }

        return GlobalHighlightsSummary(
            hasUsableSets: true,
            highestE1RM: highestE1RM,
            biggestE1RMImprovement: biggestImprovement,
            highestSessionVolume: highestSessionVolume,
            highestWeeklyVolume: highestWeeklyVolume,
            exercisesWithAtLeastTwoSessions: exercisesWithAtLeastTwoSessions
        )
    }

    private func buildMuscleGroupSummary(
        from sessions: [AnalyzedSession],
        rangeStart: Date?,
        rangeEnd: Date
    ) -> MuscleGroupSummary {
        let hasUsableSets = !sessions.isEmpty
        let weekStarts = weeksInRange(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            fallbackStart: sessions.first?.date
        )

        var weeklyVolumeByWeek: [Date: [MuscleGroup: Double]] = [:]
        var volumeByGroup = Dictionary(uniqueKeysWithValues: MuscleGroup.allCases.map { ($0, 0.0) })
        var totalVolume = 0.0

        for session in sessions {
            for (group, volume) in session.volumeByGroup {
                weeklyVolumeByWeek[session.weekStart, default: [:]][group, default: 0] += volume
                volumeByGroup[group, default: 0] += volume
                totalVolume += volume
            }
        }

        var weeklyVolumes: [MuscleGroupSummary.WeeklyGroupVolume] = []
        weeklyVolumes.reserveCapacity(weekStarts.count * MuscleGroup.allCases.count)
        for weekStart in weekStarts {
            let volumesForWeek = weeklyVolumeByWeek[weekStart] ?? [:]
            for group in MuscleGroup.allCases {
                weeklyVolumes.append(
                    MuscleGroupSummary.WeeklyGroupVolume(
                        weekStart: weekStart,
                        muscleGroup: group,
                        volume: volumesForWeek[group] ?? 0
                    )
                )
            }
        }

        let pushVolume = (volumeByGroup[.chest] ?? 0) + (volumeByGroup[.shoulders] ?? 0)
        let pullVolume = volumeByGroup[.back] ?? 0
        let torsoNumerator = (volumeByGroup[.chest] ?? 0) + (volumeByGroup[.back] ?? 0) + (volumeByGroup[.shoulders] ?? 0)
        let torsoFocusScore = totalVolume > 0 ? torsoNumerator / totalVolume : 0

        return MuscleGroupSummary(
            hasUsableSets: hasUsableSets,
            weeklyVolumes: weeklyVolumes,
            totalVolume: totalVolume,
            volumeByGroup: volumeByGroup,
            pushVolume: pushVolume,
            pullVolume: pullVolume,
            torsoFocusScore: torsoFocusScore
        )
    }

    private func buildConsistencySummary(
        from sessions: [AnalyzedSession],
        rangeStart: Date?,
        rangeEnd: Date
    ) -> ConsistencySummary {
        let workoutDays = Array(Set(sessions.map(\.day))).sorted()
        let hasWorkoutDays = !workoutDays.isEmpty
        let weekStarts = weeksInRange(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            fallbackStart: workoutDays.first
        )

        var workoutCountByWeek: [Date: Int] = [:]
        for day in workoutDays {
            workoutCountByWeek[startOfWeek(for: day), default: 0] += 1
        }

        let weeklyWorkoutCounts = weekStarts.map { weekStart in
            ConsistencySummary.WeeklyWorkoutCount(
                weekStart: weekStart,
                workouts: workoutCountByWeek[weekStart] ?? 0
            )
        }

        let streaks = streakValues(from: workoutDays)
        let averageRestDaysBetweenSessions = averageDaysBetween(
            for: workoutDays,
            subtractOneDayBetweenSessions: true
        )

        let muscleGroupSpacing = MuscleGroup.allCases.map { group in
            let groupDays = Array(
                Set(
                    sessions
                        .filter { $0.muscleGroupsHit.contains(group) }
                        .map(\.day)
                )
            )
            .sorted()

            return ConsistencySummary.MuscleGroupSpacingRow(
                muscleGroup: group,
                averageDaysBetween: averageDaysBetween(
                    for: groupDays,
                    subtractOneDayBetweenSessions: false
                ),
                sessionsCount: groupDays.count
            )
        }

        return ConsistencySummary(
            hasWorkoutDays: hasWorkoutDays,
            weeklyWorkoutCounts: weeklyWorkoutCounts,
            currentStreakDays: streaks.current,
            longestStreakDays: streaks.longest,
            averageRestDaysBetweenSessions: averageRestDaysBetweenSessions,
            muscleGroupSpacing: muscleGroupSpacing
        )
    }

    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func weeksInRange(rangeStart: Date?, rangeEnd: Date, fallbackStart: Date?) -> [Date] {
        guard let start = rangeStart ?? fallbackStart else { return [] }
        let startWeek = startOfWeek(for: start)
        let endWeek = startOfWeek(for: rangeEnd)
        guard startWeek <= endWeek else { return [startWeek] }

        var weeks: [Date] = []
        var cursor = startWeek
        var guardrail = 0

        while cursor <= endWeek, guardrail < 6000 {
            weeks.append(cursor)
            cursor = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor) ?? cursor
            guardrail += 1
        }
        return weeks
    }

    private func streakValues(from days: [Date]) -> (current: Int, longest: Int) {
        guard !days.isEmpty else { return (0, 0) }

        var currentRun = 0
        var longest = 0

        for index in days.indices {
            if index == 0 {
                currentRun = 1
            } else {
                let previous = days[index - 1]
                let delta = calendar.dateComponents([.day], from: previous, to: days[index]).day ?? 0
                if delta == 1 {
                    currentRun += 1
                } else {
                    currentRun = 1
                }
            }
            longest = max(longest, currentRun)
        }

        return (currentRun, longest)
    }

    private func averageDaysBetween(for days: [Date], subtractOneDayBetweenSessions: Bool) -> Double? {
        guard days.count >= 2 else { return nil }

        var sum = 0.0
        var segments = 0.0

        for index in 1..<days.count {
            let delta = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            let value = subtractOneDayBetweenSessions
                ? Double(max(0, delta - 1))
                : Double(max(0, delta))
            sum += value
            segments += 1
        }

        guard segments > 0 else { return nil }
        return sum / segments
    }

    private func normalizedExerciseName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func usableSets(from rawSets: [LoggedSet]) -> [LoggedSet] {
        let completedSets = rawSets.filter(\.isCompleted)
        let source = completedSets.isEmpty ? rawSets : completedSets
        return source.filter { $0.reps > 0 && $0.weight > 0 }
    }

    static func estimateOneRM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1 + (Double(reps) / 30.0))
    }
}

enum LiftingInsightsComputationService {
    static func computeSnapshot(
        sessions: [WorkoutSession],
        rangeStart: Date?,
        rangeEnd: Date = Date(),
        calendar: Calendar
    ) async -> LiftingInsightsSnapshot {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let aggregator = LiftingInsightsAggregator(calendar: calendar)
                let snapshot = aggregator.summarize(
                    sessions: sessions,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                )
                continuation.resume(returning: snapshot)
            }
        }
    }
}
