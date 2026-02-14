import SwiftUI
import Charts

extension Notification.Name {
    static let navigateToWorkoutTab = Notification.Name("navigateToWorkoutTab")
}

struct InsightsView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var selectedRunningRange: RunningRange = .days
    private let runningAccent = Color(red: 0.8, green: 48.0 / 255.0, blue: 0.0)

    private static let loadFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private enum RunningRange: String, CaseIterable, Identifiable {
        case days = "Days"
        case weeks = "Weeks"
        case months = "Months"
        case years = "Years"

        var id: String { rawValue }

        var bucketCount: Int {
            switch self {
            case .days:
                return 30
            case .weeks:
                return 12
            case .months:
                return 12
            case .years:
                return 5
            }
        }

        var subtitle: String {
            switch self {
            case .days:
                return "Last 30 days"
            case .weeks:
                return "Last 12 weeks"
            case .months:
                return "Last 12 months"
            case .years:
                return "Last 5 years"
            }
        }
    }

    private struct RunningCumulativePoint: Identifiable {
        let id: Date
        let bucketStart: Date
        let cumulativeMiles: Double
        let bucketMiles: Double
    }

    private var hasSessionData: Bool {
        !store.state.sessions.isEmpty
    }

    private var runSessions: [WorkoutSession] {
        store.state.sessions
            .filter { ($0.run?.distanceMiles ?? 0) > 0 }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private var runningCumulativePoints: [RunningCumulativePoint] {
        cumulativeRunningPoints(for: selectedRunningRange)
    }

    private var loadCalculator: TrainingLoadCalculator {
        TrainingLoadCalculator(
            sessions: store.state.sessions,
            calendar: .current,
            weekStartsOnMonday: store.state.preferences.weekStartsOnMonday
        )
    }

    private var thisWeekLoad: WeeklyTrainingLoad {
        loadCalculator.weeklyLoad(for: Date())
    }

    private var lastWeekLoad: WeeklyTrainingLoad {
        let previousWeekReferenceDate = Calendar.current.date(
            byAdding: .day,
            value: -7,
            to: thisWeekLoad.weekStart
        ) ?? Date()
        return loadCalculator.weeklyLoad(for: previousWeekReferenceDate)
    }

    private var weekDeltaPercent: Double? {
        guard hasSessionData else { return nil }
        return loadCalculator.weekOverWeekDeltaPercent(
            thisWeek: thisWeekLoad.totalLoad,
            lastWeek: lastWeekLoad.totalLoad
        )
    }

    private var totalLoadText: String {
        hasSessionData ? formatLoad(thisWeekLoad.totalLoad) : "—"
    }

    private var liftingLoadText: String {
        hasSessionData ? formatLoad(thisWeekLoad.liftingLoad) : "—"
    }

    private var runningLoadText: String {
        hasSessionData ? formatLoad(thisWeekLoad.runningLoad) : "—"
    }

    private var deltaText: String {
        guard let delta = weekDeltaPercent else { return "—" }
        let roundedMagnitude = Int(abs(delta).rounded())
        if delta > 0 {
            return "↑ \(roundedMagnitude)%"
        }
        if delta < 0 {
            return "↓ \(roundedMagnitude)%"
        }
        return "0%"
    }

    private var deltaColor: Color {
        guard let delta = weekDeltaPercent else { return .secondary }
        if delta > 0 {
            return .accentColor
        }
        if delta < 0 {
            return .red
        }
        return .secondary
    }

    private var shouldShowThisWeekEmptyHint: Bool {
        thisWeekLoad.sessionCount == 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !hasSessionData {
                    emptyStateCard
                }

                thisWeekSection
                runningInsightsSection
                trendsSection
                consistencySection
            }
            .padding()
        }
        .navigationTitle("Insights")
    }

    private var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No data yet")
                .font(.headline)

            Text("Start logging workouts to see insights.")
                .foregroundStyle(.secondary)

            Button {
                NotificationCenter.default.post(name: .navigateToWorkoutTab, object: nil)
            } label: {
                Text("Start Session")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .glassCard()
    }

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("This Week")

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Total Load")
                        .font(.headline)
                    Spacer()
                    Text(totalLoadText)
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                }

                insightRow(title: "Lifting", value: liftingLoadText)
                insightRow(title: "Running", value: runningLoadText)
                insightRow(title: "Δ vs last week", value: deltaText, valueColor: deltaColor)

                if shouldShowThisWeekEmptyHint {
                    Text("Log sessions to unlock insights.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .glassCard()
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Trends")

            VStack(spacing: 10) {
                insightRow(title: "Strength Trends", value: "—")
                insightRow(title: "Run Trends", value: "—")
                insightRow(title: "Volume Trend", value: "—")
            }
            .glassCard()
        }
    }

    private var runningInsightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Running Insights")

            VStack(alignment: .leading, spacing: 12) {
                Picker("Range", selection: $selectedRunningRange) {
                    ForEach(RunningRange.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedRunningRange.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if runSessions.isEmpty {
                    Text("Log runs to unlock cumulative distance insights.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    Chart(runningCumulativePoints) { point in
                        AreaMark(
                            x: .value("Date", point.bucketStart),
                            y: .value("Cumulative Miles", point.cumulativeMiles)
                        )
                        .foregroundStyle(runningAccent.opacity(0.14))
                        .interpolationMethod(.monotone)

                        LineMark(
                            x: .value("Date", point.bucketStart),
                            y: .value("Cumulative Miles", point.cumulativeMiles)
                        )
                        .foregroundStyle(runningAccent)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.monotone)
                    }
                    .frame(height: 210)

                    insightRow(
                        title: "Cumulative Distance",
                        value: "\(String(format: "%.2f", runningCumulativePoints.last?.cumulativeMiles ?? 0)) mi"
                    )
                }
            }
            .glassCard()
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Consistency")

            VStack(spacing: 10) {
                insightRow(title: "Sessions (7 days)", value: "0")
                insightRow(title: "Most common day", value: "—")
                insightRow(title: "This month", value: "0")
            }
            .glassCard()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func insightRow(title: String, value: String, valueColor: Color = .primary) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(valueColor)
        }
    }

    private func formatLoad(_ value: Double) -> String {
        let roundedValue = Int(value.rounded())
        return Self.loadFormatter.string(from: NSNumber(value: roundedValue)) ?? "\(roundedValue)"
    }

    private var bucketingCalendar: Calendar {
        var calendar = Calendar.current
        if store.state.preferences.weekStartsOnMonday {
            calendar.firstWeekday = 2
        }
        return calendar
    }

    private func cumulativeRunningPoints(for range: RunningRange) -> [RunningCumulativePoint] {
        let calendar = bucketingCalendar
        let bucketStarts = runningBucketStarts(for: range, calendar: calendar)
        guard let firstBucket = bucketStarts.first, let lastBucket = bucketStarts.last else { return [] }

        var bucketTotals: [Date: Double] = [:]
        for session in runSessions {
            guard let run = session.run else { continue }
            let miles = max(0, run.distanceMiles)
            guard miles > 0 else { continue }
            let bucket = runningBucketStart(for: session.completedAt, range: range, calendar: calendar)
            guard bucket >= firstBucket, bucket <= lastBucket else { continue }
            bucketTotals[bucket, default: 0] += miles
        }

        var cumulativeMiles: Double = 0
        return bucketStarts.map { bucket in
            let bucketMiles = bucketTotals[bucket, default: 0]
            cumulativeMiles += bucketMiles
            return RunningCumulativePoint(
                id: bucket,
                bucketStart: bucket,
                cumulativeMiles: cumulativeMiles,
                bucketMiles: bucketMiles
            )
        }
    }

    private func runningBucketStarts(for range: RunningRange, calendar: Calendar) -> [Date] {
        switch range {
        case .days:
            let end = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -(range.bucketCount - 1), to: end) ?? end
            return (0..<range.bucketCount).compactMap {
                calendar.date(byAdding: .day, value: $0, to: start).map(calendar.startOfDay(for:))
            }
        case .weeks:
            let end = startOfWeek(for: Date(), calendar: calendar)
            let start = calendar.date(byAdding: .weekOfYear, value: -(range.bucketCount - 1), to: end) ?? end
            return (0..<range.bucketCount).compactMap {
                calendar.date(byAdding: .weekOfYear, value: $0, to: start).map { startOfWeek(for: $0, calendar: calendar) }
            }
        case .months:
            let end = startOfMonth(for: Date(), calendar: calendar)
            let start = calendar.date(byAdding: .month, value: -(range.bucketCount - 1), to: end) ?? end
            return (0..<range.bucketCount).compactMap {
                calendar.date(byAdding: .month, value: $0, to: start).map { startOfMonth(for: $0, calendar: calendar) }
            }
        case .years:
            let end = startOfYear(for: Date(), calendar: calendar)
            let start = calendar.date(byAdding: .year, value: -(range.bucketCount - 1), to: end) ?? end
            return (0..<range.bucketCount).compactMap {
                calendar.date(byAdding: .year, value: $0, to: start).map { startOfYear(for: $0, calendar: calendar) }
            }
        }
    }

    private func runningBucketStart(for date: Date, range: RunningRange, calendar: Calendar) -> Date {
        switch range {
        case .days:
            return calendar.startOfDay(for: date)
        case .weeks:
            return startOfWeek(for: date, calendar: calendar)
        case .months:
            return startOfMonth(for: date, calendar: calendar)
        case .years:
            return startOfYear(for: date, calendar: calendar)
        }
    }

    private func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func startOfYear(for date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }
}
