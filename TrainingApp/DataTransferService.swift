import Foundation

struct ImportSummary: Equatable {
    var workoutsCount: Int
    var exercisesCount: Int
    var setsCount: Int
    var skippedDuplicatesCount: Int
    var rowErrors: [String]
}

struct StrongImportResult {
    var summary: ImportSummary
    var sessions: [WorkoutSession]
    var importedExerciseNames: Set<String>
}

enum DataTransferServiceError: LocalizedError {
    case unreadableCSV
    case emptyCSV
    case invalidHeader(expected: [String], found: [String])
    case headerMappingFailed(missingFields: [String], ambiguousFields: [String], found: [String])

    var errorDescription: String? {
        switch self {
        case .unreadableCSV:
            return "Unable to read CSV file. Please verify the file is a valid text CSV."
        case .emptyCSV:
            return "The selected CSV file is empty."
        case let .invalidHeader(expected, found):
            let expectedText = expected.joined(separator: ",")
            let foundText = found.joined(separator: ",")
            return "Unexpected CSV header. Expected: \(expectedText). Found: \(foundText)."
        case let .headerMappingFailed(missingFields, ambiguousFields, found):
            var parts: [String] = []
            if !missingFields.isEmpty {
                parts.append("Missing required columns: \(missingFields.joined(separator: ", ")).")
            }
            if !ambiguousFields.isEmpty {
                parts.append("Ambiguous column mappings: \(ambiguousFields.joined(separator: "; ")).")
            }
            parts.append("Found header: \(found.joined(separator: ",")).")
            return parts.joined(separator: " ")
        }
    }
}

private struct StrongRowParseError: Error {
    var message: String
}

private struct StrongImportRow {
    var rowNumber: Int
    var startedAt: Date
    var workoutName: String
    var durationSeconds: Int
    var exerciseName: String
    var setOrder: Int
    var weight: Double
    var reps: Int
    var distance: Double?
    var seconds: Double?
    var rpe: Double?

    var duplicateKey: StrongSetDuplicateKey {
        StrongSetDuplicateKey(
            startedAtEpochSecond: Int(startedAt.timeIntervalSince1970.rounded()),
            workoutName: workoutName,
            exerciseName: exerciseName,
            setOrder: setOrder,
            weight: weight,
            reps: reps,
            distance: distance ?? 0,
            seconds: seconds ?? 0
        )
    }
}

private struct StrongSessionKey: Hashable {
    var startedAtEpochSecond: Int
    var workoutName: String
}

private struct StrongSetDuplicateKey: Hashable {
    var startedAtEpochSecond: Int
    var workoutName: String
    var exerciseName: String
    var setOrder: Int
    var weight: String
    var reps: Int
    var distance: String
    var seconds: String

    init(
        startedAtEpochSecond: Int,
        workoutName: String,
        exerciseName: String,
        setOrder: Int,
        weight: Double,
        reps: Int,
        distance: Double,
        seconds: Double
    ) {
        self.startedAtEpochSecond = startedAtEpochSecond
        self.workoutName = Self.normalize(workoutName)
        self.exerciseName = Self.normalize(exerciseName)
        self.setOrder = setOrder
        self.weight = Self.normalize(weight)
        self.reps = reps
        self.distance = Self.normalize(distance)
        self.seconds = Self.normalize(seconds)
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalize(_ value: Double) -> String {
        String(format: "%.4f", value)
    }
}

private enum StrongCSVField: CaseIterable {
    case date
    case workoutName
    case duration
    case exerciseName
    case setOrder
    case weight
    case reps
    case distance
    case seconds
    case rpe

    var title: String {
        switch self {
        case .date:
            return "Date"
        case .workoutName:
            return "Workout Name"
        case .duration:
            return "Duration"
        case .exerciseName:
            return "Exercise Name"
        case .setOrder:
            return "Set Order"
        case .weight:
            return "Weight"
        case .reps:
            return "Reps"
        case .distance:
            return "Distance"
        case .seconds:
            return "Seconds"
        case .rpe:
            return "RPE"
        }
    }

