import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DataTransferSectionView: View {
    @EnvironmentObject private var store: TrainingStore

    @State private var showImportPicker = false
    @State private var selectedImportURL: URL?
    @State private var skipDuplicates = true
    @State private var importSummary: ImportSummary?
    @State private var showImportSummarySheet = false
    @State private var shareItem: ShareItem?

    @State private var isProcessing = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private static var csvImportTypes: [UTType] {
        var contentTypes: [UTType] = [.commaSeparatedText]
        if let explicitCSV = UTType(filenameExtension: "csv"), !contentTypes.contains(explicitCSV) {
            contentTypes.append(explicitCSV)
        }
        return contentTypes
    }

    private let maxVisibleErrors = 15

    var body: some View {
        Group {
            Button {
                showImportPicker = true
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }
            .disabled(isProcessing)

            Button {
                exportCSV()
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }
            .disabled(isProcessing)

            if isProcessing {
                SwiftUI.ProgressView("Working...")
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: Self.csvImportTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .sheet(isPresented: $showImportSummarySheet) {
            NavigationStack {
                List {
                    Section("Summary") {
                        if let importSummary {
                            summaryRow(title: "Workouts", value: importSummary.workoutsCount)
                            summaryRow(title: "Exercises", value: importSummary.exercisesCount)
                            summaryRow(title: "Sets", value: importSummary.setsCount)

                            if importSummary.skippedDuplicatesCount > 0 {
                                summaryRow(title: "Duplicates skipped", value: importSummary.skippedDuplicatesCount)
                            }
                        } else {
                            Text("No preview available.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Toggle("Skip duplicates", isOn: $skipDuplicates)
                    } footer: {
                        Text("When enabled, duplicate sets are ignored by matching date, workout, exercise, set order, and key set values.")
                    }

                    if let importSummary, !importSummary.rowErrors.isEmpty {
                        Section("Row Errors (\(importSummary.rowErrors.count))") {
                            ForEach(Array(importSummary.rowErrors.prefix(maxVisibleErrors).enumerated()), id: \.offset) { _, error in
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if importSummary.rowErrors.count > maxVisibleErrors {
                                Text("Showing first \(maxVisibleErrors) errors.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Import CSV")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showImportSummarySheet = false
                            selectedImportURL = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            commitImport()
                        }
                        .disabled(isProcessing || (importSummary?.setsCount ?? 0) == 0)
                    }
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(activityItems: [item.url])
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .onChange(of: skipDuplicates) { _, _ in
            guard showImportSummarySheet, let selectedImportURL else { return }
            previewImport(url: selectedImportURL)
        }
    }

    private func summaryRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
        }
    }

    private func handleImportSelection(_ result: Result<[URL], any Error>) {
        switch result {
        case let .failure(error):
            showError(title: "Import Failed", message: error.localizedDescription)
        case let .success(urls):
            guard let url = urls.first else { return }
            selectedImportURL = url
            previewImport(url: url)
        }
    }

    private func previewImport(url: URL) {
        isProcessing = true
        Task {
            do {
                let summary = try await store.previewStrongCSVImport(from: url, skipDuplicates: skipDuplicates)
                await MainActor.run {
                    importSummary = summary
                    showImportSummarySheet = true
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError(title: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func commitImport() {
        guard let importURL = selectedImportURL else { return }

        isProcessing = true
        Task {
            do {
                let summary = try await store.importStrongCSV(from: importURL, skipDuplicates: skipDuplicates)
                await MainActor.run {
                    importSummary = summary
                    showImportSummarySheet = false
                    selectedImportURL = nil
                    isProcessing = false

                    alertTitle = "Import Complete"
                    alertMessage = "Imported \(summary.workoutsCount) workouts, \(summary.exercisesCount) exercises, and \(summary.setsCount) sets."
                    if summary.skippedDuplicatesCount > 0 {
                        alertMessage += " Skipped \(summary.skippedDuplicatesCount) duplicates."
                    }
                    if !summary.rowErrors.isEmpty {
                        alertMessage += " \(summary.rowErrors.count) rows had errors and were skipped."
                    }
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError(title: "Import Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func exportCSV() {
        isProcessing = true

        Task {
            do {
                let url = try await store.exportStrongCSVFile()
                await MainActor.run {
                    isProcessing = false
                    shareItem = ShareItem(url: url)
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    showError(title: "Export Failed", message: error.localizedDescription)
                }
            }
        }
    }

    private func showError(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}

private struct ShareItem: Identifiable {
    var id = UUID()
    var url: URL
}

private struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        uiViewController.completionWithItemsHandler = { _, _, _, _ in }
    }
}
