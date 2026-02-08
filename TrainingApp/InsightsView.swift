import SwiftUI

extension Notification.Name {
    static let navigateToWorkoutTab = Notification.Name("navigateToWorkoutTab")
}

struct InsightsView: View {
    @EnvironmentObject private var store: TrainingStore

    private static let loadFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private var hasSessionData: Bool {
        !store.state.sessions.isEmpty
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
}