    var aliases: [String] {
        switch self {
        case .date:
            return ["Date", "Date Time", "Started At", "Start Time", "Timestamp"]
        case .workoutName:
            return ["Workout Name", "Workout", "Workout Title", "Session Name", "Name"]
        case .duration:
            return ["Duration", "Workout Duration", "Elapsed", "Elapsed Time"]
        case .exerciseName:
            return ["Exercise Name", "Exercise", "Movement", "Lift Name"]
        case .setOrder:
            return ["Set Order", "Set", "Set Number", "Set #", "Set Index", "Order"]
        case .weight:
            return ["Weight", "Load"]
        case .reps:
            return ["Reps", "Rep", "Repetitions"]
        case .distance:
            return ["Distance", "Dist"]
        case .seconds:
            return ["Seconds", "Sec", "Set Seconds", "Time Seconds", "Set Time"]
        case .rpe:
            return ["RPE", "RPE Value", "Effort"]
        }
    }
}

struct DataTransferService {
    static let strongCSVHeader = [
        "Date",
        "Workout Name",
        "Duration",
        "Exercise Name",
        "Set Order",
        "Weight",
        "Reps",
        "Distance",
        "Seconds",
        "RPE"
    ]

    private let existingSessions: [WorkoutSession]

    init(existingSessions: [WorkoutSession]) {
        self.existingSessions = existingSessions
    }

    func previewStrongImport(url: URL, skipDuplicates: Bool) async throws -> StrongImportResult {
        let csvText = try readCSVText(from: url)
        return try prepareStrongImport(csvText: csvText, skipDuplicates: skipDuplicates)
    }

    func importStrongCSV(url: URL, skipDuplicates: Bool) async throws -> ImportSummary {
        let result = try await previewStrongImport(url: url, skipDuplicates: skipDuplicates)
        return result.summary
    }

    func prepareStrongImport(csvText: String, skipDuplicates: Bool) throws -> StrongImportResult {
        let records = StrongCSVParser.parse(csvText)
        guard !records.isEmpty else {
            throw DataTransferServiceError.emptyCSV
        }

        var header = records[0]
        if let first = header.first {
            header[0] = first.replacingOccurrences(of: "\u{feff}", with: "")
        }
        let columnIndexes = try resolveColumnIndexes(from: header)

        var duplicateKeys: Set<StrongSetDuplicateKey> = skipDuplicates
            ? existingDuplicateKeys()
            : []

        var parsedRows: [StrongImportRow] = []
        parsedRows.reserveCapacity(records.count)

        var rowErrors: [String] = []
        var skippedDuplicatesCount = 0

        for index in records.indices where index > 0 {
            let rowNumber = index + 1
            let columns = records[index]

            if columns.count == 1, columns[0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }

            switch parseStrongRow(columns, rowNumber: rowNumber, columnIndexes: columnIndexes) {
            case let .failure(error):
                rowErrors.append(error.message)
            case let .success(row):
                if skipDuplicates, duplicateKeys.contains(row.duplicateKey) {
                    skippedDuplicatesCount += 1
                    continue
                }
                if skipDuplicates {
                    duplicateKeys.insert(row.duplicateKey)
                }
                parsedRows.append(row)
            }
        }

        let grouped = groupedSessions(from: parsedRows)

        let summary = ImportSummary(
            workoutsCount: grouped.sessions.count,
            exercisesCount: grouped.exerciseCount,
            setsCount: grouped.setCount,
            skippedDuplicatesCount: skippedDuplicatesCount,
            rowErrors: rowErrors
        )

        return StrongImportResult(
            summary: summary,
            sessions: grouped.sessions,
            importedExerciseNames: grouped.importedExerciseNames
        )
    }

    func exportStrongCSV() async throws -> URL {
        var lines: [String] = [Self.strongCSVHeader.map(Self.escapeCSVField).joined(separator: ",")]

        for session in existingSessions.sorted(by: { $0.startedAt < $1.startedAt }) {
            let dateText = Self.formatStrongDate(session.startedAt)
            let durationText = Self.formatDuration(session.elapsedSeconds)
            let workoutName = session.name

            for exercise in session.exercises {
                for (index, set) in exercise.sets.enumerated() {
                    let columns = [
                        dateText,
                        workoutName,
                        durationText,
                        exercise.name,
                        String(index + 1),
                        Self.formatNumber(set.weight),
                        String(set.reps),
                        set.distance.map(Self.formatNumber) ?? "",
                        set.seconds.map(Self.formatNumber) ?? "",
                        set.rpe.map(Self.formatNumber) ?? ""
                    ]

                    lines.append(columns.map(Self.escapeCSVField).joined(separator: ","))
                }
            }
        }

        let csv = lines.joined(separator: "\n") + "\n"
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("workouts-export")
            .appendingPathExtension("csv")

        if FileManager.default.fileExists(atPath: exportURL.path) {
            try? FileManager.default.removeItem(at: exportURL)
        }
        try csv.data(using: .utf8)?.write(to: exportURL, options: .atomic)

        return exportURL
    }

