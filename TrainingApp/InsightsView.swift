import SwiftUI
import Charts
import CoreLocation

extension Notification.Name {
    static let navigateToWorkoutTab = Notification.Name("navigateToWorkoutTab")
}

private struct InsightInfoButton: View {
    let message: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPopoverPresented = false
    @State private var isSheetPresented = false

    var body: some View {
        Button {
            if horizontalSizeClass == .compact {
                isSheetPresented = true
            } else {
                isPopoverPresented = true
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPopoverPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            InsightInfoPanel(message: message)
                .frame(minWidth: 280, idealWidth: 340, maxWidth: 420, minHeight: 140, maxHeight: 360)
        }
        .sheet(isPresented: $isSheetPresented) {
            NavigationStack {
                InsightInfoPanel(message: message)
                    .navigationTitle("Metric Info")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isSheetPresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.height(250), .medium])
            .presentationDragIndicator(.visible)
        }
        .accessibilityLabel("Metric info")
        .accessibilityHint(message)
    }
}

private struct InsightInfoPanel: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.liftingInsightAccent)
                Text("About this metric")
                    .font(.subheadline.weight(.semibold))
            }

            ScrollView {
                Text(message)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
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
    @State private var liftingInsightsCache: [InsightsTimeRange: LiftingInsightsSnapshot] = [:]
    @State private var loadingLiftingRange: InsightsTimeRange?

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
        filteredLiftingSessions(for: selectedRange)
    }

    private var selectedLiftingSnapshot: LiftingInsightsSnapshot? {
        liftingInsightsCache[selectedRange]
    }

    private var isLoadingSelectedLiftingSnapshot: Bool {
        loadingLiftingRange == selectedRange && selectedLiftingSnapshot == nil
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
        }
        .safeAreaPadding(.horizontal, AppUI.Spacing.screenHorizontal)
        .safeAreaPadding(.bottom, AppUI.Spacing.screenBottom)
        .navigationTitle("Insights")
        .onAppear {
            syncSelections()
            refreshLiftingSnapshotIfNeeded(for: selectedRange, force: true)
        }
        .onChange(of: store.state.sessions) { _, _ in
            syncSelections()
            liftingInsightsCache.removeAll()
            refreshLiftingSnapshotIfNeeded(for: selectedRange, force: true)
        }
        .onChange(of: selectedRange) { _, newRange in
            syncElevationSelection()
            refreshLiftingSnapshotIfNeeded(for: newRange)
        }
        .onChange(of: store.state.preferences.weekStartsOnMonday) { _, _ in
            liftingInsightsCache.removeAll()
            refreshLiftingSnapshotIfNeeded(for: selectedRange, force: true)
        }
        .onChange(of: selectedSection) { _, newSection in
            if newSection == .lifting {
                refreshLiftingSnapshotIfNeeded(for: selectedRange)
            }
        }
        .onChange(of: selectedExercise) { _, _ in
            applySuggestedTargetWeightIfPossible()
        }
    }

    private var controlsCard: some View {
        AppCard {
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
        }
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
            if let snapshot = selectedLiftingSnapshot {
                highlightsCard(summary: snapshot.globalHighlights)
                balanceCard(summary: snapshot.muscleGroupSummary)
                consistencyCard(summary: snapshot.consistencySummary)
            } else if isLoadingSelectedLiftingSnapshot {
                loadingLiftingInsightsCard
            } else {
                loadingLiftingInsightsCard
            }

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

    private var loadingLiftingInsightsCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Calculating lifting insights...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private func highlightsCard(summary: GlobalHighlightsSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Highlights") {
                InsightInfoButton(message: "Top PR and volume wins across all exercises in your selected time range.")
            }

            if !summary.hasUsableSets {
                Text("No usable sets in this range yet. Complete sets with weight and reps to unlock highlights.")
                    .foregroundStyle(.secondary)
            } else {
                if let highestE1RM = summary.highestE1RM {
                    liftInsightMetricRow(
                        title: "Highest e1RM overall",
                        value: formatWeight(highestE1RM.e1RM),
                        detail: "\(highestE1RM.exerciseName) • \(highestE1RM.date.formatted(date: .abbreviated, time: .omitted))",
                        info: "Estimated 1RM is computed as weight × (1 + reps/30), and this is the highest single-set value in range."
                    )
                }

                if let improvement = summary.biggestE1RMImprovement {
                    let deltaText = formatSignedWeight(improvement.delta)
                    let detail = "\(improvement.exerciseName) • \(improvement.firstDate.formatted(date: .abbreviated, time: .omitted)) to \(improvement.lastDate.formatted(date: .abbreviated, time: .omitted))"
                    liftInsightMetricRow(
                        title: "Biggest e1RM improvement",
                        value: deltaText,
                        detail: detail,
                        info: "For each exercise, this compares first-session best e1RM vs last-session best e1RM in range and picks the largest delta."
                    )
                } else {
                    liftInsightMetricRow(
                        title: "Biggest e1RM improvement",
                        value: "Not enough sessions yet",
                        detail: "Track at least 2 sessions for the same exercise to calculate improvement.",
                        info: "Improvement needs at least two sessions for one exercise within the selected range."
                    )
                }

                if let highestSession = summary.highestSessionVolume {
                    liftInsightMetricRow(
                        title: "Highest session volume",
                        value: formatCompactNumber(highestSession.volume),
                        detail: "\(highestSession.workoutName) • \(highestSession.date.formatted(date: .abbreviated, time: .omitted))",
                        info: "Session volume is the sum of weight × reps across all usable sets in that workout."
                    )
                }

                if let highestWeek = summary.highestWeeklyVolume {
                    liftInsightMetricRow(
                        title: "Highest weekly volume",
                        value: formatCompactNumber(highestWeek.volume),
                        detail: "Week of \(highestWeek.weekStart.formatted(date: .abbreviated, time: .omitted))",
                        info: "Weekly volume sums all usable-set volume from sessions grouped by calendar week."
                    )
                }
            }
        }
        .glassCard()
    }

    private func balanceCard(summary: MuscleGroupSummary) -> some View {
        let chartPoints = summary.weeklyVolumes
        let weeklyTotals = Dictionary(grouping: chartPoints, by: \.weekStart)
            .mapValues { points in
                points.reduce(0) { partial, point in
                    partial + point.volume
                }
            }
        let maxStackedWeeklyVolume = weeklyTotals.values.max() ?? 0
        let yMax = max(1, maxStackedWeeklyVolume * 1.2)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Balance") {
                InsightInfoButton(message: "Shows where your lifting volume is going by muscle group and whether push and pull are balanced.")
            }

            if !summary.hasUsableSets {
                Text("No usable sets in this range yet, so balance metrics are unavailable.")
                    .foregroundStyle(.secondary)
            } else {
                if chartPoints.isEmpty {
                    Text("Not enough weekly data to chart yet.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(chartPoints) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Volume", point.volume)
                        )
                        .foregroundStyle(by: .value("Muscle Group", point.muscleGroup.displayName))
                    }
                    .chartForegroundStyleScale(
                        domain: MuscleGroup.allCases.map(\.displayName),
                        range: MuscleGroup.allCases.map(muscleGroupColor(for:))
                    )
                    .chartYScale(domain: 0...yMax)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartPlotStyle { plotArea in
                        plotArea.clipped()
                    }
                    .chartLegend(position: .bottom, alignment: .leading)
                    .frame(height: 220)
                }

                liftInsightMetricRow(
                    title: "Push : Pull",
                    value: formatPushPullRatio(summary),
                    detail: pushPullStatusText(summary),
                    info: "This v1 ratio uses push = Chest + Shoulders and pull = Back for the selected range."
                )

                liftInsightMetricRow(
                    title: "Torso focus score",
                    value: "\(formatDecimal(summary.torsoFocusScore * 100, digits: 0))%",
                    detail: "Chest + Back + Shoulders volume divided by total lifting volume.",
                    info: "Higher values mean more of your training volume is concentrated on torso muscle groups."
                )
            }
        }
        .glassCard()
    }

    private func consistencyCard(summary: ConsistencySummary) -> some View {
        let maxWorkouts = max(1, summary.weeklyWorkoutCounts.map(\.workouts).max() ?? 1)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Consistency") {
                InsightInfoButton(message: "Tracks workout frequency, streaks, rest spacing, and recovery cadence by muscle group.")
            }

            if !summary.hasWorkoutDays {
                Text("No workout days with usable sets in this range yet.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(summary.weeklyWorkoutCounts) { point in
                    BarMark(
                        x: .value("Week", point.weekStart, unit: .weekOfYear),
                        y: .value("Workout Days", point.workouts)
                    )
                    .foregroundStyle(Color.liftingInsightAccent)
                }
                .chartYScale(domain: 0...Double(maxWorkouts + 1))
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)

                liftInsightMetricRow(
                    title: "Current streak",
                    value: "\(summary.currentStreakDays) day\(summary.currentStreakDays == 1 ? "" : "s")",
                    detail: "Consecutive workout days ending on your latest workout day in range.",
                    info: "A streak is one or more consecutive calendar days with at least one workout session that has usable sets."
                )

                liftInsightMetricRow(
                    title: "Longest streak",
                    value: "\(summary.longestStreakDays) day\(summary.longestStreakDays == 1 ? "" : "s")",
                    detail: "Best consecutive-day run in the selected range.",
                    info: "Longest streak scans the full range and returns the maximum run of consecutive workout days."
                )

                let avgRestText = summary.averageRestDaysBetweenSessions
                    .map { "\(formatDecimal($0, digits: 1)) days" }
                    ?? "Not enough data"
                liftInsightMetricRow(
                    title: "Average rest days",
                    value: avgRestText,
                    detail: "Computed between workout days (same-day multiple sessions count as one day).",
                    info: "Rest days are calendar days between workout days; back-to-back workouts count as 0 rest days."
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recovery spacing by muscle group")
                            .font(.subheadline.weight(.semibold))
                        InsightInfoButton(message: "Average days between workout days that include each muscle group.")
                    }

                    HStack {
                        Text("Muscle Group")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Avg Days")
                            .frame(width: 74, alignment: .trailing)
                        Text("Sessions")
                            .frame(width: 64, alignment: .trailing)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    ForEach(summary.muscleGroupSpacing) { row in
                        HStack {
                            Text(row.muscleGroup.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(row.averageDaysBetween.map { formatDecimal($0, digits: 1) } ?? "—")
                                .frame(width: 74, alignment: .trailing)
                                .monospacedDigit()
                            Text("\(row.sessionsCount)")
                                .frame(width: 64, alignment: .trailing)
                                .monospacedDigit()
                        }
                        .font(.caption)
                    }
                }
                .padding(.top, 4)
            }
        }
        .glassCard()
    }

    private func liftInsightMetricRow(title: String, value: String, detail: String, info: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                InsightInfoButton(message: info)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .appRowStyle()
    }

    private func muscleGroupColor(for group: MuscleGroup) -> Color {
        switch group {
        case .chest:
            return Color(red: 0.92, green: 0.39, blue: 0.22)
        case .back:
            return Color(red: 0.12, green: 0.57, blue: 0.86)
        case .legs:
            return Color(red: 0.20, green: 0.66, blue: 0.42)
        case .shoulders:
            return Color(red: 0.99, green: 0.65, blue: 0.18)
        case .arms:
            return Color(red: 0.75, green: 0.33, blue: 0.85)
        case .core:
            return Color(red: 0.55, green: 0.47, blue: 0.41)
        case .other:
            return .gray
        }
    }

    private func formatSignedWeight(_ value: Double) -> String {
        let sign = value >= 0 ? "+" : "-"
        return "\(sign)\(formatWeight(abs(value)))"
            .replacingOccurrences(of: "\(weightUnit)", with: "")
            .trimmingCharacters(in: .whitespaces)
            + " \(weightUnit)"
    }

    private func formatPushPullRatio(_ summary: MuscleGroupSummary) -> String {
        guard summary.pushVolume > 0 || summary.pullVolume > 0 else {
            return "No push/pull volume"
        }
        guard let ratio = summary.pushPullRatio else {
            return "Push only"
        }
        return "\(formatDecimal(ratio, digits: 1)) : 1"
    }

    private func pushPullStatusText(_ summary: MuscleGroupSummary) -> String {
        guard let ratio = summary.pushPullRatio else {
            if summary.pullVolume > 0 {
                return "Pull-dominant (no push volume captured)."
            }
            return "Pull volume is zero, so ratio cannot be balanced yet."
        }
        if ratio < 0.8 {
            return "Imbalance indicator: low push relative to pull."
        }
        if ratio > 1.25 {
            return "Imbalance indicator: high push relative to pull."
        }
        return "Within suggested range (0.8 to 1.25)."
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
            SectionHeader("Cumulative Distance") {
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
            SectionHeader("Pace Distribution") {
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
            SectionHeader("PR Progression") {
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
            SectionHeader("Elevation Profile") {
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
            SectionHeader("Best Segments") {
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
            SectionHeader("Exercise Analysis") {
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
            SectionHeader("Estimated 1RM")

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
            SectionHeader("Max Weight Progression")

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
            SectionHeader("Volume Per Workout")

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
            SectionHeader("Reps At Specific Weight")

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
            SectionHeader("Exercise Frequency")

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
            SectionHeader(title)
            Text(description)
                .foregroundStyle(.secondary)
            PrimaryButton("Start Session") {
                NotificationCenter.default.post(name: .navigateToWorkoutTab, object: nil)
            }
            .accessibilityHint("Switches to Workout tab")
        }
        .glassCard()
    }

    private func insightStatTile(title: String, value: String, subtitle: String, accent: Color) -> some View {
        StatChip(title: title, value: value, subtitle: subtitle, accent: accent)
    }

    private func elevationMetricPill(title: String, value: String) -> some View {
        StatChip(title: title, value: value)
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

    private func filteredLiftingSessions(for range: InsightsTimeRange) -> [WorkoutSession] {
        guard let cutoff = cutoffDate(for: range) else { return allLiftingSessions }
        return allLiftingSessions.filter { $0.completedAt >= cutoff }
    }

    private func refreshLiftingSnapshotIfNeeded(for range: InsightsTimeRange, force: Bool = false) {
        if !force, liftingInsightsCache[range] != nil {
            return
        }

        let sessions = filteredLiftingSessions(for: range)
        let rangeStart = cutoffDate(for: range)
        let rangeEnd = Date()
        loadingLiftingRange = range

        Task {
            let snapshot = await LiftingInsightsComputationService.computeSnapshot(
                sessions: sessions,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                calendar: calendar
            )

            guard !Task.isCancelled else { return }
            await MainActor.run {
                liftingInsightsCache[range] = snapshot
                if loadingLiftingRange == range {
                    loadingLiftingRange = nil
                }
            }
        }
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
        return LiftingInsightsAggregator.usableSets(from: allSets)
    }

    private func estimateOneRM(weight: Double, reps: Int) -> Double {
        LiftingInsightsAggregator.estimateOneRM(weight: weight, reps: reps)
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
