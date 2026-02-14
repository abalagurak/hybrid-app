import SwiftUI
import Charts
import CoreLocation

extension Notification.Name {
    static let navigateToWorkoutTab = Notification.Name("navigateToWorkoutTab")
}

private extension Color {
    static let runningInsightAccent = Color(red: 0.07, green: 0.53, blue: 0.95)
    static let liftingInsightAccent = Color(red: 0.93, green: 0.41, blue: 0.12)
}

private enum InsightsSection: String, CaseIterable, Identifiable {
    case running = "Running"
    case lifting = "Lifting"

    var id: String { rawValue }
}

private enum InsightsTimeRange: String, CaseIterable, Identifiable {
    case eightWeeks = "8W"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"

    var id: String { rawValue }
}

private enum RunningCumulativeBucket: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }
}

private enum LiftingFocus: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case volume = "Volume"

    var id: String { rawValue }
}

private enum PRDistance: String, CaseIterable, Identifiable {
    case mile = "Mile"
    case fiveK = "5K"
    case tenK = "10K"

    var id: String { rawValue }

    var miles: Double {
        switch self {
        case .mile:
            return 1.0
        case .fiveK:
            return 3.106856
        case .tenK:
            return 6.213712
        }
    }
}

private struct CumulativeDistancePoint: Identifiable {
    let date: Date
    let cumulativeMiles: Double
    let bucketMiles: Double

    var id: Date { date }
}

private struct WeeklyMileagePoint: Identifiable {
    let weekStart: Date
    let miles: Double
    var rollingAverageMiles: Double

    var id: Date { weekStart }
}

private struct PaceDistributionBin: Identifiable {
    let lowerBoundSec: Double
    let upperBoundSec: Double
    let count: Int

    var id: Double { lowerBoundSec }
}

private struct PRProgressPoint: Identifiable {
    let distance: PRDistance
    let date: Date
    let seconds: Double

    var id: String { "\(distance.rawValue)-\(date.timeIntervalSinceReferenceDate)" }
}

private struct ElevationProfilePoint: Identifiable {
    let mile: Double
    let elevationFeet: Double

    var id: Double { mile }
}

private struct SegmentComparisonPoint: Identifiable {
    let label: String
    let allTimePaceSec: Double
    let recentPaceSec: Double?

    var id: String { label }
}

private struct ExerciseSessionPoint: Identifiable {
    let sessionID: UUID
    let date: Date
    let estimatedOneRM: Double
    let maxWeight: Double
    let volume: Double
    let repsAtTargetWeight: Int?

    var id: UUID { sessionID }
}

private struct ExerciseVolumePoint: Identifiable {
    let date: Date
    let volume: Double
    let rollingAverageVolume: Double

    var id: Date { date }
}

private struct ExerciseFrequencyPoint: Identifiable {
    let weekStart: Date
    let count: Int

    var id: Date { weekStart }
}

struct PremiumInsightsView: View {
    @EnvironmentObject private var store: TrainingStore

    private static let compactNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    @State private var selectedSection: InsightsSection = .running
    @State private var selectedRange: InsightsTimeRange = .sixMonths
    @State private var runningBucket: RunningCumulativeBucket = .week
    @State private var liftingFocus: LiftingFocus = .strength
    @State private var selectedExercise = ""
    @State private var targetWeight: Double = 135
    @State private var selectedElevationSessionID: UUID?

    private var calendar: Calendar {
        var configured = Calendar.current
        configured.firstWeekday = store.state.preferences.weekStartsOnMonday ? 2 : 1
        return configured
    }

    private var weightUnit: String {
        store.state.preferences.measurementSystem.weightUnit
    }

    private var weightStep: Double {
        store.state.preferences.measurementSystem == .imperial ? 5 : 2.5
    }

    private var weightTolerance: Double {
        store.state.preferences.measurementSystem == .imperial ? 2.5 : 1.25
    }