    static func parseDuration(_ rawValue: String) -> Int? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        let parts = trimmed.split(separator: " ")
        if parts.count == 1 {
            if let hours = parseDurationComponent(parts[0], suffix: "h") {
                return hours * 3600
            }
            if let minutes = parseDurationComponent(parts[0], suffix: "m") {
                return minutes * 60
            }
            return nil
        }

        if parts.count == 2,
           let hours = parseDurationComponent(parts[0], suffix: "h"),
           let minutes = parseDurationComponent(parts[1], suffix: "m") {
            return (hours * 3600) + (minutes * 60)
        }

        return nil
    }

    static func formatDuration(_ seconds: Int) -> String {
        let totalMinutes = max(0, seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(totalMinutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }

    static func parseStrongDate(_ rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return makeStrongDateFormatter().date(from: trimmed)
    }

    static func formatStrongDate(_ date: Date) -> String {
        makeStrongDateFormatter().string(from: date)
    }

    private static func makeStrongDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private static func parseDurationComponent(_ raw: Substring, suffix: Character) -> Int? {
        guard raw.last == suffix else { return nil }
        let value = raw.dropLast()
        guard let parsed = Int(value), parsed >= 0 else { return nil }
        return parsed
    }

    private func readCSVText(from url: URL) throws -> String {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1) {
            return text
        }

        throw DataTransferServiceError.unreadableCSV
    }

    private func parseStrongRow(
        _ columns: [String],
        rowNumber: Int,
        columnIndexes: [StrongCSVField: Int]
    ) -> Result<StrongImportRow, StrongRowParseError> {
        let dateRaw = columnValue(.date, from: columns, using: columnIndexes).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let startedAt = Self.parseStrongDate(dateRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid date: \(columnValue(.date, from: columns, using: columnIndexes))"))
        }

        let workoutName = sanitizeName(columnValue(.workoutName, from: columns, using: columnIndexes), fallback: "Workout")

        let durationRaw = columnValue(.duration, from: columns, using: columnIndexes)
        guard let durationSeconds = Self.parseDuration(durationRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid duration: \(durationRaw)"))
        }

        let exerciseName = sanitizeName(columnValue(.exerciseName, from: columns, using: columnIndexes), fallback: "")
        guard !exerciseName.isEmpty else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) missing exercise name."))
        }

