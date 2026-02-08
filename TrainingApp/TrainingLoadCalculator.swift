import Foundation

extension WorkoutSession {
    var liftingLoad: Double {
        exercises.reduce(0) { partial, exercise in
            partial + exercise.sets.reduce(0) { setTotal, set in
                guard set.isCompleted else { return setTotal }
                let safeWeight = max(0, set.weight)
                let safeReps = max(0, set.reps)
                return setTotal + (safeWeight * Double(safeReps))
            }
        }
    }

    var runningLoad: Double {
        let miles = max(0, run?.distanceMiles ?? 0)
        return miles * 100
    }

    var totalLoad: Double {
        liftingLoad + runningLoad
    }
}

struct WeeklyTrainingLoad {
    let weekStart: Date
    let weekEnd: Date
    let sessionCount: Int
    let liftingLoad: Double
    let runningLoad: Double

    var totalLoad: Double {
        liftingLoad + runningLoad
    }
}

struct TrainingLoadCalculator {
    private var calendar: Calendar
    private let sessions: [WorkoutSession]

    init(
        sessions: [WorkoutSession],
        calendar: Calendar = .current,
        weekStartsOnMonday: Bool? = nil
    ) {
        var configuredCalendar = calendar
        if let weekStartsOnMonday {
            configuredCalendar.firstWeekday = weekStartsOnMonday ? 2 : 1
        }
        self.calendar = configuredCalendar
        self.sessions = sessions
    }

    func sessions(inWeekContaining date: Date) -> [WorkoutSession] {
        let weekStart = startOfWeek(for: date)
        let weekEnd = endOfWeek(for: date)
        return sessions.filter { session in
            session.completedAt >= weekStart && session.completedAt < weekEnd
        }
    }

    func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    func endOfWeek(for date: Date) -> Date {
        let weekStart = startOfWeek(for: date)
        return calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
    }

    func weeklyLoad(for weekStartDate: Date) -> WeeklyTrainingLoad {
        let weekStart = startOfWeek(for: weekStartDate)
        let weekEnd = endOfWeek(for: weekStartDate)
        let weekSessions = sessions.filter { session in
            session.completedAt >= weekStart && session.completedAt < weekEnd
        }

        let lifting = weekSessions.reduce(0) { $0 + $1.liftingLoad }
        let running = weekSessions.reduce(0) { $0 + $1.runningLoad }

        return WeeklyTrainingLoad(
            weekStart: weekStart,
            weekEnd: weekEnd,
            sessionCount: weekSessions.count,
            liftingLoad: lifting,
            runningLoad: running
        )
    }

    func weekOverWeekDeltaPercent(thisWeek: Double, lastWeek: Double) -> Double? {
        if thisWeek == 0 && lastWeek == 0 {
            return nil
        }
        let denominator = max(lastWeek, 1)
        return ((thisWeek - lastWeek) / denominator) * 100
    }
}