    private var allRunningSessions: [WorkoutSession] {
        store.state.sessions
            .filter { ($0.run?.distanceMiles ?? 0) > 0 }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private var filteredRunningSessions: [WorkoutSession] {
        guard let cutoff = cutoffDate(for: selectedRange) else { return allRunningSessions }
        return allRunningSessions.filter { $0.completedAt >= cutoff }
    }

    private var allLiftingSessions: [WorkoutSession] {
        store.state.sessions
            .filter { $0.liftingLoad > 0 }
            .sorted { $0.completedAt < $1.completedAt }
    }

    private var filteredLiftingSessions: [WorkoutSession] {
        guard let cutoff = cutoffDate(for: selectedRange) else { return allLiftingSessions }
        return allLiftingSessions.filter { $0.completedAt >= cutoff }
    }

    private var availableExercises: [String] {
        store.exerciseNamesWithHistory
    }

    private var runningTotalMiles: Double {
        filteredRunningSessions.reduce(0) { $0 + max(0, $1.run?.distanceMiles ?? 0) }
    }

    private var weeklyMileagePoints: [WeeklyMileagePoint] {
        guard !filteredRunningSessions.isEmpty else { return [] }

        var milesByWeek: [Date: Double] = [:]
        for session in filteredRunningSessions {
            let weekStart = startOfWeek(for: session.completedAt)
            milesByWeek[weekStart, default: 0] += max(0, session.run?.distanceMiles ?? 0)
        }

        guard let firstObservedWeek = milesByWeek.keys.min() else { return [] }
        let firstWeek = cutoffDate(for: selectedRange).map(startOfWeek(for:)) ?? firstObservedWeek
        let lastWeek = startOfWeek(for: Date())
        let weeks = enumerateDates(from: firstWeek, to: lastWeek, component: .weekOfYear)

        var points = weeks.map { week in
            WeeklyMileagePoint(
                weekStart: week,
                miles: milesByWeek[week] ?? 0,
                rollingAverageMiles: 0
            )
        }

        for index in points.indices {
            let lower = max(0, index - 3)
            let slice = points[lower...index]
            let average = slice.reduce(0) { $0 + $1.miles } / Double(slice.count)
            points[index].rollingAverageMiles = average
        }
        return points
    }

    private var averageWeeklyMiles: Double {
        guard !weeklyMileagePoints.isEmpty else { return 0 }
        let total = weeklyMileagePoints.reduce(0) { $0 + $1.miles }
        return total / Double(weeklyMileagePoints.count)
    }

    private var cumulativeDistancePoints: [CumulativeDistancePoint] {
        guard !filteredRunningSessions.isEmpty else { return [] }

        var milesByBucket: [Date: Double] = [:]
        for session in filteredRunningSessions {
            let bucketStart = bucketStartDate(for: session.completedAt, bucket: runningBucket)
            milesByBucket[bucketStart, default: 0] += max(0, session.run?.distanceMiles ?? 0)
        }

        guard let earliestBucket = milesByBucket.keys.min() else { return [] }
        let start = cutoffDate(for: selectedRange).map { bucketStartDate(for: $0, bucket: runningBucket) } ?? earliestBucket
        let end = bucketStartDate(for: Date(), bucket: runningBucket)
        let dates = enumerateDates(from: start, to: end, component: calendarComponent(for: runningBucket))

        var cumulative = 0.0
        return dates.map { date in
            let miles = milesByBucket[date] ?? 0
            cumulative += miles
            return CumulativeDistancePoint(date: date, cumulativeMiles: cumulative, bucketMiles: miles)
        }
    }

    private var paceDistributionBins: [PaceDistributionBin] {
        let values = filteredRunningSessions
            .flatMap { paceSamples(for: $0.run) }
            .filter { $0 > 0 }

        guard let minPace = values.min(), let maxPace = values.max() else { return [] }

        let width = 30.0
        let minBound = floor(minPace / width) * width
        let maxBound = ceil(maxPace / width) * width
        var counts: [Double: Int] = [:]

        for value in values {
            let key = floor(value / width) * width
            counts[key, default: 0] += 1
        }

        var bins: [PaceDistributionBin] = []
        var cursor = minBound
        while cursor <= maxBound {
            bins.append(
                PaceDistributionBin(
                    lowerBoundSec: cursor,
                    upperBoundSec: cursor + width,
                    count: counts[cursor] ?? 0
                )
            )
            cursor += width
        }
        return bins
    }

    private var medianPaceSec: Double? {
        let values = filteredRunningSessions
            .flatMap { paceSamples(for: $0.run) }
            .sorted()
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        if values.count.isMultiple(of: 2) {
            return (values[middle - 1] + values[middle]) / 2
        }
        return values[middle]
    }

    private var bestSegmentsRows: [SegmentComparisonPoint] {
        let recentCutoff = calendar.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        let definitions: [(label: String, miles: Double)] = [
            ("0.5 mi", 0.5),
            ("1 mi", 1.0),
            ("2 mi", 2.0)
        ]

        return definitions.compactMap { definition in
            let allTime = allRunningSessions.compactMap { session in
                session.run.flatMap { bestSegmentSeconds(for: $0, distanceMiles: definition.miles) }
            }.min()
            guard let allTime else { return nil }

            let recent = allRunningSessions
                .filter { $0.completedAt >= recentCutoff }
                .compactMap { session in
                    session.run.flatMap { bestSegmentSeconds(for: $0, distanceMiles: definition.miles) }
                }
                .min()

            return SegmentComparisonPoint(
                label: definition.label,
                allTimePaceSec: allTime / definition.miles,
                recentPaceSec: recent.map { $0 / definition.miles }
            )
        }
    }

    private var elevationSessions: [WorkoutSession] {
        filteredRunningSessions
            .filter(hasUsableElevationData(session:))
            .sorted { $0.completedAt > $1.completedAt }
    }

    private var selectedElevationSession: WorkoutSession? {
        guard !elevationSessions.isEmpty else { return nil }
        if let selectedElevationSessionID,
           let selected = elevationSessions.first(where: { $0.id == selectedElevationSessionID }) {
            return selected
        }
        return elevationSessions.first
    }

    private var selectedElevationPoints: [ElevationProfilePoint] {
        guard let run = selectedElevationSession?.run else { return [] }
        return elevationPoints(for: run)
    }

    private var selectedElevationGainLoss: (gain: Double, loss: Double) {
        guard selectedElevationPoints.count >= 2 else { return (0, 0) }
        var gain = 0.0
        var loss = 0.0

        for index in 1..<selectedElevationPoints.count {
            let delta = selectedElevationPoints[index].elevationFeet - selectedElevationPoints[index - 1].elevationFeet
            if delta > 0 {
                gain += delta
            } else {
                loss += abs(delta)
            }
        }
        return (gain, loss)
    }

    private var exerciseSessionPoints: [ExerciseSessionPoint] {
        guard !selectedExercise.isEmpty else { return [] }
        return filteredLiftingSessions.compactMap { session in
            let sets = usableSets(in: session, for: selectedExercise)
            guard !sets.isEmpty else { return nil }
            let maxWeight = sets.map(\.weight).max() ?? 0
            let estimatedOneRM = sets.map { estimateOneRM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            let volume = sets.reduce(0) { partial, set in
                partial + (set.weight * Double(set.reps))
            }
            let repsAtTarget = sets
                .filter { abs($0.weight - targetWeight) <= weightTolerance }
                .map(\.reps)
                .max()
            return ExerciseSessionPoint(
                sessionID: session.id,
                date: session.completedAt,
                estimatedOneRM: estimatedOneRM,
                maxWeight: maxWeight,
                volume: volume,
                repsAtTargetWeight: repsAtTarget
            )
        }
        .sorted { $0.date < $1.date }
    }

    private var exerciseVolumePoints: [ExerciseVolumePoint] {
        guard !exerciseSessionPoints.isEmpty else { return [] }
        var points: [ExerciseVolumePoint] = []
        for index in exerciseSessionPoints.indices {
            let lower = max(0, index - 2)
            let slice = exerciseSessionPoints[lower...index]
            let rollingAverage = slice.reduce(0) { $0 + $1.volume } / Double(slice.count)
            points.append(
                ExerciseVolumePoint(
                    date: exerciseSessionPoints[index].date,
                    volume: exerciseSessionPoints[index].volume,
                    rollingAverageVolume: rollingAverage
                )
            )
        }
        return points
    }

    private var repsAtTargetPoints: [(date: Date, reps: Int)] {
        exerciseSessionPoints.compactMap { point in
            guard let reps = point.repsAtTargetWeight else { return nil }
            return (point.date, reps)
        }
    }

    private var frequencyPoints: [ExerciseFrequencyPoint] {
        guard !selectedExercise.isEmpty else { return [] }
        let sessions = filteredLiftingSessions.filter { !usableSets(in: $0, for: selectedExercise).isEmpty }
        guard !sessions.isEmpty else { return [] }

        var counts: [Date: Int] = [:]
        for session in sessions {
            let weekStart = startOfWeek(for: session.completedAt)
            counts[weekStart, default: 0] += 1
        }

        guard let firstWeekObserved = counts.keys.min() else { return [] }
        let firstWeek = cutoffDate(for: selectedRange).map(startOfWeek(for:)) ?? firstWeekObserved
        let lastWeek = startOfWeek(for: Date())
        let weeks = enumerateDates(from: firstWeek, to: lastWeek, component: .weekOfYear)
        return weeks.map { week in
            ExerciseFrequencyPoint(weekStart: week, count: counts[week] ?? 0)
        }
    }

    private var exerciseSummarySessions: Int {
        exerciseSessionPoints.count
    }

    private var exerciseBestEstimatedOneRM: Double {
        exerciseSessionPoints.map(\.estimatedOneRM).max() ?? 0
    }

    private var exerciseBestWeight: Double {
        exerciseSessionPoints.map(\.maxWeight).max() ?? 0
    }

    private var exerciseTotalVolume: Double {
        exerciseSessionPoints.reduce(0) { $0 + $1.volume }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controlsCard

                switch selectedSection {
                case .running:
                    runningContent
                case .lifting:
                    liftingContent
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
        .onAppear {
            syncSelections()
        }
        .onChange(of: store.state.sessions) { _, _ in
            syncSelections()
        }
        .onChange(of: selectedRange) { _, _ in
            syncElevationSelection()
        }
        .onChange(of: selectedExercise) { _, _ in
            applySuggestedTargetWeightIfPossible()
        }
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Insights", selection: $selectedSection) {
                ForEach(InsightsSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)

            Picker("Time Range", selection: $selectedRange) {
                ForEach(InsightsTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
        .glassCard()
    }

    @ViewBuilder
    private var runningContent: some View {
        if filteredRunningSessions.isEmpty {
            emptyStateCard(
                title: "No running data in this range",
                description: "Log a run to unlock trend charts and performance distributions."
            )
        } else {
            runningSummaryCard
            cumulativeDistanceCard
            weeklyMileageTrendCard
            paceDistributionCard
            prProgressionCard
            elevationProfileCard
            bestSegmentsCard
        }
    }

    @ViewBuilder
    private var liftingContent: some View {
        if filteredLiftingSessions.isEmpty {
            emptyStateCard(
                title: "No lifting data in this range",
                description: "Complete lifting sets to unlock strength and volume analytics."
            )
        } else {
            exerciseSelectionCard

            if selectedExercise.isEmpty {
                Text("Select an exercise to view progression.")
                    .foregroundStyle(.secondary)
                    .glassCard()
            } else if exerciseSessionPoints.isEmpty {
                Text("No sessions for \(selectedExercise) in this range.")
                    .foregroundStyle(.secondary)
                    .glassCard()
            } else {
                exerciseSummaryCard

                if liftingFocus == .strength {
                    estimatedOneRMCard
                    maxWeightCard
                    volumeCard
                } else {
                    volumeCard
                    estimatedOneRMCard
                    maxWeightCard
                }
                repsAtTargetWeightCard
                frequencyCard
            }
        }
    }

    private var runningSummaryCard: some View {
        HStack(spacing: 10) {
            insightStatTile(
                title: "Miles",
                value: formatDecimal(runningTotalMiles, digits: 1),
                subtitle: "Total",
                accent: .runningInsightAccent
            )
            insightStatTile(
                title: "Avg / Week",
                value: formatDecimal(averageWeeklyMiles, digits: 1),
                subtitle: "Miles",
                accent: .runningInsightAccent
            )
            insightStatTile(
                title: "Runs",
                value: "\(filteredRunningSessions.count)",
                subtitle: selectedRange.rawValue,
                accent: .runningInsightAccent
            )
        }
    }

    private var cumulativeDistanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cumulative Distance")
                    .font(.headline)
                Spacer()
                Text("Miles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Granularity", selection: $runningBucket) {
                ForEach(RunningCumulativeBucket.allCases) { bucket in
                    Text(bucket.rawValue).tag(bucket)
                }
            }
            .pickerStyle(.segmented)

            if cumulativeDistancePoints.isEmpty {
                Text("Not enough data for this chart.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(cumulativeDistancePoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Cumulative Miles", point.cumulativeMiles)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.runningInsightAccent.opacity(0.14))

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Cumulative Miles", point.cumulativeMiles)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.runningInsightAccent)
                    .lineStyle(.init(lineWidth: 2))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 230)
                .accessibilityLabel("Cumulative running distance over time")
            }
        }
        .glassCard()
    }

    private var weeklyMileageTrendCard: some View {
        let maxValue = max(weeklyMileagePoints.map(\.miles).max() ?? 0, weeklyMileagePoints.map(\.rollingAverageMiles).max() ?? 0)
        let yMax = max(1, maxValue * 1.2)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Mileage Trend")
                .font(.headline)

            Chart(weeklyMileagePoints) { point in
                BarMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Miles", point.miles)
                )
                .foregroundStyle(Color.runningInsightAccent.opacity(0.35))

                LineMark(
                    x: .value("Week", point.weekStart),
                    y: .value("4-week Avg", point.rollingAverageMiles)
                )
                .foregroundStyle(Color.runningInsightAccent)
                .lineStyle(.init(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...yMax)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)
            .accessibilityLabel("Weekly mileage and rolling average")
        }
        .glassCard()
    }