        let setOrderRaw = columnValue(.setOrder, from: columns, using: columnIndexes)
        guard let setOrder = parseRequiredWholeNumber(setOrderRaw), setOrder > 0 else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid set order: \(setOrderRaw)"))
        }

        let weightRaw = columnValue(.weight, from: columns, using: columnIndexes)
        guard let weight = parseOptionalDouble(weightRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid weight: \(weightRaw)"))
        }

        let repsRaw = columnValue(.reps, from: columns, using: columnIndexes)
        guard let reps = parseOptionalWholeNumber(repsRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid reps: \(repsRaw)"))
        }

        let distanceRaw = columnValue(.distance, from: columns, using: columnIndexes)
        guard let distance = parseNullableDouble(distanceRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid distance: \(distanceRaw)"))
        }

        let secondsRaw = columnValue(.seconds, from: columns, using: columnIndexes)
        guard let seconds = parseNullableDouble(secondsRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid seconds: \(secondsRaw)"))
        }

        let rpeRaw = columnValue(.rpe, from: columns, using: columnIndexes)
        guard let rpe = parseNullableDouble(rpeRaw) else {
            return .failure(StrongRowParseError(message: "Row \(rowNumber) invalid RPE: \(rpeRaw)"))
        }

        return .success(
            StrongImportRow(
                rowNumber: rowNumber,
                startedAt: startedAt,
                workoutName: workoutName,
                durationSeconds: durationSeconds,
                exerciseName: exerciseName,
                setOrder: setOrder,
                weight: max(0, weight),
                reps: max(0, reps),
                distance: distance,
                seconds: seconds,
                rpe: rpe
            )
        )
    }

    private func sanitizeName(_ rawValue: String, fallback: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func parseRequiredWholeNumber(_ rawValue: String) -> Int? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return parseWholeNumber(trimmed)
    }

    private func parseOptionalWholeNumber(_ rawValue: String) -> Int? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return parseWholeNumber(trimmed)
    }

    private func parseOptionalDouble(_ rawValue: String) -> Double? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return Double(trimmed)
    }

    private func parseNullableDouble(_ rawValue: String) -> Double?? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        guard let value = Double(trimmed) else { return nil }
        return .some(max(0, value))
    }

    private func parseWholeNumber(_ rawValue: String) -> Int? {
        if let integer = Int(rawValue) {
            return integer
        }

        guard let decimal = Double(rawValue), decimal.isFinite else {
            return nil
        }

        guard abs(decimal.truncatingRemainder(dividingBy: 1)) < 0.000_000_1 else {
            return nil
        }

        return Int(decimal.rounded())
    }

    private func resolveColumnIndexes(from header: [String]) throws -> [StrongCSVField: Int] {
        guard !header.isEmpty else {
            throw DataTransferServiceError.invalidHeader(expected: Self.strongCSVHeader, found: header)
        }

        let normalizedHeaders = header.map { normalizeHeaderName($0) }

        var indexesByField: [StrongCSVField: Int] = [:]
        var missingFields: [String] = []
        var ambiguousFields: [String] = []

        for field in StrongCSVField.allCases {
            let normalizedAliases = Set(field.aliases.map(normalizeHeaderName))
            let matchingIndexes = normalizedHeaders.enumerated().compactMap { index, normalized in
                normalizedAliases.contains(normalized) ? index : nil
            }

            if matchingIndexes.count == 1, let index = matchingIndexes.first {
                indexesByField[field] = index
            } else if matchingIndexes.isEmpty {
                missingFields.append(field.title)
            } else {
                let matches = matchingIndexes.map { "\(header[$0]) (col \($0 + 1))" }.joined(separator: ", ")
                ambiguousFields.append("\(field.title): \(matches)")
            }
        }

        if !missingFields.isEmpty || !ambiguousFields.isEmpty {
            throw DataTransferServiceError.headerMappingFailed(
                missingFields: missingFields,
                ambiguousFields: ambiguousFields,
                found: header
            )
        }

        return indexesByField
    }

    private func columnValue(
        _ field: StrongCSVField,
        from columns: [String],
        using indexesByField: [StrongCSVField: Int]
    ) -> String {
        guard let index = indexesByField[field], index >= 0, index < columns.count else {
            return ""
        }
        return columns[index]
    }

    private func normalizeHeaderName(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }

    private func groupedSessions(from rows: [StrongImportRow]) -> (
        sessions: [WorkoutSession],
        exerciseCount: Int,
        setCount: Int,
        importedExerciseNames: Set<String>
    ) {
        var groupedBySession: [StrongSessionKey: [StrongImportRow]] = [:]
        var orderedSessionKeys: [StrongSessionKey] = []

        for row in rows {
            let sessionKey = StrongSessionKey(
                startedAtEpochSecond: Int(row.startedAt.timeIntervalSince1970.rounded()),
                workoutName: row.workoutName
            )
            if groupedBySession[sessionKey] == nil {
                orderedSessionKeys.append(sessionKey)
            }
            groupedBySession[sessionKey, default: []].append(row)
        }

        var sessions: [WorkoutSession] = []
        var totalExerciseCount = 0
        var importedExerciseNames: Set<String> = []

        for key in orderedSessionKeys {
            guard let sessionRows = groupedBySession[key], !sessionRows.isEmpty else { continue }

            let sortedRows = sessionRows.sorted { left, right in
                if left.setOrder == right.setOrder {
                    return left.rowNumber < right.rowNumber
                }
                return left.setOrder < right.setOrder
            }

            var exercisesByName: [String: [StrongImportRow]] = [:]
            var orderedExerciseNames: [String] = []

            for row in sortedRows {
                let exerciseName = row.exerciseName
                if exercisesByName[exerciseName] == nil {
                    orderedExerciseNames.append(exerciseName)
                }
                exercisesByName[exerciseName, default: []].append(row)
            }

            var exercises: [LoggedExercise] = []

            for exerciseName in orderedExerciseNames {
                guard var exerciseRows = exercisesByName[exerciseName], !exerciseRows.isEmpty else { continue }
                exerciseRows.sort { left, right in
                    if left.setOrder == right.setOrder {
                        return left.rowNumber < right.rowNumber
                    }
                    return left.setOrder < right.setOrder
                }

                let sets = exerciseRows.map { row in
                    LoggedSet(
                        reps: row.reps,
                        weight: row.weight,
                        style: .working,
                        isCompleted: true,
                        distance: row.distance,
                        seconds: row.seconds,
                        rpe: row.rpe
                    )
                }

                guard !sets.isEmpty else { continue }

                exercises.append(
                    LoggedExercise(
                        definitionID: nil,
                        name: exerciseName,
                        notes: "",
                        sets: sets
                    )
                )
                totalExerciseCount += 1
                importedExerciseNames.insert(exerciseName)
            }

            guard !exercises.isEmpty else { continue }

            let first = sessionRows[0]
            let startedAt = first.startedAt
            let duration = max(0, sessionRows.map(\.durationSeconds).max() ?? 0)
            let completedAt = startedAt.addingTimeInterval(TimeInterval(duration))

            let session = WorkoutSession(
                name: first.workoutName,
                startedAt: startedAt,
                completedAt: completedAt,
                notes: "",
                elapsedSeconds: duration,
                exercises: exercises,
                run: nil,
                achievements: []
            )

            sessions.append(session)
        }

        sessions.sort { $0.completedAt < $1.completedAt }

        return (
            sessions: sessions,
            exerciseCount: totalExerciseCount,
            setCount: rows.count,
            importedExerciseNames: importedExerciseNames
        )
    }

    private func existingDuplicateKeys() -> Set<StrongSetDuplicateKey> {
        var keys: Set<StrongSetDuplicateKey> = []

        for session in existingSessions {
            let startedAtEpochSecond = Int(session.startedAt.timeIntervalSince1970.rounded())
            for exercise in session.exercises {
                for (index, set) in exercise.sets.enumerated() {
                    let key = StrongSetDuplicateKey(
                        startedAtEpochSecond: startedAtEpochSecond,
                        workoutName: session.name,
                        exerciseName: exercise.name,
                        setOrder: index + 1,
                        weight: set.weight,
                        reps: set.reps,
                        distance: set.distance ?? 0,
                        seconds: set.seconds ?? 0
                    )
                    keys.insert(key)
                }
            }
        }

        return keys
    }

    private static func formatNumber(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.000_1 {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.4f", value).replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    private static func escapeCSVField(_ rawValue: String) -> String {
        let needsQuotes = rawValue.contains(",")
            || rawValue.contains("\n")
            || rawValue.contains("\r")
            || rawValue.contains("\"")

        guard needsQuotes else {
            return rawValue
        }

        let escaped = rawValue.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

struct StrongCSVParser {
    static func parse(_ text: String) -> [[String]] {
        guard !text.isEmpty else { return [] }

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var index = text.startIndex
        var inQuotes = false

        while index < text.endIndex {
            let character = text[index]

            if inQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = nextIndex
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
                index = text.index(after: index)
                continue
            }

            switch character {
            case "\"":
                inQuotes = true
            case ",":
                currentRow.append(currentField)
                currentField = ""
            case "\n":
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            case "\r":
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""

                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = nextIndex
                }
            default:
                currentField.append(character)
            }

            index = text.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}

extension TrainingStore {
    func previewStrongCSVImport(from url: URL, skipDuplicates: Bool) async throws -> ImportSummary {
        let service = DataTransferService(existingSessions: state.sessions)
        let result = try await service.previewStrongImport(url: url, skipDuplicates: skipDuplicates)
        return result.summary
    }

    func importStrongCSV(from url: URL, skipDuplicates: Bool) async throws -> ImportSummary {
        let service = DataTransferService(existingSessions: state.sessions)
        let result = try await service.previewStrongImport(url: url, skipDuplicates: skipDuplicates)

        guard !result.sessions.isEmpty else {
            return result.summary
        }

        state.sessions.append(contentsOf: result.sessions)
        state.sessions.sort { $0.completedAt < $1.completedAt }

        var existingExerciseNames = Set(
            state.exerciseLibrary.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )

        for importedName in result.importedExerciseNames {
            let normalized = importedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { continue }
            guard !existingExerciseNames.contains(normalized) else { continue }

            state.exerciseLibrary.append(
                ExerciseDefinition(
                    name: importedName,
                    category: .custom,
                    isCustom: true,
                    equipment: .none
                )
            )
            existingExerciseNames.insert(normalized)
        }

        return result.summary
    }

    func exportStrongCSVFile() async throws -> URL {
        let service = DataTransferService(existingSessions: state.sessions)
        return try await service.exportStrongCSV()
    }
}
