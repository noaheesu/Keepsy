import AVFoundation
import SwiftUI
import VisionKit

enum PackageDate {
    /// Finds dates as printed on packages ("2026.10.25", "26-10-25", "2026년 10월 25일", "20261025").
    /// Packages often also show a production date, so the latest plausible date wins.
    static func parse(_ text: String, now: Date = .now, calendar: Calendar = .current) -> Date? {
        let separated = /(?:20)?(\d{2})\s*[.\-\/년]\s*(\d{1,2})\s*[.\-\/월]\s*(\d{1,2})/
        let compact = /20(\d{2})(\d{2})(\d{2})/
        let candidates = text.matches(of: separated).map { ($0.1, $0.2, $0.3) }
            + text.matches(of: compact).map { ($0.1, $0.2, $0.3) }
        let thisYear = calendar.component(.year, from: now)
        return candidates
            .compactMap { year, month, day -> Date? in
                guard let y = Int(year), let m = Int(month), let d = Int(day) else { return nil }
                let parts = DateComponents(calendar: calendar, year: 2000 + y, month: m, day: d)
                guard parts.isValidDate, (thisYear - 1...thisYear + 10).contains(2000 + y) else { return nil }
                return parts.date
            }
            .max()
    }
}

/// Live camera text scanner that reports the first package date it reads.
struct DateScanner: UIViewControllerRepresentable {
    static var isSupported: Bool { DataScannerViewController.isSupported }

    /// Asks for the camera the first time; false means access is off and the user must enable it in Settings.
    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    let onDate: (Date) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .accurate, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onDate: onDate) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onDate: (Date) -> Void
        private var found = false

        init(onDate: @escaping (Date) -> Void) {
            self.onDate = onDate
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            let text = allItems.compactMap { item -> String? in
                if case .text(let text) = item { text.transcript } else { nil }
            }.joined(separator: "\n")
            guard !found, let date = PackageDate.parse(text) else { return }
            found = true
            onDate(date)
        }
    }
}

struct DateScannerSheet: View {
    let onDate: (Date) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DateScanner { date in
                onDate(date)
                dismiss()
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("Point the camera at the date on the package")
                    .padding()
                    .background(.regularMaterial, in: .capsule)
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