    private var paceDistributionCard: some View {
        let maxCount = max(1, paceDistributionBins.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pace Distribution")
                    .font(.headline)
                Spacer()
                Text("Lower is faster")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if paceDistributionBins.isEmpty {
                Text("Pace distribution requires split or average pace data.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(paceDistributionBins) { bin in
                    RectangleMark(
                        xStart: .value("Pace Start", bin.lowerBoundSec),
                        xEnd: .value("Pace End", bin.upperBoundSec),
                        y: .value("Runs", bin.count)
                    )
                    .foregroundStyle(Color.runningInsightAccent)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYScale(domain: 0...Double(maxCount + 1))
                .chartXAxis {
                    AxisMarks { value in
                        if let seconds = value.as(Double.self) {
                            AxisValueLabel(formatPace(secondsPerMile: seconds, includeUnit: false))
                        }
                    }
                }
                .frame(height: 200)

                if let medianPaceSec {
                    HStack {
                        Text("Median")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatPace(secondsPerMile: medianPaceSec))
                            .font(.caption.weight(.semibold).monospacedDigit())
                    }
                }
            }
        }
        .glassCard()
    }

    private var prProgressionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PR Progression")
                    .font(.headline)
                Spacer()
                Text("Lower is faster")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(PRDistance.allCases) { distance in
                let points = prProgressionPoints(for: distance)
                VStack(alignment: .leading, spacing: 6) {
                    Text(distance.rawValue)
                        .font(.subheadline.weight(.semibold))
                    if points.isEmpty {
                        Text("No \(distance.rawValue) progression in this range.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Chart(points) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Time", point.seconds)
                            )
                            .foregroundStyle(Color.runningInsightAccent)
                            .lineStyle(.init(lineWidth: 2))
                            .interpolationMethod(.stepEnd)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Time", point.seconds)
                            )
                            .foregroundStyle(Color.runningInsightAccent)
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                if let seconds = value.as(Double.self) {
                                    AxisValueLabel(formatClock(seconds: Int(seconds.rounded())))
                                }
                            }
                        }
                        .frame(height: 140)
                    }
                }
            }
        }
        .glassCard()
    }

    private var elevationProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Elevation Profile")
                    .font(.headline)
                Spacer()
                if !elevationSessions.isEmpty {
                    Picker("Run", selection: Binding<UUID?>(
                        get: { selectedElevationSessionID ?? elevationSessions.first?.id },
                        set: { selectedElevationSessionID = $0 }
                    )) {
                        ForEach(elevationSessions.prefix(20)) { session in
                            let miles = max(0, session.run?.distanceMiles ?? 0)
                            Text("\(session.completedAt.formatted(date: .abbreviated, time: .omitted)) • \(formatDecimal(miles, digits: 1)) mi")
                                .tag(Optional(session.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if selectedElevationPoints.count < 2 {
                Text("Elevation profile is available for GPS runs with altitude samples.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(selectedElevationPoints) { point in
                    AreaMark(
                        x: .value("Distance", point.mile),
                        y: .value("Elevation", point.elevationFeet)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [Color.runningInsightAccent.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Distance", point.mile),
                        y: .value("Elevation", point.elevationFeet)
                    )
                    .foregroundStyle(Color.runningInsightAccent)
                    .lineStyle(.init(lineWidth: 2))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 220)

                HStack(spacing: 14) {
                    elevationMetricPill(title: "Gain", value: "\(Int(selectedElevationGainLoss.gain.rounded())) ft")
                    elevationMetricPill(title: "Loss", value: "\(Int(selectedElevationGainLoss.loss.rounded())) ft")
                }
            }
        }
        .glassCard()
    }

    private var bestSegmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Best Segments")
                    .font(.headline)
                Spacer()
                Text("All-time vs 90 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if bestSegmentsRows.isEmpty {
                Text("Best-segment data will appear after more run samples.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(bestSegmentsRows) { row in
                    RuleMark(
                        xStart: .value("All-time", row.allTimePaceSec),
                        xEnd: .value("Recent", row.recentPaceSec ?? row.allTimePaceSec),
                        y: .value("Segment", row.label)
                    )
                    .foregroundStyle(Color.runningInsightAccent.opacity(0.3))

                    PointMark(
                        x: .value("All-time", row.allTimePaceSec),
                        y: .value("Segment", row.label)
                    )
                    .foregroundStyle(Color.runningInsightAccent)
                    .symbolSize(70)

                    if let recent = row.recentPaceSec {
                        PointMark(
                            x: .value("Recent", recent),
                            y: .value("Segment", row.label)
                        )
                        .foregroundStyle(.secondary)
                        .symbolSize(55)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        if let seconds = value.as(Double.self) {
                            AxisValueLabel(formatPace(secondsPerMile: seconds, includeUnit: false))
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .glassCard()
    }

    private var exerciseSelectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercise Analysis")
                    .font(.headline)
                Spacer()
                Picker("Exercise", selection: $selectedExercise) {
                    ForEach(availableExercises, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .pickerStyle(.menu)
            }

            Picker("Focus", selection: $liftingFocus) {
                ForEach(LiftingFocus.allCases) { focus in
                    Text(focus.rawValue).tag(focus)
                }
            }
            .pickerStyle(.segmented)
        }
        .glassCard()
    }

    private var exerciseSummaryCard: some View {
        HStack(spacing: 10) {
            insightStatTile(
                title: "Sessions",
                value: "\(exerciseSummarySessions)",
                subtitle: selectedRange.rawValue,
                accent: .liftingInsightAccent
            )
            insightStatTile(
                title: "Best e1RM",
                value: formatWeight(exerciseBestEstimatedOneRM),
                subtitle: weightUnit,
                accent: .liftingInsightAccent
            )
            insightStatTile(
                title: "Best Load",
                value: formatWeight(exerciseBestWeight),
                subtitle: weightUnit,
                accent: .liftingInsightAccent
            )
        }
    }

    private var estimatedOneRMCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated 1RM")
                .font(.headline)

            Chart(exerciseSessionPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated 1RM", point.estimatedOneRM)
                )
                .foregroundStyle(Color.liftingInsightAccent)
                .lineStyle(.init(lineWidth: 2))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Estimated 1RM", point.estimatedOneRM)
                )
                .foregroundStyle(Color.liftingInsightAccent)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            HStack {
                Text("Peak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatWeight(exerciseBestEstimatedOneRM))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
        }
        .glassCard()
    }

    private var maxWeightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Max Weight Progression")
                .font(.headline)

            Chart(exerciseSessionPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Max Weight", point.maxWeight)
                )
                .interpolationMethod(.stepEnd)
                .foregroundStyle(Color.liftingInsightAccent)
                .lineStyle(.init(lineWidth: 2.5))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
        }
        .glassCard()
    }

    private var volumeCard: some View {
        let maxVolume = max(exerciseVolumePoints.map(\.volume).max() ?? 0, exerciseVolumePoints.map(\.rollingAverageVolume).max() ?? 0)
        let yMax = max(1, maxVolume * 1.2)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Volume Per Workout")
                .font(.headline)

            Chart(exerciseVolumePoints) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Volume", point.volume)
                )
                .foregroundStyle(Color.liftingInsightAccent.opacity(0.35))

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("3-session Avg", point.rollingAverageVolume)
                )
                .foregroundStyle(Color.liftingInsightAccent)
                .lineStyle(.init(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }
            .chartYScale(domain: 0...yMax)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 220)

            HStack {
                Text("Total volume")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatCompactNumber(exerciseTotalVolume))
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
        }
        .glassCard()
    }

    private var repsAtTargetWeightCard: some View {
        let maxWeight = max(exerciseBestWeight * 1.2, targetWeight)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Reps At Specific Weight")
                .font(.headline)

            Stepper(
                value: $targetWeight,
                in: 0...max(10, maxWeight),
                step: weightStep
            ) {
                HStack {
                    Text("Target")
                    Spacer()
                    Text("\(formatWeight(targetWeight))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            if repsAtTargetPoints.isEmpty {
                Text("No sets near this weight yet.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(repsAtTargetPoints, id: \.date) { point in
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Reps", point.reps)
                    )
                    .foregroundStyle(Color.liftingInsightAccent)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Reps", point.reps)
                    )
                    .foregroundStyle(Color.liftingInsightAccent.opacity(0.7))
                    .lineStyle(.init(lineWidth: 2))
                }
                .chartYScale(domain: 0...max(5, Double((repsAtTargetPoints.map(\.reps).max() ?? 0) + 2)))
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
        }
        .glassCard()
    }

    private var frequencyCard: some View {
        let maxCount = max(1, frequencyPoints.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Frequency")
                .font(.headline)

            Chart(frequencyPoints) { point in
                BarMark(
                    x: .value("Week", point.weekStart, unit: .weekOfYear),
                    y: .value("Sessions", point.count)
                )
                .foregroundStyle(Color.liftingInsightAccent)
            }
            .chartYScale(domain: 0...Double(maxCount + 1))
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
        }
        .glassCard()
    }

    private func emptyStateCard(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(description)
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

    private func insightStatTile(title: String, value: String, subtitle: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(accent.opacity(0.85))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func elevationMetricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func syncSelections() {
        syncExerciseSelection()
        syncElevationSelection()
    }

    private func syncExerciseSelection() {
        guard !availableExercises.isEmpty else {
            selectedExercise = ""
            return
        }

        if !availableExercises.contains(selectedExercise) {
            selectedExercise = mostRecentExerciseName() ?? availableExercises.first ?? ""
            applySuggestedTargetWeightIfPossible()
        } else if targetWeight <= 0 {
            applySuggestedTargetWeightIfPossible()
        }
    }

    private func syncElevationSelection() {
        guard !elevationSessions.isEmpty else {
            selectedElevationSessionID = nil
            return
        }
        guard let selectedElevationSessionID else {
            self.selectedElevationSessionID = elevationSessions.first?.id
            return
        }
        if !elevationSessions.contains(where: { $0.id == selectedElevationSessionID }) {
            self.selectedElevationSessionID = elevationSessions.first?.id
        }
    }

    private func applySuggestedTargetWeightIfPossible() {
        guard let suggested = suggestedTargetWeight(for: selectedExercise) else { return }
        targetWeight = suggested
    }

    private func suggestedTargetWeight(for exerciseName: String) -> Double? {
        guard !exerciseName.isEmpty else { return nil }
        for session in store.sessionsNewestFirst {
            let sets = usableSets(in: session, for: exerciseName)
            if let best = sets.map(\.weight).max(), best > 0 {
                let rounded = (best / weightStep).rounded() * weightStep
                return max(weightStep, rounded)
            }
        }
        return nil
    }

    private func mostRecentExerciseName() -> String? {
        for session in store.sessionsNewestFirst {
            for exercise in session.exercises {
                let hasData = exercise.sets.contains { $0.reps > 0 && $0.weight > 0 }
                if hasData {
                    return exercise.name
                }
            }
        }
        return nil
    }

    private func cutoffDate(for range: InsightsTimeRange) -> Date? {
        let today = calendar.startOfDay(for: Date())
        switch range {
        case .eightWeeks:
            return calendar.date(byAdding: .weekOfYear, value: -8, to: today)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: today)
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: today)
        case .all:
            return nil
        }
    }

    private func startOfWeek(for date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func startOfMonth(for date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func startOfYear(for date: Date) -> Date {
        let components = calendar.dateComponents([.year], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func bucketStartDate(for date: Date, bucket: RunningCumulativeBucket) -> Date {
        switch bucket {
        case .day:
            return calendar.startOfDay(for: date)
        case .week:
            return startOfWeek(for: date)
        case .month:
            return startOfMonth(for: date)
        case .year:
            return startOfYear(for: date)
        }
    }

    private func calendarComponent(for bucket: RunningCumulativeBucket) -> Calendar.Component {
        switch bucket {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
        case .year:
            return .year
        }
    }

    private func enumerateDates(from start: Date, to end: Date, component: Calendar.Component) -> [Date] {
        guard start <= end else { return [] }
        var cursor = start
        var values: [Date] = []
        var guardrail = 0

        while cursor <= end, guardrail < 6000 {
            values.append(cursor)
            cursor = calendar.date(byAdding: component, value: 1, to: cursor) ?? cursor
            guardrail += 1
            if values.count > 6000 { break }
        }
        return values
    }

    private func paceSamples(for run: RunEntry?) -> [Double] {
        guard let run else { return [] }
        let splitPaces = run.splits
            .filter { $0.paceSecPerMile > 0 }
            .map { Double($0.paceSecPerMile) }
        if !splitPaces.isEmpty {
            return splitPaces
        }
        if let average = run.avgPaceSecPerMile, average > 0 {
            return [Double(average)]
        }
        guard run.distanceMiles > 0, run.durationSeconds > 0 else { return [] }
        return [Double(run.durationSeconds) / run.distanceMiles]
    }

    private func prProgressionPoints(for distance: PRDistance) -> [PRProgressPoint] {
        var bestSoFar = Double.greatestFiniteMagnitude
        var points: [PRProgressPoint] = []

        for session in allRunningSessions {
            guard let run = session.run else { continue }
            guard let candidate = bestRaceTime(for: run, targetMiles: distance.miles) else { continue }
            if candidate < bestSoFar {
                bestSoFar = candidate
                points.append(
                    PRProgressPoint(
                        distance: distance,
                        date: session.completedAt,
                        seconds: candidate
                    )
                )
            }
        }

        guard let cutoff = cutoffDate(for: selectedRange) else {
            return points
        }
        let baseline = points.last(where: { $0.date < cutoff })
        let inRange = points.filter { $0.date >= cutoff }
        if let baseline {
            return [baseline] + inRange
        }
        return inRange
    }

    private func bestRaceTime(for run: RunEntry, targetMiles: Double) -> Double? {
        guard run.distanceMiles >= targetMiles else { return nil }

        if let splitBest = bestWindowTime(from: run.splits, targetMiles: targetMiles) {
            return splitBest
        }

        if let average = run.avgPaceSecPerMile, average > 0 {
            return Double(average) * targetMiles
        }

        guard run.distanceMiles > 0, run.durationSeconds > 0 else { return nil }
        return (Double(run.durationSeconds) / run.distanceMiles) * targetMiles
    }

    private func bestSegmentSeconds(for run: RunEntry, distanceMiles: Double) -> Double? {
        return bestWindowTime(from: run.splits, targetMiles: distanceMiles)
    }

    private func bestWindowTime(from splits: [RunSplit], targetMiles: Double) -> Double? {
        let segments = splits
            .map { (distance: max(0, $0.distanceMiles), seconds: max(0, Double($0.durationSeconds))) }
            .filter { $0.distance > 0 && $0.seconds > 0 }
        guard !segments.isEmpty else { return nil }

        var cumulativeDistance = 0.0
        var cumulativeSeconds = 0.0
        var points: [(distance: Double, seconds: Double)] = [(0, 0)]
        for segment in segments {
            cumulativeDistance += segment.distance
            cumulativeSeconds += segment.seconds
            points.append((cumulativeDistance, cumulativeSeconds))
        }
        guard cumulativeDistance >= targetMiles else { return nil }

        var best: Double?
        var endIndex = 1
        for startIndex in 0..<(points.count - 1) {
            let start = points[startIndex]
            let target = start.distance + targetMiles
            if target > cumulativeDistance { break }

            while endIndex < points.count, points[endIndex].distance < target {
                endIndex += 1
            }
            guard endIndex < points.count else { break }

            let lower = points[max(startIndex, endIndex - 1)]
            let upper = points[endIndex]
            let endSeconds: Double
            if upper.distance <= lower.distance {
                endSeconds = upper.seconds
            } else {
                let ratio = (target - lower.distance) / (upper.distance - lower.distance)
                endSeconds = lower.seconds + ((upper.seconds - lower.seconds) * ratio)
            }
            let duration = endSeconds - start.seconds
            guard duration > 0 else { continue }
            if let current = best {
                best = min(current, duration)
            } else {
                best = duration
            }
        }
        return best
    }

    private func hasUsableElevationData(session: WorkoutSession) -> Bool {
        guard let route = session.run?.route else { return false }
        let altitudePoints = route.compactMap(\.altitudeMeters)
        return route.count >= 2 && altitudePoints.count >= 2
    }

    private func elevationPoints(for run: RunEntry) -> [ElevationProfilePoint] {
        guard let route = run.route else { return [] }
        let ordered = route.sorted { $0.timestamp < $1.timestamp }
        guard ordered.count >= 2 else { return [] }

        var points: [ElevationProfilePoint] = []
        var miles = 0.0

        if let firstAltitude = ordered.first?.altitudeMeters {
            points.append(ElevationProfilePoint(mile: 0, elevationFeet: firstAltitude * 3.28084))
        }

        for index in 1..<ordered.count {
            let previous = ordered[index - 1]
            let current = ordered[index]
            let segmentMeters = CLLocation(
                latitude: previous.latitude,
                longitude: previous.longitude
            )
            .distance(from: CLLocation(latitude: current.latitude, longitude: current.longitude))
            miles += max(0, segmentMeters) * 0.000621371

            if let altitude = current.altitudeMeters {
                points.append(ElevationProfilePoint(mile: miles, elevationFeet: altitude * 3.28084))
            }
        }

        guard points.count > 250 else { return points }
        let step = max(1, Int(ceil(Double(points.count) / 250)))
        return stride(from: 0, to: points.count, by: step).map { points[$0] }
    }

    private func usableSets(in session: WorkoutSession, for exerciseName: String) -> [LoggedSet] {
        let matchingExercises = session.exercises.filter {
            $0.name.caseInsensitiveCompare(exerciseName) == .orderedSame
        }
        let allSets = matchingExercises.flatMap(\.sets)
        let completedSets = allSets.filter(\.isCompleted)
        let source = completedSets.isEmpty ? allSets : completedSets
        return source.filter { $0.reps > 0 && $0.weight > 0 }
    }

    private func estimateOneRM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * (1 + (Double(reps) / 30.0))
    }

    private func formatPace(secondsPerMile: Double, includeUnit: Bool = true) -> String {
        let clamped = max(0, Int(secondsPerMile.rounded()))
        let minutes = clamped / 60
        let seconds = clamped % 60
        let base = String(format: "%d:%02d", minutes, seconds)
        if includeUnit {
            return "\(base) /mi"
        }
        return base
    }

    private func formatClock(seconds: Int) -> String {
        let clamped = max(0, seconds)
        if clamped >= 3600 {
            let hours = clamped / 3600
            let minutes = (clamped % 3600) / 60
            let secs = clamped % 60
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        let minutes = clamped / 60
        let secs = clamped % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatWeight(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.05 {
            return "\(Int(rounded.rounded())) \(weightUnit)"
        }
        return "\(String(format: "%.1f", rounded)) \(weightUnit)"
    }

    private func formatDecimal(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }

    private func formatCompactNumber(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return Self.compactNumberFormatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }
}
