import XCTest
@testable import TrainingApp

final class DataTransferServiceTests: XCTestCase {
    func testParseDurationSupportsStrongFormats() {
        XCTAssertEqual(DataTransferService.parseDuration("45m"), 45 * 60)
        XCTAssertEqual(DataTransferService.parseDuration("1h"), 60 * 60)
        XCTAssertEqual(DataTransferService.parseDuration("1h 5m"), (60 + 5) * 60)
        XCTAssertEqual(DataTransferService.parseDuration("48h 12m"), (48 * 60 + 12) * 60)
        XCTAssertNil(DataTransferService.parseDuration("5x"))
    }

    func testFormatDurationUsesStrongPatterns() {
        XCTAssertEqual(DataTransferService.formatDuration(45 * 60), "45m")
        XCTAssertEqual(DataTransferService.formatDuration(60 * 60), "1h")
        XCTAssertEqual(DataTransferService.formatDuration((60 + 5) * 60), "1h 5m")
    }

    func testStrongDateRoundTrip() throws {
        let input = "2023-09-18 20:04:10"
        let parsed = try XCTUnwrap(DataTransferService.parseStrongDate(input))
        XCTAssertEqual(DataTransferService.formatStrongDate(parsed), input)
    }

    func testCSVParserHandlesQuotesCommasAndEmbeddedNewlines() {
        let csv = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,RPE",
            "2023-09-18 20:04:10,\"Push, Day\",45m,\"Bench \"\"Heavy\"\"\",1,100,5,,,",
            "2023-09-18 20:04:10,Workout,45m,\"Line",
            "Break\",2,110,6,,,"
        ].joined(separator: "\n")

        let records = StrongCSVParser.parse(csv)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[1][1], "Push, Day")
        XCTAssertEqual(records[1][3], "Bench \"Heavy\"")
        XCTAssertEqual(records[2][3], "Line\nBreak")
    }

    func testGroupingCreatesOneSessionAndSortsBySetOrder() throws {
        let csv = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,RPE",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,2,185,5,,,",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,1,175,5,,,",
            "2023-09-18 20:04:10,Upper,45m,Barbell Row,1,135,8,,,"
        ].joined(separator: "\n")

        let service = DataTransferService(existingSessions: [])
        let result = try service.prepareStrongImport(csvText: csv, skipDuplicates: true)

        XCTAssertEqual(result.summary.workoutsCount, 1)
        XCTAssertEqual(result.summary.exercisesCount, 2)
        XCTAssertEqual(result.summary.setsCount, 3)

        let session = try XCTUnwrap(result.sessions.first)
        let bench = try XCTUnwrap(session.exercises.first { $0.name == "Bench Press" })
        XCTAssertEqual(bench.sets.map(\.weight), [175, 185])
    }

    func testSkipDuplicatesSkipsMatchingExistingSetHeuristic() throws {
        let startedAt = try XCTUnwrap(DataTransferService.parseStrongDate("2023-09-18 20:04:10"))
        let existingSession = WorkoutSession(
            name: "Upper",
            startedAt: startedAt,
            completedAt: startedAt.addingTimeInterval(45 * 60),
            notes: "",
            elapsedSeconds: 45 * 60,
            exercises: [
                LoggedExercise(
                    definitionID: nil,
                    name: "Bench Press",
                    notes: "",
                    sets: [LoggedSet(reps: 5, weight: 185)]
                )
            ],
            run: nil,
            achievements: []
        )

        let csv = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,RPE",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,1,185,5,,,"
        ].joined(separator: "\n")

        let service = DataTransferService(existingSessions: [existingSession])
        let result = try service.prepareStrongImport(csvText: csv, skipDuplicates: true)

        XCTAssertEqual(result.summary.setsCount, 0)
        XCTAssertEqual(result.summary.skippedDuplicatesCount, 1)
        XCTAssertEqual(result.summary.workoutsCount, 0)
    }

    func testWholeNumberDecimalsAreAcceptedForRepsAndSetOrder() throws {
        let csv = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,RPE",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,2.0,185,11.0,,,",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,1.0,175,10.0,,,"
        ].joined(separator: "\n")

        let service = DataTransferService(existingSessions: [])
        let result = try service.prepareStrongImport(csvText: csv, skipDuplicates: true)

        XCTAssertTrue(result.summary.rowErrors.isEmpty)
        XCTAssertEqual(result.summary.setsCount, 2)

        let session = try XCTUnwrap(result.sessions.first)
        let bench = try XCTUnwrap(session.exercises.first(where: { $0.name == "Bench Press" }))
        XCTAssertEqual(bench.sets.map(\.reps), [10, 11])
    }

    func testFractionalRepsAreRejected() throws {
        let csv = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,RPE",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,1,185,11.5,,,"
        ].joined(separator: "\n")

        let service = DataTransferService(existingSessions: [])
        let result = try service.prepareStrongImport(csvText: csv, skipDuplicates: true)

        XCTAssertEqual(result.summary.setsCount, 0)
        XCTAssertEqual(result.summary.workoutsCount, 0)
        XCTAssertEqual(result.summary.rowErrors.count, 1)
        XCTAssertTrue(result.summary.rowErrors[0].contains("invalid reps"))
    }

    func testHeaderAliasesAndOrderAreSupported() throws {
        let csv = [
            "Exercise,Date Time,Set #,Workout,RPE Value,Duration,Load,Repetitions,Dist,Sec",
            "Bench Press,2023-09-18 20:04:10,1.0,Upper,8.5,45m,185,11.0,0,0"
        ].joined(separator: "\n")

        let service = DataTransferService(existingSessions: [])
        let result = try service.prepareStrongImport(csvText: csv, skipDuplicates: true)

        XCTAssertTrue(result.summary.rowErrors.isEmpty)
        XCTAssertEqual(result.summary.workoutsCount, 1)
        XCTAssertEqual(result.summary.exercisesCount, 1)
        XCTAssertEqual(result.summary.setsCount, 1)
    }

    func testMissingRequiredHeaderShowsClearError() {
        let csv = [
            "Date,Workout Name,Duration,Exercise Name,Set Order,Weight,Distance,Seconds,RPE",
            "2023-09-18 20:04:10,Upper,45m,Bench Press,1,185,,,"
        ].joined(separator: "\n")

        let service = DataTransferService(existingSessions: [])

        XCTAssertThrowsError(try service.prepareStrongImport(csvText: csv, skipDuplicates: true)) { error in
            guard let transferError = error as? DataTransferServiceError else {
                return XCTFail("Expected DataTransferServiceError, received \(error)")
            }
            let description = transferError.localizedDescription
            XCTAssertTrue(description.contains("Missing required columns"))
            XCTAssertTrue(description.contains("Reps"))
        }
    }
}
