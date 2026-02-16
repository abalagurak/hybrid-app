import XCTest
@testable import TrainingApp

final class LiftingInsightsAggregatorTests: XCTestCase {
    private var calendar: Calendar!
    private var formatter: DateFormatter!

    override func setUp() {
        super.setUp()
        var configured = Calendar(identifier: .gregorian)
        configured.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        configured.firstWeekday = 2 // Monday
        calendar = configured

        let formatter = DateFormatter()
        formatter.calendar = configured
        formatter.timeZone = configured.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        self.formatter = formatter
    }

    func testWeeklyGroupingUsesConfiguredWeekBoundary() throws {
        let sessions = [
            makeSession(date: "2026-01-05 08:00", exerciseName: "Bench Press", weight: 100, reps: 5),
            makeSession(date: "2026-01-11 08:00", exerciseName: "Bench Press", weight: 110, reps: 5),
            makeSession(date: "2026-01-12 08:00", exerciseName: "Bench Press", weight: 120, reps: 5)
        ]

        let aggregator = LiftingInsightsAggregator(calendar: calendar)
        let summary = aggregator.summarize(
            sessions: sessions,
            rangeStart: try date("2026-01-05 00:00"),
            rangeEnd: try date("2026-01-18 23:59")
        )

        let chestVolumes = summary.muscleGroupSummary.weeklyVolumes
            .filter { $0.muscleGroup == .chest }

        XCTAssertEqual(chestVolumes.count, 2)

        let firstWeekStart = try date("2026-01-05 00:00")
        let secondWeekStart = try date("2026-01-12 00:00")

        let firstWeekVolume = try XCTUnwrap(
            chestVolumes.first(where: { calendar.isDate($0.weekStart, inSameDayAs: firstWeekStart) })?.volume
        )
        let secondWeekVolume = try XCTUnwrap(
            chestVolumes.first(where: { calendar.isDate($0.weekStart, inSameDayAs: secondWeekStart) })?.volume
        )

        XCTAssertEqual(firstWeekVolume, 1050, accuracy: 0.001)
        XCTAssertEqual(secondWeekVolume, 600, accuracy: 0.001)
    }

    func testConsistencyStreakAndAverageRestDays() throws {
        let sessions = [
            makeSession(date: "2026-01-01 08:00", exerciseName: "Bench Press", weight: 100, reps: 5),
            makeSession(date: "2026-01-02 09:00", exerciseName: "Bench Press", weight: 100, reps: 5),
            makeSession(date: "2026-01-04 08:00", exerciseName: "Bench Press", weight: 100, reps: 5),
            makeSession(date: "2026-01-05 08:00", exerciseName: "Bench Press", weight: 100, reps: 5),
            makeSession(date: "2026-01-06 08:00", exerciseName: "Bench Press", weight: 100, reps: 5)
        ]

        let aggregator = LiftingInsightsAggregator(calendar: calendar)
        let summary = aggregator.summarize(
            sessions: sessions,
            rangeStart: try date("2026-01-01 00:00"),
            rangeEnd: try date("2026-01-10 23:59")
        )

        XCTAssertEqual(summary.consistencySummary.currentStreakDays, 3)
        XCTAssertEqual(summary.consistencySummary.longestStreakDays, 3)
        let averageRestDays = try XCTUnwrap(summary.consistencySummary.averageRestDaysBetweenSessions)
        XCTAssertEqual(averageRestDays, 0.25, accuracy: 0.0001)
    }

    func testBiggestImprovementUsesFirstAndLastSessionBest() throws {
        let sessions = [
            makeSession(date: "2026-01-01 08:00", exerciseName: "Bench Press", weight: 100, reps: 5),
            makeSession(date: "2026-01-10 08:00", exerciseName: "Bench Press", weight: 130, reps: 5),
            makeSession(date: "2026-01-02 08:00", exerciseName: "Back Squat", weight: 200, reps: 5),
            makeSession(date: "2026-01-11 08:00", exerciseName: "Back Squat", weight: 210, reps: 5),
            makeSession(date: "2026-01-07 08:00", exerciseName: "Barbell Row", weight: 160, reps: 5)
        ]

        let aggregator = LiftingInsightsAggregator(calendar: calendar)
        let summary = aggregator.summarize(
            sessions: sessions,
            rangeStart: try date("2026-01-01 00:00"),
            rangeEnd: try date("2026-01-20 23:59")
        )

        let improvement = try XCTUnwrap(summary.globalHighlights.biggestE1RMImprovement)
        XCTAssertEqual(improvement.exerciseName, "Bench Press")
        XCTAssertEqual(improvement.delta, 35, accuracy: 0.001)
        XCTAssertEqual(summary.globalHighlights.exercisesWithAtLeastTwoSessions, 2)
        XCTAssertTrue(calendar.isDate(improvement.firstDate, inSameDayAs: try date("2026-01-01 08:00")))
        XCTAssertTrue(calendar.isDate(improvement.lastDate, inSameDayAs: try date("2026-01-10 08:00")))
    }

    func testExerciseMuscleMapperKeywordFallbacks() {
        let mapper = ExerciseMuscleMapper()

        XCTAssertEqual(mapper.muscleGroup(for: "Incline Bench Press"), .chest)
        XCTAssertEqual(mapper.muscleGroup(for: "Chest Supported Row"), .back)
        XCTAssertEqual(mapper.muscleGroup(for: "Cable Pulldown"), .back)
        XCTAssertEqual(mapper.muscleGroup(for: "Tricep Pushdown"), .arms)
        XCTAssertEqual(mapper.muscleGroup(for: "Lateral Raise"), .shoulders)
        XCTAssertEqual(mapper.muscleGroup(for: "Goblet Squat"), .legs)
    }

    private func makeSession(date: String, exerciseName: String, weight: Double, reps: Int) -> WorkoutSession {
        let completedAt = (try? self.date(date)) ?? .distantPast
        let startedAt = calendar.date(byAdding: .minute, value: -45, to: completedAt) ?? completedAt
        let set = LoggedSet(reps: reps, weight: weight, isCompleted: true)
        let exercise = LoggedExercise(definitionID: nil, name: exerciseName, notes: "", sets: [set])
        return WorkoutSession(
            name: "Workout",
            startedAt: startedAt,
            completedAt: completedAt,
            notes: "",
            elapsedSeconds: 2700,
            exercises: [exercise],
            run: nil,
            achievements: []
        )
    }

    private func date(_ value: String) throws -> Date {
        guard let date = formatter.date(from: value) else {
            throw NSError(domain: "LiftingInsightsAggregatorTests", code: 1)
        }
        return date
    }
}
